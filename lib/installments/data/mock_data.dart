// ---------------------------------------------------------------------------
// mock_data.dart  —  Temporary in-memory store for UI testing.
// Replace with real FFI calls once the C++ backend is ready.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class MockClient {
  final int id;
  final String name;
  final String phone;

  const MockClient({required this.id, required this.name, required this.phone});
}

class MockPayment {
  final String date;
  final double amount;

  const MockPayment({required this.date, required this.amount});
}

class MockInstallmentPlan {
  final int id;
  final MockClient client;
  final String itemName;
  String status; // 'Active' | 'Overdue' | 'Completed'
  final double totalAmount;
  double paidAmount;
  final double monthlyAmount;
  final double interestRate;
  final String nextPaymentDate;
  final List<MockPayment> payments;

  MockInstallmentPlan({
    required this.id,
    required this.client,
    required this.itemName,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.monthlyAmount,
    required this.interestRate,
    required this.nextPaymentDate,
    required this.payments,
  });

  double get remainingAmount => totalAmount - paidAmount;
  double get progress => (paidAmount / totalAmount).clamp(0.0, 1.0);
}

// ── Mock Store singleton ─────────────────────────────────────────────────────

class MockDataStore {
  MockDataStore._();
  static final MockDataStore instance = MockDataStore._()
    .._init();

  // ── Clients ──────────────────────────────────────────────────────────────
  final List<MockClient> clients = [
    const MockClient(id: 1, name: 'Sarah Smith',   phone: '+1 555-001'),
    const MockClient(id: 2, name: 'David Brown',   phone: '+1 555-002'),
    const MockClient(id: 3, name: 'Emma Wilson',   phone: '+1 555-003'),
    const MockClient(id: 4, name: 'James Taylor',  phone: '+1 555-004'),
    const MockClient(id: 5, name: 'Olivia Martin', phone: '+1 555-005'),
  ];

  // ── Plans (reactive list) ─────────────────────────────────────────────────
  final ValueNotifier<List<MockInstallmentPlan>> plansNotifier =
      ValueNotifier([]);

  int _nextId = 4;

  void _init() {
    plansNotifier.value = [
      MockInstallmentPlan(
        id: 1,
        client: clients[0],
        itemName: 'iPhone 14 Pro',
        status: 'Active',
        totalAmount: 1200,
        paidAmount: 400,
        monthlyAmount: 200,
        interestRate: 5,
        nextPaymentDate: 'May 15, 2026',
        payments: [
          const MockPayment(date: 'Mar 15, 2026', amount: 200),
          const MockPayment(date: 'Apr 15, 2026', amount: 200),
        ],
      ),
      MockInstallmentPlan(
        id: 2,
        client: clients[1],
        itemName: 'MacBook Air M2 + Accessories',
        status: 'Active',
        totalAmount: 3200,
        paidAmount: 1600,
        monthlyAmount: 400,
        interestRate: 4,
        nextPaymentDate: 'May 10, 2026',
        payments: [
          const MockPayment(date: 'Jan 10, 2026', amount: 400),
          const MockPayment(date: 'Feb 10, 2026', amount: 400),
          const MockPayment(date: 'Mar 10, 2026', amount: 400),
          const MockPayment(date: 'Apr 10, 2026', amount: 400),
        ],
      ),
      MockInstallmentPlan(
        id: 3,
        client: clients[2],
        itemName: 'Samsung Galaxy S23 Ultra',
        status: 'Overdue',
        totalAmount: 1500,
        paidAmount: 300,
        monthlyAmount: 150,
        interestRate: 6,
        nextPaymentDate: 'Apr 8, 2026',
        payments: [
          const MockPayment(date: 'Feb 8, 2026', amount: 150),
          const MockPayment(date: 'Mar 8, 2026', amount: 150),
        ],
      ),
    ];
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Record a payment on an existing plan and notify listeners.
  void recordPayment(int planId, double amount) {
    final list = List<MockInstallmentPlan>.from(plansNotifier.value);
    final idx = list.indexWhere((p) => p.id == planId);
    if (idx == -1) return;

    final plan = list[idx];
    plan.paidAmount = (plan.paidAmount + amount).clamp(0, plan.totalAmount);
    plan.payments.add(MockPayment(date: _todayLabel(), amount: amount));
    if (plan.paidAmount >= plan.totalAmount) plan.status = 'Completed';

    plansNotifier.value = list; // trigger rebuild
  }

  /// Add a brand-new plan.
  void addPlan({
    required MockClient client,
    required String itemName,
    required double totalAmount,
    required double downPayment,
    required int months,
    required double interestRate,
  }) {
    final monthly = (totalAmount - downPayment) / months;
    final plan = MockInstallmentPlan(
      id: _nextId++,
      client: client,
      itemName: itemName,
      status: 'Active',
      totalAmount: totalAmount,
      paidAmount: downPayment,
      monthlyAmount: monthly,
      interestRate: interestRate,
      nextPaymentDate: _nextMonthLabel(),
      payments: downPayment > 0
          ? [MockPayment(date: _todayLabel(), amount: downPayment)]
          : [],
    );
    plansNotifier.value = List.from(plansNotifier.value)..add(plan);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _todayLabel() {
    final d = DateTime.now();
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _nextMonthLabel() {
    final d = DateTime.now();
    final next = DateTime(d.year, d.month + 1, d.day);
    return '${_months[next.month - 1]} ${next.day}, ${next.year}';
  }
}
