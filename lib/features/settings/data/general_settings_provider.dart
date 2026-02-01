import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_provider.dart';

enum DownloadMode {
  singleFile,
  folder,
  alwaysAsk,
}

class GeneralSettingsState {
  final bool showFileThumbnails;
  final bool checkMobileData;
  final DownloadMode defaultDownloadMode;

  GeneralSettingsState({
    this.showFileThumbnails = true,
    this.checkMobileData = true,
    this.defaultDownloadMode = DownloadMode.alwaysAsk,
  });

  GeneralSettingsState copyWith({
    bool? showFileThumbnails,
    bool? checkMobileData,
    DownloadMode? defaultDownloadMode,
  }) {
    return GeneralSettingsState(
      showFileThumbnails: showFileThumbnails ?? this.showFileThumbnails,
      checkMobileData: checkMobileData ?? this.checkMobileData,
      defaultDownloadMode: defaultDownloadMode ?? this.defaultDownloadMode,
    );
  }
}

class GeneralSettingsNotifier extends StateNotifier<GeneralSettingsState> {
  final String userId;
  late final String _kShowFileThumbnailsKey;
  late final String _kCheckMobileDataKey;
  late final String _kDefaultDownloadModeKey;

  GeneralSettingsNotifier(this.userId) : super(GeneralSettingsState()) {
    final suffix = userId.isNotEmpty ? '_$userId' : '';
    _kShowFileThumbnailsKey = 'show_file_thumbnails$suffix';
    _kCheckMobileDataKey = 'check_mobile_data$suffix';
    _kDefaultDownloadModeKey = 'default_download_mode$suffix';

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final showFileThumbnails = prefs.getBool(_kShowFileThumbnailsKey) ?? true;
    final checkMobileData = prefs.getBool(_kCheckMobileDataKey) ?? true;
    final downloadModeIndex = prefs.getInt(_kDefaultDownloadModeKey) ?? 0;

    state = state.copyWith(
      showFileThumbnails: showFileThumbnails,
      checkMobileData: checkMobileData,
      defaultDownloadMode: DownloadMode
          .values[downloadModeIndex.clamp(0, DownloadMode.values.length - 1)],
    );
  }

  Future<void> setShowFileThumbnails(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowFileThumbnailsKey, value);
    state = state.copyWith(showFileThumbnails: value);
  }

  Future<void> setCheckMobileData(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCheckMobileDataKey, value);
    state = state.copyWith(checkMobileData: value);
  }

  Future<void> setDefaultDownloadMode(DownloadMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefaultDownloadModeKey, value.index);
    state = state.copyWith(defaultDownloadMode: value);
  }
}

final generalSettingsProvider =
    StateNotifierProvider<GeneralSettingsNotifier, GeneralSettingsState>((ref) {
  final authState = ref.watch(authProvider);
  final userId =
      authState.currentUser?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'guest';
  return GeneralSettingsNotifier(userId);
});
