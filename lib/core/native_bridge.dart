import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ── Native function typedefs ──────────────────────────────────────────────────

// int initialize_database()
typedef _InitDbNative = Int32 Function();
typedef _InitDbDart   = int Function();

// int login(const char* username, const char* password_hash)
typedef _LoginNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _LoginDart   = int Function(Pointer<Utf8>, Pointer<Utf8>);

// int logout()
typedef _LogoutNative = Int32 Function();
typedef _LogoutDart   = int Function();

// const char* get_all_clients()
typedef _GetClientsNative = Pointer<Utf8> Function();
typedef _GetClientsDart   = Pointer<Utf8> Function();

// int add_client(const char* name, const char* phone)
typedef _AddClientNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _AddClientDart   = int Function(Pointer<Utf8>, Pointer<Utf8>);

// int delete_client(int id)
typedef _DeleteClientNative = Int32 Function(Int32);
typedef _DeleteClientDart   = int Function(int);

// const char* get_all_products()
typedef _GetProductsNative = Pointer<Utf8> Function();
typedef _GetProductsDart   = Pointer<Utf8> Function();

// int create_sale(int user_id, int client_id, const char* items_json,
//                 const char* payment_type, double total_amount)
typedef _CreateSaleNative = Int32 Function(Int32, Int32, Pointer<Utf8>, Pointer<Utf8>, Double);
typedef _CreateSaleDart   = int Function(int, int, Pointer<Utf8>, Pointer<Utf8>, double);

// const char* get_all_installments()
typedef _GetInstallmentsNative = Pointer<Utf8> Function();
typedef _GetInstallmentsDart   = Pointer<Utf8> Function();

// int create_installment_plan(int client_id, int invoice_id, double total, int months)
typedef _CreatePlanNative = Int32 Function(Int32, Int32, Double, Int32);
typedef _CreatePlanDart   = int Function(int, int, double, int);

// int record_installment_payment(int installment_id, int user_id, double amount)
typedef _RecordPaymentNative = Int32 Function(Int32, Int32, Double);
typedef _RecordPaymentDart   = int Function(int, int, double);

// void free_ffi_string(const char* ptr)
typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart   = void Function(Pointer<Utf8>);

// ── NativeBridge ─────────────────────────────────────────────────────────────
class NativeBridge {
  static final NativeBridge _instance = NativeBridge._internal();
  factory NativeBridge() => _instance;

  late final DynamicLibrary _lib;
  bool _loaded = false;

  // Bound functions
  late final _InitDbDart       _initDb;
  late final _LoginDart        _login;
  late final _LogoutDart       _logout;
  late final _GetClientsDart   _getClients;
  late final _AddClientDart    _addClient;
  late final _DeleteClientDart _deleteClient;
  late final _GetProductsDart  _getProducts;
  late final _CreateSaleDart   _createSale;
  late final _GetInstallmentsDart  _getInstallments;
  late final _CreatePlanDart       _createPlan;
  late final _RecordPaymentDart    _recordPayment;
  late final _FreeStringDart       _freeString;

  NativeBridge._internal();

  void initialize() {
    try {
      // Locate the DLL next to the executable (windows/runner build output)
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final dllPath = '$exeDir\\flexistore.dll';

      _lib = DynamicLibrary.open(dllPath);

      _initDb        = _lib.lookupFunction<_InitDbNative,       _InitDbDart>      ('initialize_database');
      _login         = _lib.lookupFunction<_LoginNative,        _LoginDart>       ('login');
      _logout        = _lib.lookupFunction<_LogoutNative,       _LogoutDart>      ('logout');
      _getClients    = _lib.lookupFunction<_GetClientsNative,   _GetClientsDart>  ('get_all_clients');
      _addClient     = _lib.lookupFunction<_AddClientNative,    _AddClientDart>   ('add_client');
      _deleteClient  = _lib.lookupFunction<_DeleteClientNative, _DeleteClientDart>('delete_client');
      _getProducts   = _lib.lookupFunction<_GetProductsNative,  _GetProductsDart> ('get_all_products');
      _createSale    = _lib.lookupFunction<_CreateSaleNative,   _CreateSaleDart>  ('create_sale');
      _getInstallments = _lib.lookupFunction<_GetInstallmentsNative, _GetInstallmentsDart>('get_all_installments');
      _createPlan    = _lib.lookupFunction<_CreatePlanNative,   _CreatePlanDart>  ('create_installment_plan');
      _recordPayment = _lib.lookupFunction<_RecordPaymentNative,_RecordPaymentDart>('record_installment_payment');
      _freeString    = _lib.lookupFunction<_FreeStringNative,   _FreeStringDart>  ('free_ffi_string');

      _loaded = true;
    } catch (e) {
      print('[NativeBridge] Failed to load flexistore.dll: $e');
      _loaded = false;
    }
  }

