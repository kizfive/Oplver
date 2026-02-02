import 'dart:convert';

/// 漫画信息
class MangaInfo {
  final String folderPath;
  final String title;
  final String? author;
  final String? source;
  final String? description;
  final String? coverImage;
  final List<String>? tags;
  final String? status;
  final List<String> chapters; // 章节图片列表
  final int lastReadIndex; // 最后阅读的图片索引

  MangaInfo({
    required this.folderPath,
    required this.title,
    this.author,
    this.source,
    this.description,
    this.coverImage,
    this.tags,
    this.status,
    this.chapters = const [],
    this.lastReadIndex = 0,
  });

  factory MangaInfo.fromJson(Map<String, dynamic> json, String folderPath) {
    String? cover = json['cover'] as String? ?? json['cover_image'] as String? ?? json['coverUrl'] as String?;
    
    // Parse tags which can be List<String> or List<Map> (EH metadata)
    List<String>? parsedTags;
    if (json['tags'] is List) {
      final rawList = json['tags'] as List;
      if (rawList.isNotEmpty && rawList.first is Map) {
         // Handle EH metadata format: [{"tag": "name", ...}, ...]
         parsedTags = rawList.map((e) => (e as Map)['tag'].toString()).toList();
      } else {
         parsedTags = rawList.map((e) => e.toString()).toList();
      }
    }

    // Try to parse artists effectively as author
    String? parsedAuthor = json['author'] as String?;
    if (parsedAuthor == null && json['artists'] is List && (json['artists'] as List).isNotEmpty) {
       parsedAuthor = (json['artists'] as List).first.toString();
    }

    return MangaInfo(
      folderPath: folderPath,
      title: json['title'] as String? ?? '',
      author: parsedAuthor,
      source: json['originalUrl'] as String? ?? json['source'] as String?,
      description: json['description'] as String?,
      coverImage: cover,
      tags: parsedTags,
      status: json['status'] as String?,
      lastReadIndex: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (author != null) 'author': author,
      if (source != null) 'originalUrl': source,
      if (description != null) 'description': description,
      if (coverImage != null) 'cover': coverImage,
      if (tags != null) 'tags': tags,
      if (status != null) 'status': status,
    };
  }

  // --- 缓存存储专用序列化 ---

  Map<String, dynamic> toStorageJson() {
    return {
      'folderPath': folderPath,
      'title': title,
      'author': author,
      'source': source,
      'description': description,
      'coverImage': coverImage,
      'tags': tags,
      'status': status,
      'chapters': chapters,
      'lastReadIndex': lastReadIndex,
    };
  }

  factory MangaInfo.fromStorageJson(Map<String, dynamic> json) {
    return MangaInfo(
      folderPath: json['folderPath'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      source: json['source'] as String?,
      description: json['description'] as String?,
      coverImage: json['coverImage'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      status: json['status'] as String?,
      chapters: (json['chapters'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lastReadIndex: json['lastReadIndex'] as int? ?? 0,
    );
  }

  /// 获取封面图片的完整路径
  String? getCoverImagePath() {
    if (coverImage == null) return null;
    return '$folderPath/$coverImage'.replaceAll('//', '/');
  }

  /// 创建带有章节信息的副本
  MangaInfo copyWithChapters(List<String> chapters) {
    return MangaInfo(
      folderPath: folderPath,
      title: title,
      author: author,
      source: source,
      description: description,
      coverImage: coverImage,
      tags: tags,
      status: status,
      chapters: chapters,
      lastReadIndex: lastReadIndex,
    );
  }

  /// 创建副本
  MangaInfo copyWith({
    String? folderPath,
    String? title,
    String? author,
    String? source,
    String? description,
    String? coverImage,
    List<String>? tags,
    String? status,
    List<String>? chapters,
    int? lastReadIndex,
  }) {
    return MangaInfo(
      folderPath: folderPath ?? this.folderPath,
      title: title ?? this.title,
      author: author ?? this.author,
      source: source ?? this.source,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      chapters: chapters ?? this.chapters,
      lastReadIndex: lastReadIndex ?? this.lastReadIndex,
    );
  }
}