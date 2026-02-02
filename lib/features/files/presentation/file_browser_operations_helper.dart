import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../application/file_operation_service.dart';
import 'widgets/folder_selector_dialog.dart';

/// 文件浏览器操作助手 - 处理文件操作的对话框和逻辑
class FileBrowserOperationsHelper {
  /// 显示重命名对话框
  static Future<void> showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
    webdav.File file,
    VoidCallback onSuccess,
  ) async {
    final controller = TextEditingController(text: file.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新文件名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != file.name) {
      final service = ref.read(fileOperationServiceProvider);
      final success = await service.renameFile(currentPath, file.name ?? '', result);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('重命名成功'), backgroundColor: Colors.green),
          );
          onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('重命名失败'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// 显示删除确认对话框
  static Future<void> showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
    List<String> fileNames,
    VoidCallback onSuccess,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(fileNames.length == 1
            ? '确定要删除文件 "${fileNames.first}" 吗？'
            : '确定要删除选中的 ${fileNames.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(fileOperationServiceProvider);
      final success = await service.deleteFiles(currentPath, fileNames);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功'), backgroundColor: Colors.green),
          );
          onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// 显示复制/移动文件夹选择对话框
  static Future<void> showCopyMoveDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
    List<String> fileNames,
    bool isMove,
    VoidCallback onSuccess,
  ) async {
    final targetPath = await showFolderSelector(
      context,
      initialPath: currentPath,
      title: isMove ? '移动到' : '复制到',
    );

    if (targetPath != null && targetPath != currentPath) {
      final service = ref.read(fileOperationServiceProvider);
      final success = isMove
          ? await service.moveFiles(currentPath, targetPath, fileNames)
          : await service.copyFiles(currentPath, targetPath, fileNames);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isMove ? "移动" : "复制"}成功'),
              backgroundColor: Colors.green,
            ),
          );
          onSuccess();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isMove ? "移动" : "复制"}失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 显示上传文件对话框
  static Future<void> showUploadDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
    VoidCallback onSuccess,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
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
                    Text('正在上传文件...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final service = ref.read(fileOperationServiceProvider);
      int successCount = 0;
      int failCount = 0;

      for (final file in result.files) {
        if (file.bytes != null) {
          final success = await service.uploadFile(
            currentPath,
            file.name,
            file.bytes!,
          );
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        }
      }

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        String message;
        Color color;
        if (failCount == 0) {
          message = '上传成功 ($successCount 个文件)';
          color = Colors.green;
        } else if (successCount == 0) {
          message = '上传失败';
          color = Colors.red;
        } else {
          message = '部分上传成功 ($successCount 成功, $failCount 失败)';
          color = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );

        if (successCount > 0) {
          onSuccess();
        }
      }
    }
  }
}
