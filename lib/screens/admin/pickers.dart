import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/format.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Searchable member list in a bottom sheet.
Future<AdminMember?> pickMember(BuildContext context, AdminRepo repo) {
  return showModalBottomSheet<AdminMember>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (_) => FractionallySizedBox(heightFactor: 0.88, child: _MemberSearch(repo: repo)),
  );
}

class _MemberSearch extends StatefulWidget {
  const _MemberSearch({required this.repo});
  final AdminRepo repo;
  @override
  State<_MemberSearch> createState() => _MemberSearchState();
}

class _MemberSearchState extends State<_MemberSearch> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<AdminMember>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.members(search: _q.text.trim());
      if (!mounted) return;
      setState(() {
        _items = r.where((m) => m.active).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _q,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'নাম, আইডি বা মোবাইল',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
              : items == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : items.isEmpty
                      ? const Center(child: Text('কাউকে পাওয়া যায়নি।', style: TextStyle(color: AppColors.muted)))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: AppColors.line),
                          itemBuilder: (context, i) {
                            final m = items[i];
                            return ListTile(
                              leading: Avatar(text: initials(m.name), size: 42),
                              title: Text(m.name),
                              subtitle: Text(bn('${m.uid} · ${m.mobile}')),
                              onTap: () => Navigator.pop(context, m),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

/// Running projects in a bottom sheet.
Future<Project?> pickProject(BuildContext context, AdminRepo repo) {
  return showModalBottomSheet<Project>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.85,
      child: Loader<List<Project>>(
        load: () async => (await repo.projects()).where((p) => !p.closed).toList(),
        builder: (context, items, _) => items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                Text('চলমান কোনো প্রজেক্ট নেই।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              ])
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, color: AppColors.line),
                itemBuilder: (context, i) {
                  final p = items[i];
                  return ListTile(
                    title: Text([p.code, if (p.product.isNotEmpty) p.product].join(' · ')),
                    subtitle: Text(bn('${p.customer} · বিক্রয়মূল্য ${taka(p.sell)}')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
      ),
    ),
  );
}

/// Tappable field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged, this.label = 'তারিখ'});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2015),
          lastDate: DateTime(now.year, now.month, now.day),
          helpText: label,
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.event_rounded)),
        child: Text(dateBn(ymd(value)), style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class MethodChips extends StatelessWidget {
  const MethodChips({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in methodNames.entries)
          ChoiceChip(
            label: Text(m.value),
            selected: value == m.key,
            onSelected: (_) => onChanged(m.key),
            selectedColor: AppColors.brand,
            backgroundColor: AppColors.card,
            showCheckmark: false,
            side: const BorderSide(color: AppColors.line),
            labelStyle: TextStyle(color: value == m.key ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

/// Selected member/project row with a "change" action.
class PickedTile extends StatelessWidget {
  const PickedTile({super.key, required this.title, required this.subtitle, required this.onTap, this.leading});
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
          const Text('বদলান', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Parses "৫,০০০" or "5000" typed in either digit set.
double parseAmount(String s) {
  const bnDigits = '০১২৩৪৫৬৭৮৯';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = bnDigits.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (RegExp(r'[0-9.]').hasMatch(ch)) {
      b.write(ch);
    }
  }
  return double.tryParse(b.toString()) ?? 0;
}

/// Asks for the admin PIN (needed for withdrawals). Never stored.
Future<String?> askPin(BuildContext context, {String reason = 'উত্তোলন নিশ্চিত করতে পিন দিন।'}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('অ্যাডমিন পিন'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'পিন'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('নিশ্চিত'),
        ),
      ],
    ),
  );
}
