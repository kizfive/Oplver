// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path_context;

import '../../../files/application/download_service.dart';
import '../../../settings/data/general_settings_provider.dart';
import '../../../../core/enums/download_mode.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../history/data/file_history_provider.dart';

class PhotoGalleryPage extends ConsumerStatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Map<String, String> headers;
  final List<dynamic>? files; // List<webdav.File>
  final String currentPath;

  const PhotoGalleryPage({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.headers,
    this.files,
    this.currentPath = '/',
  });

  @override
  ConsumerState<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends ConsumerState<PhotoGalleryPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Add logic here to capture history for the initially opened image
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.files != null &&
          widget.files!.isNotEmpty &&
          _currentIndex < widget.files!.length) {
        _recordHistoryForCurrentIndex();
      } else if (widget.imageUrls.isNotEmpty && widget.files == null) {
        // If only urls provided (simple mode), we can't reliably get path for history without file list
        // But usually we pass files in this app.
      }
    });
  }

  void _recordHistoryForCurrentIndex() {
    if (widget.files == null || _currentIndex >= widget.files!.length) {
      return;
    }
    final file = widget.files![_currentIndex];
    // File name is in file.name
    // currentPath is provided
    final fullPath = path_context.join(widget.currentPath, file.name);
    ref.read(fileHistoryProvider.notifier).addToHistory(fullPath);
  }

  String _formatSize(int? size) {
    if (size == null) {
      return 'Unknown size';
    }
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  Future<void> _handleDownload(BuildContext context, webdav.File file) async {
    final l10n = context.l10n;
    final downloadService = ref.read(downloadServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    // 1. Check preconditions
    final status = await downloadService.checkPreconditions();

    if (!mounted) return;

    if (status == DownloadPreconditionStatus.permissionDenied) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.tr('storagePermissionRequired'))));
      return;
    }

    // Check Download Mode setting
    final settings = ref.read(generalSettingsProvider);
    var downloadMode = settings.defaultDownloadMode;

    bool proceed = true;
    bool batchDownloadMode = downloadMode == DownloadMode.folder;

    // If 'alwaysAsk', show dialog with choice
    if (downloadMode == DownloadMode.alwaysAsk) {
      final selected = await showDialog<DownloadMode>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.tr('downloadOptions')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.tr('fileName')}: ${file.name}'),
              if (file.size != null) Text('${l10n.tr('size')}: ${_formatSize(file.size)}'),
              const SizedBox(height: 16),
              Text(l10n.tr('chooseDownloadMode')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(l10n.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, DownloadMode.singleFile),
              child: Text(l10n.tr('downloadCurrentImageOnly')),
            ),
            if (widget.files != null && widget.files!.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(context, DownloadMode.folder),
                child: Text(l10n.tr('downloadAllImagesInFolder')),
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (selected == null) {
        proceed = false;
      } else {
        batchDownloadMode = selected == DownloadMode.folder;
      }
    }

    if (!proceed || !mounted) return;

    if (status == DownloadPreconditionStatus.requiresWifi) {
      proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.tr('mobileDataWarning')),
              content: Text(l10n.tr('mobileDataContinueDownload')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.tr('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.tr('continueAction')),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
    }

    if (!proceed || !mounted) return;

    Future<void> startSingleDownload(webdav.File targetFile) async {
      final fullPath =
          path_context.posix.join(widget.currentPath, targetFile.name ?? '');
      try {
        await downloadService.downloadFile(fullPath);
        if (!mounted) return;
        // Optional: snackbar per file or silent
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
            SnackBar(content: Text('${l10n.tr('downloadFailed')} (${targetFile.name}): $e')));
      }
    }

    if (batchDownloadMode && widget.files != null) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${l10n.tr('startBatchDownloadImages')} ${widget.files!.length}...'),
        action: SnackBarAction(
          label: l10n.tr('view'),
          onPressed: () => context.push('/download_records'),
        ),
      ));
      for (final f in widget.files!) {
        if (!mounted) break;
        // Ensure we are working with webdav.File
        if (f is webdav.File) {
          await startSingleDownload(f);
        }
      }
    } else {
      // Single file
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${l10n.tr('startDownload')}: ${file.name}'),
        action: SnackBarAction(
          label: l10n.tr('view'),
          onPressed: () => context.push('/download_records'),
        ),
      ));
      await startSingleDownload(file);
    }
  }

  void _showFileOptions(BuildContext context) {
    if (widget.files == null || _currentIndex >= widget.files!.length) return;

    final l10n = context.l10n;
    final file = widget.files![_currentIndex] as webdav.File;
    // AppFileType is image since we are in gallery

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(file.name ?? context.l10n.tr('unknown'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(l10n.tr('downloadToLocal')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleDownload(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.tr('details')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.tr('details')),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l10n.tr('name')}: ${file.name}'),
                          const SizedBox(height: 8),
                          Text(
                              '${l10n.tr('path')}: ${path_context.posix.join(widget.currentPath, file.name)}'),
                          const SizedBox(height: 8),
                          Text('${l10n.tr('size')}: ${_formatSize(file.size)}'),
                          const SizedBox(height: 8),
                          Text('${l10n.tr('modifiedTime')}: ${file.mTime ?? '--'}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.tr('close')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_currentIndex + 1} / ${widget.imageUrls.length}',
            style: const TextStyle(color: Colors.white)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showFileOptions(context),
          ),
        ],
      ),
      body: GestureDetector(
        onLongPress: () {
          _showFileOptions(context);
        },
        child: PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(
                widget.imageUrls[index],
                headers: widget.headers,
              ),
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image,
                          color: Colors.white, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.tr('cannotLoadImage'),
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        error.toString(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              heroAttributes:
                  PhotoViewHeroAttributes(tag: widget.imageUrls[index]),
            );
          },
          itemCount: widget.imageUrls.length,
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            _recordHistoryForCurrentIndex();
          },
        ),
      ),
    );
  }
}
