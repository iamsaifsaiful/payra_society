import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/member_widgets.dart';
import 'collections_screen.dart';
import 'entry_screen.dart';
import 'members_screen.dart';
import 'more_screen.dart';

/// Admin app: ড্যাশবোর্ড · সদস্য · ➕ এন্ট্রি · আদায় · আরও
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  late final AdminRepo _repo = AdminRepo(SessionScope.read(context));
  final _built = <int>{0};

  void _go(int i) => setState(() {
        _tab = i;
        _built.add(i);
      });

  Widget _page(int i) => switch (i) {
        0 => AdminDashboard(repo: _repo, goTab: _go),
        1 => MembersScreen(repo: _repo),
        2 => EntryScreen(repo: _repo),
        3 => CollectionsScreen(repo: _repo),
        _ => AdminMoreScreen(repo: _repo),
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
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'ড্যাশবোর্ড'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'সদস্য'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), selectedIcon: Icon(Icons.add_circle_rounded), label: 'এন্ট্রি'),
            NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'আদায়'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'আরও'),
          ],
        ),
      ),
    );
  }
}

class _DashData {
  final SocietyStats stats;
  final List<Defaulter> defaulters;
  final bool arrearsOn;
  const _DashData(this.stats, this.defaulters, this.arrearsOn);
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.repo, required this.goTab});
  final AdminRepo repo;
  final void Function(int) goTab;

  Future<_DashData> _load() async {
    final stats = await repo.dashboard();
    var list = <Defaulter>[];
    var on = false;
    try {
      (list, on) = await repo.defaulters();
    } catch (_) {}
    return _DashData(stats, list, on);
  }

  void _entry(BuildContext context, EntryKind k) => Navigator.of(context).push(
        MaterialPageRoute<bool>(builder: (_) => EntryScreen(repo: repo, initialKind: k, standalone: true)),
      );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.branding.name)),
      body: Loader<_DashData>(
        load: _load,
        builder: (context, d, _) {
          final st = d.stats;
          final irregular = d.defaulters.where((x) => x.irregular).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (s.offline) const OfflineBanner(),
              Text(bn('${greeting(DateTime.now())}, ${s.user?.name ?? ''}'), style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final q in <(IconData, String, VoidCallback)>[
                    (Icons.savings_rounded, 'সঞ্চয়', () => _entry(context, EntryKind.saving)),
                    (Icons.payments_rounded, 'কিস্তি', () => _entry(context, EntryKind.installment)),
                    (Icons.person_search_rounded, 'সদস্য', () => goTab(1)),
                    (Icons.notifications_active_rounded, 'আদায়', () => goTab(3)),
                  ])
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: q.$3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(18)),
                                child: Icon(q.$1, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(q.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (d.arrearsOn && d.defaulters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    color: AppColors.dangerSoft,
                    onTap: () => goTab(3),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bn('${d.defaulters.length} জনের সঞ্চয় বকেয়া${irregular > 0 ? ', $irregular জন অনিয়মিত' : ''}'),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
                      ],
                    ),
                  ),
                ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatTile(icon: Icons.groups_rounded, label: 'সক্রিয় সদস্য', value: bn('${st.activeMembers}/${st.members}')),
                  StatTile(icon: Icons.inventory_2_rounded, label: 'প্রজেক্ট', value: bn(st.projects)),
                  StatTile(icon: Icons.savings_rounded, label: 'মোট সঞ্চয়', value: taka(st.savings)),
                  StatTile(icon: Icons.payments_rounded, label: 'কিস্তি আদায়', value: taka(st.installments)),
                  StatTile(icon: Icons.north_east_rounded, label: 'মোট উত্তোলন', value: taka(st.withdrawals)),
                  StatTile(icon: Icons.volunteer_activism_rounded, label: 'সমিতির তহবিল', value: taka(st.societyFund)),
                ],
              ),
              if (!d.arrearsOn) ...[
                const SizedBox(height: 12),
                Panel(
                  color: AppColors.brandSoft,
                  onTap: () => goTab(4),
                  child: const Text(
                    'মাসিক সঞ্চয়ের অঙ্ক এখনো ঠিক করা হয়নি — বকেয়া হিসাব ও রিমাইন্ডার বন্ধ। "আরও → অ্যাপ ও সঞ্চয়ের নিয়ম" থেকে দিন।',
                    style: TextStyle(height: 1.55),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
