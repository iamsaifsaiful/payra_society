import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../logic/format.dart';
import '../services/session.dart';
import '../theme.dart';
import 'common.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Which statement to build. The server renders it as an A4 HTML page; the
/// phone turns that page into a PDF with Android's own renderer (correct Bengali).
class StatementRequest {
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic> linkBody;
  final String fileName;
  final String title;
  const StatementRequest({required this.path, required this.query, required this.linkBody, required this.fileName, required this.title});

  /// The signed-in member's own statement.
  factory StatementRequest.mine(String uid, String from, String to) => StatementRequest(
        path: '/member/statement.html',
        query: {if (from.isNotEmpty) 'from': from, if (to.isNotEmpty) 'to': to},
        linkBody: {'kind': 'member', 'from': from, 'to': to},
        fileName: 'statement-$uid${from.isEmpty ? '' : '-$from'}${to.isEmpty ? '' : '-$to'}.pdf',
        title: 'হিসাব বিবরণী',
      );

  /// Admin: one member's statement.
  factory StatementRequest.member(int id, String uid, String from, String to) => StatementRequest(
        path: '/members/$id/statement.html',
        query: {if (from.isNotEmpty) 'from': from, if (to.isNotEmpty) 'to': to},
        linkBody: {'kind': 'member', 'id': id, 'from': from, 'to': to},
        fileName: 'statement-$uid${from.isEmpty ? '' : '-$from'}${to.isEmpty ? '' : '-$to'}.pdf',
        title: 'হিসাব বিবরণী',
      );

  /// Admin: the society's monthly (key = 2026-10) or yearly (key = 2026) statement.
  factory StatementRequest.society({required bool yearly, required String key}) => StatementRequest(
        path: '/reports/society.html',
        query: yearly ? {'type': 'year', 'year': key} : {'type': 'month', 'month': key},
        linkBody: {'kind': 'society', 'type': yearly ? 'year' : 'month', 'key': key},
        fileName: 'society-${yearly ? 'year' : 'month'}-$key.pdf',
        title: yearly ? 'বার্ষিক বিবরণী' : 'মাসিক বিবরণী',
      );
}

Future<Uint8List> buildStatementPdf(Session s, StatementRequest r) async {
  final html = await s.api.getText(r.path, query: r.query.isEmpty ? null : r.query);
  return Printing.convertHtml(format: PdfPageFormat.a4, html: html, baseUrl: '${s.api.site}/');
}

/// Runs [job] behind a small "তৈরি হচ্ছে…" dialog and shows errors as a toast.
Future<T?> _withProgress<T>(BuildContext context, Future<T> Function() job) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.brand)),
          SizedBox(width: 18),
          Expanded(child: Text('বিবরণী তৈরি হচ্ছে…')),
        ],
      ),
    ),
  );
  try {
    final v = await job();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return v;
  } on ApiException catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      toast(context, e.message);
    }
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      toast(context, 'PDF তৈরি করা গেল না। "ব্রাউজারে খুলুন" দিয়ে চেষ্টা করুন।');
    }
  }
  return null;
}

Future<void> shareStatement(BuildContext context, Session s, StatementRequest r) async {
  final bytes = await _withProgress(context, () => buildStatementPdf(s, r));
  if (bytes == null) return;
  await Printing.sharePdf(bytes: bytes, filename: r.fileName, subject: r.title);
}

Future<void> printStatement(BuildContext context, Session s, StatementRequest r) async {
  final bytes = await _withProgress(context, () => buildStatementPdf(s, r));
  if (bytes == null) return;
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: r.fileName, format: PdfPageFormat.a4);
}

Future<void> openStatementInBrowser(BuildContext context, Session s, StatementRequest r) async {
  final url = await _withProgress(context, () async {
    final d = await s.api.post('/statements/link', r.linkBody) as Map;
    return (d['url'] ?? '').toString();
  });
  if (url == null || url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// The three actions, as a row of buttons.
class StatementActions extends StatelessWidget {
  const StatementActions({super.key, required this.session, required this.request});
  final Session session;
  final StatementRequest Function() request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => shareStatement(context, session, request()),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('PDF ডাউনলোড / শেয়ার'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => printStatement(context, session, request()),
          icon: const Icon(Icons.print_rounded),
          label: const Text('প্রিন্ট / PDF হিসেবে সেভ'),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => openStatementInBrowser(context, session, request()),
          icon: const Icon(Icons.open_in_browser_rounded),
          label: const Text('ব্রাউজারে খুলুন (৭ দিনের লিংক)'),
        ),
      ],
    );
  }
}

enum _Preset { thisMonth, lastMonth, thisYear, lastYear, all, custom }

/// Bottom sheet for a member statement: choose the period, then PDF / print / browser.
Future<void> showMemberStatementSheet(
  BuildContext context, {
  required Session session,
  required StatementRequest Function(String from, String to) build,
  String title = 'হিসাব বিবরণী',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (_) => _MemberStatementSheet(session: session, build: build, title: title),
  );
}

