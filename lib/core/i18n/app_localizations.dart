import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (instance == null) {
      throw FlutterError('AppLocalizations not found in context');
    }
    return instance;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh_CN': {
      'appTitle': 'OpenList Viewer',
      'settings': '设置',
      'general': '通用',
      'video': '视频',
      'appearance': '外观',
      'advanced': '高级',
      'language': '语言',
      'languageSubtitle': '选择软件显示语言',
      'languageSystem': '跟随系统',
      'languageZhCn': '简体中文',
      'languageEnUs': 'English',
      'checkUpdate': '检查更新',
      'checkUpdateSubtitle': '立即检查是否有新版本',
      'checkingUpdate': '正在检查更新...',
      'latestVersion': '当前已是最新版本',
      'newVersionFound': '发现新版本',
      'currentVersion': '当前版本',
      'newVersion': '最新版本',
      'updateNow': '立即更新',
      'remindLater': '稍后提醒',
      'remindIn1Day': '1天后提醒',
      'remindIn3Days': '3天后提醒',
      'remindIn7Days': '7天后提醒',
      'updateCheckFailed': '检查更新失败',
      'loginSuccess': '登录成功！',
      'apiModeEnabled': '已开启API模式',
      'apiModeFailed': '开启API模式失败',
      'defaultVideoOrientation': '默认视频方向',
      'showFileThumbnails': '文件管理缩略图',
      'showFileThumbnailsSubtitle': '在该页面显示视频和图片的预览',
      'warnMobileData': '是否警告正在使用移动流量下载',
      'warnMobileDataSubtitle': '使用移动流量下载时弹出提示',
      'defaultDownloadMode': '默认下载模式',
      'downloadModeAlwaysAsk': '每次询问',
      'downloadModeSingle': '直接下载(文件)',
      'downloadModeFolder': '直接下载(文件夹)',
      'videoAutoResume': '视频记忆播放',
      'videoAutoResumeSubtitle': '进入视频时从上次退出的进度接续播放',
      'changeThemeColor': '更改色调',
      'changeThemeColorSubtitle': '自定义软件主题色',
      'exportLogs': '导出运行日志',
      'exportLogsSubtitle': '用于问题诊断和反馈',
      'videoOrientationLandscape': '横屏',
      'videoOrientationPortrait': '竖屏',
      'videoOrientationSensorLandscape': '传感器横屏',
      'videoOrientationSensorPortrait': '传感器竖屏',
      'navHome': '首页',
      'navFiles': '文件',
      'navManga': '漫画',
      'navProfile': '我的',
      'profile': '个人中心',
      'toggleThemeMode': '切换日夜模式',
      'currentAccount': '当前账户',
      'server': '服务器',
      'notConnected': '未连接',
      'username': '用户名',
      'unknown': '未知',
      'apiEnhancement': 'API增强功能',
      'apiEnhancementSubtitle': '启用后可使用搜索、缩略图优化等高级功能',
      'checkApiConnection': '检测API连接情况',
      'checkApiConnectionSubtitle': '立即检测当前账号的API连接状态',
      'checkingApiConnection': '正在检测API连接...',
      'autoResumeManga': '漫画自动恢复阅读进度',
      'autoResumeMangaSubtitle': '进入漫画时是否自动跳转到上次阅读位置',
      'manageNavigation': '管理导航栏',
      'defaultPageAfterLogin': '登录后默认页面',
      'selectDefaultPage': '选择默认页面',
      'downloads': '下载记录',
      'about': '关于',
      'logout': '退出登录',
      'homePlayUrl': '播放 URL',
      'playNetworkVideo': '播放网络视频',
      'inputVideoUrl': '输入视频 URL (http/https/rtmp...)',
      'cancel': '取消',
      'play': '播放',
      'urlNotReachable': '无法访问',
      'frequentFolders': '常访文件夹',
      'clearFrequentCount': '清除常访计数',
      'confirmClear': '确认清除',
      'confirmClearFrequentCount': '确定要清除所有常访文件夹的访问计数吗？',
      'confirm': '确定',
      'frequentCountCleared': '已清除常访计数',
      'noFrequentRecords': '暂无常访记录',
      'loadFailed': '加载失败',
      'visitCountSuffix': '次访问',
      'playHistory': '播放历史',
      'clearPlayHistory': '清除播放历史',
      'confirmClearPlayHistory': '确定要清除所有播放历史吗？',
      'playHistoryCleared': '已清除播放历史',
      'noPlayRecords': '暂无播放记录',
      'options': '选项',
      'openParentFolder': '打开文件所在文件夹',
      'fileInfo': '文件信息',
      'details': '详细信息',
      'path': '路径',
      'lastOpened': '上次打开',
      'cannotLoadMangaInfo': '无法加载漫画信息',
      'openMangaFailed': '打开漫画失败',
      'loadDirectoryFailed': '加载目录失败',
      'login': '登录',
      'serverAddress': '服务器地址',
      'history': '历史记录',
      'password': '密码',
      'rememberPassword': '记住密码',
      'autoLogin': '自动登录',
      'connectServer': '连接服务器',
      'inputServerAddress': '请输入服务器地址',
      'inputUsername': '请输入用户名',
      'inputPassword': '请输入密码',
      'enableRuntimeLogs': '启用运行日志',
      'enableRuntimeLogsSubtitle': '默认关闭，开启后才会开始记录日志',
      'aboutDeveloper': '由 Notess 开发',
      'dependencies': '依赖库',
      'versionLabel': '版本',
      'authorLabel': '作者',
      'downloadRecords': '下载记录',
      'clearCompletedRecords': '清除已完成记录',
      'confirmClearCompletedRecords': '确定要清除所有已完成/失败的下载记录吗？',
      'completedRecordsCleared': '已清除完成记录',
      'noDownloadRecords': '没有下载记录',
      'failed': '失败',
      'paused': '已暂停',
      'cannotOpenFolderDirectly': '无法直接打开子文件夹。文件位于 "Download > Oplver Download" 中',
      'manga': '漫画',
      'refresh': '刷新',
      'selectMangaFolder': '选择漫画文件夹',
      'clearMangaCache': '清除漫画缓存',
      'apiEnhancementRequired': '需开启API增强',
      'mangaApiRequiredHint': '漫画功能需要API支持，请前往“我的”页面开启API增强功能',
      'goEnable': '前往开启',
      'selectMangaFolderTitle': '选择漫画文件夹',
      'selectMangaFolderHint': '请选择包含漫画的文件夹开始浏览',
      'selectFolder': '选择文件夹',
      'retry': '重试',
      'noMangaFound': '没有发现漫画',
      'noMangaFoundHint': '在选择的文件夹中没有找到包含.manga文件的漫画目录',
      'reselectFolder': '重新选择文件夹',
      'confirmClearMangaCache': '确定要清除所有漫画元数据和封面缓存吗？\n这将触发重新全量扫描。',
      'clear': '清除',
      'mangaCacheClearedAndRescan': '缓存已清除，正在重新扫描...',
      'exportingLogs': '正在导出日志...',
      'logsExported': '日志已导出',
      'exportFailed': '导出失败',
      'chooseThemeColor': '选择主题色',
      'allAlbums': '全部相册',
      'noImagesFound': '没有发现图片',
      'storagePermissionRequired': '需要存储权限才能下载',
      'downloadOptions': '下载选项',
      'fileName': '文件名',
      'size': '大小',
      'chooseDownloadMode': '请选择下载方式:',
      'downloadCurrentImageOnly': '仅下载当前图片',
      'downloadAllImagesInFolder': '下载整个文件夹内的图片',
      'mobileDataWarning': '流量提醒',
      'mobileDataContinueDownload': '当前处于移动数据网络，是否继续下载？',
      'continueAction': '继续',
      'downloadFailed': '下载失败',
      'startBatchDownloadImages': '开始批量下载图片',
      'view': '查看',
      'startDownload': '开始下载',
      'downloadToLocal': '下载到本地',
      'name': '名称',
      'modifiedTime': '修改时间',
      'close': '关闭',
      'cannotLoadImage': '无法加载图片',
      'readingProgressRestored': '已恢复阅读进度',
      'pagePrefix': '第',
      'pageUnit': '页',
      'totalPrefix': '共',
      'totalPages': '总共',
      'pageNumber': '页码',
      'jumpToPage': '跳转到页面',
      'jump': '跳转',
      'switchToHorizontalMode': '切换到水平模式',
      'switchToVerticalMode': '切换到垂直模式',
      'pageLoadFailedSuffix': '页加载失败',
      'runtimeLogsSubject': 'OpenList Viewer 运行日志',
      'logsContainPrefix': '日志文件包含',
      'recordsUnit': '条记录',
    },
    'en_US': {
      'appTitle': 'OpenList Viewer',
      'settings': 'Settings',
      'general': 'General',
      'video': 'Video',
      'appearance': 'Appearance',
      'advanced': 'Advanced',
      'language': 'Language',
      'languageSubtitle': 'Choose app display language',
      'languageSystem': 'Follow system',
      'languageZhCn': 'Simplified Chinese',
      'languageEnUs': 'English',
      'checkUpdate': 'Check for updates',
      'checkUpdateSubtitle': 'Check latest version now',
      'checkingUpdate': 'Checking for updates...',
      'latestVersion': 'You are on the latest version',
      'newVersionFound': 'New version available',
      'currentVersion': 'Current version',
      'newVersion': 'Latest version',
      'updateNow': 'Update now',
      'remindLater': 'Remind me later',
      'remindIn1Day': 'Remind in 1 day',
      'remindIn3Days': 'Remind in 3 days',
      'remindIn7Days': 'Remind in 7 days',
      'updateCheckFailed': 'Update check failed',
      'loginSuccess': 'Login successful!',
      'apiModeEnabled': 'API mode enabled',
      'apiModeFailed': 'Failed to enable API mode',
      'defaultVideoOrientation': 'Default video orientation',
      'showFileThumbnails': 'Show file thumbnails',
      'showFileThumbnailsSubtitle': 'Show previews for videos and images in file page',
      'warnMobileData': 'Warn on mobile data download',
      'warnMobileDataSubtitle': 'Prompt when downloading on cellular network',
      'defaultDownloadMode': 'Default download mode',
      'downloadModeAlwaysAsk': 'Always ask',
      'downloadModeSingle': 'Download file directly',
      'downloadModeFolder': 'Download folder directly',
      'videoAutoResume': 'Resume video playback',
      'videoAutoResumeSubtitle': 'Continue from last watched position',
      'changeThemeColor': 'Change accent color',
      'changeThemeColorSubtitle': 'Customize app theme color',
      'exportLogs': 'Export runtime logs',
      'exportLogsSubtitle': 'For diagnostics and feedback',
      'videoOrientationLandscape': 'Landscape',
      'videoOrientationPortrait': 'Portrait',
      'videoOrientationSensorLandscape': 'Sensor landscape',
      'videoOrientationSensorPortrait': 'Sensor portrait',
      'navHome': 'Home',
      'navFiles': 'Files',
      'navManga': 'Manga',
      'navProfile': 'Profile',
      'profile': 'Profile',
      'toggleThemeMode': 'Toggle theme mode',
      'currentAccount': 'Current account',
      'server': 'Server',
      'notConnected': 'Not connected',
      'username': 'Username',
      'unknown': 'Unknown',
      'apiEnhancement': 'API enhancement',
      'apiEnhancementSubtitle': 'Enable search, optimized thumbnails and other advanced features',
      'checkApiConnection': 'Check API connection',
      'checkApiConnectionSubtitle': 'Check current account API connection status now',
      'checkingApiConnection': 'Checking API connection...',
      'autoResumeManga': 'Auto resume manga reading',
      'autoResumeMangaSubtitle': 'Jump to last read position when opening manga',
      'manageNavigation': 'Manage navigation bar',
      'defaultPageAfterLogin': 'Default page after login',
      'selectDefaultPage': 'Select default page',
      'downloads': 'Downloads',
      'about': 'About',
      'logout': 'Log out',
      'homePlayUrl': 'Play URL',
      'playNetworkVideo': 'Play network video',
      'inputVideoUrl': 'Enter video URL (http/https/rtmp...)',
      'cancel': 'Cancel',
      'play': 'Play',
      'urlNotReachable': 'Cannot access',
      'frequentFolders': 'Frequent folders',
      'clearFrequentCount': 'Clear frequent counts',
      'confirmClear': 'Confirm clear',
      'confirmClearFrequentCount': 'Clear all frequent folder visit counts?',
      'confirm': 'Confirm',
      'frequentCountCleared': 'Frequent counts cleared',
      'noFrequentRecords': 'No frequent records',
      'loadFailed': 'Load failed',
      'visitCountSuffix': 'visits',
      'playHistory': 'Play history',
      'clearPlayHistory': 'Clear play history',
      'confirmClearPlayHistory': 'Clear all play history?',
      'playHistoryCleared': 'Play history cleared',
      'noPlayRecords': 'No play records',
      'options': 'Options',
      'openParentFolder': 'Open parent folder',
      'fileInfo': 'File info',
      'details': 'Details',
      'path': 'Path',
      'lastOpened': 'Last opened',
      'cannotLoadMangaInfo': 'Cannot load manga info',
      'openMangaFailed': 'Failed to open manga',
      'loadDirectoryFailed': 'Failed to load directory',
      'login': 'Login',
      'serverAddress': 'Server address',
      'history': 'History',
      'password': 'Password',
      'rememberPassword': 'Remember password',
      'autoLogin': 'Auto login',
      'connectServer': 'Connect server',
      'inputServerAddress': 'Please enter server address',
      'inputUsername': 'Please enter username',
      'inputPassword': 'Please enter password',
      'enableRuntimeLogs': 'Enable runtime logs',
      'enableRuntimeLogsSubtitle': 'Disabled by default. Logging starts only after enabling',
      'aboutDeveloper': 'Developed by Notess',
      'dependencies': 'Dependencies',
      'versionLabel': 'Version',
      'authorLabel': 'Author',
      'downloadRecords': 'Download records',
      'clearCompletedRecords': 'Clear completed records',
      'confirmClearCompletedRecords': 'Clear all completed/failed download records?',
      'completedRecordsCleared': 'Completed records cleared',
      'noDownloadRecords': 'No download records',
      'failed': 'Failed',
      'paused': 'Paused',
      'cannotOpenFolderDirectly': 'Cannot open subfolder directly. Files are in "Download > Oplver Download"',
      'manga': 'Manga',
      'refresh': 'Refresh',
      'selectMangaFolder': 'Select manga folder',
      'clearMangaCache': 'Clear manga cache',
      'apiEnhancementRequired': 'API enhancement required',
      'mangaApiRequiredHint': 'Manga requires API support. Enable API enhancement in Profile page.',
      'goEnable': 'Go enable',
      'selectMangaFolderTitle': 'Select manga folder',
      'selectMangaFolderHint': 'Select a folder that contains manga to start browsing',
      'selectFolder': 'Select folder',
      'retry': 'Retry',
      'noMangaFound': 'No manga found',
      'noMangaFoundHint': 'No manga folder with .manga file found in selected path',
      'reselectFolder': 'Select another folder',
      'confirmClearMangaCache': 'Clear all manga metadata and cover cache?\nThis will trigger a full rescan.',
      'clear': 'Clear',
      'mangaCacheClearedAndRescan': 'Cache cleared, rescanning...',
      'exportingLogs': 'Exporting logs...',
      'logsExported': 'Logs exported',
      'exportFailed': 'Export failed',
      'chooseThemeColor': 'Choose theme color',
      'allAlbums': 'All albums',
      'noImagesFound': 'No images found',
      'storagePermissionRequired': 'Storage permission is required to download',
      'downloadOptions': 'Download options',
      'fileName': 'File name',
      'size': 'Size',
      'chooseDownloadMode': 'Please choose a download mode:',
      'downloadCurrentImageOnly': 'Download current image only',
      'downloadAllImagesInFolder': 'Download all images in this folder',
      'mobileDataWarning': 'Mobile data warning',
      'mobileDataContinueDownload': 'You are on mobile data. Continue downloading?',
      'continueAction': 'Continue',
      'downloadFailed': 'Download failed',
      'startBatchDownloadImages': 'Starting batch image download',
      'view': 'View',
      'startDownload': 'Starting download',
      'downloadToLocal': 'Download to local',
      'name': 'Name',
      'modifiedTime': 'Modified time',
      'close': 'Close',
      'cannotLoadImage': 'Cannot load image',
      'readingProgressRestored': 'Reading progress restored',
      'pagePrefix': 'Page',
      'pageUnit': '',
      'totalPrefix': 'Total',
      'totalPages': 'Total pages',
      'pageNumber': 'Page number',
      'jumpToPage': 'Jump to page',
      'jump': 'Jump',
      'switchToHorizontalMode': 'Switch to horizontal mode',
      'switchToVerticalMode': 'Switch to vertical mode',
      'pageLoadFailedSuffix': 'failed to load',
      'runtimeLogsSubject': 'OpenList Viewer Runtime Logs',
      'logsContainPrefix': 'Log file contains',
      'recordsUnit': 'records',
    },
  };

  String _text(String key) {
    final localeKey = '${locale.languageCode}_${locale.countryCode ?? ''}';
    final fallback = _localizedValues['zh_CN']!;
    return _localizedValues[localeKey]?[key] ?? fallback[key] ?? key;
  }

  String tr(String key) => _text(key);

  String get appTitle => _text('appTitle');
  String get settings => _text('settings');
  String get general => _text('general');
  String get video => _text('video');
  String get appearance => _text('appearance');
  String get advanced => _text('advanced');
  String get language => _text('language');
  String get languageSubtitle => _text('languageSubtitle');
  String get languageSystem => _text('languageSystem');
  String get languageZhCn => _text('languageZhCn');
  String get languageEnUs => _text('languageEnUs');
  String get checkUpdate => _text('checkUpdate');
  String get checkUpdateSubtitle => _text('checkUpdateSubtitle');
  String get checkingUpdate => _text('checkingUpdate');
  String get latestVersion => _text('latestVersion');
  String get newVersionFound => _text('newVersionFound');
  String get currentVersion => _text('currentVersion');
  String get newVersion => _text('newVersion');
  String get updateNow => _text('updateNow');
  String get remindLater => _text('remindLater');
  String get remindIn1Day => _text('remindIn1Day');
  String get remindIn3Days => _text('remindIn3Days');
  String get remindIn7Days => _text('remindIn7Days');
  String get updateCheckFailed => _text('updateCheckFailed');
  String get loginSuccess => _text('loginSuccess');
  String get apiModeEnabled => _text('apiModeEnabled');
  String get apiModeFailed => _text('apiModeFailed');
  String get defaultVideoOrientation => _text('defaultVideoOrientation');
  String get showFileThumbnails => _text('showFileThumbnails');
  String get showFileThumbnailsSubtitle => _text('showFileThumbnailsSubtitle');
  String get warnMobileData => _text('warnMobileData');
  String get warnMobileDataSubtitle => _text('warnMobileDataSubtitle');
  String get defaultDownloadMode => _text('defaultDownloadMode');
  String get downloadModeAlwaysAsk => _text('downloadModeAlwaysAsk');
  String get downloadModeSingle => _text('downloadModeSingle');
  String get downloadModeFolder => _text('downloadModeFolder');
  String get videoAutoResume => _text('videoAutoResume');
  String get videoAutoResumeSubtitle => _text('videoAutoResumeSubtitle');
  String get changeThemeColor => _text('changeThemeColor');
  String get changeThemeColorSubtitle => _text('changeThemeColorSubtitle');
  String get exportLogs => _text('exportLogs');
  String get exportLogsSubtitle => _text('exportLogsSubtitle');
  String get videoOrientationLandscape => _text('videoOrientationLandscape');
  String get videoOrientationPortrait => _text('videoOrientationPortrait');
  String get videoOrientationSensorLandscape =>
      _text('videoOrientationSensorLandscape');
  String get videoOrientationSensorPortrait =>
      _text('videoOrientationSensorPortrait');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) =>
          supported.languageCode == locale.languageCode &&
          supported.countryCode == locale.countryCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationsContextExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
