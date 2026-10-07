import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/member_repo.dart';
import '../../widgets/shell_nav.dart';
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

class _MemberShellState extends State<MemberShell> with TabHistory {
  late final MemberRepo _repo = MemberRepo(SessionScope.read(context));

  Widget _page(int i) => switch (i) {
        0 => MemberHomeScreen(repo: _repo, goTab: goTab),
        1 => SavingsScreen(repo: _repo, goTab: goTab),
        2 => ProjectsScreen(repo: _repo),
        3 => StatementScreen(repo: _repo),
        _ => ProfileScreen(repo: _repo),
      };

  @override
  Widget build(BuildContext context) {
    return withTabBack(
      Scaffold(
        body: IndexedStack(
          index: tab,
          children: [for (var i = 0; i < 5; i++) built.contains(i) ? _page(i) : const SizedBox.shrink()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: goTab,
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
