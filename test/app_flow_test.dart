import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payra_society/api/api_client.dart';
import 'package:payra_society/main.dart';
import 'package:payra_society/screens/login_screen.dart';
import 'package:payra_society/screens/member/member_shell.dart';
import 'package:payra_society/services/session.dart';
import 'package:payra_society/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake plugin API with one member (shapes copied from v1.0.9.58).
http.Response _res(String body, int status) =>
    http.Response.bytes(utf8.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _route(http.Request r) {
  String ok(Object data) => jsonEncode({'success': true, 'data': data});
  final p = r.url.path.replaceFirst('/wp-json/payra/v1', '');
  final authed = r.headers['X-Payra-Token'] == 'tok123' && r.headers['Authorization'] == 'Bearer tok123';
  const user = {'uid': 1, 'name': 'রফিকুল ইসলাম', 'role': 'member', 'photoUrl': '', 'memberId': 'PSM1001', 'email': '', 'mobile': '01712000001'};
  switch (p) {
    case '/app/config':
      return _res(ok({
        'apiVersion': '1.0.9.58',
        'branding': {'name': 'পায়রা এন্টারপ্রাইজ সমিতি', 'logoUrl': ''},
        'savings': {'monthlyAmount': 5000, 'dueDay': 10, 'reminderDays': [5, 10], 'irregularAfterMonths': 3},
        'app': {'minVersion': '1.0.0', 'latestVersion': '1.0.0', 'apkUrl': ''},
        'treasurerPhone': '01700000000',
      }), 200);
    case '/auth/login':
      final b = jsonDecode(r.body) as Map;
      if (b['identifier'] == 'PSM1001' && b['password'] == 'pass1234') {
        return _res(ok({'accessToken': 'tok123', 'user': user}), 200);
      }
      return _res(jsonEncode({'success': false, 'error': {'code': 'INVALID_CREDENTIALS', 'message': 'আইডি অথবা পাসওয়ার্ড সঠিক নয়।'}}), 401);
  }
  if (!authed) {
    return _res(jsonEncode({'success': false, 'error': {'code': 'UNAUTHORIZED', 'message': 'লগইন করুন'}}), 401);
  }
  switch (p) {
    case '/auth/session':
      return _res(ok({'user': user}), 200);
    case '/member/dashboard':
      return _res(ok({
        'member': user,
        'summary': {'savings': 20000, 'investment': 3750, 'balances': {'current': 16250, 'profits': 965.63, 'total': 17215.63}},
      }), 200);
    case '/member/statement':
      return _res(ok({
        'member': {'member_uid': 'PSM1001', 'full_name': 'রফিকুল ইসলাম'},
        'rows': [
          {'tx_date': '2025-01-05', 'type': 'saving', 'credit': 10000, 'debit': 0, 'balance': 10000, 'method': 'bkash'},
          {'tx_date': '2025-03-01', 'type': 'investment', 'project_code': 'PEC1001', 'credit': 0, 'debit': 7500, 'balance': 2500},
          {'tx_date': '2025-04-10', 'type': 'distribution', 'project_code': 'PEC1001', 'capital': 1250, 'profit': 281.25, 'credit': 1531.25, 'debit': 0, 'balance': 4031.25},
        ],
      }), 200);
    case '/member/investments':
      return _res(ok([
        {'project_id': '1', 'project_code': 'PEC1001', 'invested_amount': '7500.00', 'included': '1', 'product_type': 'ফ্রিজ', 'status': 'active'},
      ]), 200);
    case '/member/arrears':
      return _res(ok({'configured': true, 'monthlyAmount': 5000, 'monthsDue': 2, 'amountDue': 10000, 'irregular': false, 'months': []}), 200);
    case '/member/notifications':
      return _res(ok({'items': [], 'unread': 3}), 200);
    case '/member/receipts':
      return _res(ok({'items': [], 'page': 1}), 200);
  }
  return _res(jsonEncode({'code': 'rest_no_route', 'message': 'No route'}), 404);
}

Future<Session> _session(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final api = ApiClient(client: MockClient((r) async => _route(r)));
  return Session(api: api, prefs: await Prefs.open(), tokens: MemoryTokenStore());
}

void main() {
  testWidgets('first run opens login for payrasociety.com → member home shows balances', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    final s = await _session({'site': 'https://old-typed-site.test'});
    await tester.pumpWidget(PayraApp(session: s));
    await s.load();
    await tester.pumpAndSettle();
    // No website screen: the society's site is built in and replaces anything typed before.
    expect(s.stage, SessionStage.needLogin);
    expect(s.api.site, 'https://payrasociety.com');
    expect(find.text('অন্য ওয়েবসাইট'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('পায়রা এন্টারপ্রাইজ সমিতি'), findsOneWidget);

    // Wrong password shows the server's message.
    await tester.enterText(find.byType(TextField).at(0), 'PSM1001');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('লগইন করুন'));
    await tester.pumpAndSettle();
    expect(find.text('আইডি অথবা পাসওয়ার্ড সঠিক নয়।'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'pass1234');
    await tester.tap(find.text('লগইন করুন'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberShell), findsOneWidget);
    expect(find.text('রফিকুল ইসলাম'), findsWidgets);
    expect(find.text('৳ ১৬,২৫০'), findsOneWidget); // বর্তমান ব্যালেন্স
    expect(find.text('৳ ৯৬৫.৬৩'), findsOneWidget); // উত্তোলনযোগ্য লাভ
    expect(find.text('২ মাসের সঞ্চয় বকেয়া'), findsOneWidget);
    expect(find.textContaining('PEC1001'), findsWidgets);

    // লেনদেন tab.
    await tester.tap(find.text('লেনদেন').last);
    await tester.pumpAndSettle();
    expect(find.text('শেষ ব্যালেন্স'), findsOneWidget);
    expect(find.text('৳ ৪,০৩১.২৫'), findsWidgets);
  });

  testWidgets('expired session goes back to login with a notice', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    final s = await _session({
      'site': 'https://payra.test',
      'user': jsonEncode({'uid': '1', 'name': 'রফিকুল ইসলাম', 'role': 'member', 'memberId': 'PSM1001'}),
    });
    (s.tokens as MemoryTokenStore).value = 'revoked-token';
    await tester.pumpWidget(PayraApp(session: s));
    await s.load();
    await tester.pumpAndSettle();
    expect(s.stage, SessionStage.needLogin);
    expect(find.textContaining('সেশন শেষ হয়েছে'), findsOneWidget);
    expect(await s.tokens.read(), isNull);
  });
}
