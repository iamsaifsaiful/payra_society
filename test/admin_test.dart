import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payra_society/api/api_client.dart';
import 'package:payra_society/main.dart';
import 'package:payra_society/screens/admin/admin_shell.dart';
import 'package:payra_society/screens/admin/pickers.dart';
import 'package:payra_society/services/admin_more.dart';
import 'package:payra_society/services/admin_repo.dart';
import 'package:payra_society/services/session.dart';
import 'package:payra_society/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _res(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic>? lastSaving;

http.Response _route(http.Request r) {
  Map<String, dynamic> ok(Object data) => {'success': true, 'data': data};
  final p = r.url.path.replaceFirst('/wp-json/payra/v1', '');
  switch ('${r.method} $p') {
    case 'GET /app/config':
      return _res(ok({
        'apiVersion': '1.0.9.58',
        'branding': {'name': 'পায়রা সমিতি'},
        'savings': {'monthlyAmount': 5000, 'dueDay': 10},
        'app': {'minVersion': '1.0.0'},
      }));
    case 'POST /auth/login':
      return _res(ok({
        'accessToken': 'adm',
        'user': {'uid': 1, 'name': 'অ্যাডমিন', 'role': 'admin'},
      }));
  }
  if (r.headers['X-Payra-Token'] != 'adm') return _res({'success': false, 'error': {'code': 'UNAUTHORIZED', 'message': 'x'}}, 401);
  switch ('${r.method} $p') {
    case 'GET /auth/session':
      return _res(ok({'user': {'uid': 1, 'name': 'অ্যাডমিন', 'role': 'admin'}}));
    case 'GET /admin/overview':
      return _res(ok({
        'kpis': {
          'activeMembers': 4, 'activeProjects': 1, 'currentInvestment': 10000, 'installmentsDue': 12500,
          'currentBalance': 68000, 'availableProfits': 4200, 'administrationFunds': 950, 'memberWelfareFunds': 450,
        },
        'totals': {'members': 4, 'projects': 1, 'savings': 73000, 'installmentsPaid': 25000, 'otherIncome': 1000},
        'members': [
          {'id': 1, 'uid': 'PSM1001', 'name': 'রফিকুল ইসলাম', 'status': 'active', 'savings': 25000, 'investment': 3750, 'current': 21250, 'profits': 965.63, 'total': 22215.63},
        ],
        'projects': [
          {'id': 1, 'code': 'PEC1001', 'customer': 'মো. হাসান', 'buy': 30000, 'sell': 37500, 'paid': 25000, 'due': 12500, 'capitalReturned': 20000, 'investment': 10000, 'installments': 4},
        ],
        'funds': {
          'projects': [{'code': 'PEC1001', 'customer': 'মো. হাসান', 'total': 500, 'half': 250}],
          'income': [{'date': '2026-10-07', 'details': 'ফর্ম ফি', 'amount': 1000, 'admin': 800, 'welfare': 200}],
          'adminExpenses': [{'date': '2026-10-07', 'details': 'খাতা', 'amount': 100, 'method': 'cash'}],
          'welfareExpenses': [],
        },
      }));
    case 'GET /admin/dashboard':
      return _res(ok({'members': 4, 'activeMembers': 4, 'savings': 73000, 'projects': 1, 'installments': 25000, 'withdrawals': 300, 'societyFund': 500}));
    case 'GET /admin/defaulters':
      return _res(ok({
        'configured': true,
        'items': [
          {'id': 2, 'memberUid': 'PSM1002', 'name': 'নাসরিন আক্তার', 'mobile': '01819000002', 'monthsDue': 4, 'amountDue': 20000, 'irregular': true},
        ],
      }));
    case 'GET /members':
      return _res(ok({
        'items': [
          {'id': 1, 'member_uid': 'PSM1001', 'full_name': 'রফিকুল ইসলাম', 'mobile': '01712000001', 'status': 'active'},
          {'id': 9, 'member_uid': 'PSM1009', 'full_name': 'পুরনো সদস্য', 'mobile': '', 'status': 'resign'},
        ],
      }));
    case 'GET /withdrawals/member/PSM1001/balances':
      return _res(ok({'current': 16250, 'profits': 965.63, 'total': 17215.63}));
    case 'POST /savings':
      lastSaving = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      return _res(ok({
        'ok': true,
        'id': 11,
        'receipt': {
          'receiptNo': 'SV-2026-00011',
          'type': 'saving',
          'refId': 11,
          'memberUid': 'PSM1001',
          'amount': 5000,
          'publicUrl': 'https://payra.test/r',
          'details': {'before': {'total': 17215.63}, 'after': {'total': 22215.63}},
        },
        'whatsappLink': 'https://wa.me/8801712000001?text=x',
      }), 201);
  }
  return _res({'code': 'rest_no_route', 'message': 'No route'}, 404);
}

