import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 应用名称和版本
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Oplver',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v1.1.0',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '由 Notess 开发',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // GitHub 按钮
          FilledButton.tonalIcon(
            onPressed: () => _launchUrl('https://github.com/kizfive/Oplver'),
            icon: const Icon(Icons.code),
            label: const Text('GitHub'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),

          const SizedBox(height: 24),

          // 依赖库标题
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Text(
              '依赖库',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          // 依赖库列表
          ..._buildLibraryItems(context),
        ],
      ),
    );
  }

  List<Widget> _buildLibraryItems(BuildContext context) {
    final libraries = [
      _LibraryInfo(
        name: 'flutter',
        version: 'SDK',
        author: 'Google',
        license: 'BSD-3-Clause',
      ),
      _LibraryInfo(
        name: 'flutter_riverpod',
        version: '2.5.1',
        author: 'Remi Rousselet',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'go_router',
        version: '14.0.0',
        author: 'Flutter Team',
        license: 'BSD-3-Clause',
      ),
      _LibraryInfo(
        name: 'webdav_client',
        version: '1.2.0',
        author: 'Various Contributors',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'fvp',
        version: '0.35.2',
        author: 'Wang Bin',
        license: 'LGPL-2.1',
        isLGPL: true,
      ),
      _LibraryInfo(
        name: 'video_player',
        version: '2.8.2',
        author: 'Flutter Team',
        license: 'BSD-3-Clause',
      ),
      _LibraryInfo(
        name: 'cached_network_image',
        version: '3.3.1',
        author: 'Baseflow',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'photo_view',
        version: '0.14.0',
        author: 'Renan C. Araújo',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'flutter_pdfview',
        version: '1.3.2',
        author: 'EnduranceCode',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'dio',
        version: '5.4.0',
        author: 'cfug',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'flutter_secure_storage',
        version: '9.0.0',
        author: 'Mogol',
        license: 'BSD-3-Clause',
      ),
      _LibraryInfo(
        name: 'shared_preferences',
        version: '2.2.2',
        author: 'Flutter Team',
        license: 'BSD-3-Clause',
      ),
      _LibraryInfo(
        name: 'path_provider',
        version: '2.1.5',
        author: 'Flutter Team',
        license: 'BSD-3-Clause',
      ),
      _LibraryInfo(
        name: 'permission_handler',
        version: '12.0.1',
        author: 'Baseflow',
        license: 'MIT',
      ),
      _LibraryInfo(
        name: 'share_plus',
        version: '10.1.2',
        author: 'Flutter Community',
        license: 'BSD-3-Clause',
      ),
    ];

    return libraries
        .map((lib) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Row(
                  children: [
                    Text(
                      lib.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lib.isLGPL) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('版本: ${lib.version}'),
                    Text('作者: ${lib.author}'),
                    if (lib.isLGPL) ...[
                      const SizedBox(height: 4),
                      Text(
                        '⚠️ LGPL库：可通过修改pubspec.yaml替换',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: lib.isLGPL
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lib.license,
                    style: TextStyle(
                      fontSize: 11,
                      color: lib.isLGPL
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ))
        .toList();
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _LibraryInfo {
  final String name;
  final String version;
  final String author;
  final String license;
  final bool isLGPL;

  _LibraryInfo({
    required this.name,
    required this.version,
    required this.author,
    required this.license,
    this.isLGPL = false,
  });
}
