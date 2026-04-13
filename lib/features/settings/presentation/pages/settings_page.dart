import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/enums/download_mode.dart';
import '../../../settings/data/video_settings_provider.dart';
import '../../../settings/data/general_settings_provider.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/services/update_checker_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final videoSettings = ref.watch(videoSettingsProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final themeState = ref.watch(appThemeStateProvider);
    final localeState = ref.watch(appLocaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // 通用设置分组
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.general,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.showFileThumbnails),
            subtitle: Text(l10n.showFileThumbnailsSubtitle),
            value: generalSettings.showFileThumbnails,
            onChanged: (bool value) {
              ref
                  .read(generalSettingsProvider.notifier)
                  .setShowFileThumbnails(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_languageLabel(context, localeState.language)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref, localeState.language),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.network_check),
            title: Text(l10n.warnMobileData),
            subtitle: Text(l10n.warnMobileDataSubtitle),
            value: generalSettings.checkMobileData,
            onChanged: (bool value) {
              ref
                  .read(generalSettingsProvider.notifier)
                  .setCheckMobileData(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(l10n.defaultDownloadMode),
            trailing: DropdownButton<DownloadMode>(
              value: generalSettings.defaultDownloadMode,
              underline: Container(),
              items: [
                DropdownMenuItem(
                    value: DownloadMode.alwaysAsk,
                    child: Text(l10n.downloadModeAlwaysAsk)),
                DropdownMenuItem(
                    value: DownloadMode.singleFile,
                    child: Text(l10n.downloadModeSingle)),
                DropdownMenuItem(
                    value: DownloadMode.folder,
                    child: Text(l10n.downloadModeFolder)),
              ],
              onChanged: (DownloadMode? value) {
                if (value != null) {
                  ref
                      .read(generalSettingsProvider.notifier)
                      .setDefaultDownloadMode(value);
                }
              },
            ),
          ),

          const Divider(height: 32),

          // 视频设置分组
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l10n.video,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.history_outlined),
            title: Text(l10n.videoAutoResume),
            subtitle: Text(l10n.videoAutoResumeSubtitle),
            value: videoSettings.enableAutoResume,
            onChanged: (bool value) {
              ref.read(videoSettingsProvider.notifier).setAutoResume(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.screen_rotation),
            title: Text(l10n.defaultVideoOrientation),
            subtitle: Text(videoSettings.defaultOrientation.label(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showOrientationDialog(context, ref);
            },
          ),

          const Divider(height: 32),

          // 外观设置分组
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l10n.appearance,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.palette, color: themeState.seedColor),
            title: Text(l10n.changeThemeColor),
            subtitle: Text(l10n.changeThemeColorSubtitle),
            trailing: CircleAvatar(
              backgroundColor: themeState.seedColor,
              radius: 12,
            ),
            onTap: () {
              _showColorPickerDialog(context, ref, themeState.seedColor);
            },
          ),

          const Divider(height: 32),

          // 高级设置分组
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l10n.advanced,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(l10n.checkUpdate),
            subtitle: Text(l10n.checkUpdateSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.checkingUpdate)),
              );
              await ref
                  .read(updateCheckerServiceProvider)
                  .checkForUpdates(context, manual: true);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.notes_outlined),
            title: Text(l10n.tr('enableRuntimeLogs')),
            subtitle: Text(l10n.tr('enableRuntimeLogsSubtitle')),
            value: generalSettings.enableRuntimeLogs,
            onChanged: (bool value) {
              ref.read(generalSettingsProvider.notifier).setEnableRuntimeLogs(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(l10n.exportLogs),
            subtitle: Text(l10n.exportLogsSubtitle),
            trailing: const Icon(Icons.upload_file),
            onTap: () => _exportLogs(context),
          ),
        ],
      ),
    );
  }

  String _languageLabel(BuildContext context, AppLanguage language) {
    final l10n = context.l10n;
    switch (language) {
      case AppLanguage.system:
        return l10n.languageSystem;
      case AppLanguage.zhCN:
        return l10n.languageZhCn;
      case AppLanguage.enUS:
        return l10n.languageEnUs;
    }
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    AppLanguage current,
  ) async {
    final l10n = context.l10n;
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: Text(l10n.language),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, AppLanguage.system),
              child: Row(
                children: [
                  if (current == AppLanguage.system)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(l10n.languageSystem),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, AppLanguage.zhCN),
              child: Row(
                children: [
                  if (current == AppLanguage.zhCN)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(l10n.languageZhCn),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, AppLanguage.enUS),
              child: Row(
                children: [
                  if (current == AppLanguage.enUS)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(l10n.languageEnUs),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (selected != null && selected != current) {
      await ref.read(appLocaleProvider.notifier).setLanguage(selected);
    }
  }

  Future<void> _exportLogs(BuildContext context) async {
    try {
      // 显示加载对话框
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(context.l10n.tr('exportingLogs')),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final logFile = File('${directory.path}/openlist_logs_$timestamp.txt');
      
      // 获取所有日志
      final logsContent = appLogger.exportLogs();
      
      // 写入文件
      await logFile.writeAsString(logsContent);
      
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        // 使用分享功能导出
        final result = await Share.shareXFiles(
          [XFile(logFile.path)],
          subject: context.l10n.tr('runtimeLogsSubject'),
          text: '${context.l10n.tr('logsContainPrefix')} ${appLogger.getLogs().length} ${context.l10n.tr('recordsUnit')}',
        );
        
        // 显示成功提示
        if (context.mounted && result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.l10n.tr('logsExported')} (${appLogger.getLogs().length})'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      // 记录错误
      logError('Settings', 'Export logs failed', e, stackTrace);
      
      // 关闭加载对话框（如果还在显示）
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.tr('exportFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrientationDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.defaultVideoOrientation),
          children: VideoOrientation.values.map((orientation) {
            return SimpleDialogOption(
              onPressed: () {
                ref
                    .read(videoSettingsProvider.notifier)
                    .setOrientation(orientation);
                Navigator.pop(context);
              },
              child: Text(orientation.label(l10n)),
            );
          }).toList(),
        );
      },
    );
  }

  void _showColorPickerDialog(
      BuildContext context, WidgetRef ref, Color currentColor) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.tr('chooseThemeColor')),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                ref.read(appThemeStateProvider.notifier).setSeedColor(color);
                Navigator.of(context).pop();
              },
              availableColors: const [
                Colors.blueAccent,
                Colors.lightBlue,
                Colors.cyan,
                Colors.teal,
                Colors.green,
                Colors.lightGreen,
                Colors.lime,
                Colors.yellow,
                Colors.amber,
                Colors.orange,
                Colors.deepOrange,
                Colors.red,
                Colors.redAccent,
                Colors.pink,
                Colors.purple,
                Colors.deepPurple,
                Colors.indigo,
                Colors.blueGrey,
                Colors.brown,
                Colors.grey,
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(context.l10n.tr('cancel')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
