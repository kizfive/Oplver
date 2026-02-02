import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:typed_data';
import '../../../core/network/openlist_service.dart';
import '../../settings/data/general_settings_provider.dart';
import '../../auth/data/auth_provider.dart';

/// 文件操作服务 - 根据设置选择使用 WebDAV 或 API
class FileOperationService {
  final Ref ref;

  FileOperationService(this.ref);

  bool get _useApi => ref.read(generalSettingsProvider).enableApiEnhancement;

  /// 删除文件
  Future<bool> deleteFiles(String dirPath, List<String> fileNames) async {
    if (_useApi) {
      final apiService = ref.read(openListApiServiceProvider);
      return await apiService.deleteFile(dirPath, fileNames);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      if (!webdavService.isConnected) return false;

      try {
        for (final fileName in fileNames) {
          final filePath = '$dirPath/$fileName'.replaceAll('//', '/');
          await webdavService.client!.remove(filePath);
        }
        return true;
      } catch (e) {
        debugPrint('WebDAV 删除文件失败: $e');
        return false;
      }
    }
  }

  /// 重命名文件
  Future<bool> renameFile(String currentPath, String oldName, String newName) async {
    final oldPath = '$currentPath/$oldName'.replaceAll('//', '/');

    if (_useApi) {
      final apiService = ref.read(openListApiServiceProvider);
      return await apiService.renameFile(oldPath, newName);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      if (!webdavService.isConnected) return false;

      try {
        final newPath = '$currentPath/$newName'.replaceAll('//', '/');
        await webdavService.client!.rename(oldPath, newPath, false);
        return true;
      } catch (e) {
        debugPrint('WebDAV 重命名文件失败: $e');
        return false;
      }
    }
  }

  /// 移动文件
  Future<bool> moveFiles(String srcDir, String dstDir, List<String> fileNames) async {
    if (_useApi) {
      final apiService = ref.read(openListApiServiceProvider);
      return await apiService.moveFiles(srcDir, dstDir, fileNames);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      if (!webdavService.isConnected) return false;

      try {
        for (final fileName in fileNames) {
          final srcPath = '$srcDir/$fileName'.replaceAll('//', '/');
          final dstPath = '$dstDir/$fileName'.replaceAll('//', '/');
          await webdavService.client!.rename(srcPath, dstPath, true);
        }
        return true;
      } catch (e) {
        debugPrint('WebDAV 移动文件失败: $e');
        return false;
      }
    }
  }

  /// 复制文件
  Future<bool> copyFiles(String srcDir, String dstDir, List<String> fileNames) async {
    if (_useApi) {
      final apiService = ref.read(openListApiServiceProvider);
      return await apiService.copyFiles(srcDir, dstDir, fileNames);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      if (!webdavService.isConnected) return false;

      try {
        for (final fileName in fileNames) {
          final srcPath = '$srcDir/$fileName'.replaceAll('//', '/');
          final dstPath = '$dstDir/$fileName'.replaceAll('//', '/');
          await webdavService.client!.copy(srcPath, dstPath, true);
        }
        return true;
      } catch (e) {
        debugPrint('WebDAV 复制文件失败: $e');
        return false;
      }
    }
  }

  /// 创建文件夹
  Future<bool> createFolder(String path) async {
    if (_useApi) {
      final apiService = ref.read(openListApiServiceProvider);
      return await apiService.createFolder(path);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      if (!webdavService.isConnected) return false;

      try {
        await webdavService.client!.mkdir(path);
        return true;
      } catch (e) {
        debugPrint('WebDAV 创建文件夹失败: $e');
        return false;
      }
    }
  }

  /// 上传文件
  Future<bool> uploadFile(String dirPath, String fileName, List<int> fileBytes) async {
    final filePath = '$dirPath/$fileName'.replaceAll('//', '/');

    if (_useApi) {
      final apiService = ref.read(openListApiServiceProvider);
      return await apiService.uploadFile(dirPath, fileName, fileBytes);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      if (!webdavService.isConnected) return false;

      try {
        await webdavService.client!.write(filePath, Uint8List.fromList(fileBytes));
        return true;
      } catch (e) {
        debugPrint('WebDAV 上传文件失败: $e');
        return false;
      }
    }
  }

  /// 搜索文件（仅API支持）
  Future<List<dynamic>> searchFiles(String keywords, {String? parent}) async {
    if (!_useApi) {
      return [];
    }

    final apiService = ref.read(openListApiServiceProvider);
    return await apiService.searchFiles(keywords, parent: parent);
  }

  /// 获取文件夹列表（用于选择目标文件夹）
  Future<List<webdav.File>> listFolders(String path) async {
    final webdavService = ref.read(webDavServiceProvider);
    if (!webdavService.isConnected) return [];

    try {
      final files = await webdavService.client!.readDir(path);
      return files.where((f) => f.isDir == true).toList();
    } catch (e) {
      debugPrint('列出文件夹失败: $e');
      return [];
    }
  }
}

final fileOperationServiceProvider = Provider<FileOperationService>((ref) {
  return FileOperationService(ref);
});
