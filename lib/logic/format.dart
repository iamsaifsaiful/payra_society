/// Bengali number, money and date formatting used everywhere in the app.
library;

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

const monthsShort = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন', 'জুলা', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
const monthsFull = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];

/// Replace ASCII digits with Bengali digits.
String bn(Object? value) {
  final s = value?.toString() ?? '';
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    if (c >= 48 && c <= 57) {
      b.write(_bnDigits[c - 48]);
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

/// Parse numbers that may arrive as int, double or string ("1,250.50").
double toNum(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0;
}

int toInt(Object? v) => toNum(v).round();

/// South-Asian grouping: 1,20,000 / 12,34,567.
String groupLakh(int n) {
  final neg = n < 0;
  var s = n.abs().toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return neg ? '-$s' : s;
}

/// ৳ ১,২০,০০০ — paisa shown only when not whole (or when [paisa] is forced).
String taka(Object? value, {bool paisa = false, bool sign = false}) {
  final v = toNum(value);
  final cents = (v.abs() * 100).round();
  final whole = cents ~/ 100;
  final frac = cents % 100;
  var out = groupLakh(whole);
  if (paisa || frac != 0) out += '.${frac.toString().padLeft(2, '0')}';
  final prefix = v < 0 ? '−' : (sign && v > 0 ? '+' : '');
  return bn('$prefix৳ $out');
}

DateTime? parseDate(Object? v) {
  final s = v?.toString() ?? '';
  if (s.isEmpty || s.startsWith('0000')) return null;
  return DateTime.tryParse(s.length == 10 ? s : s.replaceFirst(' ', 'T'));
}

/// ০৫ অক্টো ২০২৬
String dateBn(Object? v) {
  final d = parseDate(v);
  if (d == null) return '';
  return bn('${d.day.toString().padLeft(2, '0')} ${monthsShort[d.month - 1]} ${d.year}');
}

/// "2026-10" → অক্টোবর ২০২৬
String monthBn(String ym) {
  final p = ym.split('-');
  if (p.length < 2) return bn(ym);
  final m = int.tryParse(p[1]) ?? 1;
  return bn('${monthsFull[(m - 1).clamp(0, 11)]} ${p[0]}');
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'শুভ রাত্রি';
  if (h < 12) return 'শুভ সকাল';
  if (h < 16) return 'শুভ দুপুর';
  if (h < 19) return 'শুভ সন্ধ্যা';
  return 'শুভ রাত্রি';
}

const methodNames = {
  'cash': 'ক্যাশ',
  'bkash': 'বিকাশ',
  'nagad': 'নগদ',
  'bank': 'ব্যাংক',
};

String methodBn(Object? m) => methodNames[(m ?? '').toString().toLowerCase()] ?? (m ?? '').toString();

/// Two-letter avatar initials.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  String first(String p) => String.fromCharCodes(p.runes.take(1));
  return parts.length == 1 ? first(parts[0]) : first(parts[0]) + first(parts.last);
}
