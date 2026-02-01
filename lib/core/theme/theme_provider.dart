import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeState {
  final ThemeMode mode;
  final Color seedColor;

  const AppThemeState({
    required this.mode,
    required this.seedColor,
  });

  AppThemeState copyWith({ThemeMode? mode, Color? seedColor}) {
    return AppThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<AppThemeState> {
  ThemeNotifier()
      : super(const AppThemeState(
            mode: ThemeMode.system, seedColor: Colors.blueAccent)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;

    // 兼容旧的 .value 读取，以及处理可能的空值
    final colorInt = prefs.getInt('theme_color');
    final seedColor = colorInt != null ? Color(colorInt) : Colors.blueAccent;

    state = AppThemeState(
      mode: ThemeMode.values[modeIndex],
      seedColor: seedColor,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    final prefs = await SharedPreferences.getInstance();
    // 使用 value 可能会有弃用警告，但在存储时我们需要一个 int。
    // 如果 SDK 提示弃用 value，可以使用 toARGB32() (Flutter 3.22+)
    // 或者忽略警告，因为这里我们需要序列化。
    // 简单起见，我们存储 int 值。
    // ignore: deprecated_member_use
    await prefs.setInt('theme_color', color.value);
  }
}

final appThemeStateProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeState>((ref) {
  return ThemeNotifier();
});
