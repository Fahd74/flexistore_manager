import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── Native FFI Signatures ────────────────────────────────────────────────────

typedef _CreateInstallmentPlanC = Int32 Function(
  Int32 userId,
  Int32 clientId,
  Int32 invoiceId,
  Double totalAmount,
  Int32 months,
  Int32 productId,
);
typedef _CreateInstallmentPlanDart = int Function(
  int userId,
  int clientId,
  int invoiceId,
  double totalAmount,
  int months,
  int productId,
);

typedef _GetAllInstallmentsC = Pointer<Utf8> Function(Int32 userId);
typedef _GetAllInstallmentsDart = Pointer<Utf8> Function(int userId);

typedef _RecordPaymentC = Int32 Function(Int32 userId, Int32 installmentId, Double amountPaid);
typedef _RecordPaymentDart = int Function(int userId, int installmentId, double amountPaid);

typedef _CancelPlanC = Int32 Function(Int32 userId, Int32 installmentId);
typedef _CancelPlanDart = int Function(int userId, int installmentId);


/// Dart FFI bridge to the C++ installments backend.
///
/// Provides:
///  • [calculateMonthlyPayment] — Pure Dart math (no C++ round-trip needed)
///  • [createInstallmentPlan] — Creates a plan via C++ with DB transaction
class InstallmentsFFI {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final InstallmentsFFI instance = InstallmentsFFI._internal();

  late final _CreateInstallmentPlanDart _createPlan;
  late final _GetAllInstallmentsDart _getAllInstallments;
  late final _RecordPaymentDart _recordPayment;
  late final _CancelPlanDart _cancelPlan;

  InstallmentsFFI._internal() {
    _bindFunctions();
  }

  void _bindFunctions() {
    final lib = NativeBridge().lib;
    _createPlan = lib.lookupFunction<
      _CreateInstallmentPlanC,
      _CreateInstallmentPlanDart
    >('create_installment_plan');
    
    _getAllInstallments = lib.lookupFunction<
      _GetAllInstallmentsC,
      _GetAllInstallmentsDart
    >('get_all_installments');

    _recordPayment = lib
        .lookup<NativeFunction<_RecordPaymentC>>('record_installment_payment')
        .asFunction();

    _cancelPlan = lib
        .lookup<NativeFunction<_CancelPlanC>>('cancel_installment_plan')
        .asFunction();
  }

  /// Available installment period options (months).
  static const List<int> availableMonths = [3, 6, 9, 12];

  /// Calculates the monthly payment for an installment plan.
  ///
  /// Pure Dart — no FFI call needed for simple division.
  double calculateMonthlyPayment(double totalAmount, int months) {
    if (months <= 0) return totalAmount;
    final monthly = totalAmount / months;
    return (monthly * 100).roundToDouble() / 100;
  }

  /// Creates an installment plan in the C++ backend.
  ///
  /// This inserts into the `installments` table and updates `clients.total_debt`.
  ///
  /// [userId] — The cashier performing the operation.
  /// [clientId] — The client taking the installment.
  /// [invoiceId] — The invoice this plan is linked to.
  /// [totalAmount] — The full sale amount.
  /// [months] — The number of monthly payments.
  ///
  /// Returns 0 (FFI_SUCCESS) on success, negative on error.
  int createInstallmentPlan({
    required int userId,
    required int clientId,
    required int invoiceId,
    required double totalAmount,
    required int months,
    int productId = -1,
  }) {
    return _createPlan(userId, clientId, invoiceId, totalAmount, months, productId);
  }

  List<Map<String, dynamic>> getAllInstallments(int userId) {
    final ptr = _getAllInstallments(userId);
    final jsonStr = parseJsonAndFree(ptr);
    
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map && decoded.containsKey('error')) {
        print('[InstallmentsFFI] Error from C++: ${decoded['error']}');
        return [];
      }
      return List<Map<String, dynamic>>.from(decoded);
    } catch (e) {
      print('[InstallmentsFFI] JSON parse error: $e');
      return [];
    }
  }

  int recordPayment({
    required int userId,
    required int installmentId,
    required double amountPaid,
  }) {
    return _recordPayment(userId, installmentId, amountPaid);
  }

  int cancelInstallmentPlan({
    required int userId,
    required int installmentId,
  }) {
    return _cancelPlan(userId, installmentId);
  }
}
