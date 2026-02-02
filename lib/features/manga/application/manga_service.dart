import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../core/network/openlist_service.dart';
import '../../../core/network/openlist_models.dart';
import '../../settings/data/general_settings_provider.dart';
import '../../auth/data/auth_provider.dart';
import '../data/manga_models.dart';

/// 漫画服务 - 扫描和管理漫画
class MangaService {
  final Ref ref;

  MangaService(this.ref);

  /// 扫描指定路径下的所有漫画
  Future<List<MangaInfo>> scanMangaInPath(String rootPath, {List<MangaInfo>? cachedList}) async {
    final List<MangaInfo> mangaList = [];
    
    try {
      await _scanDirectory(rootPath, mangaList, cachedList: cachedList);
    } catch (e) {
      debugPrint('扫描漫画失败: $e');
    }

    return mangaList;
  }

  /// 获取单个漫画的详细信息（通过文件夹路径）
  Future<MangaInfo?> getMangaDetail(String folderPath) async {
    final settings = ref.read(generalSettingsProvider);
    
    try {
      List<String> images = [];
      String title = p.basename(folderPath); // 默认标题为文件夹名

      if (settings.enableApiEnhancement) {
        final apiService = ref.read(openListApiServiceProvider);
        if (!apiService.isConnected) return null;
        
        final fileList = await apiService.listFiles(folderPath);
        if (fileList == null) return null;

        images = _filterImagesApi(folderPath, fileList.content);
        
      } else {
        final webdavService = ref.read(webDavServiceProvider);
        if (!webdavService.isConnected) return null;
        
        final files = await webdavService.client!.readDir(folderPath);
        images = _filterImagesWebDAV(folderPath, files);
      }

      if (images.isEmpty) return null;
      
      // 按自然顺序排序
      images.sort((a, b) => _compareNaturally(a, b));

      return MangaInfo(
        title: title,
        folderPath: folderPath,
        chapters: images,
        coverImage: images.isNotEmpty ? p.basename(images.first) : null, // 使用文件名而非完整路径
        tags: [],
        author: null, // 不显示作者
        description: null,
      );

    } catch (e) {
      debugPrint('获取漫画详情失败: $e');
    }
    return null;
  }

  /// 递归扫描目录
  Future<void> _scanDirectory(String dirPath, List<MangaInfo> mangaList, {List<MangaInfo>? cachedList}) async {
    final settings = ref.read(generalSettingsProvider);
    
    if (settings.enableApiEnhancement) {
      await _scanDirectoryWithApi(dirPath, mangaList, cachedList: cachedList);
    } else {
      await _scanDirectoryWithWebDAV(dirPath, mangaList, cachedList: cachedList);
    }
  }

  /// 使用API扫描目录
  Future<void> _scanDirectoryWithApi(String dirPath, List<MangaInfo> mangaList, {List<MangaInfo>? cachedList}) async {
    final apiService = ref.read(openListApiServiceProvider);
    if (!apiService.isConnected) return;

    try {
      final fileList = await apiService.listFiles(dirPath);
      if (fileList == null) return;

      // 1. 检查当前目录是否包含图片
      final images = _filterImagesApi(dirPath, fileList.content);
      
      if (images.isNotEmpty) {
        // 找到了包含图片的文件夹 -> 视为一本漫画
        
        // 默认先按名称排序
        images.sort((a, b) => _compareNaturally(a, b));
        
        var manga = MangaInfo(
          title: p.basename(dirPath), // 文件夹名作为标题
          folderPath: dirPath,
          chapters: images, // 所有图片作为章节/页码
          coverImage: p.basename(images.first), // 使用文件名而非完整路径
          author: null,
          tags: [],
        );

        // 恢复阅读进度
        if (cachedList != null) {
           try {
             final cached = cachedList.firstWhere((m) => m.folderPath == dirPath);
             manga = manga.copyWith(lastReadIndex: cached.lastReadIndex);
           } catch (_) {}
        }

        mangaList.add(manga);
      }

      // 2. 递归扫描所有子文件夹
      // 即使当前文件夹是漫画，其子文件夹也可能是单独的漫画（例如系列/分卷）
      final subDirs = fileList.content.where((f) => f.isDir).toList();
      for (final subDir in subDirs) {
        final subPath = '$dirPath/${subDir.name}'.replaceAll('//', '/');
        await _scanDirectoryWithApi(subPath, mangaList, cachedList: cachedList);
      }
      
    } catch (e) {
      debugPrint('API扫描目录失败 $dirPath: $e');
    }
  }

