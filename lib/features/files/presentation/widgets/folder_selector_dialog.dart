import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../application/file_services_provider.dart';

/// 文件夹选择器对话框
class FolderSelectorDialog extends ConsumerStatefulWidget {
  final String initialPath;
  final String title;

  const FolderSelectorDialog({
    super.key,
    this.initialPath = '/',
    this.title = '选择文件夹',
  });

  @override
  ConsumerState<FolderSelectorDialog> createState() =>
      _FolderSelectorDialogState();
}

class _FolderSelectorDialogState extends ConsumerState<FolderSelectorDialog> {
  String _currentPath = '/';
  List<webdav.File> _folders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);

    final service = ref.read(fileOperationServiceProvider);
    List<webdav.File> folders = [];
    try {
      folders = await service.listFolders(_currentPath);
    } catch (e) {
      debugPrint('加载文件夹失败: $e');
    }

    setState(() {
      _folders = folders;
      _isLoading = false;
    });
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _currentPath = '$_currentPath/$folderName'.replaceAll('//', '/');
    });
    _loadFolders();
  }

  void _navigateUp() {
    if (_currentPath == '/') return;

    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      setState(() => _currentPath = '/');
    } else {
      setState(() => _currentPath = '/${segments.sublist(0, segments.length - 1).join('/')}');
    }
    _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // 当前路径显示
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_currentPath != '/')
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: _navigateUp,
                      tooltip: '上一级',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            // 文件夹列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _folders.isEmpty
                      ? const Center(child: Text('此目录下没有子文件夹'))
                      : ListView.builder(
                          itemCount: _folders.length,
                          itemBuilder: (context, index) {
                            final folder = _folders[index];
                            return ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(folder.name ?? ''),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _navigateToFolder(folder.name ?? ''),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentPath),
          child: const Text('选择此文件夹'),
        ),
      ],
    );
  }
}

/// 显示文件夹选择器
Future<String?> showFolderSelector(
  BuildContext context, {
  String initialPath = '/',
  String title = '选择文件夹',
}) async {
  return await showDialog<String>(
    context: context,
    builder: (context) => FolderSelectorDialog(
      initialPath: initialPath,
      title: title,
    ),
  );
}
