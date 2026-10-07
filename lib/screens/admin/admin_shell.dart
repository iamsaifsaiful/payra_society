import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/admin_repo.dart';
import '../../widgets/shell_nav.dart';
import 'dashboard_screen.dart';
import 'entry_screen.dart';
import 'members_screen.dart';
import 'more_screen.dart';
import 'projects_admin_screen.dart';

/// Admin app: ড্যাশবোর্ড · সদস্য · ➕ এন্ট্রি · প্রজেক্ট · আরও
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with TabHistory {
  late final AdminRepo _repo = AdminRepo(SessionScope.read(context));

  Widget _page(int i) => switch (i) {
        0 => AdminDashboard(repo: _repo, goTab: goTab),
        1 => MembersScreen(repo: _repo),
        2 => EntryScreen(repo: _repo),
        3 => ProjectsAdminScreen(repo: _repo),
        _ => AdminMoreScreen(repo: _repo),
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
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'ড্যাশবোর্ড'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'সদস্য'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), selectedIcon: Icon(Icons.add_circle_rounded), label: 'এন্ট্রি'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'প্রজেক্ট'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'আরও'),
          ],
        ),
      ),
    );
  }
}
