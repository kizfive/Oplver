import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../settings/data/video_settings_provider.dart';
import '../../../settings/data/general_settings_provider.dart';
import '../../../../core/services/log_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoSettings = ref.watch(videoSettingsProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final themeState = ref.watch(appThemeStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 通用设置分组
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '通用',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.photo_library_outlined),
            title: const Text('文件管理略缩图'),
            subtitle: const Text('在该页面显示视频和图片的预览'),
            value: generalSettings.showFileThumbnails,
            onChanged: (bool value) {
              ref
                  .read(generalSettingsProvider.notifier)
                  .setShowFileThumbnails(value);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.network_check),
            title: const Text('是否警告正在使用移动流量下载'),
            subtitle: const Text('使用移动流量下载时弹出提示'),
            value: generalSettings.checkMobileData,
            onChanged: (bool value) {
              ref
                  .read(generalSettingsProvider.notifier)
                  .setCheckMobileData(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('默认下载模式'),
            trailing: DropdownButton<DownloadMode>(
              value: generalSettings.defaultDownloadMode,
              underline: Container(),
              items: const [
                DropdownMenuItem(
                    value: DownloadMode.alwaysAsk, child: Text('每次询问')),
                DropdownMenuItem(
                    value: DownloadMode.singleFile, child: Text('直接下载(文件)')),
                DropdownMenuItem(
                    value: DownloadMode.folder, child: Text('直接下载(文件夹)')),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '视频',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.history_outlined),
            title: const Text('视频记忆播放'),
            subtitle: const Text('进入视频时从上次退出的进度接续播放'),
            value: videoSettings.enableAutoResume,
            onChanged: (bool value) {
              ref.read(videoSettingsProvider.notifier).setAutoResume(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.screen_rotation),
            title: const Text('默认视频方向'),
            subtitle: Text(videoSettings.defaultOrientation.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showOrientationDialog(context, ref);
            },
          ),

          const Divider(height: 32),

          // 外观设置分组
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '外观',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.palette, color: themeState.seedColor),
            title: const Text('更改色调'),
            subtitle: const Text('自定义软件主题色'),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '高级',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('导出运行日志'),
            subtitle: const Text('用于问题诊断和反馈'),
            trailing: const Icon(Icons.upload_file),
            onTap: () => _exportLogs(context),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    try {
      // 显示加载对话框
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在导出日志...'),
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
          subject: 'OpenList Viewer 运行日志',
          text: '日志文件包含 ${appLogger.getLogs().length} 条记录',
        );
        
        // 显示成功提示
        if (context.mounted && result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('日志已导出 (${appLogger.getLogs().length} 条记录)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      // 记录错误
      logError('Settings', '导出日志失败', e, stackTrace);
      
      // 关闭加载对话框（如果还在显示）
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrientationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择视频默认方向'),
          children: VideoOrientation.values.map((orientation) {
            return SimpleDialogOption(
              onPressed: () {
                ref
                    .read(videoSettingsProvider.notifier)
                    .setOrientation(orientation);
                Navigator.pop(context);
              },
              child: Text(orientation.label),
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
          title: const Text('选择主题色'),
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
              child: const Text('取消'),
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
