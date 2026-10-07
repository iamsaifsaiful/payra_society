import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/format.dart';
import '../services/storage.dart';
import '../services/whatsapp.dart';
import '../theme.dart';
import 'common.dart';

const waGreen = Color(0xFF1FA855);

/// Ready WhatsApp messages with one-tap send (from the admin's chosen WhatsApp) and a full preview.
class WaList extends StatefulWidget {
  const WaList({super.key, required this.prefs, required this.messages, this.title = 'WhatsApp-এ পাঠান'});
  final Prefs prefs;
  final List<WaMessage> messages;
  final String title;

  @override
  State<WaList> createState() => _WaListState();
}

class _WaListState extends State<WaList> {
  final _sent = <int>{};

  Future<void> _send(int i) async {
    final m = widget.messages[i];
    final ok = await WhatsApp.send(widget.prefs, phone: m.to, text: m.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _sent.add(i));
    } else {
      toast(context, 'WhatsApp খোলা যায়নি');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.chat_rounded, color: waGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title, style: head(15, weight: FontWeight.w600))),
              Text(WhatsApp.app(widget.prefs).label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        for (var i = 0; i < widget.messages.length; i++) ...[
          WaCard(message: widget.messages[i], sent: _sent.contains(i), onSend: () => _send(i)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class WaCard extends StatelessWidget {
  const WaCard({super.key, required this.message, required this.onSend, this.sent = false});
  final WaMessage message;
  final VoidCallback onSend;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name.isEmpty ? m.label : m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      [m.label, if (m.to.isNotEmpty) bn(m.to.startsWith('88') ? m.to.substring(2) : m.to) else 'মোবাইল নম্বর নেই'].where((x) => x.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (sent) const Icon(Icons.done_all_rounded, color: waGreen, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(m.text.replaceAll('*', ''), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
          Row(
            children: [
              TextButton(onPressed: () => showWaPreview(context, m, onSend), child: const Text('পুরো বার্তা')),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: waGreen, minimumSize: const Size(110, 42)),
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(sent ? 'আবার পাঠান' : 'পাঠান'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showWaPreview(BuildContext context, WaMessage m, VoidCallback onSend) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(m.name.isEmpty ? m.label : '${m.label} · ${m.name}', style: head(16, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFE7F8EC), borderRadius: BorderRadius.circular(14)),
              child: SelectableText(m.text, style: const TextStyle(height: 1.55, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: m.text));
                      toast(c, 'কপি হয়েছে');
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('কপি'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: waGreen),
                    onPressed: () {
                      Navigator.pop(c);
                      onSend();
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('পাঠান'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet with a list of messages (after an edit, a waiver, a share transfer …).
Future<void> showWaSheet(BuildContext context, Prefs prefs, List<WaMessage> messages, {String title = 'WhatsApp-এ জানান'}) {
  if (messages.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [WaList(prefs: prefs, messages: messages, title: title)],
        ),
      ),
    ),
  );
}

/// Send one message right away (e.g. a reminder button in a list).
Future<void> sendWa(BuildContext context, Prefs prefs, WaMessage m) async {
  final ok = await WhatsApp.send(prefs, phone: m.to, text: m.text);
  if (!ok && context.mounted) toast(context, 'WhatsApp খোলা যায়নি');
}
