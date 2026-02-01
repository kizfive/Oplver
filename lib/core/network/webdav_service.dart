import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class WebDavService {
  webdav.Client? _client;
  String? _baseUrl;
  String? _username;
  String? _password;

  // 初始化并验证连接
  Future<bool> connect(String url, String username, String password) async {
    // 处理 URL，确保以 / 结尾以便正确拼接，同时处理 dav 路径
    // 根据需求，用户输入 https://domain.com/dav，库通常需要完整的 endpoint
    String cleanUrl = url.trim();
    if (!cleanUrl.endsWith('/')) {
      cleanUrl += '/';
    }

    if (!cleanUrl.startsWith('http')) {
      debugPrint('URL 格式无效');
      return false;
    }

    _client = webdav.newClient(
      cleanUrl,
      user: username,
      password: password,
      debug: false, // 关闭详细日志，避免控制台刷屏
    );

    try {
      // 尝试列出根目录文件以验证连接和权限
      await _client!.readDir('/');

      // 保存连接信息以便生成播放链接
      _baseUrl = cleanUrl;
      _username = username;
      _password = password;

      return true;
    } catch (e) {
      debugPrint('WebDAV 连接失败: $e');
      _client = null;
      return false;
    }
  }

  webdav.Client? get client => _client;
  String? get baseUrl => _baseUrl;
  String? get username => _username;

  // 获取认证头
  Map<String, String> get authHeaders {
    if (_username != null && _password != null) {
      String basicAuth =
          'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
      return {'Authorization': basicAuth};
    }
    return {};
  }

  // 供外部检查是否已连接
  bool get isConnected => _client != null;

  String getUrl(String internalPath) {
    if (_baseUrl == null) return '';
    var base = _baseUrl!;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);

    var p = internalPath;
    if (!p.startsWith('/')) p = '/$p';

    return base + p;
  }
}
