import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../files/presentation/pages/download_record_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../about/presentation/pages/about_page.dart';
import '../../../../features/auth/data/auth_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../features/settings/data/general_settings_provider.dart';
import '../../../../features/settings/data/navigation_settings_provider.dart';
import 'navigation_management_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 WebDavService 状态以获取连接信息
    final webDavService = ref.watch(webDavServiceProvider);
    final themeState = ref.watch(appThemeStateProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final navSettings = ref.watch(navigationSettingsProvider);

    // Determine the icon for current theme mode
    IconData themeIcon;
    switch (themeState.mode) {
      case ThemeMode.light:
        themeIcon = Icons.wb_sunny;
        break;
      case ThemeMode.dark:
        themeIcon = Icons.nightlight_round;
        break;
      case ThemeMode.system:
        themeIcon = Icons.brightness_auto;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        centerTitle: false,
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(themeIcon),
            tooltip: '切换日夜模式',
            onPressed: () {
              // Cycle through modes: System -> Light -> Dark -> System
              final newMode = switch (themeState.mode) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              };
              ref.read(appThemeStateProvider.notifier).setThemeMode(newMode);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 用户信息卡片
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(child: Icon(Icons.person)),
                      SizedBox(width: 16),
                      Text('当前账户',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 32),
                  _InfoRow(label: '服务器', value: webDavService.baseUrl ?? '未连接'),
                  const SizedBox(height: 8),
                  _InfoRow(label: '用户名', value: webDavService.username ?? '未知'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 个性化定制
          Card(
            elevation: 1,
            child: Column(
              children: [
                 SwitchListTile(
                  secondary: const Icon(Icons.api_outlined),
                  title: const Text('API增强功能'),
                  subtitle: const Text('启用后可使用搜索、缩略图优化等高级功能'),
                  value: generalSettings.enableApiEnhancement,
                  onChanged: (bool value) {
                    ref.read(generalSettingsProvider.notifier).setEnableApiEnhancement(value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: const Text('漫画自动恢复阅读进度'),
                  subtitle: const Text('进入漫画时是否自动跳转到上次阅读位置'),
                  trailing: Switch(
                    value: generalSettings.autoResumeManga,
                    onChanged: (bool value) {
                      ref.read(generalSettingsProvider.notifier).setAutoResumeManga(value);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.view_column_outlined),
                  title: const Text('管理导航栏'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (context) => const NavigationManagementPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                 ListTile(
                  leading: const Icon(Icons.start_outlined),
                  title: const Text('登录后默认页面'),
                  subtitle: Text(_getLabelForKey(navSettings.defaultPageKey)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final newKey = await showDialog<String>(
                      context: context,
                      builder: (context) {
                         // Only show items that are currently enabled (not hidden)
                         final visibleOptions = kAllNavigationItems
                             .where((item) => !navSettings.hiddenKeys.contains(item.key))
                             .toList();

                         return SimpleDialog(
                           title: const Text('选择默认页面'),
                           children: visibleOptions.map((item) {
                             return SimpleDialogOption(
                               onPressed: () => Navigator.pop(context, item.key),
                               child: Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 8),
                                 child: Row(
                                    children: [
                                      if (item.key == navSettings.defaultPageKey)
                                        const Icon(Icons.check, size: 16, color: Colors.blue)
                                      else
                                        const SizedBox(width: 16),
                                      const SizedBox(width: 8),
                                      Text(item.label),
                                    ],
                                 ),
                               ),
                             );
                           }).toList(),
                         );
                      }
                    );
                    
                    if (newKey != null) {
                       ref.read(navigationSettingsProvider.notifier).setDefaultPage(newKey);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 功能入口区域
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_done, size: 28),
                  title: const Text(
                    '下载记录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (context) => const DownloadRecordPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.settings, size: 28),
                  title: const Text(
                    '设置',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline, size: 28),
                  title: const Text(
                    '关于',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                          builder: (context) => const AboutPage()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 退出登录按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _getLabelForKey(String key) {
    return kAllNavigationItems
        .firstWhere((item) => item.key == key, orElse: () => kAllNavigationItems.first)
        .label;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