  /// 使用WebDAV扫描目录
  Future<void> _scanDirectoryWithWebDAV(String dirPath, List<MangaInfo> mangaList, {List<MangaInfo>? cachedList}) async {
    final webdavService = ref.read(webDavServiceProvider);
    if (!webdavService.isConnected) return;

    try {
      final files = await webdavService.client!.readDir(dirPath);
      
      // 1. 检查当前目录是否包含图片
      final images = _filterImagesWebDAV(dirPath, files);

      if (images.isNotEmpty) {
        // 视为漫画
        images.sort((a, b) => _compareNaturally(a, b));

        var manga = MangaInfo(
          title: p.basename(dirPath),
          folderPath: dirPath,
          chapters: images,
          coverImage: p.basename(images.first), // 使用文件名而非完整路径
          author: null,
          tags: [],
        );

        // 恢复阅读进度
        if (cachedList != null) {
           try {
             final cached = cachedList.firstWhere((m) => m.folderPath == dirPath);
             manga = manga.copyWith(lastReadIndex: cached.lastReadIndex);
           } catch (_) {}
        }
        
        mangaList.add(manga);
      } 
      
      // 2. 递归扫描子目录
      final subDirs = files.where((f) => f.isDir == true).toList();
      for (final subDir in subDirs) {
        // 避免扫描自己 (WebDAV有时候会返回 '.'?) 
        // 通常 package:webdav_client 返回的 name 是相对或绝对路径，需谨慎。
        // 假设 list 返回的是 children。
        final subPath = '$dirPath/${subDir.name}'.replaceAll('//', '/');
        await _scanDirectoryWithWebDAV(subPath, mangaList, cachedList: cachedList);
      }

    } catch (e) {
      debugPrint('WebDAV扫描目录失败 $dirPath: $e');
    }
  }
  
  // 辅助方法：判断是否为图片
  bool _isImage(String name) {
    final ext = p.extension(name).toLowerCase();
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    return imageExtensions.contains(ext);
  }

  // 辅助方法：过滤API返回的图片
  List<String> _filterImagesApi(String dirPath, List<dynamic> files) {
    return files
        .where((f) => !f.isDir && _isImage(f.name))
        .map((f) => '$dirPath/${f.name}'.replaceAll('//', '/'))
        .toList();
  }

  // 辅助方法：过滤WebDAV返回的图片
  List<String> _filterImagesWebDAV(String dirPath, List<webdav.File> files) {
    return files
        .where((f) => f.isDir != true && f.name != null && _isImage(f.name!))
        .map((f) => '$dirPath/${f.name!}'.replaceAll('//', '/'))
        .toList();
  }


