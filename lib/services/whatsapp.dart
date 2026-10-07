import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'storage.dart';

/// A ready WhatsApp text from the server (bank-style account message, receipt, reminder).
class WaMessage {
  final String to, name, kind, label, text;
  const WaMessage({this.to = '', this.name = '', this.kind = 'member', this.label = '', this.text = ''});

  factory WaMessage.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    String s(Object? v) => v?.toString() ?? '';
    return WaMessage(to: s(m['to']), name: s(m['name']), kind: s(m['kind']), label: s(m['label']), text: s(m['text']));
  }

  static List<WaMessage> listOf(Object? v) =>
      (v is List ? v : const []).map(WaMessage.fromJson).where((w) => w.text.isNotEmpty).toList();
}

/// "01712-345678" → "8801712345678".
String waDigits(String mobile) {
  var d = mobile.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0') && d.length == 11) d = '88$d';
  return d;
}

/// Which WhatsApp app the admin sends from. Personal WhatsApp by default.
enum WaApp { personal, business }

extension WaAppX on WaApp {
  String get package => this == WaApp.business ? 'com.whatsapp.w4b' : 'com.whatsapp';
  String get label => this == WaApp.business ? 'WhatsApp Business' : 'WhatsApp (সাধারণ)';
}

class WhatsApp {
  static const _channel = MethodChannel('payra/whatsapp');
  static const _prefKey = 'wa.app';

  static WaApp app(Prefs prefs) => prefs.getString(_prefKey) == 'business' ? WaApp.business : WaApp.personal;

  static Future<void> setApp(Prefs prefs, WaApp a) => prefs.setString(_prefKey, a == WaApp.business ? 'business' : 'personal');

  /// WhatsApp apps installed on this phone (empty on platforms without the channel).
  static Future<List<WaApp>> installed() async {
    try {
      final list = await _channel.invokeListMethod<String>('installed') ?? const [];
      return [
        if (list.contains('com.whatsapp')) WaApp.personal,
        if (list.contains('com.whatsapp.w4b')) WaApp.business,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Opens the chosen WhatsApp with the text typed in. Falls back to the other
  /// WhatsApp, then to a wa.me link, when the chosen one isn't installed.
  static Future<bool> send(Prefs prefs, {required String phone, required String text}) async {
    final to = waDigits(phone);
    final first = app(prefs);
    for (final a in [first, first == WaApp.personal ? WaApp.business : WaApp.personal]) {
      try {
        final ok = await _channel.invokeMethod<bool>('send', {'package': a.package, 'phone': to, 'text': text});
        if (ok == true) return true;
      } on MissingPluginException {
        break;
      } catch (_) {
        // try the next option
      }
    }
    final uri = to.isEmpty
        ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')
        : Uri.parse('https://wa.me/$to?text=${Uri.encodeComponent(text)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
