import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_more.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'pickers.dart';

/// Add a member or edit one (all details, status and the member's monthly saving).
class MemberFormScreen extends StatelessWidget {
  const MemberFormScreen({super.key, required this.repo, this.memberId = 0});
  final AdminRepo repo;
  final int memberId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(memberId == 0 ? 'নতুন সদস্য' : 'সদস্যের তথ্য বদলান')),
      body: memberId == 0
          ? _Form(repo: repo, initial: MemberForm(joinDate: ymd(DateTime.now())))
          : Loader<MemberForm>(
              load: () => repo.memberForm(memberId),
              builder: (context, f, _) => _Form(repo: repo, initial: f),
            ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.repo, required this.initial});
  final AdminRepo repo;
  final MemberForm initial;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final MemberForm f = widget.initial;
  late final _name = TextEditingController(text: f.fullName);
  late final _mobile = TextEditingController(text: f.mobile);
  late final _email = TextEditingController(text: f.email);
  late final _nid = TextEditingController(text: f.nid);
  late final _address = TextEditingController(text: f.address);
  late final _profession = TextEditingController(text: f.profession);
  late final _nominee = TextEditingController(text: f.nomineeName);
  late final _nomineeNid = TextEditingController(text: f.nomineeNid);
  late final _monthly = TextEditingController(text: (f.monthlySaving ?? 0) > 0 ? f.monthlySaving!.toStringAsFixed(f.monthlySaving! % 1 == 0 ? 0 : 2) : '');
  final _password = TextEditingController();
  late DateTime _join = parseDate(f.joinDate) ?? DateTime.now();
  late String _status = f.status;
  bool _busy = false;
  String? _error;

  bool get _isNew => f.id == 0;

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _nid, _address, _profession, _nominee, _nomineeNid, _monthly, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    String? err;
    if (_name.text.trim().isEmpty) err = 'নাম দিন।';
    if (err == null && _mobile.text.trim().isEmpty) err = 'মোবাইল নম্বর দিন।';
    if (err == null && _isNew && _password.text.length < 6) err = 'লগইনের পাসওয়ার্ড দিন (কমপক্ষে ৬ অক্ষর)।';
    if (err == null && !_isNew && _password.text.isNotEmpty && _password.text.length < 8) err = 'নতুন পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের দিন।';
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    f
      ..fullName = _name.text.trim()
      ..mobile = _mobile.text.trim()
      ..email = _email.text.trim()
      ..nid = _nid.text.trim()
      ..address = _address.text.trim()
      ..profession = _profession.text.trim()
      ..nomineeName = _nominee.text.trim()
      ..nomineeNid = _nomineeNid.text.trim()
      ..joinDate = ymd(_join)
      ..status = _status;
    final m = parseAmount(_monthly.text);
    f.monthlySaving = m > 0 ? m : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.saveMember(f, password: _password.text);
      if (!mounted) return;
      toast(context, _isNew ? 'নতুন সদস্য যোগ হয়েছে' : 'তথ্য সংরক্ষণ হয়েছে');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = bnError(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, int lines = 1, String? help, bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          maxLines: obscure ? 1 : lines,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 3),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final societyDefault = SessionScope.of(context).config?.monthlySaving ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (!_isNew)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(bn('সদস্য আইডি: ${f.uid}'), style: const TextStyle(color: AppColors.muted)),
          ),
        const SectionTitle('পরিচয়'),
        _field(_name, 'পূর্ণ নাম *'),
        _field(_mobile, 'মোবাইল *', type: TextInputType.phone),
        _field(_email, 'ইমেইল', type: TextInputType.emailAddress),
        _field(_nid, 'জাতীয় পরিচয়পত্র নম্বর', type: TextInputType.number),
        _field(_profession, 'পেশা'),
        _field(_address, 'ঠিকানা', lines: 2),
        const SectionTitle('সঞ্চয়'),
        DateField(label: 'যোগদানের তারিখ', value: _join, onChanged: (d) => setState(() => _join = d)),
        const SizedBox(height: 12),
        _field(
          _monthly,
          'মাসিক সঞ্চয় (৳)',
          type: TextInputType.number,
          help: societyDefault > 0
              ? 'খালি রাখলে সমিতির সাধারণ অঙ্ক ${taka(societyDefault)} ধরা হবে। বকেয়া হিসাব হবে যোগদানের তারিখ থেকে।'
              : 'বকেয়া হিসাব হবে যোগদানের তারিখ থেকে। খালি রাখলে এই সদস্যের বকেয়া হিসাব হবে না।',
        ),
        const SectionTitle('নমিনি'),
        _field(_nominee, 'নমিনির নাম'),
        _field(_nomineeNid, 'নমিনির NID', type: TextInputType.number),
        const SectionTitle('অবস্থা ও লগইন'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'active', label: Text('সক্রিয়')),
            ButtonSegment(value: 'inactive', label: Text('নিষ্ক্রিয়')),
            ButtonSegment(value: 'resign', label: Text('পদত্যাগ')),
          ],
          selected: {_status},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _status = v.first),
          style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.brandSoft),
        ),
        if (_status != 'active')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('নিষ্ক্রিয়/পদত্যাগ করলে সদস্য অ্যাপে ঢুকতে পারবেন না; তাঁর হিসাব আগের মতোই থাকবে।',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        const SizedBox(height: 14),
        _field(
          _password,
          _isNew ? 'লগইনের পাসওয়ার্ড *' : 'নতুন পাসওয়ার্ড (বদলাতে চাইলে)',
          obscure: true,
          help: _isNew ? 'সদস্য আইডি বা মোবাইল আর এই পাসওয়ার্ড দিয়ে অ্যাপে ঢুকবেন।' : null,
        ),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
          const SizedBox(height: 10),
        ],
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : (_isNew ? 'সদস্য যোগ করুন' : 'সংরক্ষণ করুন'))),
      ],
    );
  }
}
