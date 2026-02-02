import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

enum FileType {
  video,
  image,
  pdf,
  manga,
  other,
}

class HistoryItem {
  final String path;
  final FileType type;
  final DateTime lastOpened;
  final double? progress; // 0.0 - 1.0
  final String? coverPath;
  final String? title;
  final Map<String, dynamic>? extra;

  HistoryItem({
    required this.path,
    required this.type,
    required this.lastOpened,
    this.progress,
    this.coverPath,
    this.title,
    this.extra,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'type': type.index,
      'lastOpened': lastOpened.millisecondsSinceEpoch,
      if (progress != null) 'progress': progress,
      if (coverPath != null) 'coverPath': coverPath,
      if (title != null) 'title': title,
      if (extra != null) 'extra': extra,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      path: json['path'] as String,
      type: FileType.values[json['type'] as int],
      lastOpened:
          DateTime.fromMillisecondsSinceEpoch(json['lastOpened'] as int),
      progress: json['progress'] as double?,
      coverPath: json['coverPath'] as String?,
      title: json['title'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}

class FileHistoryNotifier extends StateNotifier<List<HistoryItem>> {
  FileHistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const _storageKey = 'file_open_history';
  static const int _maxHistory = 30;

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        state = list.map((e) => HistoryItem.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> addToHistory(
    String path, {
    FileType? type,
    double? progress,
    String? coverPath,
    String? title,
    Map<String, dynamic>? extra,
  }) async {
    final determineType = type ?? _determineType(path);
    if (determineType == FileType.other) return; 
    
    final now = DateTime.now();

    // Remove any existing entries for the same path
    final filtered = state.where((item) => item.path != path).toList();

    // Insert the new/current entry at the front
    filtered.insert(
      0,
      HistoryItem(
        path: path,
        type: determineType,
        lastOpened: now,
        progress: progress,
        coverPath: coverPath,
        title: title,
        extra: extra,
      ),
    );

    // Trim to max length
    if (filtered.length > _maxHistory) {
      filtered.removeRange(_maxHistory, filtered.length);
    }

    state = filtered;
    _saveHistory();
  }
  
  // Update progress without moving to top (optional, but requested behavior is usually "recently played" moves to top)
  // If user is just reading, updating progress should keep it at top.
  // So addToHistory is fine.

  Future<void> removeItem(String path) async {
    state = state.where((item) => item.path != path).toList();
    _saveHistory();
  }

  Future<void> clearHistory() async {
    state = [];
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = state.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  FileType _determineType(String path) {
    if (path.endsWith('.manga') || path.contains('.manga/')) return FileType.manga; // Simple heuristic
    final ext = p.extension(path).toLowerCase();
    if (['.mp4', '.mkv', '.avi', '.mov', '.flv', '.webm'].contains(ext)) {
      return FileType.video;
    }
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
      return FileType.image;
    }
    if (['.pdf'].contains(ext)) {
      return FileType.pdf;
    }
    return FileType.other;
  }
}

final fileHistoryProvider =
    StateNotifierProvider<FileHistoryNotifier, List<HistoryItem>>((ref) {
  return FileHistoryNotifier();
});
