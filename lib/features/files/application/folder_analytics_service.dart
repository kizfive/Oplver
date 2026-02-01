import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_provider.dart';

const String kAnalyticsKeyPrefix = 'analytics_folders_';

class FolderAnalyticsNotifier extends StateNotifier<String?> {
  final Ref _ref;

  // Pending folder path that needs "verification" (file click) to be counted
  String? _pendingFolder;

  // Track specific folder verified in this session to prevent double counting
  // Requirement: "In one folder watching different files won't repeat count"
  // So we verified this folder.
  String? _currentVerifiedFolder;

  FolderAnalyticsNotifier(this._ref) : super(null);

  void enterFolder(String path) {
    if (path == _currentVerifiedFolder) {
      // Already verified this session, user came back or reloaded?
      // If user navigates away (enters another folder), _currentVerifiedFolder should probably be reset?
      // "Enters folder A -> Files -> (Count A). Enters B -> (Reset A). Enters A -> (Pending A)."
      // So verification is tied to "staying in folder".
    }

    _pendingFolder = path;
    // We entered a new folder, so we act as if we left the old one verified state?
    // "If user enters folder (A) then clicks another folder (B), this click (A) is not counted."
    // Correct.

    // Reset verified if path is different?
    if (path != _currentVerifiedFolder) {
      _currentVerifiedFolder = null;
    }
  }

  Future<void> interactWithFile(String filePath) async {
    // Determine folder of file
    // Usually calls from Browser where we are in a folder.
    // We can assume if we interact with file, the current _pendingFolder is the parent.

    if (_pendingFolder != null && _pendingFolder != _currentVerifiedFolder) {
      // Verify it!
      await _incrementCount(_pendingFolder!);
      _currentVerifiedFolder = _pendingFolder;
    }
  }

  // Manually record access (e.g., jumping from History)
  Future<void> recordDirectAccess(String path) async {
    await _incrementCount(path);
    // Also set as current verified to prevent double counting if they interact immediately
    _currentVerifiedFolder = path;
    _pendingFolder = path;
  }

  Future<void> _incrementCount(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = _ref.read(authProvider);
    final webDav = _ref.read(webDavServiceProvider);

    // Key by Server + User
    final userKey = auth.currentUser ?? 'guest';
    final serverKey = webDav.baseUrl ?? 'default_server';
    final storageKey = '$kAnalyticsKeyPrefix${serverKey}_$userKey';

    // Load map
    final jsonStr = prefs.getString(storageKey);
    Map<String, int> counts = {};
    if (jsonStr != null) {
      try {
        counts = Map<String, int>.from(jsonDecode(jsonStr));
      } catch (_) {}
    }

    // Increment
    counts[path] = (counts[path] ?? 0) + 1;

    // Save
    await prefs.setString(storageKey, jsonEncode(counts));

    _ref.invalidate(folderFrequencyProvider);
  }

  /// Clear all stored folder visit counts for the current user/server.
  Future<void> clearAllCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = _ref.read(authProvider);
    final webDav = _ref.read(webDavServiceProvider);
    final userKey = auth.currentUser ?? 'guest';
    final serverKey = webDav.baseUrl ?? 'default_server';
    final storageKey = '$kAnalyticsKeyPrefix${serverKey}_$userKey';
    await prefs.remove(storageKey);
    _ref.invalidate(folderFrequencyProvider);
  }
}

final folderAnalyticsProvider =
    StateNotifierProvider<FolderAnalyticsNotifier, String?>((ref) {
  return FolderAnalyticsNotifier(ref);
});

final folderFrequencyProvider =
    FutureProvider<List<MapEntry<String, int>>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final auth = ref.watch(authProvider);
  final webDav = ref.watch(webDavServiceProvider);

  final userKey = auth.currentUser ?? 'guest';
  final serverKey = webDav.baseUrl ?? 'default_server';
  final storageKey = '$kAnalyticsKeyPrefix${serverKey}_$userKey';

  final jsonStr = prefs.getString(storageKey);
  if (jsonStr == null) return [];

  try {
    final counts = Map<String, int>.from(jsonDecode(jsonStr));
    final entries = counts.entries.toList();
    // Sort desc
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  } catch (e) {
    return [];
  }
});
