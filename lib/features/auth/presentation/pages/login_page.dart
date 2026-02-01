import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  // Controllers
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Local State
  bool _rememberPassword = true;
  bool _autoLogin = false;
  bool _obscurePassword = true;

  List<String> _historyUrls = [];

  @override
  void initState() {
    super.initState();
    _loadSavedUrlAndHistory();

    // 页面加载后尝试自动登录
    // 这个操作是异步的，且 AuthNotifier 内部会检查 auto_login 标志
    // 所以可以无条件调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).tryAutoLogin();
    });
  }

  Future<void> _loadSavedUrlAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('saved_url');
    final history = prefs.getStringList('history_urls') ?? [];

    // 从 SecureStorage 读取记住的偏好和凭证
    final rememberMe = await _storage.read(key: 'remember_me') == 'true';
    final autoLogin = await _storage.read(key: 'auto_login') == 'true';

    if (rememberMe) {
      final sUser = await _storage.read(key: 'username');
      final sPass = await _storage.read(key: 'password');
      final sUrl = await _storage.read(key: 'server_url');

      if (mounted) {
        setState(() {
          _rememberPassword = true;
          // 只有当记住密码勾选时，自动登录开关才有效
          _autoLogin = autoLogin;
          if (sUser != null) _usernameController.text = sUser;
          if (sPass != null) _passwordController.text = sPass;
          if (sUrl != null) _urlController.text = sUrl;
        });
      }
    }

    // 如果没有历史记录但有保存的 URL，自动将其添加进历史
    if (history.isEmpty && savedUrl != null && savedUrl.isNotEmpty) {
      history.add(savedUrl);
      await prefs.setStringList('history_urls', history);
    }

    if (mounted) {
      setState(() {
        _historyUrls = history;
        // 如果 SecureStorage 没覆盖 URL，就用 SharedPrefs 的
        if (_urlController.text.isEmpty &&
            savedUrl != null &&
            savedUrl.isNotEmpty) {
          _urlController.text = savedUrl;
        }
      });
    }
  }

  Future<void> _saveHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // 移除旧的同名记录，插入到最前
    final newHistory = List<String>.from(_historyUrls)
      ..remove(url)
      ..insert(0, url);

    // 限制历史记录数量，例如 5 条
    if (newHistory.length > 5) {
      newHistory.removeLast();
    }

    await prefs.setStringList('history_urls', newHistory);
    setState(() {
      _historyUrls = newHistory;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUrlSelected(String? url) {
    if (url != null) {
      _urlController.text = url;
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // 自动补全 URL 协议头
      String url = _urlController.text.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // 默认尝试 https，为了安全
        url = 'https://$url';
        // 更新显示，让用户感知
        _urlController.text = url;
      }

      // 保存输入的 URL 和历史记录
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_url', url);
      await _saveHistory(url);

      // 关闭键盘焦点，避免影响后续页面交互
      FocusManager.instance.primaryFocus?.unfocus();

      ref.read(authProvider.notifier).login(
            url,
            _usernameController.text,
            _passwordController.text,
            _rememberPassword,
            _autoLogin,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态
    final authState = ref.watch(authProvider);

    // 监听认证错误
    ref.listen(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
      if (next.isAuthenticated) {
        // 登录成功后，GoRouter 的 redirect 逻辑会自动拦截并跳转到 /files
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功！'), backgroundColor: Colors.green),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo or Title
                  Icon(
                    Icons.cloud_circle_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OpenList Viewer',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // URL Input with History Dropdown
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://your-server.com/dav',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _historyUrls.isNotEmpty
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.history),
                              tooltip: '历史记录',
                              onSelected: _onUrlSelected,
                              itemBuilder: (context) {
                                return _historyUrls.map((url) {
                                  return PopupMenuItem(
                                    value: url,
                                    child: Text(url),
                                  );
                                }).toList();
                              },
                            )
                          : null,
                    ),
                    validator: (value) => value!.isEmpty ? '请输入服务器地址' : null,
                  ),
                  const SizedBox(height: 16),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value!.isEmpty ? '请输入用户名' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? '请输入密码' : null,
                  ),
                  const SizedBox(height: 16),

                  // Settings: Remember & Auto Login
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberPassword,
                        onChanged: (v) =>
                            setState(() => _rememberPassword = v!),
                      ),
                      const Text('记住密码'),
                      const Spacer(),
                      Switch(
                        value: _autoLogin,
                        onChanged: (v) => setState(() => _autoLogin = v),
                      ),
                      const Text('自动登录'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  FilledButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('连接服务器'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
