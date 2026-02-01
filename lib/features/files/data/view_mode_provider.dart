import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ViewMode {
  list,
  grid,
}

class ViewModeNotifier extends StateNotifier<ViewMode> {
  ViewModeNotifier() : super(ViewMode.list);

  void toggle() {
    state = state == ViewMode.list ? ViewMode.grid : ViewMode.list;
  }

  void setMode(ViewMode mode) {
    state = mode;
  }
}

final viewModeProvider =
    StateNotifierProvider<ViewModeNotifier, ViewMode>((ref) {
  return ViewModeNotifier();
});
