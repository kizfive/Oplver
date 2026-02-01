// ignore_for_file: constant_identifier_names

import 'package:dio/dio.dart';

enum DownloadTaskStatus {
  pending,
  running,
  paused,
  completed,
  failed,
  canceled,
}

class DownloadTask {
  final String id;
  final String fileName;
  final String remotePath;
  final String localPath;
  final int totalBytes;
  final int receivedBytes;
  final double speed; // bytes per second
  final DownloadTaskStatus status;
  final CancelToken? cancelToken;
  final String? error;

  // For UI optimization
  final DateTime? startTime;

  const DownloadTask({
    required this.id,
    required this.fileName,
    required this.remotePath,
    required this.localPath,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.speed = 0,
    this.status = DownloadTaskStatus.pending,
    this.cancelToken,
    this.error,
    this.startTime,
  });

  DownloadTask copyWith({
    String? id,
    String? fileName,
    String? remotePath,
    String? localPath,
    int? totalBytes,
    int? receivedBytes,
    double? speed,
    DownloadTaskStatus? status,
    CancelToken? cancelToken,
    String? error,
    DateTime? startTime,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      remotePath: remotePath ?? this.remotePath,
      localPath: localPath ?? this.localPath,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      cancelToken: cancelToken ?? this.cancelToken,
      error: error ?? this.error,
      startTime: startTime ?? this.startTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'remotePath': remotePath,
      'localPath': localPath,
      'totalBytes': totalBytes,
      'receivedBytes': receivedBytes,
      'status': status.index,
      'startTime': startTime?.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      fileName: json['fileName'],
      remotePath: json['remotePath'],
      localPath: json['localPath'],
      totalBytes: json['totalBytes'] ?? 0,
      receivedBytes: json['receivedBytes'] ?? 0,
      status: DownloadTaskStatus.values[json['status'] ?? 0],
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'])
          : null,
    );
  }
}
