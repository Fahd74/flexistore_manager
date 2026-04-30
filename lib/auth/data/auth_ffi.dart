import '../../core/native_bridge.dart';

class AuthNativeAPI {
  static final AuthNativeAPI instance = AuthNativeAPI._internal();
  AuthNativeAPI._internal();

  // Returns 0 (FFI_SUCCESS) on valid credentials, -100 on invalid
  int attemptLogin(String username, String password) =>
      NativeBridge().login(username, password);

  int attemptLogout() => NativeBridge().logout();
}
