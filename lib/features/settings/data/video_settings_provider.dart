import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_provider.dart';

enum VideoOrientation {
  landscape,
  portrait,
  sensorLandscape,
  sensorPortrait;

  String get label {
    switch (this) {
      case VideoOrientation.landscape:
        return '横屏';
      case VideoOrientation.portrait:
        return '竖屏';
      case VideoOrientation.sensorLandscape:
        return '传感器横屏';
      case VideoOrientation.sensorPortrait:
        return '传感器竖屏';
    }
  }

  List<DeviceOrientation> get deviceOrientations {
    switch (this) {
      case VideoOrientation.landscape:
        return [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ];
      case VideoOrientation.portrait:
        return [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
      case VideoOrientation.sensorLandscape:
        return [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ];
      case VideoOrientation.sensorPortrait:
        return [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
    }
  }
}

class VideoSettingsState {
  final VideoOrientation defaultOrientation;
  final bool enableAutoResume;
  final bool enableThumbnails;

  VideoSettingsState({
    this.defaultOrientation = VideoOrientation.sensorLandscape,
    this.enableAutoResume = true,
    this.enableThumbnails = true,
  });

  VideoSettingsState copyWith({
    VideoOrientation? defaultOrientation,
    bool? enableAutoResume,
    bool? enableThumbnails,
  }) {
    return VideoSettingsState(
      defaultOrientation: defaultOrientation ?? this.defaultOrientation,
      enableAutoResume: enableAutoResume ?? this.enableAutoResume,
      enableThumbnails: enableThumbnails ?? this.enableThumbnails,
    );
  }
}

class VideoSettingsNotifier extends StateNotifier<VideoSettingsState> {
  final String userId;
  late final String _keyOrientation;
  late final String _keyAutoResume;
  late final String _keyThumbnails;

  VideoSettingsNotifier(this.userId) : super(VideoSettingsState()) {
    // Isolate settings by userId
    final suffix = userId.isNotEmpty ? '_$userId' : '';
    _keyOrientation = 'video_default_orientation$suffix';
    _keyAutoResume = 'video_auto_resume$suffix';
    _keyThumbnails = 'video_enable_thumbnails$suffix';

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final orientationIndex = prefs.getInt(_keyOrientation);
    final autoResume = prefs.getBool(_keyAutoResume) ?? true;
    final thumbnails = prefs.getBool(_keyThumbnails) ?? true;

    VideoOrientation? orientation;
    if (orientationIndex != null &&
        orientationIndex >= 0 &&
        orientationIndex < VideoOrientation.values.length) {
      orientation = VideoOrientation.values[orientationIndex];
    }

    state = state.copyWith(
      defaultOrientation: orientation,
      enableAutoResume: autoResume,
      enableThumbnails: thumbnails,
    );
  }

  Future<void> setOrientation(VideoOrientation orientation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOrientation, orientation.index);
    state = state.copyWith(defaultOrientation: orientation);
  }

  Future<void> setAutoResume(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoResume, enable);
    state = state.copyWith(enableAutoResume: enable);
  }

  Future<void> setThumbnails(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThumbnails, enable);
    state = state.copyWith(enableThumbnails: enable);
  }
}

final videoSettingsProvider =
    StateNotifierProvider<VideoSettingsNotifier, VideoSettingsState>((ref) {
  // Re-create provider when currentUser changes
  final authState = ref.watch(authProvider);
  // Sanitize userId to be safe for keys
  final userId =
      authState.currentUser?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'guest';
  return VideoSettingsNotifier(userId);
});
