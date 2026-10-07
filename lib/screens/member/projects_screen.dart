import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/member_widgets.dart';

/// আমার প্রজেক্ট: every project the member has (or had) a share in.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.repo});
  final MemberRepo repo;

  Future<(List<ProjectStake>, MemberSummary)> _load() async {
    final r = await Future.wait([repo.investments(), repo.statement(), repo.summary()]);
    return (buildStakes(r[0] as List<Investment>, r[1] as List<StatementRow>), r[2] as MemberSummary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আমার প্রজেক্ট')),
      body: Loader<(List<ProjectStake>, MemberSummary)>(
        load: _load,
        builder: (context, d, _) {
          final (stakes, summary) = d;
          final active = stakes.where((s) => s.active).toList();
          final done = stakes.where((s) => !s.active).toList();
          final profit = stakes.fold<double>(0, (a, s) => a + s.profit);
          final back = stakes.fold<double>(0, (a, s) => a + s.capitalReturned + s.shareSold);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(child: StatTile(label: 'চলমান বিনিয়োগ', value: taka(summary.investment), sub: bn('${active.length}টি প্রজেক্টে'))),
                  const SizedBox(width: 12),
                  Expanded(child: StatTile(label: 'মোট লাভ', value: taka(profit))),
                ],
              ),
              const SizedBox(height: 12),
              StatTile(label: 'মূলধন ফেরত (কিস্তি ও শেয়ার বিক্রি)', value: taka(back)),
              if (stakes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'এখনো কোনো প্রজেক্টে আপনার বিনিয়োগ নেই। নতুন প্রজেক্টে সমিতি সদস্যদের ব্যালেন্স থেকে বিনিয়োগ ভাগ করে দেয়।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.6),
                  ),
                ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 8),
                const SectionTitle('চলমান'),
                for (final s in active) ...[ProjectCard(stake: s), const SizedBox(height: 10)],
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 8),
                const SectionTitle('শেষ হয়েছে বা বিক্রি'),
                for (final s in done) ...[ProjectCard(stake: s), const SizedBox(height: 10)],
              ],
              const SizedBox(height: 6),
              const Text(
                'প্রতি কিস্তির লাভের ৯০% বিনিয়োগকারীরা বাকি মূলধনের অনুপাতে পান। শেয়ার বিক্রি করলে আগের লাভ আপনার থাকে, ক্রেতা লাভ পান পরের কিস্তি থেকে।',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.55),
              ),
            ],
          );
        },
      ),
    );
  }
}
