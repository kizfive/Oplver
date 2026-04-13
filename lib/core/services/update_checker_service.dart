import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
  static const _apiUrl =
      'https://api.github.com/repos/kizfive/Oplver/releases/latest';
  static const _repoUrl = 'https://github.com/kizfive/Oplver/releases/latest';
  static const _deferUntilKey = 'update_defer_until_ms';

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
      final latest = await _fetchLatestRelease();
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
        final deferUntil = DateTime.now().add(deferDuration).millisecondsSinceEpoch;
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

  Future<UpdateInfo?> _fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Oplver-Update-Checker',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final htmlUrl = (data['html_url'] as String?) ?? _repoUrl;
      if (tag.isEmpty) {
        return null;
      }

      return UpdateInfo(tag: tag, url: htmlUrl);
    } catch (_) {
      return null;
    }
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
