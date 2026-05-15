import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/native_bridge.dart';
import '../../core/db_models.dart';
import '../../auth/data/session_ffi.dart';
import 'installments_ffi.dart';

import '../../clients/data/clients_ffi.dart';
import '../../inventory/data/inventory_ffi.dart';

/// DB-backed reactive data store — replaces the old MockDataStore.
/// All reads/writes go through [NativeBridge] → C++ FFI → MySQL.
class AppDataStore {
  AppDataStore._();
  static final AppDataStore instance = AppDataStore._();

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
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    if (userId < 0) return;
    
    final jsonStr = ClientsFFI.instance.getAllClients(userId);
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        clientsNotifier.value = decoded.map((json) => DbClient(
          id: json['id'],
          name: json['name'] ?? 'Unknown',
          phone: json['phone'] ?? '',
          totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0.0,
        )).toList();
      }
    } catch(e) {
      print('Error parsing clients: $e');
    }
  }

  Future<void> refreshProducts() async {
    final productsList = await InventoryFFI.instance.getProducts();
    productsNotifier.value = productsList.map((p) => DbProduct(
      id: p.id,
      barcode: p.barcode,
      name: p.name,
      sellingPrice: p.sellingPrice,
      stockQuantity: p.stockQuantity,
      status: p.status,
    )).toList();
  }

  void refreshInstallments() {
    
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    if (userId < 0) return;

    final data = InstallmentsFFI.instance.getAllInstallments(userId);
    installmentsNotifier.value = data.map((json) => DbInstallmentPlan(
      id: json['id'],
      clientId: json['clientId'],
      clientName: json['clientName'],
      clientPhone: json['clientPhone'] ?? '',
      invoiceId: json['invoiceId'],
      itemName: json['itemName'],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      months: json['months'],
      monthlyInstallment: (json['monthlyInstallment'] as num).toDouble(),
      status: json['status'],
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'],
      lastPaymentDate: json['lastPaymentDate'],
    )).toList();
  }

  /// Call once at app startup after initializeDatabase().
  void loadAll() {
    refreshClients();
    refreshProducts();
    refreshInstallments();
  }

  // ── Clients ────────────────────────────────────────────────────────────────
  /// Returns 0 on success, negative code on failure.
  int addClient(String name, String phone) {
    throw UnimplementedError('Native FFI for addClient not implemented in this store');
  }

  int deleteClient(int id) {
    throw UnimplementedError('Native FFI for deleteClient not implemented in this store');
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
    throw UnimplementedError('Native FFI for createSale not implemented in this store');
  }

  // ── Installments ───────────────────────────────────────────────────────────
  Future<bool> createInstallmentPlan({
    required int clientId,
    required int invoiceId,
    required double totalAmount,
    required double downPayment,
    required int months,
    required double interestRate,
    String? itemName,
    int productId = -1,
  }) async {
    
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final res = InstallmentsFFI.instance.createInstallmentPlan(
      userId: userId,
      clientId: clientId,
      invoiceId: invoiceId,
      totalAmount: totalAmount - downPayment,
      months: months,
      productId: productId,
    );
    
    if (res == 0) {
      refreshInstallments();
      return true;
    }
    return false;
  }

  Future<bool> recordPayment({
    required int installmentId,
    required int userId,
    required double amount,
  }) async {
    
    final res = InstallmentsFFI.instance.recordPayment(
      userId: userId, 
      installmentId: installmentId, 
      amountPaid: amount
    );
    if (res == 0) {
      refreshInstallments();
      return true;
    }
    return false;
  }

  Future<bool> cancelInstallmentPlan({
    required int installmentId,
  }) async {
    final userId = SessionNativeAPI.instance.getCurrentUserId();
    final res = InstallmentsFFI.instance.cancelInstallmentPlan(
      userId: userId,
      installmentId: installmentId,
    );
    if (res == 0) {
      refreshInstallments();
      return true;
    }
    return false;
  }
}
