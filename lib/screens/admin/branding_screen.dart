import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// নাম ও লোগো: used everywhere — app, receipts and WhatsApp messages.
class BrandingScreen extends StatelessWidget {
  const BrandingScreen({super.key, required this.repo});
  final AdminRepo repo;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নাম ও লোগো')),
      body: Loader<BrandingForm>(
        load: repo.branding,
        builder: (context, f, _) => _BrandingForm(repo: repo, initial: f),
      ),
    );
  }
}

class _BrandingForm extends StatefulWidget {
  const _BrandingForm({required this.repo, required this.initial});
  final AdminRepo repo;
  final BrandingForm initial;
  @override
  State<_BrandingForm> createState() => _BrandingFormState();
}

class _BrandingFormState extends State<_BrandingForm> {
  late final f = widget.initial;
  late final _name = TextEditingController(text: f.name);
  late final _logo = TextEditingController(text: f.logoUrl);
  late final _address = TextEditingController(text: f.address);
  late final _phone = TextEditingController(text: f.phone);
  late final _reg = TextEditingController(text: f.regNo);
  late final _sign = TextEditingController(text: f.signatureName);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _logo, _address, _phone, _reg, _sign]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'সমিতির নাম দিন।');
      return;
    }
    f
      ..name = _name.text.trim()
      ..logoUrl = _logo.text.trim()
      ..address = _address.text.trim()
      ..phone = _phone.text.trim()
      ..regNo = _reg.text.trim()
      ..signatureName = _sign.text.trim();
    setState(() => _busy = true);
    try {
      await widget.repo.saveBranding(f);
      if (!mounted) return;
      toast(context, 'সংরক্ষণ হয়েছে — অ্যাপ, রসিদ ও বার্তায় নতুন নাম/লোগো যাবে');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {String? help, TextInputType? type, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          maxLines: lines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Panel(
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(18)),
                child: BrandMark(name: _name.text, logoUrl: _logo.text.trim(), size: 64),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(_name.text.isEmpty ? 'সমিতির নাম' : _name.text, style: head(18))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _field(_name, 'সমিতির নাম *'),
        _field(_logo, 'লোগোর লিংক (URL)', type: TextInputType.url, help: 'ওয়েবসাইটের Media-তে লোগো আপলোড করে তার লিংক এখানে দিন।'),
        _field(_address, 'ঠিকানা', lines: 2),
        _field(_phone, 'ফোন', type: TextInputType.phone),
        _field(_reg, 'নিবন্ধন নম্বর'),
        _field(_sign, 'রসিদে স্বাক্ষরকারীর পদবি', help: 'যেমন: কোষাধ্যক্ষ'),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : 'সংরক্ষণ করুন')),
      ],
    );
  }
}
