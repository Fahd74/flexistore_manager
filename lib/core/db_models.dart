import 'dart:convert';

// ── DbClient ──────────────────────────────────────────────────────────────────
class DbClient {
  final int id;
  final String name;
  final String phone;
  final double totalDebt;

  const DbClient({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalDebt,
  });

  factory DbClient.fromJson(Map<String, dynamic> j) => DbClient(
        id:        j['id'] as int,
        name:      j['name'] as String,
        phone:     j['phone'] as String,
        totalDebt: (j['total_debt'] as num).toDouble(),
      );
}

// ── DbProduct ─────────────────────────────────────────────────────────────────
class DbProduct {
  final int id;
  final String barcode;
  final String name;
  final double sellingPrice;
  final int stockQuantity;
  final String status;

  const DbProduct({
    required this.id,
    required this.barcode,
    required this.name,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.status,
  });

  factory DbProduct.fromJson(Map<String, dynamic> j) => DbProduct(
        id:            j['id'] as int,
        barcode:       j['barcode'] as String,
        name:          j['name'] as String,
        sellingPrice:  (j['selling_price'] as num).toDouble(),
        stockQuantity: j['stock_quantity'] as int,
        status:        j['status'] as String,
      );
}

// ── DbInstallmentPlan ─────────────────────────────────────────────────────────
class DbInstallmentPlan {
  final int id;
  final int clientId;
  final String clientName;
  final String clientPhone;
  final int invoiceId;
  final double totalAmount;
  final double remainingAmount;
  final int months;
  final double monthlyInstallment;
  final String status; // 'active' | 'completed' | 'cancelled'
  final double interestRate;
  final String createdAt;

  const DbInstallmentPlan({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.invoiceId,
    required this.totalAmount,
    required this.remainingAmount,
    required this.months,
    required this.monthlyInstallment,
    required this.status,
    this.interestRate = 0.0,
    required this.createdAt,
  });

  double get paidAmount => totalAmount - remainingAmount;
  double get progress   => totalAmount > 0 ? paidAmount / totalAmount : 0.0;
  bool   get isCompleted => status == 'completed';
  bool   get isOverdue   => status == 'active' && remainingAmount > 0;

  factory DbInstallmentPlan.fromJson(Map<String, dynamic> j) => DbInstallmentPlan(
        id:                  j['id'] as int,
        clientId:            j['client_id'] as int,
        clientName:          j['client_name'] as String,
        clientPhone:         j['client_phone'] as String,
        invoiceId:           j['invoice_id'] as int,
        totalAmount:         (j['total_amount'] as num).toDouble(),
        remainingAmount:     (j['remaining_amount'] as num).toDouble(),
        months:              j['months'] as int,
        monthlyInstallment:  (j['monthly_installment'] as num).toDouble(),
        status:              j['status'] as String,
        interestRate:        (j['interest_rate'] as num?)?.toDouble() ?? 0.0,
        createdAt:           j['created_at'] as String,
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────
List<DbClient> parseClients(String json) {
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => DbClient.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) { return []; }
}

List<DbProduct> parseProducts(String json) {
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => DbProduct.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) { return []; }
}

List<DbInstallmentPlan> parseInstallments(String json) {
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => DbInstallmentPlan.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) { return []; }
}
