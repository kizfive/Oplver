import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'file_operation_service.dart';
import 'file_properties_service.dart';

/// 文件操作服务提供者
final fileOperationServiceProvider = Provider<FileOperationService>((ref) {
  return FileOperationService(ref);
});

/// 文件属性服务提供者
final filePropertiesServiceProvider = Provider<FilePropertiesService>((ref) {
  return FilePropertiesService(ref);
});