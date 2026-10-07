import '../logic/format.dart';
import 'admin_repo.dart';

String _s(Object? v) => v?.toString() ?? '';
Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _l(Object? v) => v is List ? v : const [];

// ---------------------------------------------------------------------------
// Dashboard (same 8 KPIs as the web dashboard) and the rows behind them.

class OvMember {
  final int id;
  final String uid, name, mobile, status, joinDate;
  final double savings, investment, current, profits, total;
  const OvMember({
    required this.id,
    required this.uid,
    required this.name,
    this.mobile = '',
    this.status = 'active',
    this.joinDate = '',
    this.savings = 0,
    this.investment = 0,
    this.current = 0,
    this.profits = 0,
    this.total = 0,
  });
  factory OvMember.fromJson(Object? j) {
    final m = _m(j);
    return OvMember(
      id: toInt(m['id']),
      uid: _s(m['uid']),
      name: _s(m['name']),
      mobile: _s(m['mobile']),
      status: _s(m['status']),
      joinDate: _s(m['joinDate']),
      savings: toNum(m['savings']),
      investment: toNum(m['investment']),
      current: toNum(m['current']),
      profits: toNum(m['profits']),
      total: toNum(m['total']),
    );
  }
  bool get active => status == 'active';
}

class OvProject {
  final int id, installments;
  final String code, customer, mobile, product, lastInstallment, buyDate, start, end;
  final double buy, sell, paid, due, capitalReturned, investment, investorProfit;
  const OvProject({
    required this.id,
    required this.code,
    this.customer = '',
    this.mobile = '',
    this.product = '',
    this.installments = 0,
    this.lastInstallment = '',
    this.buyDate = '',
    this.start = '',
    this.end = '',
    this.buy = 0,
    this.sell = 0,
    this.paid = 0,
    this.due = 0,
    this.capitalReturned = 0,
    this.investment = 0,
    this.investorProfit = 0,
  });
  factory OvProject.fromJson(Object? j) {
    final m = _m(j);
    return OvProject(
      id: toInt(m['id']),
      code: _s(m['code']),
      customer: _s(m['customer']),
      mobile: _s(m['mobile']),
      product: _s(m['product']),
      installments: toInt(m['installments']),
      lastInstallment: _s(m['lastInstallment']),
      buyDate: _s(m['buyDate']),
      start: _s(m['start']),
      end: _s(m['end']),
      buy: toNum(m['buy']),
      sell: toNum(m['sell']),
      paid: toNum(m['paid']),
      due: toNum(m['due']),
      capitalReturned: toNum(m['capitalReturned']),
      investment: toNum(m['investment']),
      investorProfit: toNum(m['investorProfit']),
    );
  }
  bool get running => due > 0.009;
  double get progress => sell <= 0 ? 0 : (paid / sell).clamp(0, 1).toDouble();
}

class FundRow {
  final String date, title, sub;
  final double amount, share;
  const FundRow({this.date = '', this.title = '', this.sub = '', this.amount = 0, this.share = 0});
}

class Overview {
  final Map<String, double> kpis;
  final Map<String, double> totals;
  final List<OvMember> members;
  final List<OvProject> projects;
  final List<Map<String, dynamic>> fundProjects, fundIncome, adminExpenses, welfareExpenses;

  const Overview({
    required this.kpis,
    required this.totals,
    required this.members,
    required this.projects,
    required this.fundProjects,
    required this.fundIncome,
    required this.adminExpenses,
    required this.welfareExpenses,
  });

  factory Overview.fromJson(Object? j) {
    final m = _m(j);
    Map<String, double> nums(Object? v) => _m(v).map((k, x) => MapEntry(k, toNum(x)));
    final f = _m(m['funds']);
    List<Map<String, dynamic>> rows(Object? v) => _l(v).map(_m).toList();
    return Overview(
      kpis: nums(m['kpis']),
      totals: nums(m['totals']),
      members: _l(m['members']).map(OvMember.fromJson).toList(),
      projects: _l(m['projects']).map(OvProject.fromJson).toList(),
      fundProjects: rows(f['projects']),
      fundIncome: rows(f['income']),
      adminExpenses: rows(f['adminExpenses']),
      welfareExpenses: rows(f['welfareExpenses']),
    );
  }

  double k(String key) => kpis[key] ?? 0;
  double t(String key) => totals[key] ?? 0;
}

// ---------------------------------------------------------------------------
// Members

class MemberForm {
  int id;
  String uid, fullName, mobile, email, nid, address, profession, joinDate, status, nomineeName, nomineeNid;
  double? monthlySaving;
  double effectiveMonthly;

