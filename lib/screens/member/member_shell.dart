import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/member_repo.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'projects_screen.dart';
import 'savings_screen.dart';
import 'statement_screen.dart';

/// Member app: হোম · সঞ্চয় · প্রজেক্ট · লেনদেন · প্রোফাইল
class MemberShell extends StatefulWidget {
  const MemberShell({super.key});
  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _tab = 0;
  late final MemberRepo _repo = MemberRepo(SessionScope.read(context));
  // Tabs are built the first time they are opened, then kept alive.
  final _built = <int>{0};

  void _go(int i) => setState(() {
        _tab = i;
        _built.add(i);
      });

  Widget _page(int i) => switch (i) {
        0 => MemberHomeScreen(repo: _repo, goTab: _go),
        1 => SavingsScreen(repo: _repo, goTab: _go),
        2 => ProjectsScreen(repo: _repo),
        3 => StatementScreen(repo: _repo),
        _ => ProfileScreen(repo: _repo),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [for (var i = 0; i < 5; i++) _built.contains(i) ? _page(i) : const SizedBox.shrink()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'হোম'),
            NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded), label: 'সঞ্চয়'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'প্রজেক্ট'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'লেনদেন'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'প্রোফাইল'),
          ],
        ),
      ),
    );
  }
}
