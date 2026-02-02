import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'openlist_api_service.dart';

// OpenList API服务的全局Provider
final openListApiServiceProvider = Provider<OpenListApiService>((ref) {
  return OpenListApiService();
});