  MemberForm({
    this.id = 0,
    this.uid = '',
    this.fullName = '',
    this.mobile = '',
    this.email = '',
    this.nid = '',
    this.address = '',
    this.profession = '',
    this.joinDate = '',
    this.status = 'active',
    this.nomineeName = '',
    this.nomineeNid = '',
    this.monthlySaving,
    this.effectiveMonthly = 0,
  });

  factory MemberForm.fromJson(Object? j) {
    final m = _m(j);
    final own = m['monthly_saving'];
    return MemberForm(
      id: toInt(m['id']),
      uid: _s(m['member_uid']),
      fullName: _s(m['full_name']),
      mobile: _s(m['mobile']),
      email: _s(m['email']),
      nid: _s(m['nid_no']),
      address: _s(m['address']),
      profession: _s(m['profession']),
      joinDate: _s(m['join_date']),
      status: _s(m['status']).isEmpty ? 'active' : _s(m['status']),
      nomineeName: _s(m['nominee_name']),
      nomineeNid: _s(m['nominee_nid']),
      monthlySaving: own == null ? null : toNum(own),
      effectiveMonthly: toNum(m['monthly_saving_effective']),
    );
  }

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'mobile': mobile,
        'email': email,
        'nid_no': nid,
        'address': address,
        'profession': profession,
        if (joinDate.isNotEmpty) 'join_date': joinDate,
        'status': status,
        'nominee_name': nomineeName,
        'nominee_nid': nomineeNid,
        'monthly_saving': monthlySaving ?? 0,
      };
}

// ---------------------------------------------------------------------------
// Projects

class ProjectInvestor {
  final String uid, name, startDate;
  final double invested, capitalReturned, shareSold, profit, remaining;
  final bool active;
  const ProjectInvestor({
    required this.uid,
    this.name = '',
    this.startDate = '',
    this.invested = 0,
    this.capitalReturned = 0,
    this.shareSold = 0,
    this.profit = 0,
    this.remaining = 0,
    this.active = true,
  });
  factory ProjectInvestor.fromJson(Object? j) {
    final m = _m(j);
    return ProjectInvestor(
      uid: _s(m['uid']),
      name: _s(m['name']),
      startDate: _s(m['startDate']),
      invested: toNum(m['invested']),
      capitalReturned: toNum(m['capitalReturned']),
      shareSold: toNum(m['shareSold']),
      profit: toNum(m['profit']),
      remaining: toNum(m['remaining']),
      active: m['active'] == true,
    );
  }
}

class ProjectDetail {
  final Project project;
  final Map<String, dynamic> raw;
  final double paid, due, societyFund;
  final List<Map<String, dynamic>> installments;
  final List<ProjectInvestor> investors;
  const ProjectDetail({
    required this.project,
    required this.raw,
    required this.paid,
    required this.due,
    required this.societyFund,
    required this.installments,
    required this.investors,
  });
  factory ProjectDetail.fromJson(Object? j) {
    final m = _m(j);
    return ProjectDetail(
      project: Project.fromJson(m['project']),
      raw: _m(m['project']),
      paid: toNum(m['paid']),
      due: toNum(m['due']),
      societyFund: toNum(m['societyFund']),
      installments: _l(m['installments']).map(_m).toList(),
      investors: _l(m['investors']).map(ProjectInvestor.fromJson).toList(),
    );
  }
}

class AllocRow {
  final String uid, name;
  final double balance, amount;
  const AllocRow(this.uid, this.name, this.balance, this.amount);
}

