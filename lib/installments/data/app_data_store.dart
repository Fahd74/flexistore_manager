import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/native_bridge.dart';
import '../../core/db_models.dart';

/// DB-backed reactive data store — replaces the old MockDataStore.
/// All reads/writes go through [NativeBridge] → C++ FFI → MySQL.
class AppDataStore {
  AppDataStore._();
  static final AppDataStore instance = AppDataStore._();

  final _bridge = NativeBridge();
  bool _isMockMode = false;
  int _mockPlanId = 100;

  // ── Notifiers ──────────────────────────────────────────────────────────────
  final ValueNotifier<List<DbClient>>          clientsNotifier      = ValueNotifier([]);
  final ValueNotifier<List<DbProduct>>         productsNotifier     = ValueNotifier([]);
  final ValueNotifier<List<DbInstallmentPlan>> installmentsNotifier = ValueNotifier([]);

  // ── Convenience getters ────────────────────────────────────────────────────
  List<DbClient>          get clients      => clientsNotifier.value;
  List<DbProduct>         get products     => productsNotifier.value;
  List<DbInstallmentPlan> get installments => installmentsNotifier.value;

  // ── Load / Refresh ─────────────────────────────────────────────────────────
  void refreshClients() {
    if (_isMockMode) return;
    clientsNotifier.value = parseClients(_bridge.getAllClients());
  }

  void refreshProducts() {
    if (_isMockMode) return;
    productsNotifier.value = parseProducts(_bridge.getAllProducts());
  }

  void refreshInstallments() {
    if (_isMockMode) return;
    installmentsNotifier.value = parseInstallments(_bridge.getAllInstallments());
  }

  /// Call once at app startup after initializeDatabase().
  void loadAll() {
    refreshClients();
    refreshProducts();
    refreshInstallments();
  }

  /// Populates the notifiers with hardcoded mock data for testing/demo.
  void applyMockData() {
    _isMockMode = true;
    clientsNotifier.value = [
      const DbClient(id: 1, name: 'Sarah Smith',   phone: '+1 555-001', totalDebt: 800),
      const DbClient(id: 2, name: 'David Brown',   phone: '+1 555-002', totalDebt: 1600),
      const DbClient(id: 3, name: 'Emma Wilson',   phone: '+1 555-003', totalDebt: 150),
      const DbClient(id: 4, name: 'James Taylor',  phone: '+1 555-004', totalDebt: 0),
      const DbClient(id: 5, name: 'Olivia Martin', phone: '+1 555-005', totalDebt: 0),
    ];

    productsNotifier.value = [
      const DbProduct(id: 1, barcode: 'P001', name: 'iPhone 14 Pro', sellingPrice: 1200, stockQuantity: 5, status: 'active'),
      const DbProduct(id: 2, barcode: 'P002', name: 'MacBook Air M2', sellingPrice: 3200, stockQuantity: 12, status: 'active'),
      const DbProduct(id: 3, barcode: 'P003', name: 'iPad Pro', sellingPrice: 450, stockQuantity: 2, status: 'active'),
      const DbProduct(id: 4, barcode: 'P004', name: 'Samsung Galaxy S23', sellingPrice: 900, stockQuantity: 25, status: 'active'),
    ];

    installmentsNotifier.value = [
      const DbInstallmentPlan(
        id: 1, clientId: 1, clientName: 'Sarah Smith', clientPhone: '+1 555-001',
        invoiceId: 101, totalAmount: 1200, remainingAmount: 800, months: 6,
        monthlyInstallment: 200, status: 'active', createdAt: '2026-03-15',
        interestRate: 5.0,
      ),
      const DbInstallmentPlan(
        id: 2, clientId: 2, clientName: 'David Brown', clientPhone: '+1 555-002',
        invoiceId: 102, totalAmount: 3200, remainingAmount: 1600, months: 8,
        monthlyInstallment: 400, status: 'active', createdAt: '2026-01-10',
        interestRate: 8.5,
      ),
      const DbInstallmentPlan(
        id: 3, clientId: 3, clientName: 'Emma Wilson', clientPhone: '+1 555-003',
        invoiceId: 103, totalAmount: 450, remainingAmount: 0, months: 3,
        monthlyInstallment: 150, status: 'completed', createdAt: '2025-12-05',
        interestRate: 0.0,
      ),
      const DbInstallmentPlan(
        id: 4, clientId: 4, clientName: 'James Taylor', clientPhone: '+1 555-004',
        invoiceId: 104, totalAmount: 900, remainingAmount: 900, months: 12,
        monthlyInstallment: 75, status: 'active', createdAt: '2026-04-20',
        interestRate: 10.0,
      ),
      const DbInstallmentPlan(
        id: 5, clientId: 5, clientName: 'Olivia Martin', clientPhone: '+1 555-005',
        invoiceId: 105, totalAmount: 2400, remainingAmount: 2400, months: 24,
        monthlyInstallment: 100, status: 'overdue', createdAt: '2025-10-15',
        interestRate: 12.0,
      ),
    ];
  }

