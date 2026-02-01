import 'package:flutter/material.dart';

enum AppFileType {
  video,
  image,
  audio,
  pdf,
  folder,
  unknown,
}

class FileUtils {
  static const _videoExts = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'flv',
    'wmv',
    'm4v',
    'mpg',
    'mpeg',
    'rmvb',
    'ts',
    'vob',
    '3gp',
    'ogv'
  };
  static const _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic'
  };
  static const _audioExts = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'};

  static AppFileType getFileType(String fileName, bool isDirectory) {
    if (isDirectory) return AppFileType.folder;

    final ext = fileName.split('.').last.toLowerCase();

    if (_videoExts.contains(ext)) return AppFileType.video;
    if (_imageExts.contains(ext)) return AppFileType.image;
    if (_audioExts.contains(ext)) return AppFileType.audio;
    if (ext == 'pdf') return AppFileType.pdf;

    return AppFileType.unknown;
  }

  static IconData getFileIcon(String fileName) {
    final type = getFileType(fileName, false);
    switch (type) {
      case AppFileType.video:
        return Icons.videocam;
      case AppFileType.image:
        return Icons.image;
      case AppFileType.audio:
        return Icons.audiotrack;
      case AppFileType.pdf:
        return Icons.picture_as_pdf;
      case AppFileType.folder:
        return Icons.folder;
      default:
        return Icons.insert_drive_file;
    }
  }
}
