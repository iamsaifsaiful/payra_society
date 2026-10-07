import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the login token lives. The real app uses the Android keystore;
/// tests use [MemoryTokenStore].
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _key = 'payra.token';
  final FlutterSecureStorage _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read() async {
    try {
      return await _s.read(key: _key);
    } catch (_) {
      // A keystore reset (e.g. after restoring a backup) makes old values unreadable.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(String token) => _s.write(key: _key, value: token);

  @override
  Future<void> clear() async {
    try {
      await _s.delete(key: _key);
    } catch (_) {}
  }
}

class MemoryTokenStore implements TokenStore {
  String? value;
  MemoryTokenStore([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

/// Small wrapper over shared_preferences for settings and the offline cache.
class Prefs {
  Prefs(this._p);
  final SharedPreferences _p;

  static Future<Prefs> open() async => Prefs(await SharedPreferences.getInstance());

  String? getString(String k) => _p.getString(k);
  bool? getBool(String k) => _p.getBool(k);
  double? getDouble(String k) => _p.getDouble(k);
  Future<void> setString(String k, String v) => _p.setString(k, v);
  Future<void> setBool(String k, bool v) => _p.setBool(k, v);
  Future<void> setDouble(String k, double v) => _p.setDouble(k, v);
  Future<void> remove(String k) => _p.remove(k);

  Future<void> removePrefix(String prefix) async {
    for (final k in _p.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _p.remove(k);
    }
  }
}