  // ── Clients ────────────────────────────────────────────────────────────────
  /// Returns 0 on success, negative code on failure.
  int addClient(String name, String phone) {
    if (_isMockMode) {
      final newId = clients.isEmpty ? 1 : clients.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
      clientsNotifier.value = [...clients, DbClient(id: newId, name: name, phone: phone, totalDebt: 0)];
      return 0;
    }
    final result = _bridge.addClient(name, phone);
    if (result == 0) refreshClients();
    return result;
  }

  int deleteClient(int id) {
    if (_isMockMode) {
      clientsNotifier.value = clients.where((c) => c.id != id).toList();
      return 0;
    }
    final result = _bridge.deleteClient(id);
    if (result == 0) refreshClients();
    return result;
  }

  // ── POS / Sales ────────────────────────────────────────────────────────────
  /// Creates invoice + items + decrements stock.
  /// Returns new invoice_id (>= 1) on success, negative error code on failure.
  Future<int> createSale({
    required int userId,
    required int? clientId,
    required String itemsJson,
    required String paymentMethod,
    required double totalAmount,
  }) async {
    if (_isMockMode) {
      // Decode items and decrement stock
      try {
        final List<dynamic> items = jsonDecode(itemsJson);
        final List<DbProduct> currentProducts = List.from(products);
        
        for (var item in items) {
          final pid = item['product_id'] as int;
          final qty = item['quantity'] as int;
          final idx = currentProducts.indexWhere((p) => p.id == pid);
          if (idx != -1) {
            final p = currentProducts[idx];
            currentProducts[idx] = DbProduct(
              id: p.id,
              barcode: p.barcode,
              name: p.name,
              sellingPrice: p.sellingPrice,
              stockQuantity: (p.stockQuantity - qty).clamp(0, 999999),
              status: p.status,
            );
          }
        }
        productsNotifier.value = currentProducts;
      } catch (_) {}
      
      return 999; 
    }
    final invoiceId = _bridge.createSale(
      userId:      userId,
      clientId:    clientId ?? 0,
      itemsJson:   itemsJson,
      paymentType: paymentMethod,
      totalAmount: totalAmount,
    );
    if (invoiceId > 0) refreshProducts(); // stock changed
    return invoiceId;
  }

  // ── Installments ───────────────────────────────────────────────────────────
  Future<bool> createInstallmentPlan({
    required int clientId,
    required int invoiceId,
    required double totalAmount,
    required double downPayment,
    required int months,
    required double interestRate,
  }) async {
    if (_isMockMode) {
      final client = clients.firstWhere((c) => c.id == clientId);
      final newPlan = DbInstallmentPlan(
        id: _mockPlanId++,
        clientId: clientId,
        clientName: client.name,
        clientPhone: client.phone,
        invoiceId: invoiceId,
        totalAmount: totalAmount,
        remainingAmount: totalAmount - downPayment,
        months: months,
        monthlyInstallment: (totalAmount - downPayment) / months,
        status: 'active',
        interestRate: interestRate,
        createdAt: DateTime.now().toString().split(' ')[0],
      );
      
      installmentsNotifier.value = [...installments, newPlan];
      
      // Update client debt
      clientsNotifier.value = clients.map((c) {
        if (c.id == clientId) {
          return DbClient(id: c.id, name: c.name, phone: c.phone, totalDebt: c.totalDebt + (totalAmount - downPayment));
        }
        return c;
      }).toList();
      
      return true;
    }
    final result = _bridge.createInstallmentPlan(
      clientId:    clientId,
      invoiceId:   invoiceId,
      totalAmount: totalAmount,
      months:      months,
    );
    if (result == 0) {
      refreshInstallments();
      refreshClients(); // total_debt updated
      return true;
    }
    return false;
  }

  Future<bool> recordPayment({
    required int installmentId,
    required int userId,
    required double amount,
  }) async {
    if (_isMockMode) {
      final planIdx = installments.indexWhere((p) => p.id == installmentId);
      if (planIdx == -1) return false;
      
      final plan = installments[planIdx];
      final newRemaining = (plan.remainingAmount - amount).clamp(0.0, plan.totalAmount);
      
      final updatedPlan = DbInstallmentPlan(
        id: plan.id,
        clientId: plan.clientId,
        clientName: plan.clientName,
        clientPhone: plan.clientPhone,
        invoiceId: plan.invoiceId,
        totalAmount: plan.totalAmount,
        remainingAmount: newRemaining,
        months: plan.months,
        monthlyInstallment: plan.monthlyInstallment,
        status: newRemaining <= 0 ? 'completed' : 'active',
        interestRate: plan.interestRate,
        createdAt: plan.createdAt,
      );
      
      installmentsNotifier.value = List.from(installments)..[planIdx] = updatedPlan;
      
      // Update client debt
      clientsNotifier.value = clients.map((c) {
        if (c.id == plan.clientId) {
          return DbClient(id: c.id, name: c.name, phone: c.phone, totalDebt: (c.totalDebt - amount).clamp(0.0, 999999.0));
        }
        return c;
      }).toList();
      
      return true;
    }
    final result = _bridge.recordInstallmentPayment(
      installmentId: installmentId,
      userId:        userId,
      amount:        amount,
    );
    if (result == 0) {
      refreshInstallments();
      refreshClients(); // total_debt decremented
      return true;
    }
    return false;
  }
}
