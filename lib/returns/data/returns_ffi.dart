import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

// ── Models ───────────────────────────────────────────────────────────────────

/// Represents an invoice fetched from the backend for return processing.
class ReturnableInvoice {
  final int id;
  final int? clientId;
  final String? clientName;
  final double totalAmount;
  final String paymentMethod; // 'cash' or 'installment'
  final String createdAt;
  final List<ReturnableItem> items;

  ReturnableInvoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    required this.items,
  });

  factory ReturnableInvoice.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List?) ?? [];
    // client_id of 0 means "Walk-in / guest"
    final cid = json['client_id'] as int?;
    return ReturnableInvoice(
      id: json['id'] as int,
      clientId: (cid == null || cid == 0) ? null : cid,
      clientName: json['client_name'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethod: (json['payment_method'] as String?) ??
          (json['payment_type'] as String?) ??
          'cash',
      createdAt: json['created_at'] as String? ?? '',
      items: itemsJson
          .map((e) => ReturnableItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isInstallment => paymentMethod == 'installment';
}

/// A single line item on an invoice that can be returned.
class ReturnableItem {
  final int productId;
  final String productName;
  final String barcode;
  final int quantitySold;
  final int quantityAlreadyReturned;
  final double unitPrice;

  ReturnableItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantitySold,
    required this.quantityAlreadyReturned,
    required this.unitPrice,
  });

  factory ReturnableItem.fromJson(Map<String, dynamic> json) {
    return ReturnableItem(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String? ?? 'Unknown',
      barcode: json['barcode'] as String? ?? '',
      quantitySold: json['quantity_sold'] as int,
      quantityAlreadyReturned: json['quantity_returned'] as int? ?? 0,
      unitPrice: (json['unit_price'] as num).toDouble(),
    );
  }

  int get quantityRemaining => quantitySold - quantityAlreadyReturned;
  double get lineTotal => unitPrice * quantitySold;
}

/// A historical return record.
class ReturnRecord {
  final int id;
  final int invoiceId;
  final int? clientId;
  final String? clientName;
  final double refundAmount;
  final String reason;
  final String createdAt;
  final String processedBy;

  ReturnRecord({
    required this.id,
    required this.invoiceId,
    required this.clientId,
    required this.clientName,
    required this.refundAmount,
    required this.reason,
    required this.createdAt,
    required this.processedBy,
  });

  factory ReturnRecord.fromJson(Map<String, dynamic> json) {
    final cid = json['client_id'] as int?;
    // Strip "RETURN_" prefix used by the backend as a reason encoding hack
    String reason = (json['reason'] as String?) ?? '';
    if (reason.startsWith('RETURN_')) {
      reason = reason.substring(7);
    }
    return ReturnRecord(
      id: json['id'] as int,
      invoiceId: json['invoice_id'] as int,
      clientId: (cid == null || cid == 0) ? null : cid,
      clientName: json['client_name'] as String?,
      refundAmount: (json['refund_amount'] as num).toDouble(),
      reason: reason,
      createdAt: json['created_at'] as String? ?? '',
      processedBy: json['processed_by'] as String? ?? 'System',
    );
  }
}

/// Aggregated stats for the returns dashboard header.
class ReturnsStats {
  final int totalReturns;
  final double totalRefunded;
  final int returnsToday;

  ReturnsStats({
    required this.totalReturns,
    required this.totalRefunded,
    required this.returnsToday,
  });

  factory ReturnsStats.fromJson(Map<String, dynamic> json) {
    return ReturnsStats(
      totalReturns: json['total_returns'] as int? ?? 0,
      totalRefunded: (json['total_refunded'] as num?)?.toDouble() ?? 0.0,
      returnsToday: json['returns_today'] as int? ?? 0,
    );
  }
}

// ── FFI Signatures ───────────────────────────────────────────────────────────

typedef GetInvoiceForReturnC = Pointer<Utf8> Function(Int32 userId, Int32 invoiceId);
typedef GetInvoiceForReturnDart = Pointer<Utf8> Function(int userId, int invoiceId);

typedef ProcessReturnC = Int32 Function(
  Int32 userId,
  Int32 invoiceId,
  Pointer<Utf8> itemsJson,
  Pointer<Utf8> reason,
);
typedef ProcessReturnDart = int Function(
  int userId,
  int invoiceId,
  Pointer<Utf8> itemsJson,
  Pointer<Utf8> reason,
);

typedef GetAllReturnsC = Pointer<Utf8> Function(Int32 userId);
typedef GetAllReturnsDart = Pointer<Utf8> Function(int userId);

typedef GetReturnsStatsC = Pointer<Utf8> Function(Int32 userId);
typedef GetReturnsStatsDart = Pointer<Utf8> Function(int userId);

