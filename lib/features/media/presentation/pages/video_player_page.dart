// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../auth/data/auth_provider.dart';
import '../../../settings/data/video_settings_provider.dart';
import '../../data/video_playback_history_provider.dart';
import '../../../history/data/file_history_provider.dart';

enum PlayMode { sequence, random, singleLoop }

class VideoPlayerPage extends ConsumerStatefulWidget {
  final String filePath;
  final List<String> initialPlaylist;

  const VideoPlayerPage({
    super.key,
    required this.filePath,
    this.initialPlaylist = const [],
  });

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  bool _initialized = false;
  bool _hasError = false;
  bool _isDisposed = false;
  final String _errorMsg = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Seek gesture state
  bool _isSeeking = false;
  String _seekText = '';
  Duration? _seekTarget;
  Offset? _dragStartPos;

  // Gesture State
  bool _isAdjustingBrightness = false;
  bool _isAdjustingVolume = false;
  double _startBrightness = 0.0;
  double _startVolume = 0.0;
  // Feedback
  bool _showFeedback = false;
  String _feedbackText = '';
  IconData? _feedbackIcon;
  Timer? _feedbackTimer;

  // Controls state
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _saveTimer;

  // Playlist & Settings
  bool _isLocked = false;
  bool _isFastForwarding = false;
  PlayMode _playMode = PlayMode.sequence;
  List<String> _playlist = [];
  bool _isPortrait = false;
  String _currentFilePath = '';

