import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../core/network/openlist_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../settings/data/general_settings_provider.dart';

/// 详细文件属性
class DetailedFileProperties {
  final String fileName;
  final int size;
  final String mimeType;
  final DateTime? modified;
  final bool isDirectory;
  
  // 图片属性
  final String? resolution;
  final int? width;
  final int? height;
  
  // 视频属性
  final String? duration;
  final String? videoCodec;
  final String? audioCodec;
  
  // 音频属性
  final String? audioDuration;
  final String? bitrate;
  
  // 文档属性
  final int? pageCount;
  
  // 压缩包属性
  final int? fileCount;

  DetailedFileProperties({
    required this.fileName,
    required this.size,
    required this.mimeType,
    this.modified,
    required this.isDirectory,
    this.resolution,
    this.width,
    this.height,
    this.duration,
    this.videoCodec,
    this.audioCodec,
    this.audioDuration,
    this.bitrate,
    this.pageCount,
    this.fileCount,
  });
  
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

/// 文件属性服务
class FilePropertiesService {
  final Ref ref;

  FilePropertiesService(this.ref);

  /// 获取详细文件属性
  Future<DetailedFileProperties> getDetailedProperties(
    String currentPath,
    webdav.File file,
  ) async {
    final filePath = '$currentPath/${file.name}'.replaceAll('//', '/');
    final fileType = FileUtils.getFileType(file.name ?? '', file.isDir ?? false);
    
    // 基础属性
    var properties = DetailedFileProperties(
      fileName: file.name ?? '',
      size: file.size ?? 0,
      mimeType: file.mimeType ?? 'unknown',
      modified: file.mTime,
      isDirectory: file.isDir ?? false,
    );

    // 如果启用了API增强功能，尝试获取更多详细信息
    final settings = ref.read(generalSettingsProvider);
    if (settings.enableApiEnhancement) {
      properties = await _getApiEnhancedProperties(filePath, properties, fileType);
    }

    return properties;
  }

  /// 通过API获取增强属性
  Future<DetailedFileProperties> _getApiEnhancedProperties(
    String filePath,
    DetailedFileProperties baseProperties,
    AppFileType fileType,
  ) async {
    final apiService = ref.read(openListApiServiceProvider);
    if (!apiService.isConnected) return baseProperties;

    try {
      final fileInfo = await apiService.getFileInfo(filePath);
      if (fileInfo?.rawProps != null) {
        return _parseRawProperties(baseProperties, fileInfo!.rawProps!, fileType);
      }
    } catch (e) {
      // API获取失败，返回基础属性
    }

    return baseProperties;
  }

  /// 解析原始属性数据
  DetailedFileProperties _parseRawProperties(
    DetailedFileProperties baseProperties,
    Map<String, dynamic> rawProps,
    AppFileType fileType,
  ) {
    switch (fileType) {
      case AppFileType.image:
        return _parseImageProperties(baseProperties, rawProps);
      case AppFileType.video:
        return _parseVideoProperties(baseProperties, rawProps);
      case AppFileType.audio:
        return _parseAudioProperties(baseProperties, rawProps);
      case AppFileType.pdf:
        return _parsePdfProperties(baseProperties, rawProps);
      case AppFileType.archive:
        return _parseArchiveProperties(baseProperties, rawProps);
      default:
        return baseProperties;
    }
  }

  DetailedFileProperties _parseImageProperties(
    DetailedFileProperties base,
    Map<String, dynamic> props,
  ) {
    int? width;
    int? height;
    String? resolution;

    // 尝试从多个可能的字段获取分辨率信息
    if (props.containsKey('width') && props.containsKey('height')) {
      width = props['width'] as int?;
      height = props['height'] as int?;
      if (width != null && height != null) {
        resolution = '${width}x$height';
      }
    } else if (props.containsKey('resolution')) {
      resolution = props['resolution'] as String?;
    } else if (props.containsKey('dimensions')) {
      resolution = props['dimensions'] as String?;
    }

    return DetailedFileProperties(
      fileName: base.fileName,
      size: base.size,
      mimeType: base.mimeType,
      modified: base.modified,
      isDirectory: base.isDirectory,
      resolution: resolution,
      width: width,
      height: height,
    );
  }

  DetailedFileProperties _parseVideoProperties(
    DetailedFileProperties base,
    Map<String, dynamic> props,
  ) {
    String? duration;
    String? resolution;
    String? videoCodec;
    String? audioCodec;
    int? width;
    int? height;

    // 时长
    if (props.containsKey('duration')) {
      final durationValue = props['duration'];
      if (durationValue is int) {
        duration = _formatDuration(durationValue);
      } else if (durationValue is String) {
        duration = durationValue;
      }
    }

    // 分辨率
    if (props.containsKey('width') && props.containsKey('height')) {
      width = props['width'] as int?;
      height = props['height'] as int?;
      if (width != null && height != null) {
        resolution = '${width}x$height';
      }
    } else if (props.containsKey('resolution')) {
      resolution = props['resolution'] as String?;
    }

    // 编码信息
    videoCodec = props['video_codec'] as String? ?? props['vcodec'] as String?;
    audioCodec = props['audio_codec'] as String? ?? props['acodec'] as String?;

    return DetailedFileProperties(
      fileName: base.fileName,
      size: base.size,
      mimeType: base.mimeType,
      modified: base.modified,
      isDirectory: base.isDirectory,
      resolution: resolution,
      width: width,
      height: height,
      duration: duration,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
    );
  }

  DetailedFileProperties _parseAudioProperties(
    DetailedFileProperties base,
    Map<String, dynamic> props,
  ) {
    String? duration;
    String? bitrate;

    if (props.containsKey('duration')) {
      final durationValue = props['duration'];
      if (durationValue is int) {
        duration = _formatDuration(durationValue);
      } else if (durationValue is String) {
        duration = durationValue;
      }
    }

    if (props.containsKey('bitrate')) {
      final bitrateValue = props['bitrate'];
      if (bitrateValue is int) {
        bitrate = '${(bitrateValue / 1000).toStringAsFixed(0)} kbps';
      }
    }

    return DetailedFileProperties(
      fileName: base.fileName,
      size: base.size,
      mimeType: base.mimeType,
      modified: base.modified,
      isDirectory: base.isDirectory,
      audioDuration: duration,
      bitrate: bitrate,
    );
  }

  DetailedFileProperties _parsePdfProperties(
    DetailedFileProperties base,
    Map<String, dynamic> props,
  ) {
    int? pageCount;

    if (props.containsKey('pages') || props.containsKey('page_count')) {
      pageCount = props['pages'] as int? ?? props['page_count'] as int?;
    }

    return DetailedFileProperties(
      fileName: base.fileName,
      size: base.size,
      mimeType: base.mimeType,
      modified: base.modified,
      isDirectory: base.isDirectory,
      pageCount: pageCount,
    );
  }

  DetailedFileProperties _parseArchiveProperties(
    DetailedFileProperties base,
    Map<String, dynamic> props,
  ) {
    int? fileCount;

    if (props.containsKey('file_count') || props.containsKey('entries')) {
      fileCount = props['file_count'] as int? ?? props['entries'] as int?;
    }

    return DetailedFileProperties(
      fileName: base.fileName,
      size: base.size,
      mimeType: base.mimeType,
      modified: base.modified,
      isDirectory: base.isDirectory,
      fileCount: fileCount,
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
}