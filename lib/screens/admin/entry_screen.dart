import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../logic/format.dart';
import '../../main.dart';
import '../../services/admin_repo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'entry_success_screen.dart';
import 'pickers.dart';

enum EntryKind { saving, installment, withdrawal }

/// ➕ এন্ট্রি: savings, installment or withdrawal. Saved at once (no approval step).
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.repo, this.initialKind = EntryKind.saving, this.member, this.standalone = false});
  final AdminRepo repo;
  final EntryKind initialKind;
  final AdminMember? member;

  /// Opened from another screen (has its own back button).
  final bool standalone;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late EntryKind _kind = widget.initialKind;
  AdminMember? _member;
  Project? _project;
  ProjectPayments? _payments;
  Balances? _balances;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'cash';
  String _withdrawType = 'current';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.member != null) _setMember(widget.member!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _defaultAmount());
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _defaultAmount() {
    if (!mounted) return;
    final monthly = SessionScope.read(context).config?.monthlySaving ?? 0;
    if (_kind == EntryKind.saving && monthly > 0 && _amount.text.isEmpty) {
      _amount.text = monthly.toStringAsFixed(monthly % 1 == 0 ? 0 : 2);
    }
  }

  Future<void> _setMember(AdminMember m) async {
    setState(() {
      _member = m;
      _balances = null;
      _error = null;
    });
    try {
      final b = await widget.repo.balanceByUid(m.uid);
      if (mounted && _member?.uid == m.uid) setState(() => _balances = b);
    } catch (_) {}
  }

  Future<void> _setProject(Project p) async {
    setState(() {
      _project = p;
      _payments = null;
      _error = null;
    });
    try {
      final pay = await widget.repo.payments(p);
      if (!mounted || _project?.id != p.id) return;
      setState(() {
        _payments = pay;
        if (pay.suggested > 0) _amount.text = pay.suggested.toStringAsFixed(pay.suggested % 1 == 0 ? 0 : 2);
      });
    } catch (_) {}
  }

  void _switch(EntryKind k) {
    setState(() {
      _kind = k;
      _error = null;
      _amount.clear();
    });
    if (k == EntryKind.saving) _defaultAmount();
    if (k == EntryKind.installment && _payments != null && _payments!.suggested > 0) {
      _amount.text = _payments!.suggested.toStringAsFixed(_payments!.suggested % 1 == 0 ? 0 : 2);
    }
  }

  String? _validate(double amount) {
    if (_kind == EntryKind.installment) {
      if (_project == null) return 'প্রজেক্ট বাছুন।';
    } else if (_member == null) {
      return 'সদস্য বাছুন।';
    }
    if (amount <= 0) return 'টাকার অঙ্ক দিন।';
    if (_kind == EntryKind.installment && _payments != null && amount > _payments!.due + 0.001) {
      return 'প্রজেক্টের বাকি ${taka(_payments!.due)}-এর বেশি কিস্তি দেওয়া যাবে না।';
    }
    if (_kind == EntryKind.withdrawal && _balances != null) {
      final limit = switch (_withdrawType) {
        'profits' => _balances!.profits,
        'total' => _balances!.total,
        _ => _balances!.current,
      };
      if (amount > limit + 0.001) return 'সর্বোচ্চ ${taka(limit)} তোলা যাবে।';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final amount = parseAmount(_amount.text);
    final err = _validate(amount);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    String? pin;
    if (_kind == EntryKind.withdrawal) {
      pin = await askPin(context);
      if (pin == null || pin.isEmpty) return;
    }
    if (!mounted) return;
    final ok = await _confirm(amount);
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final EntryResult r;
      switch (_kind) {
        case EntryKind.saving:
          r = await widget.repo.addSaving(member: _member!, amount: amount, date: ymd(_date), method: _method, note: _note.text.trim());
        case EntryKind.installment:
          r = await widget.repo.addInstallment(project: _project!, amount: amount, date: ymd(_date), method: _method, note: _note.text.trim());
        case EntryKind.withdrawal:
          r = await widget.repo.addWithdrawal(
            member: _member!,
            amount: amount,
            type: _withdrawType,
            date: ymd(_date),
            method: _method,
            pin: pin!,
            note: _note.text.trim(),
          );
      }
      if (!mounted) return;
      final again = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EntrySuccessScreen(kind: _kind, result: r, amount: amount)),
      );
      if (!mounted) return;
      _note.clear();
      if (_kind == EntryKind.installment && _project != null) {
        _setProject(_project!);
      } else if (_member != null) {
        if (again == true && !widget.standalone) {
          setState(() => _member = null);
          _amount.clear();
          _defaultAmount();
        } else {
          _setMember(_member!);
        }
      }
      if (widget.standalone && again != true) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = bnError(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(double amount) {
    final who = _kind == EntryKind.installment ? '${_project!.code} · ${_project!.customer}' : '${_member!.name} (${_member!.uid})';
    final what = switch (_kind) {
      EntryKind.saving => 'সঞ্চয় জমা',
      EntryKind.installment => 'কিস্তি জমা',
      EntryKind.withdrawal => 'উত্তোলন',
    };
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$what নিশ্চিত করুন'),
        content: Text(
          bn('$who\n${taka(amount)} · ${methodBn(_method)} · ${dateBn(ymd(_date))}\n\nসেভ করলেই হিসাবে যোগ হবে, সদস্য রসিদ ও নোটিফিকেশন পাবেন।'),
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('আবার দেখি')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('সেভ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _balances;
    final pay = _payments;
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন এন্ট্রি'), automaticallyImplyLeading: widget.standalone),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<EntryKind>(
            segments: const [
              ButtonSegment(value: EntryKind.saving, label: Text('সঞ্চয়'), icon: Icon(Icons.savings_rounded)),
              ButtonSegment(value: EntryKind.installment, label: Text('কিস্তি'), icon: Icon(Icons.payments_rounded)),
              ButtonSegment(value: EntryKind.withdrawal, label: Text('উত্তোলন'), icon: Icon(Icons.north_east_rounded)),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (v) => _switch(v.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.brand,
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          if (_kind == EntryKind.installment) ...[
            if (_project == null)
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await pickProject(context, widget.repo);
                  if (p != null) _setProject(p);
                },
                icon: const Icon(Icons.inventory_2_rounded),
                label: const Text('প্রজেক্ট বাছুন'),
              )
            else
              PickedTile(
                title: [_project!.code, if (_project!.product.isNotEmpty) _project!.product].join(' · '),
                subtitle: bn('${_project!.customer} ${_project!.customerMobile}'),
                onTap: () async {
                  final p = await pickProject(context, widget.repo);
                  if (p != null) _setProject(p);
                },
              ),
            if (pay != null) ...[
              const SizedBox(height: 10),
              _InfoRow(items: [
                ('বিক্রয়মূল্য', taka(pay.project.sell)),
                ('পরিশোধিত', bn('${taka(pay.paid)} (${pay.count}টি)')),
                ('বাকি', taka(pay.due)),
              ]),
            ],
          ] else ...[
            if (_member == null)
              OutlinedButton.icon(
                onPressed: () async {
                  final m = await pickMember(context, widget.repo);
                  if (m != null) _setMember(m);
                },
                icon: const Icon(Icons.person_search_rounded),
                label: const Text('সদস্য বাছুন'),
              )
            else
              PickedTile(
                leading: Avatar(text: initials(_member!.name), size: 42),
                title: _member!.name,
                subtitle: bn('${_member!.uid} · ${_member!.mobile}'),
                onTap: () async {
                  final m = await pickMember(context, widget.repo);
                  if (m != null) _setMember(m);
                },
              ),
            if (b != null) ...[
              const SizedBox(height: 10),
              _InfoRow(items: [
                ('বর্তমান ব্যালেন্স', taka(b.current)),
                ('লাভ', taka(b.profits)),
                ('মোট', taka(b.total)),
              ]),
            ],
          ],
          if (_kind == EntryKind.withdrawal) ...[
            const SizedBox(height: 16),
            const Text('কোথা থেকে তুলবেন', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'current', label: Text('ব্যালেন্স')),
                ButtonSegment(value: 'profits', label: Text('লাভ')),
                ButtonSegment(value: 'total', label: Text('মোট')),
              ],
              selected: {_withdrawType},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _withdrawType = v.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.brandSoft),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: head(24),
            decoration: const InputDecoration(labelText: 'টাকার অঙ্ক', prefixText: '৳ '),
          ),
          const SizedBox(height: 12),
          DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 14),
          const Text('মাধ্যম', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          MethodChips(value: _method, onChanged: (m) => setState(() => _method = m)),
          const SizedBox(height: 14),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('সেভ করুন'),
          ),
          const SizedBox(height: 8),
          const Text(
            'সেভ করার সাথে সাথে হিসাবে যোগ হয়। ভুল হলে ওয়েব অ্যাডমিন থেকে সংশোধন করুন।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.$1, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
