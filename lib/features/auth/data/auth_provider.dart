import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/webdav_service.dart';
import '../../../../core/network/openlist_service.dart';
import '../../../../core/network/openlist_api_service.dart';
import '../../../core/services/log_service.dart';

// 全局 WebDAV 服务 Provider
final webDavServiceProvider = Provider<WebDavService>((ref) {
  return WebDavService();
});

// Auth State
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  // Temporary simplified user info.
  // Ideally should be a proper User model, but we just need a unique ID for local storage.
  // Using username or URL+username hash as ID.
  final String? currentUser;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.currentUser,
  });
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final WebDavService _webDavService;
  final OpenListApiService _apiService;
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this._webDavService, this._apiService) : super(AuthState());

  Future<void> login(String url, String username, String password,
      bool rememberMe, bool autoLogin) async {
    state = AuthState(isLoading: true);
    logInfo('Auth', '尝试登录: $username @ $url');

    try {
      final success = await _webDavService.connect(url, username, password);

      if (success) {
        // 尝试登录 OpenList API
        // 如果 URL 包含 /dav 后缀，则去除，因为 API 通常位于根路径或 /api
        String apiUrl = url;
        if (apiUrl.endsWith('/dav/')) {
          apiUrl = apiUrl.substring(0, apiUrl.length - 5);
        } else if (apiUrl.endsWith('/dav')) {
          apiUrl = apiUrl.substring(0, apiUrl.length - 4);
        }
        
        // 即使 API 登录失败，只要 WebDAV 成功也就视为登录成功
        try {
          await _apiService.login(apiUrl, username, password);
        } catch (e) {
           logWarning('Auth', 'API 登录失败: $e');
        }

        logInfo('Auth', '登录成功: $username');
        if (rememberMe) {
          await _saveCredentials(url, username, password, autoLogin);
        } else {
          await _clearCredentials();
        }
        state = AuthState(
            isLoading: false, isAuthenticated: true, currentUser: username);
      } else {
        logWarning('Auth', '登录失败: 连接失败');
        state = AuthState(isLoading: false, error: '连接失败，请检查服务器地址或账号密码');
      }
    } catch (e) {
      logError('Auth', '登录异常', e);
      state = AuthState(isLoading: false, error: '发生未知错误: $e');
    }
  }

  Future<void> _saveCredentials(
      String url, String username, String password, bool autoLogin) async {
    await _storage.write(key: 'server_url', value: url);
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);
    await _storage.write(key: 'remember_me', value: 'true');
    await _storage.write(
        key: 'auto_login', value: autoLogin ? 'true' : 'false');
  }

  Future<void> _clearCredentials() async {
    await _storage.delete(key: 'password');
    await _storage.write(key: 'remember_me', value: 'false');
    await _storage.write(key: 'auto_login', value: 'false');
  }

  // 尝试自动登录
  Future<void> tryAutoLogin() async {
    // 1. Check if "Auto Login" was enabled
    final autoLogin = await _storage.read(key: 'auto_login') == 'true';
    if (!autoLogin) return;

    logInfo('Auth', '尝试自动登录');

    // 2. Check if credentials exist (Remember Me implies this, but let's check)
    final rememberMe = await _storage.read(key: 'remember_me') == 'true';
    if (!rememberMe) return;

    final url = await _storage.read(key: 'server_url');
    final username = await _storage.read(key: 'username');
    final password = await _storage.read(key: 'password');

    if (url != null && username != null && password != null) {
      // Auto-login also means keep remembering and auto-login
      await login(url, username, password, true, true);
    }
  }

  Future<void> logout() async {
    logInfo('Auth', '用户登出');
    // 登出时，必须禁用自动登录，否则回到登录页（或下次启动）又会自动登入
    await _storage.write(key: 'auto_login', value: 'false');
    // 如果需要“彻底忘记”，可以把 remember_me 也清掉，但通常“退出登录”保留账号密码填入比较好
    // 只禁用自动登录即可

    state = AuthState(isAuthenticated: false);
  }
}

// 暴露 AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final webDavService = ref.watch(webDavServiceProvider);
  final apiService = ref.watch(openListApiServiceProvider);
  return AuthNotifier(webDavService, apiService);
});