  // Optimistic UI
  bool? _optimisticIsPlaying;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlaylist.isNotEmpty) {
      _playlist = List.from(widget.initialPlaylist);
    } else {
      _playlist = [widget.filePath];
    }
    _currentFilePath = widget.filePath;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      FocusManager.instance.primaryFocus?.unfocus();
    });
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final orientationSettings = ref.read(videoSettingsProvider);
    SystemChrome.setPreferredOrientations(
        orientationSettings.defaultOrientation.deviceOrientations);

    try {
      final webDavService = ref.read(webDavServiceProvider);
      if (!webDavService.isConnected || webDavService.baseUrl == null) {
        throw Exception('WebDAV 服务未连接');
      }

      final Uri baseUri = Uri.parse(webDavService.baseUrl!);
      var pathSegments = List<String>.from(baseUri.pathSegments);
      if (pathSegments.isNotEmpty && pathSegments.last.isEmpty) {
        pathSegments.removeLast();
      }
      final fileSegments =
          _currentFilePath.split('/').where((s) => s.isNotEmpty);
      pathSegments.addAll(fileSegments);
      final fullUri = baseUri.replace(pathSegments: pathSegments);

      debugPrint('Video URL: $fullUri');

      _videoPlayerController = VideoPlayerController.networkUrl(
        fullUri,
        httpHeaders: webDavService.authHeaders,
        videoPlayerOptions: VideoPlayerOptions(
          // 使用 fvp 的混合模式，避免暂停时的帧跳动
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoPlayerController.initialize();
      
      // fvp 已经通过 registerWith 配置了精确的暂停参数
      // 使用 video-sync: display-resample 和 hr-seek 来减少跳帧
      debugPrint('video: using fvp with optimized pause configuration');

      // Initialize system controls
      try {
        _startBrightness = await ScreenBrightness().current;
        _startVolume = await FlutterVolumeController.getVolume() ?? 0.5;
      } catch (e) {
        debugPrint('Error init controls: $e');
      }

      if (!mounted || _isDisposed) {
        // Ensure we pause/dispose if initialization took too long and user left
        try {
          await _videoPlayerController.pause();
          await _videoPlayerController.dispose();
        } catch (_) {}
        return;
      }

      // Auto Resume Logic
      final videoSettings = ref.read(videoSettingsProvider);
      if (videoSettings.enableAutoResume) {
        final history = ref.read(videoPlaybackHistoryProvider.notifier);
        final savedPosMs = history.getPosition(_currentFilePath);
        if (savedPosMs > 0) {
          final durationMs =
              _videoPlayerController.value.duration.inMilliseconds;
          // Only resume if valid and not at the very end (e.g. >95% or < 3s remaining)
          if (savedPosMs < durationMs - 3000) {
            await _videoPlayerController
                .seekTo(Duration(milliseconds: savedPosMs));
            if (!mounted || _isDisposed) return;
          }
        }
      }

      if (!mounted || _isDisposed) return;

      // Start periodic save
      _saveTimer?.cancel();
      _saveTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());

      _videoPlayerController.addListener(_onVideoTick);
      _scheduleHideControls();

      if (mounted && !_isDisposed) {
        // Record history here - video is initialized and about to start
        ref.read(fileHistoryProvider.notifier).addToHistory(_currentFilePath);

        await _videoPlayerController.play();
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      debugPrint('Video Error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Capture state BEFORE pausing/disposing to ensure we get the latest valid position
    int? finalPos;
    int? finalDur;
    try {
      if (_videoPlayerController.value.isInitialized) {
        finalPos = _videoPlayerController.value.position.inMilliseconds;
        finalDur = _videoPlayerController.value.duration.inMilliseconds;
      }
    } catch (_) {}

    // CRITICAL FIX: Pause immediately to stop background audio
    try {
      _videoPlayerController.pause();
    } catch (_) {}

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

    _saveTimer?.cancel();
    _saveTimer = null;

    // Save progress using captured values
    if (finalPos != null && finalDur != null && finalDur > 0) {
      try {
        debugPrint(
            'Saving on exit: pos=$finalPos, dur=$finalDur, path=$_currentFilePath');
        ref
            .read(videoPlaybackHistoryProvider.notifier)
            .saveProgress(_currentFilePath, finalPos, finalDur);
      } catch (e) {
        debugPrint('Exit Save Error: $e');
      }
    }

    _hideTimer?.cancel();
    _hideTimer = null;
    _videoPlayerController.removeListener(_onVideoTick);

    // Restore system brightness
    ScreenBrightness().resetScreenBrightness();

    _videoPlayerController.dispose();
    super.dispose();
  }

  void _saveProgress() {
    if (!_videoPlayerController.value.isInitialized) return;
    if (!mounted || _isDisposed) return;

    final currentPos = _videoPlayerController.value.position.inMilliseconds;
    final totalDur = _videoPlayerController.value.duration.inMilliseconds;

    // Don't save if invalid
    if (totalDur <= 0) return;

    ref
        .read(videoPlaybackHistoryProvider.notifier)
        .saveProgress(_currentFilePath, currentPos, totalDur);
  }

  void _onVideoTick() {
    if (!mounted || _isDisposed) return;
    setState(() {});
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHideControls();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    if (!_videoPlayerController.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
        _scheduleHideControls(); // Retry later if drawer is open
        return;
      }
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _togglePlayPause() async {
    final wasPlaying = _videoPlayerController.value.isPlaying;

    // 更新 UI 状态
    setState(() {
      _optimisticIsPlaying = !wasPlaying;
    });

    try {
      if (wasPlaying) {
        // 暂停视频
        // fvp 的配置 (video-sync: display-resample, hr-seek, framedrop: no)
        // 已经优化了暂停时的帧精确度
        debugPrint('video: pause requested - pos=${_videoPlayerController.value.position.inMilliseconds}ms');
        await _videoPlayerController.pause();
        debugPrint('video: paused at pos=${_videoPlayerController.value.position.inMilliseconds}ms');
      } else {
        // 播放视频
        debugPrint('video: play requested');
        await _videoPlayerController.play();
        debugPrint('video: playing');
      }
    } catch (e) {
      debugPrint('video: error during play/pause toggle: $e');
    }
  }

  // removed unused helper _seekTo

  Duration get _position => _videoPlayerController.value.position;
  Duration get _duration {
    final d = _videoPlayerController.value.duration;
    return d == Duration.zero ? const Duration(milliseconds: 1) : d;
  }

  String get _fileName =>
      _currentFilePath.split('/').where((e) => e.isNotEmpty).last;

  Future<void> _switchVideo(String newPath) async {
    setState(() {
      _currentFilePath = newPath;
      _initialized = false;
      _hasError = false;
    });
    // Ensure cleanup of old controller if needed, although initializePlayer creates a new one
    // But it's safer to dispose the old one first if we are doing a full re-init
    // However, _initializePlayer overwrites _videoPlayerController.
    // Let's dispose carefully.
    _saveTimer?.cancel();
    _saveTimer = null;
    final oldController = _videoPlayerController;
    oldController.removeListener(_onVideoTick);
    // We can't dispose it immediately if we want to avoid UI errors before new one is ready
    // But since we set _initialized = false, UI shows loading, so it is safe.
    await oldController.dispose();

    await _initializePlayer();
  }

  void _playNext() {
    _scheduleHideControls();
    if (_playlist.isEmpty) return;

    final currentIndex = _playlist.indexOf(_currentFilePath);
    if (currentIndex != -1 && currentIndex < _playlist.length - 1) {
      _switchVideo(_playlist[currentIndex + 1]);
    }
  }

  void _playPrevious() {
    _scheduleHideControls();
    if (_playlist.isEmpty) return;

    final currentIndex = _playlist.indexOf(_currentFilePath);
    if (currentIndex > 0) {
      _switchVideo(_playlist[currentIndex - 1]);
    }
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _showControls = true;
        _scheduleHideControls();
      }
    });
  }

  void _cyclePlayMode() {
    setState(() {
      _playMode =
          PlayMode.values[(_playMode.index + 1) % PlayMode.values.length];
    });
  }

  void _toggleOrientation() {
    setState(() {
      _isPortrait = !_isPortrait;
    });
    if (_isPortrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Widget _buildPlaylistDrawer() {
    return Drawer(
      width: 300,
      backgroundColor: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '播放列表',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _playlist.removeAt(oldIndex);
                  _playlist.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _playlist.length; i++)
                  ListTile(
                    key: ValueKey(_playlist[i]),
                    title: Text(
                      _playlist[i].split('/').where((e) => e.isNotEmpty).last,
                      style: TextStyle(
                        color: _playlist[i] == _currentFilePath
                            ? Colors.blue
                            : Colors.white,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _playlist.removeAt(i);
                        });
                      },
                    ),
                    onTap: () {
                      _switchVideo(_playlist[i]);
                      Navigator.of(context).pop(); // Close drawer
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackPanel(IconData icon, String text) {
    setState(() {
      _showFeedback = true;
      _feedbackIcon = icon;
      _feedbackText = text;
      _showControls = false;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showFeedback = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('播放错误')),
        body: Center(
            child: Text('无法播放视频:\n$_errorMsg', textAlign: TextAlign.center)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Intercept back navigation
        try {
          // 1. Pause video
          if (_videoPlayerController.value.isInitialized) {
            await _videoPlayerController.pause();
          }

          // 2. Force save progress immediately
          final pos = _videoPlayerController.value.position.inMilliseconds;
          final dur = _videoPlayerController.value.duration.inMilliseconds;
          if (dur > 0) {
            ref
                .read(videoPlaybackHistoryProvider.notifier)
                .saveProgress(_currentFilePath, pos, dur);
          }

          // 3. Reset orientation to portrait (prevents landscape glitch on previous page)
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
              overlays: SystemUiOverlay.values);
        } catch (e) {
          debugPrint('Pop Logic Error: $e');
        } finally {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        endDrawer: _buildPlaylistDrawer(),
        body: _initialized
            ? Listener(
                behavior: HitTestBehavior
                    .translucent, // Allow events to pass through if needed, but opaque captures them.
                onPointerDown: (event) async {
                  // REMOVED: if (_showControls) return; -> Gestures now work even if controls are shown
                  _isSeeking = false;
                  _isAdjustingBrightness = false;
                  _isAdjustingVolume = false;
                  _dragStartPos = event.position;

                  try {
                    // Only fetch if not dragging? No, needed for start values.
                    _startBrightness = await ScreenBrightness().current;
                    _startVolume =
                        await FlutterVolumeController.getVolume() ?? 0.5;
                  } catch (_) {}
                },
                onPointerMove: (event) {
                  // REMOVED: if (_showControls) return;
                  if (_dragStartPos == null) return;

                  final moveDelta = event.position - _dragStartPos!;

                  // Detect gesture type if not yet locked
                  if (!_isSeeking &&
                      !_isAdjustingBrightness &&
                      !_isAdjustingVolume) {
                    // Threshold check
                    if (moveDelta.dx.abs() > 10 &&
                        moveDelta.dx.abs() > moveDelta.dy.abs()) {
                      // Horizontal -> Seek
                      setState(() {
                        _isSeeking = true;
                        _seekTarget = _videoPlayerController.value.position;
                        if (_isFastForwarding) {
                          _isFastForwarding = false;
                          _videoPlayerController.setPlaybackSpeed(1.0);
                        }
                      });
                    } else if (moveDelta.dy.abs() > 10 &&
                        moveDelta.dy.abs() > moveDelta.dx.abs()) {
                      // Vertical -> Brightness (Left) or Volume (Right)
                      final screenWidth = MediaQuery.of(context).size.width;
                      if (_dragStartPos!.dx < screenWidth / 2) {
                        setState(() => _isAdjustingBrightness = true);
                      } else {
                        setState(() => _isAdjustingVolume = true);
                      }
                    }
                  }

                  if (_isSeeking) {
                    if (!_videoPlayerController.value.isInitialized) return;
                    final duration = _videoPlayerController.value.duration;
                    final deltaMs = event.delta.dx * 200; // Sensitivity
                    if (_seekTarget == null) return; // Guard

                    final currentMs = _seekTarget!.inMilliseconds;
                    final newMs = (currentMs + deltaMs)
                        .clamp(0.0, duration.inMilliseconds.toDouble());

                    setState(() {
                      _seekTarget = Duration(milliseconds: newMs.toInt());
                      final diffMs = newMs.toInt() -
                          _videoPlayerController.value.position.inMilliseconds;
                      final sign = diffMs.isNegative ? '-' : '+';
                      _seekText =
                          '${_formatDuration(_seekTarget!)} ($sign${(diffMs.abs() / 1000).toStringAsFixed(0)}s)';
                    });
                  } else if (_isAdjustingBrightness) {
                    final delta = -event.delta.dy / 300; // sensitivity
                    final newValue = (_startBrightness + delta).clamp(0.0, 1.0);
                    _startBrightness = newValue;
                    ScreenBrightness().setScreenBrightness(newValue);
                    _showFeedbackPanel(Icons.brightness_medium,
                        '${(newValue * 100).toInt()}%');
                  } else if (_isAdjustingVolume) {
                    final delta = -event.delta.dy / 300;
                    final newValue = (_startVolume + delta).clamp(0.0, 1.0);
                    _startVolume = newValue;
                    FlutterVolumeController.setVolume(newValue);
                    _showFeedbackPanel(
                        Icons.volume_up, '${(newValue * 100).toInt()}%');
                  }
                },
                onPointerUp: (event) {
                  if (_isSeeking && _seekTarget != null) {
                    _videoPlayerController.seekTo(_seekTarget!);
                  }
                  setState(() {
                    _isSeeking = false;
                    _isAdjustingBrightness = false;
                    _isAdjustingVolume = false;
                    _dragStartPos = null;
                    _seekTarget = null; // 清除 seekTarget，恢复进度条正常更新
                  });
                },
                onPointerCancel: (event) {
                  setState(() {
                    _isSeeking = false;
                    _isAdjustingBrightness = false;
                    _isAdjustingVolume = false;
                    _seekTarget = null; // 清除 seekTarget
                    _dragStartPos = null;
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 1: Video Surface & Background Gestures
                    // Captures DoubleTap (Play/Pause) and LongPress (Speed)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _togglePlayPause,
                      onTap: _toggleControls,
                      onLongPressStart: (_) {
                        if (_isSeeking ||
                            _isAdjustingBrightness ||
                            _isAdjustingVolume ||
                            !_videoPlayerController.value.isInitialized) {
                          return;
                        }
                        _videoPlayerController.setPlaybackSpeed(2.0);
                        setState(() {
                          _isFastForwarding = true;
                        });
                      },
                      onLongPressEnd: (_) {
                        _videoPlayerController.setPlaybackSpeed(1.0);
                        setState(() {
                          _isFastForwarding = false;
                        });
                      },
                      onLongPressCancel: () {
                        _videoPlayerController.setPlaybackSpeed(1.0);
                        setState(() {
                          _isFastForwarding = false;
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio:
                                  _videoPlayerController.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController),
                            ),
                          ),
                          if (_isSeeking || _isFastForwarding)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        _isSeeking
                                            ? ((_seekTarget?.inMilliseconds ??
                                                        0) >
                                                    _videoPlayerController.value
                                                        .position.inMilliseconds
                                                ? Icons.fast_forward
                                                : Icons.fast_rewind)
                                            : Icons.fast_forward,
                                        color: Colors.white,
                                        size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isSeeking
                                          ? _seekText
                                          : (_isFastForwarding
                                              ? '2.0x 倍速中'
                                              : ''),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_showFeedback)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_feedbackIcon,
                                        color: Colors.white, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      _feedbackText,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Layer 2: Controls Overlay
                    // Separated from Layer 1 to avoid 'DoubleTap' delay on single tap buttons
                    IgnorePointer(
                      ignoring: !_showControls,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          // Tap empty space on controls layer to toggle (hide) controls
                          onTap: _toggleControls,
                          behavior: HitTestBehavior.translucent,
                          child: _buildControls(context),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    if (_isLocked) {
      return Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.lock, color: Colors.white),
                        onPressed: _toggleLock,
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isPlaying =
        _optimisticIsPlaying ?? _videoPlayerController.value.isPlaying;
    final position = _position;
    final duration = _duration;
    final buffered = _videoPlayerController.value.buffered.isNotEmpty
        ? _videoPlayerController.value.buffered.last.end.inMilliseconds
            .toDouble()
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Color(0x00000000), Color(0x88000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              // 只在顶部和底部包裹 SafeArea，中间不包裹
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        _fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center controls removed as requested

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Group
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.lock_open,
                                  color: Colors.white),
                              onPressed: _toggleLock,
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                _playMode == PlayMode.sequence
                                    ? Icons.repeat
                                    : _playMode == PlayMode.random
                                        ? Icons.shuffle
                                        : Icons.repeat_one,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _scheduleHideControls();
                                _cyclePlayMode();
                              },
                            ),
                          ],
                        ),

                        // Center Group (Playback)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.skip_previous_rounded,
                                    color: Colors.white),
                                onPressed: _playPrevious,
                              ),
                              SizedBox(width: _isPortrait ? 4 : 16),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                iconSize: 32,
                                onPressed: _togglePlayPause,
                              ),
                              SizedBox(width: _isPortrait ? 4 : 16),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.skip_next_rounded,
                                    color: Colors.white),
                                onPressed: _playNext,
                              ),
                            ],
                          ),
                        ),

                        // Right Group
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.playlist_play,
                                  color: Colors.white),
                              onPressed: () {
                                _scheduleHideControls();
                                _scaffoldKey.currentState?.openEndDrawer();
                              },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                _isPortrait
                                    ? Icons.fullscreen
                                    : Icons.fullscreen_exit,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _scheduleHideControls();
                                _toggleOrientation();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatDuration(_seekTarget ?? position),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10),
                            ),
                            child: Slider(
                              min: 0,
                              max: duration.inMilliseconds.toDouble(),
                              value: (_seekTarget?.inMilliseconds ??
                                      position.inMilliseconds)
                                  .clamp(0, duration.inMilliseconds)
                                  .toDouble(),
                              secondaryTrackValue: buffered,
                              onChangeStart: (_) => _hideTimer?.cancel(),
                              onChanged: (v) {
                                final target =
                                    Duration(milliseconds: v.toInt());
                                setState(() => _seekTarget = target);
                              },
                              onChangeEnd: (v) async {
                                final target =
                                    Duration(milliseconds: v.toInt());
                                await _videoPlayerController.seekTo(target);
                                _scheduleHideControls();
                                setState(() => _seekTarget = null);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}
