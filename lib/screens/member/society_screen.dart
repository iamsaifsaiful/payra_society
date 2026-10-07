import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/member_widgets.dart';

/// সমিতির স্বচ্ছতা: the society's headline numbers.
class SocietyScreen extends StatelessWidget {
  const SocietyScreen({super.key, required this.repo});
  final MemberRepo repo;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final b = s.branding;
    return Scaffold(
      appBar: AppBar(title: const Text('সমিতি')),
      body: Loader<SocietyStats>(
        load: repo.society,
        builder: (context, st, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Panel(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
                    child: BrandMark(name: b.name, logoUrl: b.logoUrl, size: 56),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name, style: head(18)),
                        if (b.address.isNotEmpty) Text(b.address, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        if (b.regNo.isNotEmpty) Text(bn('নিবন্ধন: ${b.regNo}'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(icon: Icons.groups_rounded, label: 'সদস্য', value: bn(st.members)),
                StatTile(icon: Icons.inventory_2_rounded, label: 'চলমান প্রজেক্ট', value: bn(st.activeProjects > 0 ? st.activeProjects : st.projects)),
                if (!st.limited) ...[
                  StatTile(icon: Icons.savings_rounded, label: 'মোট সঞ্চয়', value: taka(st.savings)),
                  StatTile(icon: Icons.shopping_bag_rounded, label: 'প্রজেক্টে কেনা', value: taka(st.projectBuy)),
                  StatTile(icon: Icons.payments_rounded, label: 'কিস্তি আদায়', value: taka(st.installments)),
                  StatTile(icon: Icons.volunteer_activism_rounded, label: 'সমিতির তহবিল', value: taka(st.societyFund)),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Panel(
              color: AppColors.brandSoft,
              child: const Text(
                'লাভ ভাগের নিয়ম: প্রতি কিস্তির লাভের ৯০% বিনিয়োগকারী সদস্যরা পান (বাকি মূলধনের অনুপাতে), ১০% সমিতির তহবিলে যায় — ৫% প্রশাসনিক, ৫% কল্যাণ।',
                style: TextStyle(height: 1.6, fontSize: 14),
              ),
            ),
            if (st.limited) ...[
              const SizedBox(height: 10),
              const Text(
                'সমিতির পূর্ণ হিসাব দেখানো অ্যাডমিন বন্ধ রেখেছেন।',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
