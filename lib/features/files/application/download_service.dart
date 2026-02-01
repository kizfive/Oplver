import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as notifs;

import '../../../../core/router/app_router.dart';
import '../../../core/network/webdav_service.dart';
import '../../auth/data/auth_provider.dart';
import '../../settings/data/general_settings_provider.dart';
import 'download_task.dart';
import '../../../core/services/log_service.dart';

enum DownloadPreconditionStatus {
  success,
  error,
  requiresWifi,
  permissionDenied,
}

class DownloadNotifier extends StateNotifier<List<DownloadTask>> {
  final Ref ref;
  DownloadNotifier(this.ref) : super([]) {
    _loadTasks();
  }

  // For speed calculation
  final Map<String, int> _lastBytes = {};
  final Map<String, DateTime> _lastTime = {};

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = ref.read(authProvider).currentUser ?? 'guest';
    final key = 'downloads_$userId';
    final jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        state = list.map((e) {
          final task = DownloadTask.fromJson(e);
          // If app was killed while running, reset to paused so user can resume
          if (task.status == DownloadTaskStatus.running) {
            return task.copyWith(status: DownloadTaskStatus.paused);
          }
          return task;
        }).toList();
      } catch (e) {
        debugPrint('Error loading tasks: $e');
      }
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = ref.read(authProvider).currentUser ?? 'guest';
    final key = 'downloads_$userId';
    final list = state.map((t) => t.toJson()).toList();
    await prefs.setString(key, jsonEncode(list));
  }

  void addTask(DownloadTask task) {
    state = [...state, task];
    _saveTasks();
  }

  void updateTask(String id, DownloadTask Function(DownloadTask) update) {
    state = [
      for (final task in state)
        if (task.id == id) update(task) else task
    ];
    // Don't save on every progress update for performance
    // Save only if status changed? Or debounce?
    // For now, let's rely on explicit save points if possible,
    // or just accept overhead on status changes (not progress).

    // Check if status changed for this task
    final newTask = state.firstWhere((t) => t.id == id);
    if (newTask.status != DownloadTaskStatus.running) {
      _saveTasks();
    }
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
    _saveTasks();
  }

  void clearCompletedTasks() {
    state = state.where((t) => 
      t.status != DownloadTaskStatus.completed &&
      t.status != DownloadTaskStatus.failed &&
      t.status != DownloadTaskStatus.canceled
    ).toList();
    _saveTasks();
  }

  DownloadTask? getTask(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateProgress(String id, int received, int total) {
    if (!mounted) return;
    final now = DateTime.now();
    final lastRec = _lastBytes[id] ?? 0;
    final lastT = _lastTime[id] ?? now;

    double speed = 0;
    final diffMs = now.difference(lastT).inMilliseconds;

    // Update speed every 1s approximately
    if (diffMs > 1000) {
      final diffBytes = received - lastRec;
      speed = (diffBytes / diffMs) * 1000; // bytes per second
      _lastBytes[id] = received;
      _lastTime[id] = now;

      updateTask(
          id,
          (t) => t.copyWith(
                receivedBytes: received,
                totalBytes: total,
                speed: speed,
              ));
    } else {
      // Just update bytes often
      // Note: updateTask saves only if status != running,
      // but here we are running. So this is safe (in-memory update).
      updateTask(
          id, (t) => t.copyWith(receivedBytes: received, totalBytes: total));
    }
  }
}

class DownloadService {
  final WebDavService _webDavService;
  final Ref _ref;
  final Dio _dio = Dio();
  final DownloadNotifier _notifier;
  final notifs.FlutterLocalNotificationsPlugin _notificationsPlugin =
      notifs.FlutterLocalNotificationsPlugin();

