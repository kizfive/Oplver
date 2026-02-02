import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationItem {
  final String key;
  final String label;
  final String route;
  final int branchIndex; // The fixed index in the shell routes

  const NavigationItem({
    required this.key,
    required this.label,
    required this.route,
    required this.branchIndex,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'route': route,
        'branchIndex': branchIndex,
      };

  factory NavigationItem.fromJson(Map<String, dynamic> json) => NavigationItem(
        key: json['key'],
        label: json['label'],
        route: json['route'],
        branchIndex: json['branchIndex'],
      );
}

class NavigationSettings {
  final List<String> order; // List of keys in order
  final Set<String> hiddenKeys; // Set of keys that are hidden
  final String defaultPageKey;

  const NavigationSettings({
    required this.order,
    required this.hiddenKeys,
    required this.defaultPageKey,
  });

  NavigationSettings copyWith({
    List<String>? order,
    Set<String>? hiddenKeys,
    String? defaultPageKey,
  }) {
    return NavigationSettings(
      order: order ?? this.order,
      hiddenKeys: hiddenKeys ?? this.hiddenKeys,
      defaultPageKey: defaultPageKey ?? this.defaultPageKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'order': order,
        'hiddenKeys': hiddenKeys.toList(),
        'defaultPageKey': defaultPageKey,
      };

  factory NavigationSettings.fromJson(Map<String, dynamic> json) {
    return NavigationSettings(
      order: List<String>.from(json['order'] ?? []),
      hiddenKeys: Set<String>.from(json['hiddenKeys'] ?? []),
      defaultPageKey: json['defaultPageKey'] ?? 'home',
    );
  }
}

// Fixed definition of all available items
const List<NavigationItem> kAllNavigationItems = [
  NavigationItem(key: 'home', label: '首页', route: '/home', branchIndex: 0),
  NavigationItem(key: 'browse', label: '文件', route: '/browse', branchIndex: 1),
  NavigationItem(key: 'manga', label: '漫画', route: '/manga', branchIndex: 2),
  NavigationItem(key: 'profile', label: '我的', route: '/profile', branchIndex: 3),
];

class NavigationSettingsNotifier extends StateNotifier<NavigationSettings> {
  NavigationSettingsNotifier()
      : super(const NavigationSettings(
          order: ['home', 'browse', 'manga', 'profile'],
          hiddenKeys: {},
          defaultPageKey: 'home',
        )) {
    _loadSettings();
  }

  static const _prefsKey = 'navigation_settings_v1';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr);
        final settings = NavigationSettings.fromJson(data);
        // Ensure profile is never hidden and exists
        if (!settings.order.contains('profile')) {
          final newOrder = List<String>.from(settings.order)..add('profile');
           state = settings.copyWith(order: newOrder);
        } else {
           state = settings;
        }
      } catch (e) {
        // Fallback to default
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  void toggleVisibility(String key, bool visible) {
    if (key == 'profile') return; // Cannot hide profile

    final newHidden = Set<String>.from(state.hiddenKeys);
    if (visible) {
      newHidden.remove(key);
    } else {
       // Cannot hide if it makes list empty? Valid requirement not stated but good UX 
       // but profile is always there so it's fine.
      newHidden.add(key);
    }
    
    // If the default page is now hidden, reset default to 'home' or first available
    String newDefault = state.defaultPageKey;
    if (newHidden.contains(newDefault)) {
       // Try 'profile' as safe fallback
       newDefault = 'profile'; 
    }

    state = state.copyWith(hiddenKeys: newHidden, defaultPageKey: newDefault);
    _saveSettings();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newOrder = List<String>.from(state.order);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);
    
    state = state.copyWith(order: newOrder);
    _saveSettings();
  }
  
  void setDefaultPage(String key) {
    if (state.hiddenKeys.contains(key)) return;
    state = state.copyWith(defaultPageKey: key);
    _saveSettings();
  }
}

final navigationSettingsProvider =
    StateNotifierProvider<NavigationSettingsNotifier, NavigationSettings>((ref) {
  return NavigationSettingsNotifier();
});
