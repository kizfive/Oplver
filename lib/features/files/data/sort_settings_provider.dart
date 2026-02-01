import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_sort_enums.dart';

class SortSettingsState {
  final SortOption sortOption;
  final SortOrder sortOrder;

  SortSettingsState({
    this.sortOption = SortOption.name,
    this.sortOrder = SortOrder.asc,
  });

  SortSettingsState copyWith({
    SortOption? sortOption,
    SortOrder? sortOrder,
  }) {
    return SortSettingsState(
      sortOption: sortOption ?? this.sortOption,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class SortSettingsNotifier extends StateNotifier<SortSettingsState> {
  SortSettingsNotifier() : super(SortSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final optionIndex = prefs.getInt('sort_option') ?? SortOption.name.index;
    final orderIndex = prefs.getInt('sort_order') ?? SortOrder.asc.index;

    state = SortSettingsState(
      sortOption: SortOption.values[optionIndex],
      sortOrder: SortOrder.values[orderIndex],
    );
  }

  Future<void> setSort(SortOption option, SortOrder order) async {
    state = state.copyWith(sortOption: option, sortOrder: order);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sort_option', option.index);
    await prefs.setInt('sort_order', order.index);
  }
}

final sortSettingsProvider =
    StateNotifierProvider<SortSettingsNotifier, SortSettingsState>((ref) {
  return SortSettingsNotifier();
});
