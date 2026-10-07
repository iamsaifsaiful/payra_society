import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

/// Loads data with a spinner, an error view with retry, and pull to refresh.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  T? _data;
  Object? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _busy = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d != null) {
      return RefreshIndicator(onRefresh: reload, color: AppColors.brand, child: widget.builder(context, d, reload));
    }
    if (_busy) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    return ErrorView(error: _error, onRetry: reload);
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final net = error is ApiException && (error as ApiException).isNetwork;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(net ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 48, color: AppColors.muted),
        const SizedBox(height: 16),
        Text(
          net ? 'ইন্টারনেট নেই' : 'তথ্য আনা যায়নি',
          textAlign: TextAlign.center,
          style: head(20),
        ),
        const SizedBox(height: 8),
        Text(
          error?.toString() ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 200,
            child: FilledButton(onPressed: onRetry, child: const Text('আবার চেষ্টা করুন')),
          ),
        ),
      ],
    );
  }
}

/// White rounded card with the canvas' border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: box),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: head(17, weight: FontWeight.w600))),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(action!, style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.text, this.url = '', this.size = 44, this.dark = false});
  final String text;
  final String url;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        text,
        style: head(size * 0.36, color: dark ? Colors.white : AppColors.brand, weight: FontWeight.w600),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.16) : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// Society logo or its first letter.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.name, this.logoUrl = '', this.size = 64});
  final String name, logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? 'প' : String.fromCharCodes(name.runes.take(1));
    final fallback = Center(child: Text(letter, style: head(size * 0.46, color: AppColors.brand)));
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.28)),
      child: logoUrl.isEmpty
          ? fallback
          : Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: Image.network(logoUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback),
            ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4DC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFF8A6100)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ইন্টারনেট নেই — শেষবার আনা তথ্য দেখাচ্ছে',
              style: TextStyle(color: Color(0xFF8A6100), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: bodyFont))));
}

/// Amount coloured by direction (+ green, − red).
class Amount extends StatelessWidget {
  const Amount(this.text, {super.key, required this.positive, this.size = 15});
  final String text;
  final bool positive;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: head(size, color: positive ? AppColors.credit : AppColors.danger, weight: FontWeight.w600),
      );
}
