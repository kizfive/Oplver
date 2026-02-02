// OpenList API 数据模型

/// API 响应基础模型
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? dataParser,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int,
      message: json['message'] as String,
      data: dataParser != null && json['data'] != null
          ? dataParser(json['data'])
          : null,
    );
  }

  bool get isSuccess => code == 200;
}

/// 登录响应数据
class LoginData {
  final String token;

  LoginData({required this.token});

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(token: json['token'] as String);
  }
}

/// 文件/文件夹信息
class FileInfo {
  final String name;
  final int size;
  final bool isDir;
  final String modified;
  final String? path;
  final String? provider;
  final String? thumb;
  final String? rawUrl;
  final Map<String, dynamic>? rawProps;

  FileInfo({
    required this.name,
    required this.size,
    required this.isDir,
    required this.modified,
    this.path,
    this.provider,
    this.thumb,
    this.rawUrl,
    this.rawProps,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      name: json['name'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      isDir: json['is_dir'] as bool? ?? false,
      modified: json['modified'] as String? ?? '',
      path: json['path'] as String?,
      provider: json['provider'] as String?,
      thumb: json['thumb'] as String?,
      rawUrl: json['raw_url'] as String?,
      rawProps: json['raw_props'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'is_dir': isDir,
      'modified': modified,
      if (path != null) 'path': path,
      if (provider != null) 'provider': provider,
      if (thumb != null) 'thumb': thumb,
      if (rawUrl != null) 'raw_url': rawUrl,
      if (rawProps != null) 'raw_props': rawProps,
    };
  }
}

/// 文件列表响应
class FileListData {
  final List<FileInfo> content;
  final String? provider;
  final String? readme;
  final String? header;
  final int? total;

  FileListData({
    required this.content,
    this.provider,
    this.readme,
    this.header,
    this.total,
  });

  factory FileListData.fromJson(Map<String, dynamic> json) {
    return FileListData(
      content: (json['content'] as List<dynamic>?)
              ?.map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      provider: json['provider'] as String?,
      readme: json['readme'] as String?,
      header: json['header'] as String?,
      total: json['total'] as int?,
    );
  }
}

/// 搜索结果
class SearchResult {
  final String name;
  final String parent;
  final bool isDir;
  final int size;

  SearchResult({
    required this.name,
    required this.parent,
    required this.isDir,
    required this.size,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      name: json['name'] as String? ?? '',
      parent: json['parent'] as String? ?? '',
      isDir: json['is_dir'] as bool? ?? false,
      size: json['size'] as int? ?? 0,
    );
  }
}

/// 用户信息
class UserInfo {
  final int id;
  final String username;
  final String? password;
  final String? basePath;
  final int role;
  final bool disabled;
  final int permission;
  final bool otp;
  final bool ssoId;

  UserInfo({
    required this.id,
    required this.username,
    this.password,
    this.basePath,
    required this.role,
    required this.disabled,
    required this.permission,
    required this.otp,
    required this.ssoId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      password: json['password'] as String?,
      basePath: json['base_path'] as String?,
      role: json['role'] as int? ?? 0,
      disabled: json['disabled'] as bool? ?? false,
      permission: json['permission'] as int? ?? 0,
      otp: json['otp'] as bool? ?? false,
      ssoId: json['sso_id'] as bool? ?? false,
    );
  }
}

/// 漫画元数据 (.manga 文件)
class MangaMetadata {
  final String title;
  final String? author;
  final String? source;
  final String? description;
  final String? coverImage;
  final List<String>? tags;
  final String? status;

  MangaMetadata({
    required this.title,
    this.author,
    this.source,
    this.description,
    this.coverImage,
    this.tags,
    this.status,
  });

  factory MangaMetadata.fromJson(Map<String, dynamic> json) {
    return MangaMetadata(
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      source: json['source'] as String?,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (author != null) 'author': author,
      if (source != null) 'source': source,
      if (description != null) 'description': description,
      if (coverImage != null) 'cover_image': coverImage,
      if (tags != null) 'tags': tags,
      if (status != null) 'status': status,
    };
  }
}