void main() {
  test('amount parsing accepts Bengali digits and commas', () {
    expect(parseAmount('৫,০০০'), 5000);
    expect(parseAmount('1,250.50'), 1250.5);
    expect(parseAmount(''), 0);
  });

  test('plugin errors are shown in Bengali', () {
    expect(bnError('Amount exceeds available current balance.'), contains('বর্তমান ব্যালেন্স'));
    expect(bnError('কিছু একটা'), 'কিছু একটা');
  });

  test('share buyers: lowest balance first, equal cut, capped by balance', () {
    final out = lowestFirst(10000, {'A': 2000, 'B': 6000, 'C': 9000});
    expect(out['A'], 2000);
    expect(out['B'], 4000);
    expect(out['C'], 4000);
    expect(out.values.reduce((a, b) => a + b), 10000);
    final short = lowestFirst(5000, {'A': 1000, 'B': 1500});
    expect(short.values.reduce((a, b) => a + b), 2500); // not enough balance
    final odd = lowestFirst(100.01, {'A': 500, 'B': 500, 'C': 500});
    expect(odd.values.reduce((a, b) => a + b), closeTo(100.01, 0.0001));
  });

  test('next installment suggestion never exceeds what is due', () {
    const p = Project(id: 1, code: 'PEC1001', sell: 37500, firstInstallment: 7500, perInstallment: 6250);
    expect(const ProjectPayments(p, 0, 0).suggested, 7500);
    expect(const ProjectPayments(p, 25000, 4).suggested, 6250);
    expect(const ProjectPayments(p, 35000, 5).suggested, 2500);
    expect(const ProjectPayments(p, 37500, 6).due, 0);
  });

  testWidgets('admin saves a saving and gets the receipt + WhatsApp button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    SharedPreferences.setMockInitialValues({'site': 'https://payra.test'});
    final s = Session(
      api: ApiClient(client: MockClient((r) async => _route(r))),
      prefs: await Prefs.open(),
      tokens: MemoryTokenStore(),
    );
    await tester.pumpWidget(PayraApp(session: s));
    await s.load();
    await tester.pumpAndSettle();
    await s.login('admin', 'x');
    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.textContaining('১ জনের সঞ্চয় বকেয়া'), findsOneWidget);
    // Same 8 KPIs as the web dashboard; a KPI opens its details.
    expect(find.text('প্রশাসন তহবিল'), findsOneWidget);
    expect(find.text('৳ ৯৫০'), findsOneWidget);
    await tester.tap(find.text('প্রশাসন তহবিল'));
    await tester.pumpAndSettle();
    expect(find.text('ফর্ম ফি'), findsOneWidget);
    expect(find.text('+৳ ৮০০'), findsOneWidget);
    expect(find.text('−৳ ১০০'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('এন্ট্রি'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('সদস্য বাছুন'));
    await tester.pumpAndSettle();
    expect(find.text('পুরনো সদস্য'), findsNothing); // resigned members are hidden
    await tester.tap(find.text('রফিকুল ইসলাম'));
    await tester.pumpAndSettle();
    expect(find.text('৳ ১৬,২৫০'), findsOneWidget);
    expect(find.widgetWithText(TextField, '5000'), findsOneWidget); // monthly amount pre-filled

    await tester.tap(find.text('সেভ করুন').last);
    await tester.pumpAndSettle();
    expect(find.text('সঞ্চয় জমা নিশ্চিত করুন'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'সেভ করুন').last);
    await tester.pumpAndSettle();

    expect(lastSaving?['member_uid'], 'PSM1001');
    expect(lastSaving?['amount'], 5000);
    expect(find.text('সঞ্চয় জমা হয়েছে'), findsOneWidget);
    expect(find.text('৳ ২২,২১৫.৬৩'), findsOneWidget);
    expect(find.text('WhatsApp-এ রসিদ পাঠান'), findsOneWidget);

    // Back from the success screen, then the tab's back arrow returns to the dashboard.
    await tester.tap(find.text('ঠিক আছে'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('পেছনে'));
    await tester.pumpAndSettle();
    expect(find.text('প্রশাসন তহবিল'), findsOneWidget);
  });
}