  /// 从API加载漫画元数据
  Future<MangaInfo?> _loadMangaMetadata(String dirPath, String mangaFileName, List<dynamic>? siblings) async {
    final apiService = ref.read(openListApiServiceProvider);
    final filePath = '$dirPath/$mangaFileName'.replaceAll('//', '/');
    
    // 自动寻找同名图片作为封面 (仅适用于 .manga 文件)
    // 对于 metadata.json , 不进行同名推测，除非有 metadata.jpg (暂不实现)
    String? autoCoverImage;
    if (siblings != null && mangaFileName != 'metadata.json') {
      final nameWithoutExt = mangaFileName.replaceAll(RegExp(r'\.manga$'), '');
      final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
      
      for (final file in siblings) {
        if (!file.isDir) {
           final fileName = file.name as String;
           final lowerName = fileName.toLowerCase();
           // 检查是否以此名为前缀 且 后缀为图片
           // 严格匹配：文件名(不含扩展名) == Manga文件名(不含扩展名)
           // 例如 Manga: abc.manga, Cover: abc.jpg
           if (lowerName.startsWith(nameWithoutExt.toLowerCase())) {
             final ext = lowerName.substring(lowerName.lastIndexOf('.'));
             final baseName = lowerName.substring(0, lowerName.lastIndexOf('.'));
             
             if (baseName == nameWithoutExt.toLowerCase() && imageExtensions.contains(ext)) {
               autoCoverImage = fileName;
               break; 
             }
           }
        }
      }
    }

    try {
      final fileInfo = await apiService.getFileInfo(filePath);
      if (fileInfo == null) return null;

      // 尝试通过rawUrl直接获取内容
      if (fileInfo.rawUrl != null) {
        try {
          // 如果rawUrl是相对路径，可能需要拼接baseUrl，但通常rawUrl是完整的
          final response = await http.get(Uri.parse(fileInfo.rawUrl!));
          if (response.statusCode == 200) {
            final jsonStr = utf8.decode(response.bodyBytes);
            final jsonData = _safeJsonDecode(jsonStr) as Map<String, dynamic>;
            var info = MangaInfo.fromJson(jsonData, dirPath);
            
            if (mangaFileName == 'metadata.json') {
               info = info.copyWith(tags: []);
               if (siblings != null) {
                  final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
                  final images = <String>[];
                  for (final file in siblings) {
                     if (file is FileInfo && !file.isDir) {
                        if (imageExtensions.any((ext) => file.name.toLowerCase().endsWith(ext))) {
                           images.add(file.name);
                        }
                     }
                  }
                  if (images.isNotEmpty) {
                     images.sort((a, b) => _compareNaturally(a, b));
                     info = info.copyWith(coverImage: images.first);
                  }
               }
               return info;
            }

            // 封面策略：
            // 1. 如果JSON中指定了cover，则使用JSON中的。
            // 2. 如果JSON中未指定，尝试使用自动匹配的同名图片。
            if (info.coverImage != null && info.coverImage!.isNotEmpty) {
              return info;
            } else if (autoCoverImage != null) {
              return info.copyWith(coverImage: autoCoverImage);
            }
            return info;
          }
        } catch (e) {
          debugPrint('API下载漫画元数据失败 $filePath: $e');
          // 继续尝试WebDAV
        }
      }

      // 如果API获取失败，尝试通过WebDAV获取
      return await _loadMangaMetadataWebDAV(dirPath, mangaFileName, null); // WebDAV部分也需要修改以支持siblings传入
    } catch (e) {
      debugPrint('加载漫画元数据失败 $filePath: $e');
      return null;
    }
  }

