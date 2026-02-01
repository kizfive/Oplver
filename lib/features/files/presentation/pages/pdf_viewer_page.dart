import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../../features/auth/data/auth_provider.dart';
import '../../data/pdf_progress_provider.dart';
import '../../../../features/history/data/file_history_provider.dart';

class PdfViewerPage extends ConsumerStatefulWidget {
  final String path;

  const PdfViewerPage({super.key, required this.path});

  @override
  ConsumerState<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends ConsumerState<PdfViewerPage> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int? _totalPages;
  int? _currentPage = 0;
  bool _pdfReady = false;
  PDFViewController? _pdfViewController;
  int _initialPage = 0;

  @override
  void initState() {
    super.initState();
    // Load initial progress
    final progress = ref.read(pdfProgressProvider)[widget.path];
    _initialPage = progress?.page ?? 0;
    _currentPage = _initialPage;
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final webDavService = ref.read(webDavServiceProvider);
      if (!webDavService.isConnected || webDavService.baseUrl == null) {
        throw Exception('未连接服务器');
      }

      final Uri baseUri = Uri.parse(webDavService.baseUrl!);
      var pathSegments = List<String>.from(baseUri.pathSegments);
      if (pathSegments.isNotEmpty && pathSegments.last.isEmpty) {
        pathSegments.removeLast();
      }

      final cleanPath =
          widget.path.startsWith('/') ? widget.path.substring(1) : widget.path;
      final segs = cleanPath.split('/').where((s) => s.isNotEmpty);
      pathSegments.addAll(segs);

      final fullUri = baseUri.replace(pathSegments: pathSegments);

      final tempDir = await getTemporaryDirectory();
      final fileName = 'temp_pdf_${widget.path.hashCode}.pdf';
      final saveFile = File('${tempDir.path}/$fileName');

      if (await saveFile.exists() && await saveFile.length() > 0) {
        if (mounted) {
          setState(() {
            _localPath = saveFile.path;
            _loading = false;
          });
          // Add to history if loading from cache
          ref.read(fileHistoryProvider.notifier).addToHistory(widget.path);
        }
        return;
      }

      final response =
          await http.get(fullUri, headers: webDavService.authHeaders);

      if (response.statusCode == 200) {
        await saveFile.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            _localPath = saveFile.path;
            _loading = false;
          });
          // Add to history after successful download/load
          ref.read(fileHistoryProvider.notifier).addToHistory(widget.path);
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path.split('/').last),
        actions: [
          if (_pdfReady)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${(_currentPage ?? 0) + 1} / $_totalPages',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _pdfReady
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'prev',
                  mini: true,
                  onPressed: () {
                    final page = _currentPage ?? 0;
                    if (page > 0) {
                      _pdfViewController?.setPage(page - 1);
                    }
                  },
                  child: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  heroTag: 'next',
                  mini: true,
                  onPressed: () {
                    final page = _currentPage ?? 0;
                    final total = _totalPages ?? 0;
                    if (page < total - 1) {
                      _pdfViewController?.setPage(page + 1);
                    }
                  },
                  child: const Icon(Icons.chevron_right),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败: $_error'));
    }
    if (_localPath != null) {
      return PDFView(
        filePath: _localPath,
        enableSwipe: true,
        swipeHorizontal: false, // Vertical scroll is usually better for reading
        autoSpacing: false,
        pageFling: false,
        defaultPage: _initialPage, // Restore progress
        onRender: (pages) {
          setState(() {
            _totalPages = pages;
            _pdfReady = true;
          });
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
          });
        },
        onPageError: (page, error) {
          // ignore: avoid_print
          print('$page: ${error.toString()}');
        },
        onViewCreated: (PDFViewController pdfViewController) {
          _pdfViewController = pdfViewController;
        },
        onPageChanged: (int? page, int? total) {
          if (mounted) {
            setState(() {
              _currentPage = page;
              _totalPages = total; // Ensure total is also updated
            });
          }
          // Save progress
          if (page != null && total != null) {
            ref
                .read(pdfProgressProvider.notifier)
                .setProgress(widget.path, page, total);
          }
        },
      );
    }
    return const Center(child: Text('未知错误'));
  }
}
