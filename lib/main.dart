import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/login_screen.dart';
import 'screens/member/member_shell.dart';
import 'screens/setup_screen.dart';
import 'services/session.dart';
import 'services/storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  final session = Session(api: ApiClient(), prefs: await Prefs.open(), tokens: SecureTokenStore());
  runApp(PayraApp(session: session));
  await session.load();
}

/// Gives every screen access to the session.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);

  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Read without rebuilding on changes.
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

class PayraApp extends StatelessWidget {
  const PayraApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => MaterialApp(
          // A new navigator per stage, so screens opened before a logout or
          // an expired session never stay on top of the login screen.
          key: ValueKey(session.stage),
          title: session.branding.name,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(session.textScale)),
            child: child!,
          ),
          home: _home(),
        ),
      ),
    );
  }

  Widget _home() => switch (session.stage) {
        SessionStage.loading => const _Splash(),
        SessionStage.needSite => const SetupScreen(),
        SessionStage.needLogin => const LoginScreen(),
        SessionStage.ready => session.needsUpdate
            ? const UpdateRequiredScreen()
            : session.user!.isAdmin
                ? AdminShell(key: ValueKey('admin-${session.user!.uid}'))
                : MemberShell(key: ValueKey('member-${session.user!.uid}')),
      };
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.brand,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
}
