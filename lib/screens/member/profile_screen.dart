import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/member_repo.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_nav.dart';
import 'receipts_screen.dart';
import 'society_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.repo});
  final MemberRepo repo;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final u = s.user!;
    return Scaffold(
      appBar: AppBar(leading: shellBack(context), title: const Text('প্রোফাইল')),
      body: Loader<MemberProfile>(
        load: repo.profile,
        builder: (context, p, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Panel(
              child: Row(
                children: [
                  Avatar(text: initials(u.name), url: u.photoUrl, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.fullName.isEmpty ? u.name : p.fullName, style: head(19)),
                        Text(p.memberUid.isEmpty ? u.memberId : p.memberUid, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(99)),
                          child: const Text('সক্রিয় সদস্য', style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('ব্যক্তিগত তথ্য'),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Info(icon: Icons.phone_rounded, label: 'মোবাইল', value: bn(p.mobile)),
                  _Info(icon: Icons.mail_rounded, label: 'ইমেইল', value: p.email),
                  _Info(icon: Icons.home_rounded, label: 'ঠিকানা', value: p.address),
                  _Info(icon: Icons.work_rounded, label: 'পেশা', value: p.profession),
                  _Info(icon: Icons.event_rounded, label: 'সদস্য হয়েছেন', value: dateBn(p.joinDate)),
                  if (p.nomineeName.isNotEmpty) _Info(icon: Icons.family_restroom_rounded, label: 'নমিনি', value: p.nomineeName),
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: AppColors.brand),
                    title: const Text('তথ্য বদলান', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final saved = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: AppColors.bg,
                        builder: (_) => _EditProfile(repo: repo, profile: p),
                      );
                      if (saved == true) reload();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('আমার হিসাব ও সমিতি'),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Nav(icon: Icons.receipt_long_rounded, text: 'আমার রসিদ', page: ReceiptsScreen(repo: repo)),
                  _Nav(icon: Icons.groups_rounded, text: 'সমিতির হিসাব ও তহবিল', page: SocietyScreen(repo: repo)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('নিরাপত্তা ও সেটিংস'),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Nav(icon: Icons.lock_reset_rounded, text: 'পাসওয়ার্ড পরিবর্তন', page: ChangePasswordScreen(repo: repo)),
                  _Nav(icon: Icons.notifications_active_rounded, text: 'কোথায় খবর পাবেন', page: _PrefsScreen(repo: repo)),
                  SwitchListTile(
                    secondary: const Icon(Icons.text_increase_rounded, color: AppColors.brand),
                    title: const Text('বড় লেখা'),
                    value: s.textScale > 1.0,
                    activeTrackColor: AppColors.brand,
                    onChanged: (v) => s.setTextScale(v ? 1.18 : 1.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('লগআউট করবেন?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('লগআউট'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await s.logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('লগআউট'),
            ),
            const SizedBox(height: 14),
            Text(
              bn('অ্যাপ $appVersion · সার্ভার ${s.config?.apiVersion ?? ''}'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.muted),
        title: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
      );
}

class _Nav extends StatelessWidget {
  const _Nav({required this.icon, required this.text, required this.page});
  final IconData icon;
  final String text;
  final Widget page;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.brand),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
      );
}

class _EditProfile extends StatefulWidget {
  const _EditProfile({required this.repo, required this.profile});
  final MemberRepo repo;
  final MemberProfile profile;
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _mobile = TextEditingController(text: widget.profile.mobile);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _profession = TextEditingController(text: widget.profile.profession);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_mobile, _email, _address, _profession]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.updateProfile({
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'profession': _profession.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('তথ্য বদলান', style: head(20)),
            const SizedBox(height: 14),
            TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'মোবাইল')),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল')),
            const SizedBox(height: 10),
            TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'ঠিকানা')),
            const SizedBox(height: 10),
            TextField(controller: _profession, decoration: const InputDecoration(labelText: 'পেশা')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : 'সংরক্ষণ করুন')),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.repo});
  final MemberRepo repo;
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? err;
    if (_current.text.isEmpty) err = 'বর্তমান পাসওয়ার্ড দিন।';
    if (err == null && _next.text.length < 8) err = 'নতুন পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে।';
    if (err == null && _next.text != _again.text) err = 'নতুন পাসওয়ার্ড দুইবার একই হয়নি।';
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.changePassword(_current.text, _next.text);
      if (!mounted) return;
      toast(context, 'পাসওয়ার্ড বদলানো হয়েছে। অন্য সব ফোন থেকে লগআউট হয়ে গেছে।');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('পাসওয়ার্ড পরিবর্তন')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড')),
          const SizedBox(height: 12),
          TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড (কমপক্ষে ৮ অক্ষর)')),
          const SizedBox(height: 12),
          TextField(controller: _again, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড আবার')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'বদলানো হচ্ছে…' : 'পাসওয়ার্ড বদলান')),
        ],
      ),
    );
  }
}

class _PrefsScreen extends StatelessWidget {
  const _PrefsScreen({required this.repo});
  final MemberRepo repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('কোথায় খবর পাবেন')),
      body: Loader<Map<String, bool>>(
        load: repo.preferences,
        builder: (context, prefs, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'অ্যাপের ভেতরে সব খবর সবসময় পাবেন। নিচে বাছুন আর কোথায় পাঠানো হবে (সমিতি যেটা চালু রেখেছে)।',
              style: TextStyle(color: AppColors.muted, height: 1.55),
            ),
            const SizedBox(height: 12),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final e in const [('whatsapp', 'WhatsApp', Icons.chat_rounded), ('sms', 'SMS', Icons.sms_rounded), ('email', 'ইমেইল', Icons.mail_rounded)])
                    SwitchListTile(
                      secondary: Icon(e.$3, color: AppColors.brand),
                      title: Text(e.$2),
                      value: prefs[e.$1] ?? true,
                      activeTrackColor: AppColors.brand,
                      onChanged: (v) async {
                        try {
                          await repo.setPreference(e.$1, v);
                          await reload();
                        } on ApiException catch (err) {
                          if (context.mounted) toast(context, err.message);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
