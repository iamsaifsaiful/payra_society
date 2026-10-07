import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'members_screen.dart';

/// আদায়: members behind on savings, with one-tap WhatsApp reminders.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key, required this.repo});
  final AdminRepo repo;
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  int _min = 1;
  final _loader = GlobalKey<LoaderState<(List<Defaulter>, bool)>>();

  String _wa(String mobile) {
    var d = mobile.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0') && d.length == 11) d = '88$d';
    return d;
  }

  void _remind(Defaulter x) {
    final s = SessionScope.read(context);
    final name = s.branding.name;
    final msg = bn('$name\n${x.name}, আপনার ${x.monthsDue} মাসের সঞ্চয় (${taka(x.amountDue)}) বকেয়া আছে। '
        'প্রতি মাসের ${s.config?.dueDay ?? 10} তারিখের মধ্যে জমা দিন। ধন্যবাদ।');
    launchUrl(Uri.parse('https://wa.me/${_wa(x.mobile)}?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আদায়')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final n in const [1, 2, 3])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(n == 3 ? 'অনিয়মিত (৩+ মাস)' : bn('$n+ মাস বকেয়া')),
                      selected: _min == n,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(color: _min == n ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                      onSelected: (_) {
                        setState(() => _min = n);
                        _loader.currentState?.reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Loader<(List<Defaulter>, bool)>(
              key: _loader,
              load: () => widget.repo.defaulters(minMonths: _min),
              builder: (context, d, _) {
                final (items, on) = d;
                if (!on) {
                  return ListView(padding: const EdgeInsets.all(24), children: const [
                    SizedBox(height: 40),
                    Icon(Icons.tune_rounded, size: 44, color: AppColors.muted),
                    SizedBox(height: 12),
                    Text(
                      'মাসিক সঞ্চয়ের অঙ্ক ঠিক করা নেই, তাই বকেয়া হিসাব বন্ধ।\n"আরও → অ্যাপ ও সঞ্চয়ের নিয়ম" থেকে অঙ্কটা দিন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.6),
                    ),
                  ]);
                }
                final total = items.fold<double>(0, (a, x) => a + x.amountDue);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Panel(
                      color: items.isEmpty ? AppColors.brandSoft : AppColors.dangerSoft,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bn('${items.length} জন সদস্য'), style: head(18)),
                                const Text('মোট বকেয়া', style: TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Text(taka(total), style: head(22, color: items.isEmpty ? AppColors.brand : AppColors.danger)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('এই তালিকায় কেউ নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      ),
                    for (final x in items) ...[
                      Panel(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        onTap: x.id > 0
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => MemberDetailScreen(repo: widget.repo, memberId: x.id)),
                                )
                            : null,
                        child: Row(
                          children: [
                            Avatar(text: initials(x.name), size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(x.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    bn('${x.memberUid} · ${x.monthsDue} মাস · ${taka(x.amountDue)}'),
                                    style: TextStyle(fontSize: 13, color: x.irregular ? AppColors.danger : AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            if (x.mobile.isNotEmpty) ...[
                              IconButton(
                                tooltip: 'কল',
                                onPressed: () => launchUrl(Uri(scheme: 'tel', path: x.mobile)),
                                icon: const Icon(Icons.call_rounded, color: AppColors.brand),
                              ),
                              IconButton(
                                tooltip: 'WhatsApp-এ মনে করিয়ে দিন',
                                onPressed: () => _remind(x),
                                icon: const Icon(Icons.chat_rounded, color: Color(0xFF1FA855)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
