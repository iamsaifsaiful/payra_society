import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_repo.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../member/receipts_screen.dart';
import 'pickers.dart';

const releaseApkUrl = 'https://github.com/iamsaifsaiful/payra_society/releases/latest/download/payra-society.apk';

/// আরও: receipts, app & savings rules, logout.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key, required this.repo});
  final AdminRepo repo;

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final b = s.branding;
    return Scaffold(
      appBar: AppBar(title: const Text('আরও')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
                  child: BrandMark(name: b.name, logoUrl: b.logoUrl, size: 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name, style: head(17)),
                      Text(s.user?.name ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded, color: AppColors.brand),
                  title: const Text('সব রসিদ'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, _AllReceipts(repo: repo)),
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: AppColors.brand),
                  title: const Text('অ্যাপ ও সঞ্চয়ের নিয়ম'),
                  subtitle: const Text('মাসিক অঙ্ক, শেষ তারিখ, কোষাধ্যক্ষের নম্বর, অ্যাপ আপডেট'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, _SettingsScreen(repo: repo)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Panel(
            color: AppColors.brandSoft,
            child: Text(
              'নাম ও লোগো, নতুন প্রজেক্ট, শেয়ার ট্রান্সফার, ব্যাকআপ — এগুলো এখন ওয়েব অ্যাডমিন থেকে করুন। অ্যাপে আসছে পরের ধাপে।',
              style: TextStyle(height: 1.55, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: s.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('লগআউট'),
          ),
          const SizedBox(height: 12),
          Text(
            bn('অ্যাপ $appVersion · সার্ভার ${s.config?.apiVersion ?? ''}'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AllReceipts extends StatefulWidget {
  const _AllReceipts({required this.repo});
  final AdminRepo repo;
  @override
  State<_AllReceipts> createState() => _AllReceiptsState();
}

class _AllReceiptsState extends State<_AllReceipts> {
  String _type = '';
  final _loader = GlobalKey<LoaderState<List<Receipt>>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সব রসিদ')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in const [('', 'সব'), ('saving', 'সঞ্চয়'), ('installment', 'কিস্তি'), ('withdrawal', 'উত্তোলন')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.$2),
                      selected: _type == t.$1,
                      showCheckmark: false,
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(color: _type == t.$1 ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                      onSelected: (_) {
                        setState(() => _type = t.$1);
                        _loader.currentState?.reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Loader<List<Receipt>>(
              key: _loader,
              load: () => widget.repo.receipts(type: _type),
              builder: (context, items, _) => items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 80),
                      Text('কোনো রসিদ নেই। অ্যাপ বা ওয়েব থেকে নতুন এন্ট্রি দিলে এখানে আসবে।', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                      itemBuilder: (context, i) {
                        final r = items[i];
                        final out = r.type == 'withdrawal';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${r.title} · ${r.memberUid.isEmpty ? r.receiptNo : r.memberUid}'),
                          subtitle: Text(bn('${r.receiptNo} · ${dateBn(r.date.isEmpty ? r.createdAt : r.date)}')),
                          trailing: Amount(out ? taka(-r.amount) : taka(r.amount, sign: true), positive: !out),
                          onTap: () => openReceipt(context, r),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({required this.repo});
  final AdminRepo repo;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ ও সঞ্চয়ের নিয়ম')),
      body: Loader<AppSettings>(
        load: repo.settings,
        builder: (context, st, _) => _SettingsForm(repo: repo, initial: st),
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.repo, required this.initial});
  final AdminRepo repo;
  final AppSettings initial;
  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late final AppSettings st = widget.initial;
  late final _monthly = TextEditingController(text: st.monthlySaving > 0 ? st.monthlySaving.toStringAsFixed(0) : '');
  late final _dueDay = TextEditingController(text: '${st.dueDay}');
  late final _days = TextEditingController(text: st.reminderDays.join(', '));
  late final _irregular = TextEditingController(text: '${st.irregularAfterMonths}');
  late final _phone = TextEditingController(text: st.treasurerPhone);
  late final _apk = TextEditingController(text: st.apkUrl);
  late final _latest = TextEditingController(text: st.latestAppVersion);
  late final _min = TextEditingController(text: st.minAppVersion);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_monthly, _dueDay, _days, _irregular, _phone, _apk, _latest, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    st
      ..monthlySaving = parseAmount(_monthly.text)
      ..dueDay = parseAmount(_dueDay.text).round().clamp(1, 28).toInt()
      ..reminderDays = _days.text
          .split(RegExp(r'[,\s]+'))
          .map((x) => parseAmount(x).round())
          .where((x) => x >= 1 && x <= 28)
          .toList()
      ..irregularAfterMonths = parseAmount(_irregular.text).round().clamp(1, 24).toInt()
      ..treasurerPhone = _phone.text.trim()
      ..apkUrl = _apk.text.trim()
      ..latestAppVersion = _latest.text.trim()
      ..minAppVersion = _min.text.trim();
    setState(() => _busy = true);
    try {
      await widget.repo.saveSettings(st);
      if (mounted) {
        toast(context, 'সংরক্ষণ হয়েছে');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {String? help, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 3)),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const SectionTitle('সঞ্চয়'),
        _field(_monthly, 'মাসিক সঞ্চয় (৳)', type: TextInputType.number, help: '০ বা খালি রাখলে বকেয়া হিসাব ও রিমাইন্ডার বন্ধ থাকবে।'),
        _field(_dueDay, 'প্রতি মাসের শেষ তারিখ', type: TextInputType.number),
        _field(_days, 'রিমাইন্ডারের দিন (কমা দিয়ে)', help: 'যেমন: 5, 10'),
        _field(_irregular, 'কত মাস বকেয়া হলে অনিয়মিত', type: TextInputType.number),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('রিমাইন্ডার পাঠানো চালু'),
          value: st.remindersEnabled,
          activeTrackColor: AppColors.brand,
          onChanged: (v) => setState(() => st.remindersEnabled = v),
        ),
        _field(_phone, 'কোষাধ্যক্ষের মোবাইল', type: TextInputType.phone, help: 'সদস্যরা অ্যাপ থেকে এই নম্বরে কল করবেন।'),
        const SectionTitle('অ্যাপ আপডেট'),
        _field(_apk, 'APK ডাউনলোড লিংক'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _apk.text = releaseApkUrl),
            child: const Text('GitHub-এর সর্বশেষ APK লিংক বসান'),
          ),
        ),
        _field(_latest, 'সর্বশেষ ভার্সন', help: bn('এখনকার অ্যাপ $appVersion')),
        _field(_min, 'সর্বনিম্ন ভার্সন', help: 'এর চেয়ে পুরনো অ্যাপ খুললে আপডেট করতে বলবে। সাবধানে বাড়ান।'),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : 'সংরক্ষণ করুন')),
      ],
    );
  }
}
