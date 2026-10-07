import '../api/models.dart';
import '../logic/format.dart';
import 'session.dart';
import 'whatsapp.dart';

String _s(Object? v) => v?.toString() ?? '';

class AdminMember {
  final int id;
  final String uid, name, mobile, email, status, joinDate, photoUrl;
  const AdminMember({
    required this.id,
    required this.uid,
    required this.name,
    this.mobile = '',
    this.email = '',
    this.status = 'active',
    this.joinDate = '',
    this.photoUrl = '',
  });

  factory AdminMember.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return AdminMember(
      id: toInt(m['id']),
      uid: _s(m['member_uid']),
      name: _s(m['full_name']),
      mobile: _s(m['mobile']),
      email: _s(m['email']),
      status: _s(m['status']).isEmpty ? 'active' : _s(m['status']),
      joinDate: _s(m['join_date']),
    );
  }

  bool get active => status == 'active';

  String get statusBn => switch (status) {
        'active' => 'সক্রিয়',
        'inactive' => 'নিষ্ক্রিয়',
        'resign' => 'পদত্যাগ',
        _ => status,
      };
}

class Project {
  final int id;
  final String code, customer, customerMobile, product, status, installmentStart;
  final double buy, sell, firstInstallment, perInstallment;
  const Project({
    required this.id,
    required this.code,
    this.customer = '',
    this.customerMobile = '',
    this.product = '',
    this.status = '',
    this.installmentStart = '',
    this.buy = 0,
    this.sell = 0,
    this.firstInstallment = 0,
    this.perInstallment = 0,
  });

  factory Project.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return Project(
      id: toInt(m['id']),
      code: _s(m['project_code']),
      customer: _s(m['customer_name']),
      customerMobile: _s(m['customer_mobile']),
      product: _s(m['product_type']),
      status: _s(m['status']),
      installmentStart: _s(m['installment_start']),
      buy: toNum(m['buy_amount']),
      sell: toNum(m['sell_amount']),
      firstInstallment: toNum(m['first_installment_amount']),
      perInstallment: toNum(m['remaining_per_installment_amount']),
    );
  }

  bool get closed => status == 'completed' || status == 'closed' || status == 'deleted';
}

class ProjectPayments {
  final Project project;
  final double paid;
  final int count;
  const ProjectPayments(this.project, this.paid, this.count);
  double get due => (project.sell - paid).clamp(0, double.infinity).toDouble();

  /// What the next installment should normally be.
  double get suggested {
    final per = count == 0 && project.firstInstallment > 0 ? project.firstInstallment : project.perInstallment;
    if (per <= 0) return due;
    return per > due ? due : per;
  }
}

class EntryResult {
  final Receipt? receipt;
  final String whatsappLink;
  final String memberName;
  final List<Map<String, dynamic>> distribution;

  /// Ready WhatsApp texts (member's bank-style message; customer + investors for installments).
  final List<WaMessage> whatsapp;

  /// Raw receipt details (installment: paidBefore, paidAfter, dueAfter …).
  final Map<String, dynamic> details;
  const EntryResult({this.receipt, this.whatsappLink = '', this.memberName = '', this.distribution = const [], this.details = const {}, this.whatsapp = const []});

