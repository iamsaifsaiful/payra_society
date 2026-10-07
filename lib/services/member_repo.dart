import '../api/models.dart';
import '../logic/format.dart';
import 'session.dart';

class MemberHome {
  final AppUser member;
  final MemberSummary summary;
  final Arrears arrears;
  final List<StatementRow> recent;
  final List<ProjectStake> projects;
  final int unread;
  const MemberHome({
    required this.member,
    required this.summary,
    required this.arrears,
    required this.recent,
    required this.projects,
    required this.unread,
  });
}

/// A member's position in one project, built from investor rows plus the
/// ledger (capital returned and profit per project).
class ProjectStake {
  final String projectCode, productType, customerName, status;
  final int projectId;
  final double invested, capitalReturned, profit, shareSold;
  final bool sold;

  const ProjectStake({
    required this.projectId,
    required this.projectCode,
    this.productType = '',
    this.customerName = '',
    this.status = '',
    this.invested = 0,
    this.capitalReturned = 0,
    this.profit = 0,
    this.shareSold = 0,
    this.sold = false,
  });

  double get remaining => (invested - capitalReturned - shareSold).clamp(0, double.infinity).toDouble();
  double get progress => invested <= 0 ? 0 : ((capitalReturned + shareSold) / invested).clamp(0, 1).toDouble();
  bool get active => !sold && remaining > 0.009 && status != 'completed' && status != 'closed';
}

/// Combines investor rows with ledger rows into one card per project.
List<ProjectStake> buildStakes(List<Investment> inv, List<StatementRow> ledger) {
  final byCode = <String, ProjectStake>{};
  for (final i in inv) {
    final prev = byCode[i.projectCode];
    byCode[i.projectCode] = ProjectStake(
      projectId: i.projectId,
      projectCode: i.projectCode,
      productType: i.productType,
      customerName: i.customerName,
      status: i.status,
      invested: (prev?.invested ?? 0) + i.invested,
      sold: (prev?.sold ?? true) && i.sold,
    );
  }
  final capital = <String, double>{}, profit = <String, double>{}, sale = <String, double>{};
  for (final r in ledger) {
    if (r.projectCode.isEmpty) continue;
    if (r.type == 'distribution') {
      capital[r.projectCode] = (capital[r.projectCode] ?? 0) + r.capital;
      profit[r.projectCode] = (profit[r.projectCode] ?? 0) + r.profit;
    } else if (r.type == 'share_sale') {
      sale[r.projectCode] = (sale[r.projectCode] ?? 0) + r.capital;
    }
  }
  final out = byCode.values
      .map((s) => ProjectStake(
            projectId: s.projectId,
            projectCode: s.projectCode,
            productType: s.productType,
            customerName: s.customerName,
            status: s.status,
            invested: s.invested,
            capitalReturned: capital[s.projectCode] ?? 0,
            profit: profit[s.projectCode] ?? 0,
            shareSold: sale[s.projectCode] ?? 0,
            sold: s.sold,
          ))
      .toList();
  out.sort((a, b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    return b.projectId.compareTo(a.projectId);
  });
  return out;
}

/// Totals for a list of ledger rows (used on the লেনদেন screen).
class LedgerTotals {
  double saved = 0, profit = 0, capitalBack = 0, withdrawn = 0, invested = 0, penalty = 0;
  double get net => saved + profit + capitalBack - withdrawn - invested - penalty;

  static LedgerTotals of(Iterable<StatementRow> rows) {
    final t = LedgerTotals();
    for (final r in rows) {
      switch (r.type) {
        case 'saving':
          t.saved += r.credit;
        case 'distribution':
          t.profit += r.profit;
          t.capitalBack += r.capital;
        case 'share_sale':
          t.capitalBack += r.credit;
        case 'withdrawal':
          t.withdrawn += r.debit;
        case 'investment':
          t.invested += r.debit;
        case 'penalty':
          t.penalty += r.debit;
      }
    }
    return t;
  }
}

class MemberRepo {
  MemberRepo(this.session);
  final Session session;

  Future<MemberSummary> summary() async {
    final d = await session.cachedGet('/member/dashboard') as Map;
    return MemberSummary.fromJson(d['summary']);
  }

  Future<List<StatementRow>> statement({String? from, String? to}) async {
    final q = <String, String>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    final d = await session.cachedGet('/member/statement', query: q.isEmpty ? null : q) as Map;
    final rows = (d['rows'] as List? ?? const []).map(StatementRow.fromJson).toList();
    return rows;
  }

  /// Full member row (address, join date …) comes with the statement.
  Future<MemberProfile> profile() async {
    final d = await session.cachedGet('/member/statement', query: {'from': '2999-01-01'}) as Map;
    return MemberProfile.fromJson(d['member']);
  }

  Future<List<Investment>> investments() async {
    final d = await session.cachedGet('/member/investments');
    return (d as List? ?? const []).map(Investment.fromJson).toList();
  }

  Future<Arrears> arrears() async {
    try {
      return Arrears.fromJson(await session.cachedGet('/member/arrears'));
    } catch (_) {
      return const Arrears();
    }
  }

  Future<(List<AppNotification>, int)> notifications() async {
    final d = await session.cachedGet('/member/notifications', query: {'per_page': '50'}) as Map;
    final items = (d['items'] as List? ?? const []).map(AppNotification.fromJson).toList();
    return (items, toInt(d['unread']));
  }

  Future<void> markAllRead() => session.api.post('/member/notifications/read', {'all': true});

  Future<List<Receipt>> receipts() async {
    final d = await session.cachedGet('/member/receipts', query: {'per_page': '50'}) as Map;
    return (d['items'] as List? ?? const []).map(Receipt.fromJson).toList();
  }

  Future<SocietyStats> society() async => SocietyStats.fromJson(await session.cachedGet('/society/dashboard'));

  Future<MemberHome> home() async {
    final results = await Future.wait([
      session.cachedGet('/member/dashboard'),
      statement(),
      investments(),
      arrears(),
      notifications().then((n) => n.$2).catchError((_) => 0),
    ]);
    final dash = results[0] as Map;
    final ledger = results[1] as List<StatementRow>;
    final recent = ledger.reversed.take(5).toList();
    return MemberHome(
      member: AppUser.fromJson(dash['member']),
      summary: MemberSummary.fromJson(dash['summary']),
      recent: recent,
      projects: buildStakes(results[2] as List<Investment>, ledger),
      arrears: results[3] as Arrears,
      unread: results[4] as int,
    );
  }

  Future<void> changePassword(String current, String next) =>
      session.api.post('/auth/change-password', {'currentPassword': current, 'newPassword': next});

  Future<void> updateProfile(Map<String, String> fields) => session.api.post('/member/profile', fields);

  Future<Map<String, bool>> preferences() async {
    final d = await session.api.get('/member/preferences') as Map;
    return {for (final k in ['email', 'sms', 'whatsapp']) k: d[k] == true};
  }

  Future<void> setPreference(String channel, bool on) => session.api.post('/member/preferences', {channel: on});
}
