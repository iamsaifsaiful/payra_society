import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../logic/format.dart';
import '../services/admin_more.dart';
import '../services/admin_repo.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// সমিতির নিয়মাবলি with the date of the last update (members and admins).
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.load, this.onEdit});
  final Future<Rules> Function() load;

  /// Admins get an edit button.
  final Future<bool?> Function(BuildContext context, Rules current)? onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সমিতির নিয়মাবলি')),
      body: Loader<Rules>(
        load: load,
        builder: (context, r, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (r.updatedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Row(
                  children: [
                    const Icon(Icons.update_rounded, size: 18, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(bn('সর্বশেষ হালনাগাদ: ${dateBn(r.updatedAt)}'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
            Panel(
              child: r.text.trim().isEmpty
                  ? const Text('এখনো নিয়মাবলি দেওয়া হয়নি।', style: TextStyle(color: AppColors.muted))
                  : SelectableText(r.text, style: const TextStyle(fontSize: 15.5, height: 1.7)),
            ),
            if (onEdit != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final changed = await onEdit!(context, r);
                  if (changed == true) reload();
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('নিয়মাবলি লিখুন / বদলান'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Admin: open the rules with an editor.
Widget adminRulesScreen(AdminRepo repo) => RulesScreen(
      load: repo.rules,
      onEdit: (context, r) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RulesEditScreen(repo: repo, initial: r))),
    );

class RulesEditScreen extends StatefulWidget {
  const RulesEditScreen({super.key, required this.repo, required this.initial});
  final AdminRepo repo;
  final Rules initial;
  @override
  State<RulesEditScreen> createState() => _RulesEditScreenState();
}

class _RulesEditScreenState extends State<RulesEditScreen> {
  late final _text = TextEditingController(text: widget.initial.text);
  bool _notify = true;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.repo.saveRules(_text.text, notify: _notify);
      if (!mounted) return;
      toast(context, _notify ? 'সংরক্ষণ হয়েছে — সদস্যদের জানানো হয়েছে' : 'সংরক্ষণ হয়েছে');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নিয়মাবলি লিখুন')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TextField(
            controller: _text,
            minLines: 14,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: '১. প্রতি মাসের ১০ তারিখের মধ্যে সঞ্চয় জমা দিতে হবে।\n২. …',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(height: 1.6),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('সব সদস্যকে নোটিফিকেশন দিন'),
            subtitle: const Text('অ্যাপে জানাবে যে নিয়মাবলি হালনাগাদ হয়েছে'),
            value: _notify,
            activeTrackColor: AppColors.brand,
            onChanged: (v) => setState(() => _notify = v),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : 'সংরক্ষণ করুন')),
        ],
      ),
    );
  }
}
