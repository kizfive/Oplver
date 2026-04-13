import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  system,
  zhCN,
  enUS,
}

class LocaleState {
  const LocaleState({required this.language});

  final AppLanguage language;

  Locale? get locale {
    switch (language) {
      case AppLanguage.system:
        return null;
      case AppLanguage.zhCN:
        return const Locale('zh', 'CN');
      case AppLanguage.enUS:
        return const Locale('en', 'US');
    }
  }

  LocaleState copyWith({AppLanguage? language}) {
    return LocaleState(language: language ?? this.language);
  }
}

class LocaleNotifier extends StateNotifier<LocaleState> {
  LocaleNotifier() : super(const LocaleState(language: AppLanguage.system)) {
    _load();
  }

  static const _storageKey = 'app_language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey) ?? AppLanguage.system.name;
    final lang = AppLanguage.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppLanguage.system,
    );
    state = state.copyWith(language: lang);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, language.name);
  }
}

final appLocaleProvider =
    StateNotifierProvider<LocaleNotifier, LocaleState>((ref) {
  return LocaleNotifier();
});
