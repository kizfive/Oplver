import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'openlist_models.dart';

/// OpenList API 服务
class OpenListApiService {
  String? _baseUrl;
  String? _token;
  final Map<String, String> _headers = {};

  bool get isConnected => _token != null && _baseUrl != null;
  String? get baseUrl => _baseUrl;

  /// 登录并获取token
  Future<bool> login(String url, String username, String password) async {
    try {
      // 确保URL格式正确
      String cleanUrl = url.trim();
      if (!cleanUrl.endsWith('/')) {
        cleanUrl += '/';
      }
      if (!cleanUrl.startsWith('http')) {
        debugPrint('URL 格式无效');
        return false;
      }

      _baseUrl = cleanUrl;

      final response = await http.post(
        Uri.parse('${cleanUrl}api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<LoginData>.fromJson(
          jsonDecode(response.body),
          (data) => LoginData.fromJson(data as Map<String, dynamic>),
        );

        if (apiResponse.isSuccess && apiResponse.data?.token != null) {
          _token = apiResponse.data!.token;
          _headers['Authorization'] = _token!;
          debugPrint('OpenList API 登录成功');
          return true;
        }
      }

      debugPrint('OpenList API 登录失败: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('OpenList API 登录错误: $e');
      return false;
    }
  }

  /// 获取当前用户信息
  Future<UserInfo?> getCurrentUser() async {
    if (!isConnected) return null;

    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}api/me'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<UserInfo>.fromJson(
          jsonDecode(response.body),
          (data) => UserInfo.fromJson(data as Map<String, dynamic>),
        );

