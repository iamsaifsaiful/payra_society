import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'storage.dart';

/// App version shown to the server's min/latest version check.
const appVersion = '1.1.0';

/// A site baked in at build time: `flutter build apk --dart-define=PAYRA_SITE=https://...`
const presetSite = String.fromEnvironment('PAYRA_SITE');

enum SessionStage { loading, needSite, needLogin, ready }

/// Holds the site, config, token and signed-in user, and the offline cache.
class Session extends ChangeNotifier {
  Session({required this.api, required this.prefs, required this.tokens}) {
    api.onUnauthorized = (_) => _expire();
  }

  final ApiClient api;
  final Prefs prefs;
  final TokenStore tokens;

  SessionStage stage = SessionStage.loading;
  AppConfig? config;
  AppUser? user;

  /// True when the last screen load fell back to cached data.
  bool offline = false;

  /// Message shown once on the login screen (e.g. "session expired").
  String? notice;

  /// Font scale chosen in Profile → বড় লেখা.
  double textScale = 1.0;

  Branding get branding => config?.branding ?? const Branding(name: 'পায়রা সমিতি');

  bool get needsUpdate => _cmp(appVersion, config?.minAppVersion ?? '1.0.0') < 0;
  bool get updateAvailable => _cmp(appVersion, config?.latestAppVersion ?? '1.0.0') < 0;

  static int _cmp(String a, String b) {
    List<int> p(String v) => v.split('.').map((x) => int.tryParse(x.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 4; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  Future<void> load() async {
    textScale = prefs.getDouble('ui.textScale') ?? 1.0;
    final site = prefs.getString('site') ?? '';
    final cfg = prefs.getString('config');
    if (site.isEmpty && presetSite.isEmpty) {
      _go(SessionStage.needSite);
      return;
    }
    api.site = site.isEmpty ? ApiClient.normalizeSite(presetSite) : site;
    api.queryStyle = prefs.getBool('queryStyle') ?? false;
    if (cfg != null) config = AppConfig.fromJson(jsonDecode(cfg));
    final tok = await tokens.read();
    final u = prefs.getString('user');
    if (tok != null && tok.isNotEmpty && u != null) {
      api.token = tok;
      user = AppUser.fromJson(jsonDecode(u));
      _go(SessionStage.ready);
    } else {
      _go(SessionStage.needLogin);
    }
    // Refresh branding, settings and the session in the background.
    refreshConfig();
    if (stage == SessionStage.ready) _checkSession();
  }

  Future<void> refreshConfig() async {
    if (api.site.isEmpty) return;
    try {
      final data = await api.get('/app/config');
      config = AppConfig.fromJson(data);
      await prefs.setString('config', jsonEncode(data));
      notifyListeners();
    } catch (_) {
      // Offline: keep the cached config.
    }
  }

  Future<void> _checkSession() async {
    try {
      final data = await api.get('/auth/session');
      final u = AppUser.fromJson((data as Map)['user']);
      if (u.name.isNotEmpty) {
        user = u;
        await prefs.setString('user', jsonEncode(u.toJson()));
        notifyListeners();
      }
    } catch (_) {
      // 401 is handled by onUnauthorized; network errors keep the cached user.
    }
  }

  /// Setup screen: find the API on the site and remember it.
  Future<void> connect(String site) async {
    final cfg = await api.discover(site);
    config = cfg;
    await prefs.setString('site', api.site);
    await prefs.setBool('queryStyle', api.queryStyle);
    try {
      await prefs.setString('config', jsonEncode(await api.get('/app/config')));
    } catch (_) {}
    _go(SessionStage.needLogin);
  }

  Future<void> changeSite() async {
    await _clearUser();
    await prefs.remove('site');
    await prefs.remove('config');
    config = null;
    api.site = '';
    _go(presetSite.isEmpty ? SessionStage.needSite : SessionStage.needLogin);
    if (presetSite.isNotEmpty) await load();
  }

  Future<void> login(String identifier, String password) async {
    final data = await api.post('/auth/login', {
      'identifier': identifier.trim(),
      'password': password,
      'device': 'Payra App $appVersion (Android)',
    });
    final m = data as Map;
    final tok = (m['accessToken'] ?? '').toString();
    if (tok.isEmpty) throw const ApiException('BAD_RESPONSE', 'লগইন টোকেন পাওয়া যায়নি।');
    api.token = tok;
    user = AppUser.fromJson(m['user']);
    await tokens.write(tok);
    await prefs.setString('user', jsonEncode(user!.toJson()));
    notice = null;
    offline = false;
    _go(SessionStage.ready);
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _clearUser();
    _go(SessionStage.needLogin);
  }

  void _expire() {
    if (stage != SessionStage.ready) return;
    notice = 'সেশন শেষ হয়েছে বা হিসাবটি বন্ধ করা হয়েছে। আবার লগইন করুন।';
    _clearUser();
    _go(SessionStage.needLogin);
  }

  Future<void> _clearUser() async {
    api.token = null;
    user = null;
    await tokens.clear();
    await prefs.remove('user');
    await prefs.removePrefix('cache.');
  }

  Future<void> setTextScale(double v) async {
    textScale = v;
    await prefs.setDouble('ui.textScale', v);
    notifyListeners();
  }

  void _go(SessionStage s) {
    stage = s;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Offline-friendly GET: returns fresh data, or the last copy when offline.

  Future<dynamic> cachedGet(String path, {Map<String, String>? query}) async {
    final key = 'cache.${user?.uid ?? ''}.$path?${query == null ? '' : Uri(queryParameters: query).query}';
    try {
      final data = await api.get(path, query: query);
      await prefs.setString(key, jsonEncode(data));
      if (offline) {
        offline = false;
        notifyListeners();
      }
      return data;
    } on ApiException catch (e) {
      final cached = prefs.getString(key);
      if (e.isNetwork && cached != null) {
        if (!offline) {
          offline = true;
          notifyListeners();
        }
        return jsonDecode(cached);
      }
      rethrow;
    }
  }
}
