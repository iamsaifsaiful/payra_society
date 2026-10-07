import '../logic/format.dart';

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _list(Object? v) => v is List ? v : const [];
String _str(Object? v) => v?.toString() ?? '';

class Branding {
  final String name, logoUrl, address, phone, regNo;
  const Branding({required this.name, this.logoUrl = '', this.address = '', this.phone = '', this.regNo = ''});

  factory Branding.fromJson(Object? j) {
    final m = _map(j);
    final name = _str(m['name']).trim();
    return Branding(
      name: name.isEmpty ? 'পায়রা সমিতি' : name,
      logoUrl: _str(m['logoUrl']),
      address: _str(m['address']),
      phone: _str(m['phone']),
      regNo: _str(m['regNo']),
    );
  }
}

class AppConfig {
  final String apiVersion;
  final Branding branding;
  final double monthlySaving;
  final int dueDay;
  final List<int> reminderDays;
  final int irregularAfterMonths;
  final String minAppVersion, latestAppVersion, apkUrl, treasurerPhone;
  final bool penaltyEnabled;
  final double penaltyRate;
  final String penaltySince, penaltyBase, rulesUpdatedAt;

  const AppConfig({
    required this.apiVersion,
    required this.branding,
    this.monthlySaving = 0,
    this.dueDay = 10,
    this.reminderDays = const [5, 10],
    this.irregularAfterMonths = 3,
    this.minAppVersion = '1.0.0',
    this.latestAppVersion = '1.0.0',
    this.apkUrl = '',
    this.treasurerPhone = '',
    this.penaltyEnabled = false,
    this.penaltyRate = 0,
    this.penaltySince = '',
    this.penaltyBase = 'monthly',
    this.rulesUpdatedAt = '',
  });

  factory AppConfig.fromJson(Object? j) {
    final m = _map(j);
    final s = _map(m['savings']);
    final a = _map(m['app']);
    return AppConfig(
      apiVersion: _str(m['apiVersion']),
      branding: Branding.fromJson(m['branding']),
      monthlySaving: toNum(s['monthlyAmount']),
      dueDay: toInt(s['dueDay']) == 0 ? 10 : toInt(s['dueDay']),
      reminderDays: _list(s['reminderDays']).map(toInt).toList(),
      irregularAfterMonths: toInt(s['irregularAfterMonths']) == 0 ? 3 : toInt(s['irregularAfterMonths']),
      minAppVersion: _str(a['minVersion']).isEmpty ? '1.0.0' : _str(a['minVersion']),
      latestAppVersion: _str(a['latestVersion']).isEmpty ? '1.0.0' : _str(a['latestVersion']),
      apkUrl: _str(a['apkUrl']),
      treasurerPhone: _str(m['treasurerPhone']),
      penaltyEnabled: _map(m['penalty'])['enabled'] == true,
      penaltyRate: toNum(_map(m['penalty'])['rate']),
      penaltySince: _str(_map(m['penalty'])['since']),
      penaltyBase: _str(_map(m['penalty'])['base']).isEmpty ? 'monthly' : _str(_map(m['penalty'])['base']),
      rulesUpdatedAt: _str(m['rulesUpdatedAt']),
    );
  }
}

