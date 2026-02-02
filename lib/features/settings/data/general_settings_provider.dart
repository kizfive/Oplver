import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/enums/download_mode.dart';
import '../../auth/data/auth_provider.dart';

class GeneralSettingsState {
  final bool showFileThumbnails;
  final bool checkMobileData;
  final DownloadMode defaultDownloadMode;
  final bool enableApiEnhancement;
  final bool autoResumeManga;

  GeneralSettingsState({
    this.showFileThumbnails = true,
    this.checkMobileData = true,
    this.defaultDownloadMode = DownloadMode.alwaysAsk,
    this.enableApiEnhancement = false,
    this.autoResumeManga = true,
  });

  GeneralSettingsState copyWith({
    bool? showFileThumbnails,
    bool? checkMobileData,
    DownloadMode? defaultDownloadMode,
    bool? enableApiEnhancement,
    bool? autoResumeManga,
  }) {
    return GeneralSettingsState(
      showFileThumbnails: showFileThumbnails ?? this.showFileThumbnails,
      checkMobileData: checkMobileData ?? this.checkMobileData,
      defaultDownloadMode: defaultDownloadMode ?? this.defaultDownloadMode,
      enableApiEnhancement: enableApiEnhancement ?? this.enableApiEnhancement,
      autoResumeManga: autoResumeManga ?? this.autoResumeManga,
    );
  }
}

class GeneralSettingsNotifier extends StateNotifier<GeneralSettingsState> {
  final String userId;
  late final String _kShowFileThumbnailsKey;
  late final String _kCheckMobileDataKey;
  late final String _kDefaultDownloadModeKey;
  late final String _kEnableApiEnhancementKey;
  late final String _kAutoResumeMangaKey;

  GeneralSettingsNotifier(this.userId) : super(GeneralSettingsState()) {
    final suffix = userId.isNotEmpty ? '_$userId' : '';
    _kShowFileThumbnailsKey = 'show_file_thumbnails$suffix';
    _kCheckMobileDataKey = 'check_mobile_data$suffix';
    _kDefaultDownloadModeKey = 'default_download_mode$suffix';
    _kEnableApiEnhancementKey = 'enable_api_enhancement$suffix';
    _kAutoResumeMangaKey = 'auto_resume_manga$suffix';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final showFileThumbnails = prefs.getBool(_kShowFileThumbnailsKey) ?? true;
    final checkMobileData = prefs.getBool(_kCheckMobileDataKey) ?? false;
    final downloadModeIndex = prefs.getInt(_kDefaultDownloadModeKey) ?? 0;
    final enableApiEnhancement = prefs.getBool(_kEnableApiEnhancementKey) ?? false;
    final autoResumeManga = prefs.getBool(_kAutoResumeMangaKey) ?? true;

    state = state.copyWith(
      showFileThumbnails: showFileThumbnails,
      checkMobileData: checkMobileData,
      defaultDownloadMode: DownloadMode.values[downloadModeIndex.clamp(0, DownloadMode.values.length - 1)],
      enableApiEnhancement: enableApiEnhancement,
      autoResumeManga: autoResumeManga,
    );
  }

  Future<void> setShowFileThumbnails(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowFileThumbnailsKey, value);
    state = state.copyWith(showFileThumbnails: value);
  }
  
  Future<void> setAutoResumeManga(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoResumeMangaKey, value);
    state = state.copyWith(autoResumeManga: value);
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

  Future<void> setEnableApiEnhancement(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnableApiEnhancementKey, value);
    state = state.copyWith(enableApiEnhancement: value);
  }
}

final generalSettingsProvider = StateNotifierProvider<GeneralSettingsNotifier, GeneralSettingsState>((ref) {
  final authState = ref.watch(authProvider);
  final userId = authState.currentUser?.replaceAll(RegExp(r'[^\w]'), '_') ?? 'guest';
  return GeneralSettingsNotifier(userId);
});