  DownloadService(this._webDavService, this._ref, this._notifier) {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        notifs.AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
        notifs.InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Check current location to avoid pushing if already on download page if possible
          // But from background/notification, pushing is safer.
          // Issue: Pushing creates history entry. Back goes to PREVIOUS page (File Browser), but user might expect 'close app' OR 'back to where I was'.
          // If user was in browser -> clicks notif -> Download Page -> Back -> Browser. (This is standard)
          // If bug is "Back exits app", it means stack is empty or Download Page replaced root?
          // Using 'push' adds to stack.
          // The user says: "After returning to file manager... back gesture exits app".
          // This suggests the "File Manager" they returned to might be in a weird state or different branch?
          // Or maybe 'push' on existing stack behaves oddly with ShellRoute?
          _ref.read(routerProvider).push('/download_records');
        });
  }

  Future<void> _updateNotification(
      String taskId, String fileName, int received, int total,
      {bool ongoing = true, String? title}) async {
    // Use hashCode of taskId for notification ID
    final notifId = taskId.hashCode;
    final progress = total > 0 ? ((received / total) * 100).toInt() : 0;

    final androidDetails = notifs.AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Download progress',
      importance: notifs.Importance.low,
      priority: notifs.Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: ongoing,
      autoCancel: !ongoing,
    );

    await _notificationsPlugin.show(
        id: notifId,
        title: title ?? (ongoing ? 'Downloading...' : 'Download Complete'),
        body: fileName,
        notificationDetails:
            notifs.NotificationDetails(android: androidDetails));
  }

  /// Checks if we can proceed with download immediately or need confirmation/permissions
  Future<DownloadPreconditionStatus> checkPreconditions() async {
    // 1. Check Permissions
    if (!await _requestPermissions()) {
      return DownloadPreconditionStatus.permissionDenied;
    }

    // 2. Check Network if setting is enabled
    final checkMobile = _ref.read(generalSettingsProvider).checkMobileData;
    if (checkMobile) {
      // ignore: no_leading_underscores_for_local_identifiers
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        return DownloadPreconditionStatus.requiresWifi;
      }
    }

    return DownloadPreconditionStatus.success;
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Android 11 (API 30) and above
      if (androidInfo.version.sdkInt >= 30) {
        if (androidInfo.version.sdkInt >= 33) {
          await Permission.notification.request();
        }

        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true;
  }

  Future<Directory?> _getDownloadDirectory() async {
    Directory? directory;
    try {
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/Oplver Download');
        if (!directory.existsSync()) {
          try {
            await directory.create(recursive: true);
          } catch (e) {
            directory = await getExternalStorageDirectory();
          }
        }
      } else {
        directory = await getDownloadsDirectory();
        if (directory != null) {
          directory = Directory('${directory.path}/Oplver Download');
        }
      }

      if (directory != null && !directory.existsSync()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      debugPrint("Error getting download dir: $e");
    }
    return directory;
  }

  Future<void> startDownload(String remotePath) async {
    // Wrapper to conform to simple file download
    await downloadFile(remotePath);
  }

  // Generate unique ID
  String _uuid() => const Uuid().v4();

  Future<void> downloadFile(String remotePath,
      {String? taskId, String? subDirectory}) async {
    logInfo('Download', '开始下载: $remotePath');
    
    final saveDirRoot = await _getDownloadDirectory();
    if (saveDirRoot == null) {
      logError('Download', '无法访问下载目录');
      throw Exception("Cannot access download directory");
    }

    Directory saveDir = saveDirRoot;
    if (subDirectory != null && subDirectory.isNotEmpty) {
      saveDir = Directory(path.join(saveDirRoot.path, subDirectory));
      if (!saveDir.existsSync()) {
        saveDir.createSync(recursive: true);
      }
    }

    // remotePath is a WebDav path (URL-like), so use posix or url context to parse name
    final fileName = path.posix.basename(remotePath);
    // savePath is local, so use platform context (path.join)
    final savePath = path.join(saveDir.path, fileName);

    // Check if task exists (resume)
    DownloadTask? existingTask = _notifier.getTask(taskId ?? '');
    // ignore: unnecessary_null_comparison
    if (existingTask == null && taskId != null) {
      // Should not happen if strictly controlled, but for safety
    }

    // Create new ID if fresh
    final id = taskId ?? _uuid();
    final cancelToken = CancelToken();

    final task = DownloadTask(
      id: id,
      fileName: fileName,
      remotePath: remotePath,
      localPath: savePath,
      status: DownloadTaskStatus.running,
      cancelToken: cancelToken,
      startTime: DateTime.now(),
    );

    if (existingTask == null) {
      _notifier.addTask(task);
    } else {
      _notifier.updateTask(
          id,
          (t) => t.copyWith(
                status: DownloadTaskStatus.running,
                cancelToken: cancelToken,
                error: null,
              ));
    }

    final url = _webDavService.getUrl(remotePath);

    // Check for existing file for Resume support
    int startBytes = 0;
    final file = File(savePath);
    FileMode fileMode = FileMode.write;

    if (file.existsSync()) {
      final len = file.lengthSync();
      // If restarting a completed or failed download, maybe we want to overwrite?
      // But for Resume logic, we want to append.
      // Let's check status. If it was 'paused', we append.
      if (existingTask?.status == DownloadTaskStatus.paused) {
        startBytes = len;
        fileMode = FileMode.append;
      } else {
        // Fresh start
        startBytes = 0;
      }
    }

    final headers = Map<String, dynamic>.from(_webDavService.authHeaders);
    if (startBytes > 0) {
      headers['range'] = 'bytes=$startBytes-';
    }

    final options = Options(
      headers: headers,
      responseType: ResponseType.stream,
    );

    IOSink? sink;
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: options,
        cancelToken: cancelToken,
      );

      final stream = response.data!.stream;
      // Content-Length usually returns the REMAINING length
      final contentLength = int.tryParse(
              response.headers.value(Headers.contentLengthHeader) ?? '0') ??
          0;
      final total = startBytes + contentLength;

      // Ensure notifier has correct total (if known)
      if (total > 0) {
        _notifier.updateTask(id, (t) => t.copyWith(totalBytes: total));
      }

      int received = startBytes;
      // Init speed tracker
      _notifier._lastBytes[id] = received;
      _notifier._lastTime[id] = DateTime.now();

      sink = file.openWrite(mode: fileMode);

      int lastNotifTime = 0;

      await stream.listen(
        (data) {
          sink?.add(data);
          received += data.length;
          _notifier.updateProgress(id, received, total);

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - lastNotifTime > 1000) {
            _updateNotification(id, fileName, received, total);
            lastNotifTime = nowMs;
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();
      sink = null; // Prevent double close

      // Verify completion
      _notifier.updateTask(
          id,
          (t) => t.copyWith(
                status: DownloadTaskStatus.completed,
                receivedBytes: received,
                totalBytes: total > 0 ? total : received,
              ));
      _updateNotification(id, fileName, total, total, ongoing: false);
      _notifier._saveTasks();
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }

      // Handle DioException specially for 416 (Range Not Satisfiable)
      // This happens if we try to resume a file that is already fully downloaded
      if (e is DioException && e.response?.statusCode == 416) {
        debugPrint("Download 416 (Already completed?): $id");
        // Assume completed if we have a local file?
        if (file.existsSync() && file.lengthSync() > 0) {
          _notifier.updateTask(
              id,
              (t) => t.copyWith(
                    status: DownloadTaskStatus.completed,
                    receivedBytes: file.lengthSync(),
                    totalBytes: file.lengthSync(),
                  ));
          _notifier._saveTasks();
          return;
        }
      }

      // Ensure sink is closed if error occurred
      try {
        // Using a new IOSink instance would be wrong, we need reference to open one.
        // But `sink` variable is inside try block.
        // We should structure try/finally or use a variable outside.
        // Since we can't easily access `sink` here if it was defined inside,
        // let's refactor the whole method in next step or rely on the previous structure
        // actually `sink` definition is inside `try` block.
        // If error happens BEFORE sink is defined, no problem.
        // If error happens AFTER sink is defined, we might leak it if we don't catch inside.
      } catch (_) {}

      // Check if cancelled
      if (e is DioException && CancelToken.isCancel(e)) {
        _notifier.updateTask(
            id, (t) => t.copyWith(status: DownloadTaskStatus.paused));
        debugPrint("Download paused: $id");
        _notificationsPlugin.cancel(id: id.hashCode);
      } else {
        debugPrint("Download failed: $e");
        _notifier.updateTask(
            id,
            (t) => t.copyWith(
                status: DownloadTaskStatus.failed, error: e.toString()));
        _updateNotification(id, fileName, 0, 0,
            ongoing: false, title: 'Download Failed');
      }
    }
  }

  Future<void> pauseDownload(String id) async {
    final task = _notifier.getTask(id);
    if (task != null && task.status == DownloadTaskStatus.running) {
      task.cancelToken?.cancel();
      // Status update handled in catch block above
    }
  }

  Future<void> resumeDownload(String id) async {
    final task = _notifier.getTask(id);
    if (task != null &&
        (task.status == DownloadTaskStatus.paused ||
            task.status == DownloadTaskStatus.failed)) {
      // Restart
      await downloadFile(task.remotePath, taskId: id);
    }
  }

  /// Recursively download a folder
  Future<void> downloadFolder(String remotePath,
      {Function(String, int, int)? onProgress}) async {
    try {
      // The remotePath might be "/Dav/Folder". We want to save to ".../Oplver Download/Folder"
      // Use posix for remote WebDav paths
      final folderName = path.posix.basename(remotePath.endsWith('/')
          ? remotePath.substring(0, remotePath.length - 1)
          : remotePath);

      await _processDownloadRecursive(remotePath, folderName, onProgress);
    } catch (e) {
      debugPrint("Folder download failed: $e");
      rethrow;
    }
  }

  Future<void> _processDownloadRecursive(String currentRemotePath,
      String relativePath, Function(String, int, int)? onProgress) async {
    // Get list of files in remote directory
    final list = await _webDavService.client!.readDir(currentRemotePath);

    for (var file in list) {
      if (file.name == null) continue;

      String remoteFilePath = file.path ?? '';
      if (remoteFilePath.isEmpty) continue;

      // Name of the file/folder
      final name = file.name!;
      // Construct relative path using local system separator as it maps to local hierarchy
      final nextRelativePath = path.join(relativePath, name);

      if (file.isDir ?? false) {
        // Recurse with extended relative path
        await _processDownloadRecursive(
            remoteFilePath, nextRelativePath, onProgress);
      } else {
        // Download file putting it into the correct sub-directory
        await downloadFile(remoteFilePath, subDirectory: relativePath);
      }
    }
  }
}

final downloadNotifierProvider =
    StateNotifierProvider<DownloadNotifier, List<DownloadTask>>((ref) {
  return DownloadNotifier(ref);
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final webDav = ref.watch(webDavServiceProvider);
  final notifier = ref.watch(downloadNotifierProvider.notifier);
  return DownloadService(webDav, ref, notifier);
});