class AllocationPreview {
  final bool ok;
  final String error;
  final double available;
  final List<AllocRow> rows;
  const AllocationPreview(this.ok, this.error, this.available, this.rows);
  factory AllocationPreview.fromJson(Object? j) {
    final m = _m(j);
    return AllocationPreview(
      m['ok'] == true,
      _s(m['error']),
      toNum(m['availableTotal']),
      _l(m['rows']).map((r) {
        final x = _m(r);
        return AllocRow(_s(x['uid']), _s(x['name']), toNum(x['balance']), toNum(x['amount']));
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Share transfer

class SharePlanProject {
  final int projectId;
  final String code, customer;
  final double transferAmount, installmentsDue, invested, capitalReturned;
  const SharePlanProject({
    required this.projectId,
    required this.code,
    this.customer = '',
    this.transferAmount = 0,
    this.installmentsDue = 0,
    this.invested = 0,
    this.capitalReturned = 0,
  });
  factory SharePlanProject.fromJson(Object? j) {
    final m = _m(j);
    return SharePlanProject(
      projectId: toInt(m['project_id']),
      code: _s(m['project_code']),
      customer: _s(m['customer_name']),
      transferAmount: toNum(m['transfer_amount']),
      installmentsDue: toNum(m['installments_due']),
      invested: toNum(m['from_invested_amount']),
      capitalReturned: toNum(m['capital_returned']),
    );
  }
}

class TransferBatch {
  final String fromUid, name, time;
  final double total;
  final List<String> projects;
  const TransferBatch(this.fromUid, this.name, this.time, this.total, this.projects);
  factory TransferBatch.fromJson(Object? j) {
    final m = _m(j);
    return TransferBatch(
      _s(m['from_member_uid']),
      _s(m['member_name']),
      _s(m['transfer_time']),
      toNum(m['total_amount']),
      _l(m['projects']).map((p) => '${_s(_m(p)['project_code'])} ${taka(_m(p)['amount'])}').toList(),
    );
  }
}

/// Lowest balance first, equal cut: everyone gets the same amount until the
/// smallest balance is used up, then the rest is shared among the others.
/// [balances] are what each buyer can still spend. Works in paisa.
Map<String, double> lowestFirst(double amount, Map<String, double> balances) {
  var remaining = (amount * 100).round();
  final left = {for (final e in balances.entries) e.key: (e.value * 100).floor()}..removeWhere((_, v) => v <= 0);
  final out = {for (final k in left.keys) k: 0};
  while (remaining > 0 && left.isNotEmpty) {
    final n = left.length;
    final minBal = left.values.reduce((a, b) => a < b ? a : b);
    if (minBal * n <= remaining) {
      for (final k in left.keys.toList()) {
        out[k] = out[k]! + minBal;
        left[k] = left[k]! - minBal;
      }
      remaining -= minBal * n;
      left.removeWhere((_, v) => v <= 0);
    } else {
      final base = remaining ~/ n;
      var extra = remaining - base * n;
      final keys = left.keys.toList()..sort((a, b) => left[b]!.compareTo(left[a]!));
      for (final k in keys) {
        var add = base;
        if (extra > 0 && left[k]! > base) {
          add += 1;
          extra--;
        }
        out[k] = out[k]! + add;
      }
      remaining = 0;
    }
  }
  return out.map((k, v) => MapEntry(k, v / 100));
}

// ---------------------------------------------------------------------------
// Other income / expense and branding

class MoneyRow {
  final int id;
  final String date, source, details, method, note;
  final double amount;
  const MoneyRow(this.id, this.date, this.source, this.details, this.method, this.note, this.amount);
  factory MoneyRow.fromJson(Object? j, {required bool income}) {
    final m = _m(j);
    return MoneyRow(
      toInt(m['id']),
      _s(m[income ? 'income_date' : 'expense_date']),
      _s(m['source']),
      _s(m['source_details']),
      _s(m['method']),
      _s(m['note']),
      toNum(m['amount']),
    );
  }
}

class BrandingForm {
  String name, logoUrl, address, phone, regNo, signatureName;
  BrandingForm({this.name = '', this.logoUrl = '', this.address = '', this.phone = '', this.regNo = '', this.signatureName = ''});
  factory BrandingForm.fromJson(Object? j) {
    final m = _m(j);
    return BrandingForm(
      name: _s(m['name']),
      logoUrl: _s(m['logoUrl']),
      address: _s(m['address']),
      phone: _s(m['phone']),
      regNo: _s(m['regNo']),
      signatureName: _s(m['signatureName']),
    );
  }
  Map<String, dynamic> toJson() => {
        'society_name': name,
        'logo_url': logoUrl,
        'address': address,
        'phone': phone,
        'reg_no': regNo,
        'signature_name': signatureName,
      };
}

// ---------------------------------------------------------------------------
// Savings penalty (plugin 1.0.9.62)

class Penalty {
  final int id;
  final String uid, name, month, status, waivedBy, note;
  final double base, rate, amount;
  const Penalty({
    required this.id,
    required this.uid,
    this.name = '',
    this.month = '',
    this.status = 'active',
    this.waivedBy = '',
    this.note = '',
    this.base = 0,
    this.rate = 0,
    this.amount = 0,
  });
  factory Penalty.fromJson(Object? j) {
    final m = _m(j);
    return Penalty(
      id: toInt(m['id']),
      uid: _s(m['uid']),
      name: _s(m['name']),
      month: _s(m['month']),
      status: _s(m['status']),
      waivedBy: _s(m['waivedBy']),
      note: _s(m['note']),
      base: toNum(m['base']),
      rate: toNum(m['rate']),
      amount: toNum(m['amount']),
    );
  }
  bool get waived => status == 'waived';
}

class PenaltyBook {
  final bool enabled, skipAdvance;
  final double rate, totalAll, active, waived;
  final String since, lastMonth, nextRun;
  final List<Penalty> items;
  const PenaltyBook({
    this.enabled = false,
    this.skipAdvance = true,
    this.rate = 2,
    this.totalAll = 0,
    this.active = 0,
    this.waived = 0,
    this.since = '',
    this.lastMonth = '',
    this.nextRun = '',
    this.items = const [],
  });
  factory PenaltyBook.fromJson(Object? j) {
    final m = _m(j);
    final st = _m(m['settings']);
    final t = _m(m['totals']);
    return PenaltyBook(
      enabled: st['enabled'] == true,
      skipAdvance: st['skipAdvance'] != false,
      rate: st['rate'] == null ? 2 : toNum(st['rate']),
      since: _s(st['since']),
      lastMonth: _s(m['lastMonth']),
      nextRun: _s(m['nextRun']),
      totalAll: toNum(m['totalAll']),
      active: toNum(t['active']),
      waived: toNum(t['waived']),
      items: _l(m['items']).map(Penalty.fromJson).toList(),
    );
  }
}

extension AdminRepoMore on AdminRepo {
  Future<Overview> overview() async => Overview.fromJson(await session.cachedGet('/admin/overview'));

  Future<MemberForm> memberForm(int id) async => MemberForm.fromJson(await session.api.get('/members/$id'));

  Future<void> saveMember(MemberForm f, {String password = ''}) async {
    final body = f.toJson();
    if (password.isNotEmpty) body['password'] = password;
    if (f.id > 0) {
      await session.api.put('/members/${f.id}', body);
    } else {
      await session.api.post('/members', body);
    }
  }

  Future<ProjectDetail> projectDetail(int id) async => ProjectDetail.fromJson(await session.api.get('/projects/$id/overview'));

  Future<AllocationPreview> allocationPreview(double buy, List<String> included) async =>
      AllocationPreview.fromJson(await session.api.post('/projects/allocation-preview', {'buy_amount': buy, 'included': included}));

  Future<String> createProject(Map<String, dynamic> project, List<String> included) async {
    final d = await session.api.post('/projects', {'project': project, 'included': included}) as Map;
    return _s(d['project_code']);
  }

  Future<List<SharePlanProject>> sharePlan(String fromUid) async {
    final d = await session.api.post('/share-transfer/plan', {'from_member_uid': fromUid}) as Map;
    return _l(d['projects']).map(SharePlanProject.fromJson).toList();
  }

  Future<void> executeTransfer(String fromUid, Map<int, Map<String, double>> allocations, String pin) =>
      session.api.post('/share-transfer/execute', {
        'from_member_uid': fromUid,
        'pin': pin,
        'projects': [
          for (final e in allocations.entries) {'project_id': e.key, 'allocations': e.value},
        ],
      });

  Future<List<TransferBatch>> transferHistory() async {
    final d = await session.api.get('/share-transfer/history') as Map;
    return _l(d['candidates']).map(TransferBatch.fromJson).toList();
  }

  Future<void> undoTransfer(TransferBatch b, String pin) =>
      session.api.post('/share-transfer/undo', {'from_member_uid': b.fromUid, 'transfer_time': b.time, 'pin': pin});

  Future<List<MoneyRow>> moneyRows({required bool income}) async {
    final d = await session.api.get(income ? '/other-income' : '/other-expense', query: {'per_page': '50'}) as Map;
    return _l(d['items']).map((r) => MoneyRow.fromJson(r, income: income)).toList();
  }

  Future<void> addMoney({
    required bool income,
    required String source,
    required String details,
    required String date,
    required double amount,
    required String method,
    String note = '',
  }) =>
      session.api.post(income ? '/other-income' : '/other-expense', {
        'source': source,
        'source_details': details,
        income ? 'income_date' : 'expense_date': date,
        'amount': amount,
        'method': method,
        'note': note,
      });

  Future<BrandingForm> branding() async => BrandingForm.fromJson(await session.api.get('/settings/branding'));

  Future<void> saveBranding(BrandingForm f) async {
    await session.api.post('/settings/branding', f.toJson());
    await session.refreshConfig();
  }

  Future<PenaltyBook> penalties({String month = ''}) async =>
      PenaltyBook.fromJson(await session.api.get('/penalties', query: month.isEmpty ? null : {'month': month}));

  Future<void> savePenaltySettings({required bool enabled, required double rate, required bool skipAdvance}) =>
      session.api.post('/settings/app', {'penalty_enabled': enabled, 'penalty_rate': rate, 'penalty_skip_advance': skipAdvance});

  Future<void> waivePenalty(int id, String note) => session.api.post('/penalties/$id/waive', {'note': note});
  Future<void> restorePenalty(int id) => session.api.post('/penalties/$id/restore');
}