  int initializeDatabase() {
    if (!_loaded) return 0;
    try { return _initDb(); } catch (e) { print('[NativeBridge] initializeDatabase error: $e'); return -1; }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  int login(String username, String password) {
    if (!_loaded) return _fallbackLogin(username, password);
    final u = username.toNativeUtf8();
    final p = password.toNativeUtf8();
    try {
      return _login(u, p);
    } finally {
      malloc.free(u);
      malloc.free(p);
    }
  }

  int logout() {
    if (!_loaded) return 0;
    try { return _logout(); } catch (_) { return 0; }
  }

  // ── Clients ───────────────────────────────────────────────────────────────
  String getAllClients() {
    if (!_loaded) return '[]';
    final ptr = _getClients();
    final json = ptr.toDartString();
    _freeString(ptr);
    return json;
  }

  int addClient(String name, String phone) {
    if (!_loaded) return -1;
    final n = name.toNativeUtf8();
    final p = phone.toNativeUtf8();
    try {
      return _addClient(n, p);
    } finally {
      malloc.free(n);
      malloc.free(p);
    }
  }

  int deleteClient(int id) {
    if (!_loaded) return -1;
    return _deleteClient(id);
  }

  // ── Products ──────────────────────────────────────────────────────────────
  String getAllProducts() {
    if (!_loaded) return '[]';
    final ptr = _getProducts();
    final json = ptr.toDartString();
    _freeString(ptr);
    return json;
  }

  // ── POS / Sales ───────────────────────────────────────────────────────────
  /// Returns new invoice_id (>= 1) on success, negative error code on failure.
  int createSale({
    required int userId,
    required int clientId,
    required String itemsJson,
    required String paymentType,
    required double totalAmount,
  }) {
    if (!_loaded) return -1;
    final items = itemsJson.toNativeUtf8();
    final ptype = paymentType.toNativeUtf8();
    try {
      return _createSale(userId, clientId, items, ptype, totalAmount);
    } finally {
      malloc.free(items);
      malloc.free(ptype);
    }
  }

  // ── Installments ──────────────────────────────────────────────────────────
  String getAllInstallments() {
    if (!_loaded) return '[]';
    final ptr = _getInstallments();
    final json = ptr.toDartString();
    _freeString(ptr);
    return json;
  }

  int createInstallmentPlan({
    required int clientId,
    required int invoiceId,
    required double totalAmount,
    required int months,
  }) {
    if (!_loaded) return -1;
    return _createPlan(clientId, invoiceId, totalAmount, months);
  }

  int recordInstallmentPayment({
    required int installmentId,
    required int userId,
    required double amount,
  }) {
    if (!_loaded) return -1;
    return _recordPayment(installmentId, userId, amount);
  }

  // ── Fallback (DLL not available) ──────────────────────────────────────────
  int _fallbackLogin(String user, String pass) {
    if (user == 'admin1'   && pass == 'admin123') return 0;
    if (user == 'cashier1' && pass == '123456')   return 0;
    if (user == 'store_mng'&& pass == 'store123') return 0;
    return -100;
  }
}
