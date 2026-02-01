import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/log_service.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..maxConnectionsPerHost = 10;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化日志服务
  await appLogger.initialize();
  logInfo('App', '应用启动');
  
  HttpOverrides.global = MyHttpOverrides();
  
  // 配置 fvp 播放器以获得更精确的暂停控制
  fvp.registerWith(options: {
    'platforms': ['windows', 'linux', 'macos', 'android', 'ios'],
    'video.decoders': ['FFmpeg'],
    'player': {
      // 暂停时保持最后一帧
      'keep-open': 'yes',
      // 使用显示同步模式，精确控制每一帧
      'video-sync': 'display-resample',
      // 禁用帧丢弃
      'framedrop': 'no',
      // 精确寻帧，不丢帧
      'hr-seek': 'yes',
      'hr-seek-framedrop': 'no',
      // 缓冲配置
      'cache': 'yes',
      'cache-pause': 'yes',
      'demuxer-max-bytes': '150M',
      'demuxer-max-back-bytes': '100M',
      // 降低延迟，更快响应暂停
      'video-latency-hacks': 'yes',
    },
  });
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(appThemeStateProvider);

    return MaterialApp.router(
      title: 'OpenList Viewer',
      theme: AppTheme.lightTheme(themeState.seedColor),
      darkTheme: AppTheme.darkTheme(themeState.seedColor),
      themeMode: themeState.mode,
      routerConfig: router,
    );
  }
}
