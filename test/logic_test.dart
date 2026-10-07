import 'package:flutter_test/flutter_test.dart';
import 'package:payra_society/api/api_client.dart';
import 'package:payra_society/api/models.dart';
import 'package:payra_society/logic/format.dart';
import 'package:payra_society/services/member_repo.dart';
import 'package:payra_society/widgets/statement_export.dart';

void main() {
  group('format', () {
    test('Bengali digits and lakh grouping', () {
      expect(bn('2026-10-07'), '২০২৬-১০-০৭');
      expect(groupLakh(120000), '1,20,000');
      expect(groupLakh(1234567), '12,34,567');
      expect(groupLakh(999), '999');
      expect(taka(120000), '৳ ১,২০,০০০');
      expect(taka(17215.63), '৳ ১৭,২১৫.৬৩');
      expect(taka(5000, sign: true), '+৳ ৫,০০০');
      expect(taka(-300), '−৳ ৩০০');
      expect(taka('1,250.5'), '৳ ১,২৫০.৫০');
      expect(taka(84320, paisa: true), '৳ ৮৪,৩২০.০০');
    });

    test('dates', () {
      expect(dateBn('2026-10-05'), '০৫ অক্টো ২০২৬');
      expect(dateBn('2026-10-06 20:17:51'), '০৬ অক্টো ২০২৬');
      expect(dateBn('0000-00-00'), '');
      expect(monthBn('2026-03'), 'মার্চ ২০২৬');
    });

    test('initials and methods', () {
      expect(initials('রফিকুল ইসলাম'), 'রই');
      expect(initials(''), '?');
      expect(methodBn('nagad'), 'নগদ');
      expect(methodBn('cash'), 'ক্যাশ');
    });
  });

  group('api', () {
    test('site normalisation', () {
      expect(ApiClient.normalizeSite('payra.com/'), 'https://payra.com');
      expect(ApiClient.normalizeSite('http://payra.com/wp-admin/'), 'http://payra.com');
      expect(ApiClient.normalizeSite(' https://x.org/wp-json/payra/v1 '), 'https://x.org');
    });

    test('uri styles', () {
      final a = ApiClient()..site = 'https://x.org';
      expect(a.uri('/member/statement', {'from': '2026-01-01'}).toString(),
          'https://x.org/wp-json/payra/v1/member/statement?from=2026-01-01');
      a.queryStyle = true;
      final u = a.uri('/app/config');
      expect(u.queryParameters['rest_route'], '/payra/v1/app/config');
    });

    test('decode unwraps data and errors', () {
      final a = ApiClient();
      expect(a.decode(200, '{"success":true,"data":{"x":1}}'), {'x': 1});
      expect(
        () => a.decode(401, '{"success":false,"error":{"code":"INVALID_CREDENTIALS","message":"ভুল"}}'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS').having((e) => e.isAuth, 'auth', true)),
      );
      expect(
        () => a.decode(404, '{"code":"rest_no_route","message":"No route"}'),
        throwsA(isA<ApiException>().having((e) => e.message, 'msg', contains('১.০.৯.৫৮'))),
      );
      expect(() => a.decode(500, '<html>'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'BAD_RESPONSE')));
    });
  });

  group('ledger', () {
    // Real rows from the plugin test site (member PSM1001, after a share purchase).
    final rows = [
      {'tx_date': '2025-01-05', 'type': 'saving', 'credit': 10000, 'debit': 0, 'balance': 10000, 'method': 'bkash'},
      {'tx_date': '2025-02-05', 'type': 'saving', 'credit': 10000, 'debit': 0, 'balance': 20000, 'method': 'bkash'},
      {'tx_date': '2025-03-01', 'type': 'investment', 'ref': 1, 'project_code': 'PEC1001', 'credit': 0, 'debit': 7500, 'balance': 12500},
      {'tx_date': '2025-04-10', 'type': 'distribution', 'ref': 1, 'project_code': 'PEC1001', 'capital': 1250, 'profit': 281.25, 'credit': 1531.25, 'debit': 0, 'balance': 14031.25},
      {'tx_date': '2025-05-10', 'type': 'distribution', 'ref': 2, 'project_code': 'PEC1001', 'capital': 1250, 'profit': 281.25, 'credit': 1531.25, 'debit': 0, 'balance': 15562.5},
      {'tx_date': '2025-06-10', 'type': 'distribution', 'ref': 3, 'project_code': 'PEC1001', 'capital': 1250, 'profit': 281.25, 'credit': 1531.25, 'debit': 0, 'balance': 17093.75},
      {'tx_date': '2025-06-15', 'type': 'withdrawal', 'withdraw_type': 'profits', 'credit': 0, 'debit': 300, 'balance': 16793.75},
      {'tx_date': '2026-10-06', 'type': 'investment', 'ref': 1, 'project_code': 'PEC1001', 'credit': 0, 'debit': 1875, 'balance': 14918.75},
      {'tx_date': '2026-10-06', 'type': 'distribution', 'ref': 4, 'project_code': 'PEC1001', 'capital': 1875, 'profit': 421.88, 'credit': 2296.88, 'debit': 0, 'balance': 17215.63},
    ].map(StatementRow.fromJson).toList();

    test('totals match the final balance', () {
      final t = LedgerTotals.of(rows);
      expect(t.saved, 20000);
      expect(t.withdrawn, 300);
      expect(t.invested, 9375);
      expect(t.net, closeTo(rows.last.balance, 0.001));
    });

    test('titles', () {
      expect(rows[0].title, 'মাসিক সঞ্চয় · জানুয়ারি');
      expect(rows[6].title, 'লাভ উত্তোলন');
      expect(rows[3].subtitle, contains('লাভ ৳ ২৮১.২৫'));
    });

    test('stakes merge investor rows and the ledger', () {
      final inv = [
        {'project_id': '1', 'project_code': 'PEC1001', 'invested_amount': '7500.00', 'included': '1', 'product_type': 'ফ্রিজ', 'status': 'active'},
        {'project_id': '1', 'project_code': 'PEC1001', 'invested_amount': '1875.00', 'included': '1', 'status': 'active'},
      ].map(Investment.fromJson).toList();
      final s = buildStakes(inv, rows).single;
      expect(s.invested, 9375);
      expect(s.capitalReturned, 5625);
      expect(s.remaining, 3750); // equals the server's active investment
      expect(s.active, isTrue);
    });

    test('a sold share is no longer active', () {
      final inv = [
        {'project_id': '1', 'project_code': 'PEC1001', 'invested_amount': '7500.00', 'included': '0', 'ended_at': '2026-10-06 20:17:55'},
      ].map(Investment.fromJson).toList();
      final ledger = [
        {'type': 'distribution', 'project_code': 'PEC1001', 'capital': 3750, 'profit': 843.75},
        {'type': 'share_sale', 'project_code': 'PEC1001', 'capital': 3750, 'credit': 3750},
      ].map(StatementRow.fromJson).toList();
      final s = buildStakes(inv, ledger).single;
      expect(s.sold, isTrue);
      expect(s.remaining, 0);
      expect(s.active, isFalse);
    });
  });

  test('arrears streak counts paid months from the newest', () {
    final a = Arrears.fromJson({
      'configured': true,
      'monthsDue': 0,
      'months': [
        {'month': '2026-05', 'due': true, 'paid': false},
        {'month': '2026-06', 'due': true, 'paid': true},
        {'month': '2026-07', 'due': true, 'paid': true},
        {'month': '2026-08', 'due': true, 'paid': true},
        {'month': '2026-09', 'due': true, 'paid': true},
        {'month': '2026-10', 'due': false, 'paid': false},
      ],
    });
    expect(a.regularStreak, 4);
  });

  group('statement requests', () {
    test('member, admin and society statements hit the right pages', () {
      final mine = StatementRequest.mine('PSM1001', '2026-01-01', '2026-06-30');
      expect(mine.path, '/member/statement.html');
      expect(mine.query, {'from': '2026-01-01', 'to': '2026-06-30'});
      expect(mine.fileName, 'statement-PSM1001-2026-01-01-2026-06-30.pdf');
      final all = StatementRequest.mine('PSM1001', '', '');
      expect(all.query, isEmpty);
      final adm = StatementRequest.member(7, 'PSM1007', '', '');
      expect(adm.path, '/members/7/statement.html');
      expect(adm.linkBody['id'], 7);
      final y = StatementRequest.society(yearly: true, key: '2025');
      expect(y.query, {'type': 'year', 'year': '2025'});
      expect(y.linkBody, {'kind': 'society', 'type': 'year', 'key': '2025'});
      final m = StatementRequest.society(yearly: false, key: '2026-10');
      expect(m.query, {'type': 'month', 'month': '2026-10'});
      expect(m.fileName, 'society-month-2026-10.pdf');
    });
  });
}