  factory EntryResult.fromJson(Object? j, {String memberName = ''}) {
    final m = j is Map ? j : const {};
    final r = m['receipt'];
    return EntryResult(
      receipt: r is Map && r.isNotEmpty ? Receipt.fromJson(r) : null,
      whatsappLink: _s(m['whatsappLink']),
      whatsapp: WaMessage.listOf(m['whatsapp']),
      memberName: memberName,
      details: r is Map && r['details'] is Map ? Map<String, dynamic>.from(r['details'] as Map) : const {},
      distribution: (m['distribution'] is List ? m['distribution'] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

class Defaulter {
  final int id;
  final String memberUid, name, mobile;
  final int monthsDue;
  final double amountDue;
  final bool irregular;
  final String dueMonthsText;
  final WaMessage? whatsapp;
  const Defaulter(this.id, this.memberUid, this.name, this.mobile, this.monthsDue, this.amountDue, this.irregular, {this.dueMonthsText = '', this.whatsapp});
  factory Defaulter.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return Defaulter(
      toInt(m['id']),
      _s(m['memberUid']),
      _s(m['name']),
      _s(m['mobile']),
      toInt(m['monthsDue']),
      toNum(m['amountDue']),
      m['irregular'] == true,
      dueMonthsText: _s(m['dueMonthsText']),
      whatsapp: m['whatsapp'] is Map ? WaMessage.fromJson(m['whatsapp']) : null,
    );
  }
}

class AppSettings {
  double monthlySaving;
  int dueDay;
  List<int> reminderDays;
  int irregularAfterMonths;
  bool remindersEnabled;
  String minAppVersion, latestAppVersion, apkUrl, treasurerPhone;

  /// Savings penalty. Changed only from the penalty screen (see [penaltyJson]).
  bool penaltyEnabled, penaltySkipAdvance;
  double penaltyRate;
  String penaltyStart;

  AppSettings({
    this.monthlySaving = 0,
    this.dueDay = 10,
    this.reminderDays = const [5, 10],
    this.irregularAfterMonths = 3,
    this.remindersEnabled = true,
    this.minAppVersion = '1.0.0',
    this.latestAppVersion = '1.0.0',
    this.apkUrl = '',
    this.treasurerPhone = '',
    this.penaltyEnabled = false,
    this.penaltySkipAdvance = true,
    this.penaltyRate = 2,
    this.penaltyStart = '',
  });

  factory AppSettings.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return AppSettings(
      monthlySaving: toNum(m['monthly_saving']),
      dueDay: toInt(m['due_day']) == 0 ? 10 : toInt(m['due_day']),
      reminderDays: (m['reminder_days'] is List ? m['reminder_days'] as List : const [5, 10]).map(toInt).toList(),
      irregularAfterMonths: toInt(m['irregular_after_months']) == 0 ? 3 : toInt(m['irregular_after_months']),
      remindersEnabled: m['reminders_enabled'] != false,
      minAppVersion: _s(m['min_app_version']),
      latestAppVersion: _s(m['latest_app_version']),
      apkUrl: _s(m['apk_url']),
      treasurerPhone: _s(m['treasurer_phone']),
      penaltyEnabled: m['penalty_enabled'] == true,
      penaltySkipAdvance: m['penalty_skip_advance'] != false,
      penaltyRate: m['penalty_rate'] == null ? 2 : toNum(m['penalty_rate']),
      penaltyStart: _s(m['penalty_start']),
    );
  }

  Map<String, dynamic> toJson() => {
        'monthly_saving': monthlySaving,
        'due_day': dueDay,
        'reminder_days': reminderDays,
        'irregular_after_months': irregularAfterMonths,
        'reminders_enabled': remindersEnabled,
        'min_app_version': minAppVersion,
        'latest_app_version': latestAppVersion,
        'apk_url': apkUrl,
        'treasurer_phone': treasurerPhone,
      };

  Map<String, dynamic> penaltyJson() => {
        'penalty_enabled': penaltyEnabled,
        'penalty_rate': penaltyRate,
        'penalty_skip_advance': penaltySkipAdvance,
      };
}

/// Plugin messages are partly English; show the common ones in Bengali.
String bnError(String msg) {
  const map = {
    'Amount exceeds available current balance.': 'বর্তমান ব্যালেন্সের চেয়ে বেশি টাকা চাওয়া হয়েছে।',
    'Amount exceeds available profit balance.': 'জমা লাভের চেয়ে বেশি টাকা চাওয়া হয়েছে।',
    'Amount exceeds available total balance.': 'মোট ব্যালেন্সের চেয়ে বেশি টাকা চাওয়া হয়েছে।',
    'Amount must be greater than 0.': 'টাকার অঙ্ক দিন।',
    'Amount must be greater than zero.': 'টাকার অঙ্ক দিন।',
    'Valid date is required.': 'সঠিক তারিখ দিন।',
    'Member not found.': 'সদস্য পাওয়া যায়নি।',
    'Please select a Member ID.': 'সদস্য বাছুন।',
    'Project is required.': 'প্রজেক্ট বাছুন।',
  };
  for (final e in map.entries) {
    if (msg.contains(e.key)) return e.value;
  }
  if (msg.toLowerCase().contains('exceed')) return 'প্রজেক্টের বাকি টাকার চেয়ে বেশি কিস্তি দেওয়া যাবে না।';
  if (msg.toLowerCase().contains('transfer')) return 'শেয়ার ট্রান্সফারের আগের তারিখে কিস্তি দেওয়া যাবে না।';
  return msg;
}

class AdminRepo {
  AdminRepo(this.session);
  final Session session;

  Future<SocietyStats> dashboard() async => SocietyStats.fromJson(await session.cachedGet('/admin/dashboard'));

  Future<(List<Defaulter>, bool)> defaulters({int minMonths = 1}) async {
    final d = await session.cachedGet('/admin/defaulters', query: {'min_months': '$minMonths'}) as Map;
    return ((d['items'] as List? ?? const []).map(Defaulter.fromJson).toList(), d['configured'] == true);
  }

  Future<List<AdminMember>> members({String search = '', int perPage = 50}) async {
    final d = await session.api.get('/members', query: {'search': search, 'per_page': '$perPage'}) as Map;
    return (d['items'] as List? ?? const []).map(AdminMember.fromJson).toList();
  }

  Future<AdminMember> member(int id) async => AdminMember.fromJson(await session.api.get('/members/$id'));

  Future<Balances> balance(int id) async => Balances.fromJson(await session.api.get('/members/$id/balance'));

  Future<Balances> balanceByUid(String uid) async =>
      Balances.fromJson(await session.api.get('/withdrawals/member/${Uri.encodeComponent(uid)}/balances'));

  Future<Arrears> arrears(int id) async {
    try {
      return Arrears.fromJson(await session.api.get('/members/$id/arrears'));
    } catch (_) {
      return const Arrears();
    }
  }

  Future<List<StatementRow>> statement(int id) async {
    final d = await session.api.get('/members/$id/statement') as Map;
    return (d['rows'] as List? ?? const []).map(StatementRow.fromJson).toList();
  }

  /// Returns (temporary password or null, WhatsApp link).
  Future<(String?, String)> resetPassword(int id, {String newPassword = ''}) async {
    final d = await session.api.post('/members/$id/reset-password', {'newPassword': newPassword}) as Map;
    final t = d['temporaryPassword'];
    return (t == null ? null : t.toString(), _s(d['whatsappLink']));
  }

  Future<List<Project>> projects({String search = ''}) async {
    final d = await session.api.get('/projects', query: {'search': search, 'per_page': '50'}) as Map;
    return (d['items'] as List? ?? const []).map(Project.fromJson).toList();
  }

  Future<ProjectPayments> payments(Project p) async {
    final rows = await session.api.get('/projects/${p.id}/installments') as List? ?? const [];
    final paid = rows.fold<double>(0, (a, r) => a + toNum((r as Map)['amount']));
    return ProjectPayments(p, paid, rows.length);
  }

  Future<EntryResult> addSaving({
    required AdminMember member,
    required double amount,
    required String date,
    required String method,
    String note = '',
  }) async {
    final d = await session.api.post('/savings', {
      'member_uid': member.uid,
      'amount': amount,
      'saving_date': date,
      'method': method,
      'note': note,
    });
    return EntryResult.fromJson(d, memberName: member.name);
  }

  Future<EntryResult> addWithdrawal({
    required AdminMember member,
    required double amount,
    required String type,
    required String date,
    required String method,
    required String pin,
    String note = '',
  }) async {
    final d = await session.api.post('/withdrawals', {
      'member_uid': member.uid,
      'amount': amount,
      'withdraw_type': type,
      'withdraw_date': date,
      'method': method,
      'note': note,
      'pin': pin,
    });
    return EntryResult.fromJson(d, memberName: member.name);
  }

  Future<EntryResult> addInstallment({
    required Project project,
    required double amount,
    required String date,
    required String method,
    String note = '',
  }) async {
    final d = await session.api.post('/installments', {
      'project_id': project.id,
      'project_code': project.code,
      'amount': amount,
      'installment_date': date,
      'method': method,
      'note': note,
    });
    return EntryResult.fromJson(d, memberName: project.customer);
  }

  Future<List<Receipt>> receipts({String type = ''}) async {
    final d = await session.api.get('/receipts', query: {if (type.isNotEmpty) 'type': type, 'per_page': '50'}) as Map;
    return (d['items'] as List? ?? const []).map(Receipt.fromJson).toList();
  }

  Future<AppSettings> settings() async => AppSettings.fromJson(await session.api.get('/settings/app'));

  Future<AppSettings> saveSettings(AppSettings s) async {
    final d = await session.api.post('/settings/app', s.toJson());
    await session.refreshConfig();
    return AppSettings.fromJson(d);
  }
}