        if (apiResponse.isSuccess) {
          return apiResponse.data;
        }
      }
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
    }
    return null;
  }

  /// 列出目录内容
  Future<FileListData?> listFiles(String path, {
    int? page,
    int? perPage,
    String? password,
    bool? refresh,
  }) async {
    if (!isConnected) return null;

    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      if (password != null) queryParams['password'] = password;
      if (refresh != null) queryParams['refresh'] = refresh.toString();

      final uri = Uri.parse('${_baseUrl}api/fs/list').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<FileListData>.fromJson(
          jsonDecode(response.body),
          (data) => FileListData.fromJson(data as Map<String, dynamic>),
        );

        if (apiResponse.isSuccess) {
          return apiResponse.data;
        }
      }
    } catch (e) {
      debugPrint('列出文件失败: $e');
    }
    return null;
  }

  /// 搜索文件
  Future<List<SearchResult>> searchFiles(String keywords, {
    String? parent,
    String? scope,
    int? page,
    int? perPage,
    String? password,
  }) async {
    if (!isConnected) return [];

    try {
      final body = <String, dynamic>{
        'keywords': keywords,
        'page': page ?? 1,
        'per_page': perPage ?? 100,
      };
      if (parent != null) body['parent'] = parent;
      if (scope != null) body['scope'] = scope;
      if (password != null) body['password'] = password;

      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/search'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint('搜索响应: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);
        // 处理分页格式的搜索结果
        // 搜索结果通常是 { "code": 200, "data": { "content": [...], "total": 10 } }
        
        List<SearchResult> searchResults = [];
        
        if (jsonMap['code'] == 200 && jsonMap['data'] != null) {
          final data = jsonMap['data'];
          if (data is List) {
            // 如果直接返回列表 (旧版本或其他接口)
            searchResults = data
                .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
                .toList();
          } else if (data is Map && data['content'] is List) {
            // 如果是分页结构
            searchResults = (data['content'] as List)
                .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
        
        return searchResults;
      }
    } catch (e) {
      debugPrint('搜索文件失败: $e');
    }
    return [];
  }

  /// 获取缩略图URL
  String? getThumbnailUrl(String path) {
    if (!isConnected) return null;
    return '${_baseUrl}api/fs/thumb?path=${Uri.encodeComponent(path)}';
  }

  /// 获取文件下载URL(直链)
  /// 用于获取文件的直接内容流
  String? getDownloadUrl(String path) {
    if (!isConnected) return null;
    
    // Alist 的 /d/ 路径通常用于直接下载/访问文件
    // 需要处理路径中的特殊字符
    // path 通常以 / 开头
    String encodedPath = path.split('/').map((segment) => Uri.encodeComponent(segment)).join('/');
    if (encodedPath.startsWith('/')) {
       // 如果path是 /folder/file，split后第一个是空字符串，join后开头会有/，没问题
       // 但为了保险，我们可以手动拼接
    }

    // 更简单的方法，直接使用Uri构建
    // 假设 path = "/Test Folder/File.jpg"
    // 我们想要 url = "http://host:port/d/Test%20Folder/File.jpg"
    
    // 移除开头的 / 防止双重斜杠
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    
    // 逐段编码
    final encodedSegments = cleanPath.split('/').map((s) => Uri.encodeComponent(s)).join('/');
    
    return '${_baseUrl}d/$encodedSegments';
  }

  /// 获取文件API信息URL
  /// 用于获取文件的JSON元数据（包含raw_url等）
  String? getFileMetaUrl(String path) {
    if (!isConnected) return null;
    return '${_baseUrl}api/fs/get?path=${Uri.encodeComponent(path)}';
  }

  /// 重命名文件
  Future<bool> renameFile(String path, String newName) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/rename'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'path': path,
          'name': newName,
        }),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
          null,
        );
        return apiResponse.isSuccess;
      }
    } catch (e) {
      debugPrint('重命名文件失败: $e');
    }
    return false;
  }

  /// 删除文件
  Future<bool> deleteFile(String path, List<String> names) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/remove'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'dir': path,
          'names': names,
        }),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
          null,
        );
        return apiResponse.isSuccess;
      }
    } catch (e) {
      debugPrint('删除文件失败: $e');
    }
    return false;
  }

  /// 移动文件
  Future<bool> moveFiles(String srcDir, String dstDir, List<String> names) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/move'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'src_dir': srcDir,
          'dst_dir': dstDir,
          'names': names,
        }),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
          null,
        );
        return apiResponse.isSuccess;
      }
    } catch (e) {
      debugPrint('移动文件失败: $e');
    }
    return false;
  }

  /// 复制文件
  Future<bool> copyFiles(String srcDir, String dstDir, List<String> names) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/copy'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'src_dir': srcDir,
          'dst_dir': dstDir,
          'names': names,
        }),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
          null,
        );
        return apiResponse.isSuccess;
      }
    } catch (e) {
      debugPrint('复制文件失败: $e');
    }
    return false;
  }

  /// 创建文件夹
  Future<bool> createFolder(String path) async {
    if (!isConnected) return false;

    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/mkdir'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
          null,
        );
        return apiResponse.isSuccess;
      }
    } catch (e) {
      debugPrint('创建文件夹失败: $e');
    }
    return false;
  }

  /// 上传文件
  Future<bool> uploadFile(String dirPath, String fileName, List<int> fileBytes) async {
    if (!isConnected) return false;

    // Alist API 上传通常使用 PUT /api/fs/put 
    try {
      // 1. 构造文件完整路径
      String filePath = dirPath.endsWith('/') ? '$dirPath$fileName' : '$dirPath/$fileName';
      
      // 使用 /api/fs/put 接口
      // 官方文档推荐 PUT /api/fs/put 并把文件内容放在 Body，文件路径放在 Header [File-Path]
      
      final url = Uri.parse('${_baseUrl}api/fs/put');
      final request = http.Request('PUT', url);
      
      request.headers.addAll({
        ..._headers,
        'File-Path': Uri.encodeFull(filePath), // 关键 Header
        'Content-Type': 'application/octet-stream',
        'Content-Length': fileBytes.length.toString(),
      });
      
      request.bodyBytes = fileBytes;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
         final apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
          null,
        );
        return apiResponse.isSuccess;
      } else {
        debugPrint('上传失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('上传文件失败: $e');
    }
    return false;
  }

  /// 获取文件详细信息（包含元数据）
  Future<FileInfo?> getFileInfo(String path) async {
    if (!isConnected) return null;

    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/fs/get'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse<FileInfo>.fromJson(
          jsonDecode(response.body),
          (data) => FileInfo.fromJson(data as Map<String, dynamic>),
        );

        if (apiResponse.isSuccess) {
          return apiResponse.data;
        }
      }
    } catch (e) {
      debugPrint('获取文件信息失败: $e');
    }
    return null;
  }

  /// 获取认证头（用于直接访问资源）
  Map<String, String> get authHeaders => _headers;

  /// 登出
  void logout() {
    _token = null;
    _baseUrl = null;
    _headers.clear();
  }
}