class _MemberStatementSheet extends StatefulWidget {
  const _MemberStatementSheet({required this.session, required this.build, required this.title});
  final Session session;
  final StatementRequest Function(String from, String to) build;
  final String title;
  @override
  State<_MemberStatementSheet> createState() => _MemberStatementSheetState();
}

class _MemberStatementSheetState extends State<_MemberStatementSheet> {
  _Preset _preset = _Preset.all;
  DateTimeRange? _custom;

  (String, String) get _range {
    final now = DateTime.now();
    switch (_preset) {
      case _Preset.thisMonth:
        return (_ymd(DateTime(now.year, now.month, 1)), _ymd(now));
      case _Preset.lastMonth:
        return (_ymd(DateTime(now.year, now.month - 1, 1)), _ymd(DateTime(now.year, now.month, 0)));
      case _Preset.thisYear:
        return (_ymd(DateTime(now.year, 1, 1)), _ymd(now));
      case _Preset.lastYear:
        return (_ymd(DateTime(now.year - 1, 1, 1)), _ymd(DateTime(now.year - 1, 12, 31)));
      case _Preset.all:
        return ('', '');
      case _Preset.custom:
        final c = _custom;
        return c == null ? ('', '') : (_ymd(c.start), _ymd(c.end));
    }
  }

  String _label(_Preset p) => switch (p) {
        _Preset.thisMonth => 'এই মাস',
        _Preset.lastMonth => 'গত মাস',
        _Preset.thisYear => 'এই বছর',
        _Preset.lastYear => 'গত বছর',
        _Preset.all => 'শুরু থেকে',
        _Preset.custom => _custom == null ? 'অন্য সময়…' : '${dateBn(_ymd(_custom!.start))} – ${dateBn(_ymd(_custom!.end))}',
      };

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _custom,
      helpText: 'সময়সীমা বাছুন',
      saveText: 'ঠিক আছে',
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _preset = _Preset.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: head(20)),
          const SizedBox(height: 4),
          const Text('A4 পাতায় সুন্দর করে সাজানো — সারাংশ, প্রজেক্ট ও সব লেনদেন।', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _Preset.values)
                ChoiceChip(
                  label: Text(_label(p)),
                  selected: _preset == p,
                  showCheckmark: false,
                  selectedColor: AppColors.brand,
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.line),
                  labelStyle: TextStyle(color: _preset == p ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                  onSelected: (_) => p == _Preset.custom ? _pickCustom() : setState(() => _preset = p),
                ),
            ],
          ),
          const SizedBox(height: 18),
          StatementActions(session: widget.session, request: () {
            final (from, to) = _range;
            return widget.build(from, to);
          }),
        ],
      ),
    );
  }
}

/// Admin: society statement for a month or a year.
class SocietyReportScreen extends StatefulWidget {
  const SocietyReportScreen({super.key, required this.session});
  final Session session;
  @override
  State<SocietyReportScreen> createState() => _SocietyReportScreenState();
}

class _SocietyReportScreenState extends State<SocietyReportScreen> {
  bool _yearly = false;
  late String _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _year = now.year;
  }

  List<String> get _months {
    final now = DateTime.now();
    return [
      for (var i = 0; i < 36; i++)
        () {
          final d = DateTime(now.year, now.month - i, 1);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('সমিতির বিবরণী')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('মাসিক'), icon: Icon(Icons.calendar_view_month_rounded)),
              ButtonSegment(value: true, label: Text('বার্ষিক'), icon: Icon(Icons.calendar_today_rounded)),
            ],
            selected: {_yearly},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _yearly = v.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.brand,
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          if (_yearly)
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'বছর'),
              items: [for (var y = now.year; y >= 2015; y--) DropdownMenuItem(value: y, child: Text(bn('$y সাল')))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _month,
              decoration: const InputDecoration(labelText: 'মাস'),
              items: [for (final m in _months) DropdownMenuItem(value: m, child: Text(monthBn(m)))],
              onChanged: (v) => setState(() => _month = v ?? _month),
            ),
          const SizedBox(height: 16),
          Panel(
            color: AppColors.brandSoft,
            child: Text(
              _yearly
                  ? 'বার্ষিক বিবরণীতে থাকবে: টাকার আসা-যাওয়া, লাভ ও তহবিল, ১২ মাসের হিসাব, নতুন প্রজেক্ট, প্রজেক্ট ও সদস্যভিত্তিক হিসাব, আজকের সার্বিক অবস্থা।'
                  : 'মাসিক বিবরণীতে থাকবে: টাকার আসা-যাওয়া, লাভ ও তহবিল, নতুন প্রজেক্ট, প্রজেক্ট ও সদস্যভিত্তিক হিসাব, আজকের সার্বিক অবস্থা।',
              style: const TextStyle(height: 1.55),
            ),
          ),
          const SizedBox(height: 18),
          StatementActions(
            session: widget.session,
            request: () => StatementRequest.society(yearly: _yearly, key: _yearly ? '$_year' : _month),
          ),
        ],
      ),
    );
  }
}
