import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/log_service.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_provider.dart';
import 'core/services/update_checker_service.dart';
import 'core/ui/global_scaffold_messenger.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..maxConnectionsPerHost = 10
      ..connectionTimeout = const Duration(seconds: 10);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务
  await appLogger.initialize();
  logInfo('App', '应用启动');

  HttpOverrides.global = MyHttpOverrides();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(appThemeStateProvider);
    final localeState = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      theme: AppTheme.lightTheme(themeState.seedColor),
      darkTheme: AppTheme.darkTheme(themeState.seedColor),
      themeMode: themeState.mode,
      locale: localeState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return _StartupUpdateCheckGate(child: child ?? const SizedBox.shrink());
      },
      routerConfig: router,
    );
  }
}

class _StartupUpdateCheckGate extends ConsumerStatefulWidget {
  const _StartupUpdateCheckGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_StartupUpdateCheckGate> createState() =>
      _StartupUpdateCheckGateState();
}

class _StartupUpdateCheckGateState
    extends ConsumerState<_StartupUpdateCheckGate> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) {
      return;
    }
    _checked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(updateCheckerServiceProvider).checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
