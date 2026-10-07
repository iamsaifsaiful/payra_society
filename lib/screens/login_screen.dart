import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../main.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _admin = false;
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'আইডি ও পাসওয়ার্ড দুটোই দিন।');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).login(_id.text, _pw.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot(Session s) {
    final phone = s.config?.treasurerPhone ?? '';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.bg,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('পাসওয়ার্ড ভুলে গেছেন?', style: head(20)),
            const SizedBox(height: 8),
            const Text(
              'অ্যাডমিন বা কোষাধ্যক্ষকে জানান। তাঁরা অ্যাপ থেকে নতুন পাসওয়ার্ড দিয়ে আপনার WhatsApp-এ পাঠিয়ে দেবেন। লগইনের পর প্রোফাইল থেকে পাসওয়ার্ড বদলে নিন।',
              style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 20),
            if (phone.isNotEmpty)
              FilledButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                icon: const Icon(Icons.call_rounded),
                label: const Text('কোষাধ্যক্ষকে কল করুন'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final b = s.branding;
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
          children: [
            BrandMark(name: b.name, logoUrl: b.logoUrl),
            const SizedBox(height: 18),
            Text(b.name, style: head(28, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              'সঞ্চয়, বিনিয়োগ আর লাভ — এক জায়গায়',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 15),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(24)),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.notice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
                        child: Text(s.notice!, style: const TextStyle(color: AppColors.danger, height: 1.45)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('সদস্য'), icon: Icon(Icons.person_rounded)),
                        ButtonSegment(value: true, label: Text('অ্যাডমিন'), icon: Icon(Icons.admin_panel_settings_rounded)),
                      ],
                      selected: {_admin},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => setState(() => _admin = v.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.brand,
                        selectedForegroundColor: Colors.white,
                        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _id,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: _admin ? TextInputType.emailAddress : TextInputType.text,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: _admin ? 'ইমেইল বা ইউজারনেম' : 'সদস্য আইডি, মোবাইল বা ইমেইল',
                        hintText: _admin ? null : 'PSM1001 বা 017…',
                        prefixIcon: Icon(_admin ? Icons.alternate_email_rounded : Icons.badge_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pw,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'পাসওয়ার্ড',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          tooltip: _hide ? 'পাসওয়ার্ড দেখান' : 'লুকান',
                          icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('লগইন করুন'),
                    ),
                    const SizedBox(height: 6),
                    TextButton(onPressed: () => _forgot(s), child: const Text('পাসওয়ার্ড ভুলে গেছেন?')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text('সুরক্ষিত সংযোগ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              ],
            ),
            if (presetSite.isEmpty)
              TextButton(
                onPressed: s.changeSite,
                child: Text('অন্য ওয়েবসাইট', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
          ],
        ),
      ),
    );
  }
}
