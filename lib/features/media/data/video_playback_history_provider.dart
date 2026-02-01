import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_provider.dart';

class VideoPlaybackHistoryState {
  final Map<String, int> positions; // path -> ms
  final Map<String, int> durations; // path -> ms

  VideoPlaybackHistoryState({
    this.positions = const {},
    this.durations = const {},
  });

  VideoPlaybackHistoryState copyWith({
    Map<String, int>? positions,
    Map<String, int>? durations,
  }) {
    return VideoPlaybackHistoryState(
      positions: positions ?? this.positions,
      durations: durations ?? this.durations,
    );
  }
}

class VideoPlaybackHistoryNotifier
    extends StateNotifier<VideoPlaybackHistoryState> {
  final String userId;
  late final String _storageKey;

  VideoPlaybackHistoryNotifier(this.userId)
      : super(VideoPlaybackHistoryState()) {
    final suffix = userId.isNotEmpty ? '_$userId' : '';
    _storageKey = 'video_playback_history$suffix';
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonString);
        final positions = (data['positions'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ??
            {};
        final durations = (data['durations'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ??
            {};
        state = VideoPlaybackHistoryState(
            positions: positions, durations: durations);
      } catch (e) {
        // ignore error
      }
    }
  }

  Future<void> saveProgress(String path, int positionMs, int durationMs) async {
    final newPositions = Map<String, int>.from(state.positions);
    final newDurations = Map<String, int>.from(state.durations);

    newPositions[path] = positionMs;
    // Only update duration if it's potentially more accurate/available
    if (durationMs > 0) {
      newDurations[path] = durationMs;
    }

    state = state.copyWith(positions: newPositions, durations: newDurations);

    // Persist
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'positions': state.positions,
      'durations': state.durations,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  double getProgress(String path) {
    // Return 0.0 to 1.0
    final pos = state.positions[path] ?? 0;
    final dur = state.durations[path] ?? 0;
    if (dur <= 0) return 0.0;
    return (pos / dur).clamp(0.0, 1.0);
  }

  int getPosition(String path) {
    return state.positions[path] ?? 0;
  }
}

final videoPlaybackHistoryProvider = StateNotifierProvider<
    VideoPlaybackHistoryNotifier, VideoPlaybackHistoryState>((ref) {
  final authState = ref.watch(authProvider);
  final userId =
      authState.currentUser?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'guest';
  return VideoPlaybackHistoryNotifier(userId);
});
