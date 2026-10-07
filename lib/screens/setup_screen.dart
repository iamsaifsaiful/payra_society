import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../main.dart';
import '../theme.dart';

/// First run: ask for the society's website and check the API is there.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _site = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _site.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).connect(_site.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.account_balance_rounded, color: AppColors.brand, size: 34),
            ),
            const SizedBox(height: 20),
            Text('সমিতির অ্যাপ চালু করুন', style: head(28, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'আপনার সমিতির ওয়েবসাইটের ঠিকানা দিন। অ্যাডমিন এই ঠিকানা জানিয়ে দেবেন — একবার দিলেই হবে।',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _site,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _connect(),
                    decoration: const InputDecoration(
                      labelText: 'ওয়েবসাইট',
                      hintText: 'payrasomiti.com',
                      prefixIcon: Icon(Icons.language_rounded),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('সংযোগ করুন'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the server requires a newer app (config `app.minVersion`).
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final url = s.config?.apkUrl ?? '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.system_update_rounded, size: 56, color: AppColors.brand),
              const SizedBox(height: 18),
              Text('অ্যাপটি হালনাগাদ করুন', textAlign: TextAlign.center, style: head(24)),
              const SizedBox(height: 10),
              const Text(
                'সমিতির হিসাব ঠিক রাখতে নতুন ভার্সন লাগবে। নিচের বোতাম চেপে নতুন অ্যাপ নামিয়ে ইনস্টল করুন।',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.55),
              ),
              const SizedBox(height: 24),
              if (url.isNotEmpty)
                FilledButton(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  child: const Text('নতুন অ্যাপ নামান'),
                )
              else
                const Text('অ্যাডমিনের কাছ থেকে নতুন অ্যাপ নিন।', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: s.logout, child: const Text('লগআউট')),
            ],
          ),
        ),
      ),
    );
  }
}
