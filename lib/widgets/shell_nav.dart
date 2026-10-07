import 'package:flutter/material.dart';

/// Lets bottom-menu screens go back to the previously opened tab.
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.tab, required this.back, required super.child});

  /// The tab shown now.
  final int tab;

  /// Go to the previous tab (or the first tab).
  final VoidCallback back;

  static ShellNav? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellNav>();

  @override
  bool updateShouldNotify(ShellNav oldWidget) => oldWidget.tab != tab;
}

/// AppBar `leading` for a tab screen: a back arrow on every tab except the first.
/// Returns null for pushed pages, so their normal back arrow stays.
Widget? shellBack(BuildContext context) {
  final nav = ShellNav.of(context);
  if (nav == null || nav.tab == 0 || Navigator.of(context).canPop()) return null;
  return IconButton(
    tooltip: 'পেছনে',
    icon: const BackButtonIcon(),
    onPressed: nav.back,
  );
}

/// Tab history kept by the member and admin shells.
mixin TabHistory<T extends StatefulWidget> on State<T> {
  int tab = 0;
  final built = <int>{0};
  final _history = <int>[];

  void goTab(int i) {
    if (i == tab) return;
    setState(() {
      _history.remove(i);
      _history.add(tab);
      tab = i;
      built.add(i);
    });
  }

  void backTab() {
    setState(() {
      tab = _history.isEmpty ? 0 : _history.removeLast();
      built.add(tab);
    });
  }

  /// Wraps the shell's Scaffold: system back goes to the previous tab first.
  Widget withTabBack(Widget child) => PopScope(
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) backTab();
        },
        child: ShellNav(tab: tab, back: backTab, child: child),
      );
}
