import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../logic/format.dart';
import '../../services/member_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repo});
  final MemberRepo repo;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<AppNotification>> _load() async {
    final (items, unread) = await widget.repo.notifications();
    if (unread > 0) {
      // Opening the list counts as reading it; the highlight stays for this visit.
      widget.repo.markAllRead().catchError((_) {});
    }
    return items;
  }

  IconData _icon(String event) => switch (event) {
        'saving_added' => Icons.savings_rounded,
        'withdrawal_saved' => Icons.north_east_rounded,
        'installment_received' => Icons.trending_up_rounded,
        'project_created' => Icons.inventory_2_rounded,
        'share_transfer_executed' => Icons.swap_horiz_rounded,
        'saving_reminder' => Icons.event_rounded,
        'saving_overdue' => Icons.warning_amber_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নোটিফিকেশন')),
      body: Loader<List<AppNotification>>(
        load: _load,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.muted),
                SizedBox(height: 12),
                Text('কোনো নোটিফিকেশন নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = items[i];
              final warn = n.event == 'saving_overdue';
              return Panel(
                color: n.read ? AppColors.card : const Color(0xFFF4F9F6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: warn ? AppColors.dangerSoft : AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_icon(n.event), size: 20, color: warn ? AppColors.danger : AppColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_clean(n.message), style: const TextStyle(fontSize: 14.5, height: 1.5)),
                          const SizedBox(height: 4),
                          Text(dateBn(n.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    if (!n.read)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 6, left: 6),
                        decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Messages are written for WhatsApp; drop the society-name line and the
  /// raw receipt URL, which the in-app list does not need.
  String _clean(String m) {
    final lines = m.split('\n').where((l) => !l.trim().startsWith('http')).toList();
    if (lines.length > 1 && !lines.first.contains(',') && !lines.first.contains('৳')) lines.removeAt(0);
    return bn(lines.join('\n').trim());
  }
}
