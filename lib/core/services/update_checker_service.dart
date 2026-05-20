import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/app_localizations.dart';

class UpdateInfo {
  UpdateInfo({
    required this.tag,
    required this.url,
  });

  final String tag;
  final String url;
}

class UpdateCheckerService {
  static const _customApiUrl = 'https://update.notess.top/api/check';
  static const _githubApiUrl =
      'https://api.github.com/repos/kizfive/Oplver/releases/latest';
  static const _repoUrl = 'https://github.com/kizfive/Oplver/releases/latest';
  static const _cacheTagKey = 'update_latest_tag';
  static const _cacheUrlKey = 'update_latest_url';
  static const _deferUntilKey = 'update_defer_until_ms';
  static const _timeout = Duration(seconds: 8);

  Future<void> checkForUpdates(
    BuildContext context, {
    bool manual = false,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deferUntilMs = prefs.getInt(_deferUntilKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!manual && now < deferUntilMs) {
        return;
      }

      final package = await PackageInfo.fromPlatform();
      final currentVersion = package.version;
      final latest = await _fetchLatestRelease(prefs);
      if (latest == null) {
        if (manual && context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.updateCheckFailed)),
          );
        }
        return;
      }

      final latestVersion = _normalizeVersion(latest.tag);
      if (!_isNewerVersion(currentVersion, latestVersion)) {
        if (manual && context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.latestVersion)),
          );
        }
        return;
      }

      if (!context.mounted) return;

      final action = await showDialog<_UpdateAction>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.newVersionFound),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.currentVersion}: $currentVersion'),
                const SizedBox(height: 8),
                Text('${l10n.newVersion}: $latestVersion'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, _UpdateAction.defer1Day),
                child: Text(l10n.remindIn1Day),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _UpdateAction.defer3Days),
                child: Text(l10n.remindIn3Days),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _UpdateAction.defer7Days),
                child: Text(l10n.remindIn7Days),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _UpdateAction.later),
                child: Text(l10n.remindLater),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _UpdateAction.updateNow),
                child: Text(l10n.updateNow),
              ),
            ],
          );
        },
      );

      if (action == null || !context.mounted) {
        return;
      }

      if (action == _UpdateAction.updateNow) {
        final target = latest.url.isNotEmpty ? latest.url : _repoUrl;
        await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
        return;
      }

      final deferDuration = switch (action) {
        _UpdateAction.defer1Day => const Duration(days: 1),
        _UpdateAction.defer3Days => const Duration(days: 3),
        _UpdateAction.defer7Days => const Duration(days: 7),
        _UpdateAction.later => Duration.zero,
        _UpdateAction.updateNow => Duration.zero,
      };

      if (deferDuration > Duration.zero) {
        final deferUntil =
            DateTime.now().add(deferDuration).millisecondsSinceEpoch;
        await prefs.setInt(_deferUntilKey, deferUntil);
      }
    } catch (_) {
      if (manual && context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.updateCheckFailed)),
        );
      }
    }
  }

  /// 三层降级获取最新版本信息
  Future<UpdateInfo?> _fetchLatestRelease(SharedPreferences prefs) async {
    // 第一层：自定义 API
    final custom = await _fetchFromCustomApi();
    if (custom != null) return _cacheAndReturn(prefs, custom);

    // 第二层：GitHub API（通过系统代理可达）
    final github = await _fetchFromGitHub();
    if (github != null) return _cacheAndReturn(prefs, github);

    // 第三层：本地缓存
    final cachedTag = prefs.getString(_cacheTagKey);
    final cachedUrl = prefs.getString(_cacheUrlKey);
    if (cachedTag != null && cachedTag.isNotEmpty) {
      return UpdateInfo(tag: cachedTag, url: cachedUrl ?? _repoUrl);
    }

    return null;
  }

  Future<UpdateInfo?> _fetchFromCustomApi() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = _timeout;
      try {
        final uri = Uri.parse(_customApiUrl);
        final request = await client.getUrl(uri);
        request.headers.set('Accept', 'application/json');
        request.headers.set('User-Agent', 'Oplver-Update-Checker');

        final response = await request.close().timeout(_timeout);
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          // API返回格式: {"version":"v1.x.x","url":"..."}
          final version = (data['version'] as String?) ?? '';
          final url = (data['url'] as String?) ?? _repoUrl;
          if (version.isNotEmpty) {
            return UpdateInfo(tag: version, url: url);
          }
        }
      } finally {
        client.close();
      }
    } on TimeoutException {
      // 超时，降级
    } on SocketException {
      // 网络不可达，降级
    } catch (_) {}
    return null;
  }

  Future<UpdateInfo?> _fetchFromGitHub() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = _timeout;
      try {
        final uri = Uri.parse(_githubApiUrl);
        final request = await client.getUrl(uri);
        request.headers.set('Accept', 'application/vnd.github+json');
        request.headers.set('User-Agent', 'Oplver-Update-Checker');

        final response = await request.close().timeout(_timeout);
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final tag = (data['tag_name'] as String?) ?? '';
          final htmlUrl = (data['html_url'] as String?) ?? _repoUrl;
          if (tag.isNotEmpty) {
            return UpdateInfo(tag: tag, url: htmlUrl);
          }
        }
      } finally {
        client.close();
      }
    } on TimeoutException {
      // 超时，降级
    } on SocketException {
      // 网络不可达，降级
    } catch (_) {}
    return null;
  }

  UpdateInfo _cacheAndReturn(SharedPreferences prefs, UpdateInfo info) {
    prefs.setString(_cacheTagKey, info.tag);
    prefs.setString(_cacheUrlKey, info.url);
    return info;
  }

  String _normalizeVersion(String raw) {
    return raw.toLowerCase().startsWith('v') ? raw.substring(1) : raw;
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = _toVersionParts(current);
    final latestParts = _toVersionParts(latest);

    final maxLen = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var i = 0; i < maxLen; i++) {
      final cur = i < currentParts.length ? currentParts[i] : 0;
      final lat = i < latestParts.length ? latestParts[i] : 0;
      if (lat > cur) return true;
      if (lat < cur) return false;
    }
    return false;
  }

  List<int> _toVersionParts(String value) {
    final sanitized = value.split('-').first;
    return sanitized
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}

enum _UpdateAction {
  updateNow,
  later,
  defer1Day,
  defer3Days,
  defer7Days,
}

final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  return UpdateCheckerService();
});
