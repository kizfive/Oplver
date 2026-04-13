import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/settings/data/navigation_settings_provider.dart';
import '../../../../core/i18n/app_localizations.dart';

class NavigationManagementPage extends ConsumerWidget {
  const NavigationManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(navigationSettingsProvider);
    final notifier = ref.read(navigationSettingsProvider.notifier);

    // Get items in current order
    final items = settings.order
        .map((key) => kAllNavigationItems.firstWhere((item) => item.key == key))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('manageNavigation')),
      ),
      body: ReorderableListView.builder(
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) {
          notifier.reorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final item = items[index];
          final isHidden = settings.hiddenKeys.contains(item.key);
          final isProfile = item.key == 'profile';
          final labelByKey = {
            'home': context.l10n.tr('navHome'),
            'browse': context.l10n.tr('navFiles'),
            'manga': context.l10n.tr('navManga'),
            'profile': context.l10n.tr('navProfile'),
          };

          return ListTile(
            key: ValueKey(item.key),
            title: Text(labelByKey[item.key] ?? item.label),
            leading: const Icon(Icons.drag_handle),
            trailing: Switch(
              value: !isHidden,
              onChanged: isProfile
                  ? null // Profile cannot be disabled
                  : (value) {
                      notifier.toggleVisibility(item.key, value);
                    },
            ),
          );
        },
      ),
    );
  }
}