  /// 从WebDAV加载漫画元数据
  Future<MangaInfo?> _loadMangaMetadataWebDAV(String dirPath, String mangaFileName, List<webdav.File>? siblings) async {
    final webdavService = ref.read(webDavServiceProvider);
    if (!webdavService.isConnected) return null;

    final filePath = '$dirPath/$mangaFileName'.replaceAll('//', '/');
    
    // 自动寻找同名图片作为封面 (WebDAV 版本)
    String? autoCoverImage;
    if (siblings != null && mangaFileName != 'metadata.json') {
      final nameWithoutExt = mangaFileName.replaceAll(RegExp(r'\.manga$'), '');
      final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
      
      for (final file in siblings) {
        if (file.isDir != true && file.name != null) {
           final fileName = file.name!;
           final lowerName = fileName.toLowerCase();
           if (lowerName.startsWith(nameWithoutExt.toLowerCase())) {
             final ext = lowerName.substring(lowerName.lastIndexOf('.'));
             final baseName = lowerName.substring(0, lowerName.lastIndexOf('.'));
             
             if (baseName == nameWithoutExt.toLowerCase() && imageExtensions.contains(ext)) {
               autoCoverImage = fileName;
               break; 
             }
           }
        }
      }
    }

    try {
      final content = await webdavService.client!.read(filePath);
      final jsonStr = String.fromCharCodes(content);
      final jsonData = _safeJsonDecode(jsonStr) as Map<String, dynamic>;
      
      var info = MangaInfo.fromJson(jsonData, dirPath);
      
      if (mangaFileName == 'metadata.json') {
          info = info.copyWith(tags: []);
          if (siblings != null) {
             final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
             final images = <String>[];
             for (final file in siblings) {
                if (file.isDir != true && file.name != null) {
                   final name = file.name!;
                   if (imageExtensions.any((ext) => name.toLowerCase().endsWith(ext))) {
                      images.add(name);
                   }
                }
             }
             if (images.isNotEmpty) {
                images.sort((a, b) => _compareNaturally(a, b));
                info = info.copyWith(coverImage: images.first);
             }
          }
          return info;
      }

      if (info.coverImage != null && info.coverImage!.isNotEmpty) {
        return info;
      } else if (autoCoverImage != null) {
        return info.copyWith(coverImage: autoCoverImage);
      }
      return info;
    } catch (e) {
      debugPrint('加载漫画元数据失败 $filePath: $e');
      return null;
    }
  }

