import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfProgressItem {
  final int page;
  final int total;

  PdfProgressItem({required this.page, required this.total});

  Map<String, dynamic> toJson() => {'page': page, 'total': total};

  factory PdfProgressItem.fromJson(Map<String, dynamic> json) {
    return PdfProgressItem(
      page: json['page'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}

class PdfProgressNotifier extends StateNotifier<Map<String, PdfProgressItem>> {
  PdfProgressNotifier() : super({}) {
    _loadProgress();
  }

  static const _storageKey = 'pdf_reading_progress';

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        state = jsonMap.map((key, value) {
          if (value is int) {
            // Migration for old format (just page number)
            return MapEntry(key, PdfProgressItem(page: value, total: 0));
          } else {
            return MapEntry(key,
                PdfProgressItem.fromJson(Map<String, dynamic>.from(value)));
          }
        });
      } catch (e) {
        // Handle error or ignore
      }
    }
  }

  Future<void> setProgress(String path, int page, int total) async {
    state = {...state, path: PdfProgressItem(page: page, total: total)};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(state));
  }

  PdfProgressItem? getProgress(String path) {
    return state[path];
  }
}

final pdfProgressProvider =
    StateNotifierProvider<PdfProgressNotifier, Map<String, PdfProgressItem>>(
        (ref) {
  return PdfProgressNotifier();
});
