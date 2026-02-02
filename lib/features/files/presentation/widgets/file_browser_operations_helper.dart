import 'package:flutter/material.dart';

/// 文件浏览器操作助手类
class FileBrowserOperationsHelper {
  /// 显示文件操作选择对话框
  static Future<String?> showFileOperationDialog(
    BuildContext context, {
    required List<String> operations,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择操作'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: operations.map((operation) {
              return ListTile(
                title: Text(operation),
                onTap: () {
                  Navigator.of(context).pop(operation);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 显示复制/移动对话框
  static Future<Map<String, dynamic>?> showCopyMoveDialog(
    BuildContext context, {
    required bool isMove,
    required List<String> selectedFiles,
  }) async {
    String? targetPath;
    
    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isMove ? '移动文件' : '复制文件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('选中的文件: ${selectedFiles.length} 个'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '目标路径',
                  hintText: '输入目标路径',
                ),
                onChanged: (value) => targetPath = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (targetPath != null && targetPath!.isNotEmpty) {
                  Navigator.of(context).pop({
                    'targetPath': targetPath,
                    'isMove': isMove,
                  });
                }
              },
              child: Text(isMove ? '移动' : '复制'),
            ),
          ],
        );
      },
    );
  }

  /// 显示重命名对话框
  static Future<String?> showRenameDialog(
    BuildContext context, {
    required String currentName,
  }) async {
    final controller = TextEditingController(text: currentName);
    
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '新名称',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('重命名'),
            ),
          ],
        );
      },
    );
  }

  /// 显示删除确认对话框
  static Future<bool> showDeleteDialog(
    BuildContext context, {
    required List<String> files,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除确认'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('确定要删除以下 ${files.length} 个文件吗？'),
              const SizedBox(height: 8),
              ...files.take(5).map((file) => Text('• $file')),
              if (files.length > 5) Text('...还有 ${files.length - 5} 个文件'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 显示上传对话框
  static Future<bool> showUploadDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('上传文件'),
          content: const Text('选择要上传的文件'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('选择文件'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 显示确认对话框
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 显示文本输入对话框
  static Future<String?> showTextInputDialog(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? hintText,
    String confirmText = '确认',
    String cancelText = '取消',
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hintText),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 显示加载对话框
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }
}