  /// 尝试安全解析JSON（尝试修复常见格式错误）
  dynamic _safeJsonDecode(String jsonStr) {
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      // 尝试修复常见错误：缺少逗号
      // 匹配模式：值(引号/数字/boolean/null)后面跟着换行和引号(下一个key)，中间缺少逗号
      // Regex: ("|true|false|null|\d+)\s*\n\s*"
      try {
        final fixedJson = jsonStr.replaceAllMapped(
          RegExp(r'(["\d]|true|false|null)\s*\n\s*"'),
          (match) => '${match.group(1)},\n"',
        );
        return jsonDecode(fixedJson);
      } catch (_) {
        rethrow; // 如果修复后仍失败，抛出原始异常
      }
    }
  }

  /// 获取章节图片列表（API版本）
  Future<List<String>> _getChapterImages(String dirPath, List<dynamic> files) async {
    final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
    final images = <String>[];

    for (final file in files) {
      if (!file.isDir && file.name != null) {
        final fileName = file.name as String;
        final ext = fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
        
        if (imageExtensions.contains(ext) && !fileName.endsWith('.manga') && fileName != 'metadata.json') {
          images.add('$dirPath/$fileName'.replaceAll('//', '/'));
        }
      }
    }

    // 按数字顺序排序
    images.sort((a, b) => _compareNaturally(a, b));
    return images;
  }

  /// 获取章节图片列表（WebDAV版本）
  Future<List<String>> _getChapterImagesWebDAV(String dirPath, List<webdav.File> files) async {
    final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
    final images = <String>[];

    for (final file in files) {
      if (file.isDir != true && file.name != null) {
        final fileName = file.name!;
        final ext = fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
        
        if (imageExtensions.contains(ext) && !fileName.endsWith('.manga') && fileName != 'metadata.json') {
          images.add('$dirPath/$fileName'.replaceAll('//', '/'));
        }
      }
    }

    // 按数字顺序排序
    images.sort((a, b) => _compareNaturally(a, b));
    return images;
  }

  /// 自然排序比较函数
  int _compareNaturally(String a, String b) {
    final RegExp numberRegex = RegExp(r'\d+');
    final Iterable<Match> aMatches = numberRegex.allMatches(a);
    final Iterable<Match> bMatches = numberRegex.allMatches(b);

    if (aMatches.isEmpty && bMatches.isEmpty) {
      return a.compareTo(b);
    }

    if (aMatches.isEmpty) return -1;
    if (bMatches.isEmpty) return 1;

    // 提取第一个数字进行比较
    final int aNum = int.tryParse(aMatches.first.group(0) ?? '0') ?? 0;
    final int bNum = int.tryParse(bMatches.first.group(0) ?? '0') ?? 0;
    
    return aNum.compareTo(bNum);
  }

  /// 获取漫画封面图片URL
  String? getCoverImageUrl(MangaInfo manga) {
    final coverPath = manga.getCoverImagePath();
    if (coverPath == null) return null;

    final settings = ref.read(generalSettingsProvider);
    
    if (settings.enableApiEnhancement) {
      final apiService = ref.read(openListApiServiceProvider);
      return apiService.getThumbnailUrl(coverPath) ?? apiService.getDownloadUrl(coverPath);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      return webdavService.getUrl(coverPath);
    }
  }

  /// 获取漫画图片URL（同步，用于WebDAV或API直链预览）
  String? getImageUrl(String imagePath) {
    final settings = ref.read(generalSettingsProvider);
    
    if (settings.enableApiEnhancement) {
      final apiService = ref.read(openListApiServiceProvider);
      return apiService.getDownloadUrl(imagePath);
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      return webdavService.getUrl(imagePath);
    }
  }

  /// 异步获取漫画图片真实URL（推荐API模式使用，可解决重定向和鉴权问题）
  Future<String?> resolveImageUrl(String imagePath) async {
    final settings = ref.read(generalSettingsProvider);
    
    if (settings.enableApiEnhancement) {
      final apiService = ref.read(openListApiServiceProvider);
      // 尝试获取文件信息以得到 raw_url (直链)
      final fileInfo = await apiService.getFileInfo(imagePath);
      if (fileInfo?.rawUrl != null) {
        return fileInfo!.rawUrl;
      }
      // 降级：如果无法获取 raw_url，尝试使用 /p/ 代理链接 (如果支持)
      // 或者回退到旧的 /d/ 链接
      return apiService.getDownloadUrl(imagePath);
    } else {
      // WebDAV 模式直接返回 URL
      final webdavService = ref.read(webDavServiceProvider);
      return webdavService.getUrl(imagePath);
    }
  }

  /// 获取图片缩略图URL (仅API模式支持, 否则回退到原图)
  Future<String?> resolveThumbnailUrl(String imagePath) async {
    final settings = ref.read(generalSettingsProvider);
    
    if (settings.enableApiEnhancement) {
      final apiService = ref.read(openListApiServiceProvider);
      
      // 多一层保险：先获取文件信息检查是否有略缩图
      try {
        final fileInfo = await apiService.getFileInfo(imagePath);
        if (fileInfo != null) {
          // 1. 如果有略缩图且不为空，使用略缩图
          if (fileInfo.thumb != null && fileInfo.thumb!.isNotEmpty) {
            return fileInfo.thumb;
          }
          // 2. 如果没有略缩图，尝试使用直链 (raw_url)
          if (fileInfo.rawUrl != null && fileInfo.rawUrl!.isNotEmpty) {
            return fileInfo.rawUrl;
          }
        }
      } catch (e) {
        debugPrint('获取文件信息失败，尝试直接构造URL: $e');
      }

      // 3. 如果以上都失败（或获取信息出错），回退到构造的 API 下载链接
      return apiService.getDownloadUrl(imagePath);
    } else {
      // WebDAV 模式不支持缩略图 API，回退到原图
      final webdavService = ref.read(webDavServiceProvider);
      return webdavService.getUrl(imagePath);
    }
  }

  /// 判断是否启用API增强模式
  bool isApiMode() {
    return ref.read(generalSettingsProvider).enableApiEnhancement;
  }

  /// 获取认证头
  Map<String, String> getAuthHeaders() {
    final settings = ref.read(generalSettingsProvider);
    
    if (settings.enableApiEnhancement) {
      final apiService = ref.read(openListApiServiceProvider);
      return apiService.authHeaders;
    } else {
      final webdavService = ref.read(webDavServiceProvider);
      return webdavService.authHeaders;
    }
  }

  /// 获取适合指定URL的Headers（辅助方法）
  /// 如果URL是API缩略图，必须带Header
  /// 如果URL是直链（raw_url），通常不带Header（避免签名冲突）
  Map<String, String>? getHeadersForUrl(String url) {
    // 优先：如果URL包含 /dav/，无论什么模式，都是WebDAV协议，需要Basic Auth
    if (url.contains('/dav/')) {
       final webdavService = ref.read(webDavServiceProvider);
       return webdavService.authHeaders;
    }

    if (!isApiMode()) {
       // WebDAV模式始终带Header
       return getAuthHeaders();
    }
    
    // API模式：判断URL类型
    if (url.contains('/api/fs/thumb') || url.contains('/api/fs/get')) {
       // Alist API接口，需要认证
       return getAuthHeaders();
    }
    
    // 直链/代理链接，不带Header
    return null;
  }

  /// 下载并缓存漫画封面
  /// 返回本地文件路径
  Future<String?> downloadAndCacheCover(String imagePath) async {
     try {
       // 1. 生成简单唯一的文件名
       final fileName = 'cover_${imagePath.hashCode}.jpg';

       // 2. 获取缓存目录
       final cacheDir = await getApplicationDocumentsDirectory();
       final coversDir = Directory(p.join(cacheDir.path, 'manga_covers'));
       if (!coversDir.existsSync()) {
         coversDir.createSync(recursive: true);
       }
       
       final file = File(p.join(coversDir.path, fileName));
       
       // 3. 检查文件是否存在且有效
       if (file.existsSync() && file.lengthSync() > 0) {
         return file.path;
       }
       
       // 4. 获取下载链接
       final apiService = ref.read(openListApiServiceProvider);
       // 4.1 优先尝试使用API获取文件详情中的略缩图 (API模式下更可靠)
       if (isApiMode()) {
         try {
           final fileInfo = await apiService.getFileInfo(imagePath);
           // 如果有略缩图且不为空，优先使用略缩图链接 (通常是 /api/fs/thumb)
           if (fileInfo?.thumb != null && fileInfo!.thumb!.isNotEmpty) {
              final url = fileInfo.thumb!;
              // 略缩图API肯定需要API Header
              final headers = getAuthHeaders();
              final response = await http.get(Uri.parse(url), headers: headers);
              if (response.statusCode == 200) {
                 await file.writeAsBytes(response.bodyBytes);
                 return file.path;
              }
           }
         } catch (e) {
           debugPrint('尝试获取详情下载封面失败：$e');
         }
       }

       // 4.2 如果并没有获取到thumb或者不在API模式，走回退逻辑
       final url = await resolveThumbnailUrl(imagePath);
       if (url == null) return null;
       
       Map<String, String>? headers;
       if (url.contains('/dav/')) {
          final webdavService = ref.read(webDavServiceProvider);
          headers = webdavService.authHeaders;
       } else {
          headers = getHeadersForUrl(url);
       }
       
       final response = await http.get(Uri.parse(url), headers: headers);
       if (response.statusCode == 200) {
         await file.writeAsBytes(response.bodyBytes);
         return file.path;
       } else {
         debugPrint('下载封面失败: ${response.statusCode} URL: $url');
         return null;
       }
     } catch (e) {
       debugPrint('缓存封面异常: $e');
       return null;
     }
  }

  /// 清除封面缓存
  Future<void> clearCoverCache() async {
    try {
      final cacheDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(cacheDir.path, 'manga_covers'));
      if (coversDir.existsSync()) {
        await coversDir.delete(recursive: true);
        debugPrint('封面缓存已清除');
      }
    } catch (e) {
      debugPrint('清除封面缓存失败: $e');
    }
  }
}

final mangaServiceProvider = Provider<MangaService>((ref) {
  return MangaService(ref);
});