class AppUser {
  final String uid, name, role, photoUrl, memberId, email, mobile;
  const AppUser({
    required this.uid,
    required this.name,
    required this.role,
    this.photoUrl = '',
    this.memberId = '',
    this.email = '',
    this.mobile = '',
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Object? j) {
    final m = _map(j);
    return AppUser(
      uid: _str(m['uid']),
      name: _str(m['name']),
      role: _str(m['role']).isEmpty ? 'member' : _str(m['role']),
      photoUrl: _str(m['photoUrl']),
      memberId: _str(m['memberId']),
      email: _str(m['email']),
      mobile: _str(m['mobile']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid, 'name': name, 'role': role, 'photoUrl': photoUrl,
        'memberId': memberId, 'email': email, 'mobile': mobile,
      };
}

class Balances {
  /// বর্তমান ব্যালেন্স = সঞ্চয় − চলমান বিনিয়োগ − সঞ্চয় থেকে উত্তোলন
  final double current;
  /// উত্তোলনযোগ্য লাভ
  final double profits;
  final double total;
  const Balances({this.current = 0, this.profits = 0, this.total = 0});

  factory Balances.fromJson(Object? j) {
    final m = _map(j);
    return Balances(current: toNum(m['current']), profits: toNum(m['profits']), total: toNum(m['total']));
  }
}

class MemberSummary {
  final double savings, investment;
  final Balances balances;
  const MemberSummary({this.savings = 0, this.investment = 0, this.balances = const Balances()});

  factory MemberSummary.fromJson(Object? j) {
    final m = _map(j);
    return MemberSummary(
      savings: toNum(m['savings']),
      investment: toNum(m['investment']),
      balances: Balances.fromJson(m['balances']),
    );
  }
}

/// "2.00" → "2", "2.50" → "2.5".
String _rate(double r) => r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

/// One line of the member ledger. Types: saving, investment, distribution,
/// share_sale, withdrawal, penalty (savings penalty, from profit), opening.
class StatementRow {
  final String date, type, note, projectCode, method, withdrawType, month;
  final double credit, debit, balance, capital, profit, rate, base;
  final int ref;

  const StatementRow({
    required this.date,
    required this.type,
    this.note = '',
    this.projectCode = '',
    this.method = '',
    this.withdrawType = '',
    this.credit = 0,
    this.debit = 0,
    this.balance = 0,
    this.capital = 0,
    this.profit = 0,
    this.ref = 0,
    this.month = '',
    this.rate = 0,
    this.base = 0,
  });

  factory StatementRow.fromJson(Object? j) {
    final m = _map(j);
    return StatementRow(
      date: _str(m['tx_date']),
      type: _str(m['type']),
      note: _str(m['note']),
      projectCode: _str(m['project_code']),
      method: _str(m['method']),
      withdrawType: _str(m['withdraw_type']),
      credit: toNum(m['credit']),
      debit: toNum(m['debit']),
      balance: toNum(m['balance']),
      capital: toNum(m['capital']),
      profit: toNum(m['profit']),
      ref: toInt(m['ref']),
      month: _str(m['month']),
      rate: toNum(m['rate']),
      base: toNum(m['base']),
    );
  }

  double get amount => credit - debit;
  bool get isOpening => type == 'opening';

  String get title {
    switch (type) {
      case 'saving':
        final d = parseDate(date);
        return d == null ? 'সঞ্চয় জমা' : 'মাসিক সঞ্চয় · ${monthsFull[d.month - 1]}';
      case 'investment':
        return 'বিনিয়োগ · $projectCode';
      case 'distribution':
        return 'কিস্তি থেকে ফেরত · $projectCode';
      case 'share_sale':
        return 'শেয়ার বিক্রি · $projectCode';
      case 'withdrawal':
        return withdrawType == 'profits' ? 'লাভ উত্তোলন' : 'উত্তোলন';
      case 'opening':
        return 'প্রারম্ভিক ব্যালেন্স';
      case 'penalty':
        return 'সঞ্চয় জরিমানা · ${month.isEmpty ? '' : monthBn(month)}';
    }
    return note.isEmpty ? type : note;
  }

  /// Line under the title: date · method, or the capital/profit split.
  String get subtitle {
    final parts = <String>[dateBn(date)];
    if (type == 'distribution') {
      parts.add('মূলধন ${taka(capital)} + লাভ ${taka(profit)}');
    } else if (type == 'penalty') {
      // The server's note says what the rate was taken of (monthly installment, savings, or profit).
      final i = note.indexOf(' · ');
      parts.add(i > 0 ? note.substring(i + 3) : 'লভ্যাংশ ${taka(base)}-এর ${bn(_rate(rate))}% · প্রশাসনিক তহবিলে');
    } else if (method.isNotEmpty) {
      parts.add(methodBn(method));
    }
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }
}

class ArrearsMonth {
  final String month, dueDate;
  final bool due, paid;
  const ArrearsMonth({required this.month, required this.dueDate, required this.due, required this.paid});
  factory ArrearsMonth.fromJson(Object? j) {
    final m = _map(j);
    return ArrearsMonth(month: _str(m['month']), dueDate: _str(m['dueDate']), due: m['due'] == true, paid: m['paid'] == true);
  }
}

class Arrears {
  final bool configured, irregular;
  final double monthlyAmount, amountDue, paid;
  final int monthsDue;
  final List<ArrearsMonth> months;
  const Arrears({
    this.configured = false,
    this.irregular = false,
    this.monthlyAmount = 0,
    this.amountDue = 0,
    this.paid = 0,
    this.monthsDue = 0,
    this.months = const [],
  });

  factory Arrears.fromJson(Object? j) {
    final m = _map(j);
    return Arrears(
      configured: m['configured'] == true,
      irregular: m['irregular'] == true,
      monthlyAmount: toNum(m['monthlyAmount']),
      amountDue: toNum(m['amountDue']),
      paid: toNum(m['paid']),
      monthsDue: toInt(m['monthsDue']),
      months: _list(m['months']).map(ArrearsMonth.fromJson).toList(),
    );
  }

  /// How many months in a row (newest first) are paid.
  int get regularStreak {
    var n = 0;
    for (final mo in months.reversed) {
      if (!mo.due && !mo.paid) continue; // current month before its due day
      if (!mo.paid) break;
      n++;
    }
    return n;
  }
}

class Investment {
  final int projectId;
  final String projectCode, productType, customerName, status, startDate, endedAt;
  final double invested;
  final bool included;

  const Investment({
    required this.projectId,
    required this.projectCode,
    this.productType = '',
    this.customerName = '',
    this.status = '',
    this.startDate = '',
    this.endedAt = '',
    this.invested = 0,
    this.included = true,
  });

  factory Investment.fromJson(Object? j) {
    final m = _map(j);
    return Investment(
      projectId: toInt(m['project_id']),
      projectCode: _str(m['project_code']),
      productType: _str(m['product_type']),
      customerName: _str(m['customer_name']),
      status: _str(m['status']),
      startDate: _str(m['investment_start_date']),
      endedAt: _str(m['ended_at']),
      invested: toNum(m['invested_amount']),
      included: toInt(m['included']) == 1,
    );
  }

  bool get sold => endedAt.isNotEmpty && !endedAt.startsWith('0000');
}

class AppNotification {
  final int id;
  final String event, message, createdAt;
  final bool read;
  const AppNotification({required this.id, required this.event, required this.message, required this.createdAt, required this.read});
  factory AppNotification.fromJson(Object? j) {
    final m = _map(j);
    final readAt = _str(m['read_at']);
    return AppNotification(
      id: toInt(m['id']),
      event: _str(m['event']),
      message: _str(m['message']),
      createdAt: _str(m['created_at']),
      read: readAt.isNotEmpty && readAt != 'null',
    );
  }
}

class Receipt {
  final String receiptNo, type, memberUid, createdAt, publicUrl, date, method;
  final double amount, beforeTotal, afterTotal;
  final int refId;

  const Receipt({
    required this.receiptNo,
    required this.type,
    this.refId = 0,
    this.memberUid = '',
    this.createdAt = '',
    this.publicUrl = '',
    this.date = '',
    this.method = '',
    this.amount = 0,
    this.beforeTotal = 0,
    this.afterTotal = 0,
  });

  factory Receipt.fromJson(Object? j) {
    final m = _map(j);
    final d = _map(m['details']);
    return Receipt(
      receiptNo: _str(m['receiptNo']),
      type: _str(m['type']),
      refId: toInt(m['refId']),
      memberUid: _str(m['memberUid']),
      createdAt: _str(m['createdAt']),
      publicUrl: _str(m['publicUrl']),
      date: _str(d['date']),
      method: _str(d['method']),
      amount: toNum(m['amount']),
      beforeTotal: toNum(_map(d['before'])['total']),
      afterTotal: toNum(_map(d['after'])['total']),
    );
  }

  String get title => switch (type) {
        'saving' => 'সঞ্চয় জমা',
        'withdrawal' => 'উত্তোলন',
        'installment' => 'কিস্তি',
        _ => 'রসিদ',
      };
}

class SocietyStats {
  final int members, activeMembers, projects, activeProjects;
  final double savings, projectBuy, installments, withdrawals, societyFund;
  final bool limited;
  const SocietyStats({
    this.members = 0,
    this.activeMembers = 0,
    this.projects = 0,
    this.activeProjects = 0,
    this.savings = 0,
    this.projectBuy = 0,
    this.installments = 0,
    this.withdrawals = 0,
    this.societyFund = 0,
    this.limited = false,
  });

  factory SocietyStats.fromJson(Object? j) {
    final m = _map(j);
    return SocietyStats(
      members: toInt(m['members']),
      activeMembers: toInt(m['activeMembers']),
      projects: toInt(m['projects']),
      activeProjects: toInt(m['activeProjects']),
      savings: toNum(m['savings']),
      projectBuy: toNum(m['projectBuy']),
      installments: toNum(m['installments']),
      withdrawals: toNum(m['withdrawals']),
      societyFund: toNum(m['societyFund']),
      limited: m['limited'] == true,
    );
  }
}

class MemberProfile {
  final String memberUid, fullName, mobile, email, address, profession, joinDate, status, nomineeName;
  const MemberProfile({
    required this.memberUid,
    required this.fullName,
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.profession = '',
    this.joinDate = '',
    this.status = 'active',
    this.nomineeName = '',
  });
  factory MemberProfile.fromJson(Object? j) {
    final m = _map(j);
    return MemberProfile(
      memberUid: _str(m['member_uid']),
      fullName: _str(m['full_name']),
      mobile: _str(m['mobile']),
      email: _str(m['email']),
      address: _str(m['address']),
      profession: _str(m['profession']),
      joinDate: _str(m['join_date']),
      status: _str(m['status']),
      nomineeName: _str(m['nominee_name']),
    );
  }
}

/// সমিতির নিয়মাবলি, set by the admin.
class Rules {
  final String text, updatedAt, updatedBy;
  const Rules({this.text = '', this.updatedAt = '', this.updatedBy = ''});
  factory Rules.fromJson(Object? j) {
    final m = _map(j);
    return Rules(text: _str(m['text']), updatedAt: _str(m['updatedAt']), updatedBy: _str(m['updatedBy']));
  }
}