typedef SearchReturnsC = Pointer<Utf8> Function(Int32 userId, Pointer<Utf8> query);
typedef SearchReturnsDart = Pointer<Utf8> Function(int userId, Pointer<Utf8> query);

typedef GetCurrentUserIdC = Int32 Function();
typedef GetCurrentUserIdDart = int Function();

// ── Native API Class ─────────────────────────────────────────────────────────

class ReturnsFFI {
  static final ReturnsFFI instance = ReturnsFFI._internal();
  ReturnsFFI._internal() {
    _bindFunctions();
  }

  late GetInvoiceForReturnDart _getInvoiceForReturn;
  late ProcessReturnDart _processReturn;
  late GetAllReturnsDart _getAllReturns;
  late GetReturnsStatsDart _getReturnsStats;
  late SearchReturnsDart _searchReturns;
  late GetCurrentUserIdDart _getCurrentUserId;

  bool _isInitialized = false;

  void _bindFunctions() {
    if (_isInitialized) return;
    try {
      final lib = NativeBridge().lib;
      _getInvoiceForReturn = lib.lookupFunction<GetInvoiceForReturnC,
          GetInvoiceForReturnDart>('get_invoice_for_return');
      _processReturn =
          lib.lookupFunction<ProcessReturnC, ProcessReturnDart>('process_return');
      _getAllReturns = lib
          .lookupFunction<GetAllReturnsC, GetAllReturnsDart>('get_all_returns');
      _getReturnsStats = lib.lookupFunction<GetReturnsStatsC,
          GetReturnsStatsDart>('get_returns_stats');
      _searchReturns = lib
          .lookupFunction<SearchReturnsC, SearchReturnsDart>('search_returns');
      _getCurrentUserId = lib.lookupFunction<GetCurrentUserIdC,
          GetCurrentUserIdDart>('get_current_user_id');
      _isInitialized = true;
    } catch (e) {
      print('Failed to bind Returns FFI functions: $e');
      // Don't rethrow - allow UI to render empty states instead of crashing
    }
  }

  int get _userId {
    try {
      return _getCurrentUserId();
    } catch (_) {
      return 1;
    }
  }

  Future<ReturnableInvoice?> getInvoiceForReturn(int invoiceId) async {
    if (!_isInitialized) return null;
    try {
      final ptr = _getInvoiceForReturn(_userId, invoiceId);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr.isEmpty || jsonStr == '[]' || jsonStr == '{}') return null;

      final Map<String, dynamic> map = jsonDecode(jsonStr);
      if (map.containsKey('error')) {
        print('Backend error: ${map['error']}');
        return null;
      }
      return ReturnableInvoice.fromJson(map);
    } catch (e) {
      print('Failed to parse invoice for return: $e');
      return null;
    }
  }

  Future<int> processReturn({
    required int invoiceId,
    required List<Map<String, dynamic>> items,
    required String reason,
  }) async {
    if (!_isInitialized) return -1;

    final itemsJsonStr = jsonEncode(items);
    final itemsPtr = toNativeUtf8(itemsJsonStr);
    final reasonPtr = toNativeUtf8(reason);
    try {
      return _processReturn(_userId, invoiceId, itemsPtr, reasonPtr);
    } catch (e) {
      print('FFI Exception in processReturn: $e');
      return -1;
    } finally {
      calloc.free(itemsPtr);
      calloc.free(reasonPtr);
    }
  }

  Future<List<ReturnRecord>> getAllReturns() async {
    if (!_isInitialized) return [];
    try {
      final ptr = _getAllReturns(_userId);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr.isEmpty || jsonStr == '[]') return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => ReturnRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Failed to parse returns history: $e');
      return [];
    }
  }

  Future<ReturnsStats> getStats() async {
    if (!_isInitialized) {
      return ReturnsStats(totalReturns: 0, totalRefunded: 0, returnsToday: 0);
    }
    try {
      final ptr = _getReturnsStats(_userId);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr.isEmpty || jsonStr == '[]') {
        return ReturnsStats(totalReturns: 0, totalRefunded: 0, returnsToday: 0);
      }
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return ReturnsStats.fromJson(map);
    } catch (e) {
      print('Failed to parse returns stats: $e');
      return ReturnsStats(totalReturns: 0, totalRefunded: 0, returnsToday: 0);
    }
  }

  Future<List<ReturnRecord>> searchReturns(String query) async {
    if (!_isInitialized) return [];
    final qPtr = toNativeUtf8(query);
    try {
      final ptr = _searchReturns(_userId, qPtr);
      final jsonStr = parseJsonAndFree(ptr);
      if (jsonStr.isEmpty || jsonStr == '[]') return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => ReturnRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Failed to search returns: $e');
      return [];
    } finally {
      calloc.free(qPtr);
    }
  }
}
