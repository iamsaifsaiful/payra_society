import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  const ApiException(this.code, this.message, {this.status = 0});

  bool get isAuth => status == 401;
  bool get isNetwork => code == 'NETWORK';

  @override
  String toString() => message;
}

/// Talks to the plugin's `payra/v1` REST namespace.
///
/// Works with pretty permalinks (`/wp-json/payra/v1/...`) and without them
/// (`/?rest_route=/payra/v1/...`). The token is sent both as
/// `Authorization: Bearer` and `X-Payra-Token`, because many shared hosts
/// strip the Authorization header before PHP sees it.
class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 25)}) : _http = client ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  String site = '';
  bool queryStyle = false;
  String? token;

  /// Called when the server says the session is no longer valid.
  void Function(ApiException e)? onUnauthorized;

  static const ns = '/payra/v1';

  /// "example.com" → "https://example.com" (no trailing slash).
  static String normalizeSite(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    for (final tail in ['/wp-json', '/wp-admin', '/wp-login.php']) {
      final i = s.indexOf(tail);
      if (i > 0) s = s.substring(0, i);
    }
    return s;
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final q = <String, String>{...?query};
    if (queryStyle) {
      final base = Uri.parse('$site/');
      return base.replace(queryParameters: {'rest_route': '$ns$path', ...q});
    }
    final u = Uri.parse('$site/wp-json$ns$path');
    return q.isEmpty ? u : u.replace(queryParameters: q);
  }

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        if (token != null && token!.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'X-Payra-Token': token!,
        },
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(
      () => _http.post(uri(path), headers: _headers(json: true), body: jsonEncode(body ?? const {})));

  /// PUT sent as POST + X-HTTP-Method-Override, because some shared hosts block PUT.
  Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _send(() => _http.post(
        uri(path),
        headers: {..._headers(json: true), 'X-HTTP-Method-Override': 'PUT'},
        body: jsonEncode(body ?? const {}),
      ));

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    if (site.isEmpty) throw const ApiException('NO_SITE', 'সমিতির ওয়েবসাইট ঠিক করা নেই।');
    http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('NETWORK', 'সার্ভার সাড়া দিচ্ছে না। একটু পরে আবার চেষ্টা করুন।');
    } on SocketException {
      throw const ApiException('NETWORK', 'ইন্টারনেট সংযোগ পাওয়া যায়নি।');
    } on HandshakeException {
      throw const ApiException('NETWORK', 'নিরাপদ সংযোগ (SSL) তৈরি করা যায়নি।');
    } on http.ClientException {
      throw const ApiException('NETWORK', 'ইন্টারনেট সংযোগ পাওয়া যায়নি।');
    }
    return decode(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  /// Unwraps `{success, data}` / `{success:false, error:{code,message}}`.
  dynamic decode(int status, String body) {
    dynamic j;
    try {
      j = jsonDecode(body);
    } catch (_) {
      throw ApiException('BAD_RESPONSE', 'সার্ভারের উত্তর বোঝা যায়নি (কোড $status)। প্লাগিন চালু আছে কি না দেখুন।', status: status);
    }
    if (j is Map && j['success'] == true) return j['data'];
    String code = 'ERROR';
    String message = 'কিছু একটা সমস্যা হয়েছে (কোড $status)।';
    if (j is Map && j['error'] is Map) {
      code = (j['error']['code'] ?? code).toString();
      message = (j['error']['message'] ?? message).toString();
    } else if (j is Map && j['code'] != null) {
      code = j['code'].toString();
      if (code == 'rest_no_route') {
        message = 'এই ওয়েবসাইটে পায়রা প্লাগিনের নতুন ভার্সন (১.০.৯.৫৮+) পাওয়া যায়নি।';
      } else if (j['message'] != null) {
        message = j['message'].toString();
      }
    }
    final e = ApiException(code, message, status: status);
    if (status == 401 && token != null) onUnauthorized?.call(e);
    throw e;
  }

  /// Finds the API on [input] and returns its public config.
  Future<AppConfig> discover(String input) async {
    final s = normalizeSite(input);
    if (s.isEmpty) throw const ApiException('NO_SITE', 'ওয়েবসাইটের ঠিকানা লিখুন।');
    site = s;
    ApiException? last;
    for (final qs in [false, true]) {
      queryStyle = qs;
      try {
        final data = await get('/app/config');
        return AppConfig.fromJson(data);
      } on ApiException catch (e) {
        last = e;
        if (e.isNetwork) rethrow;
      }
    }
    throw last ?? const ApiException('NOT_FOUND', 'এই ওয়েবসাইটে সমিতির API পাওয়া যায়নি।');
  }
}
