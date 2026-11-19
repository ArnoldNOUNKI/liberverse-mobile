// Composants partagés : logo, icônes de navigation (les mêmes que le site), images protégées, avatars, cartes, messages.
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Icône carrée Liberverse (L calligraphique + masque doré + étoile)
class LiberIcon extends StatelessWidget {
  final double size;
  const LiberIcon({super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/icon.svg', width: size, height: size);
}

/// Logo complet : icône + « Liber*verse* »
class LiberLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color accent;
  const LiberLogo({super.key, this.size = 22, this.color, this.accent = LvColors.red});
  @override
  Widget build(BuildContext context) {
    final c = color ?? LvColors.of(context).ink;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LiberIcon(size: size * 1.5),
      SizedBox(width: size * .45),
      Text.rich(TextSpan(children: [
        TextSpan(text: 'Liber', style: TextStyle(color: c)),
        TextSpan(text: 'verse', style: TextStyle(color: accent, fontStyle: FontStyle.italic)),
      ]), style: TextStyle(fontFamily: kSerif, fontSize: size, fontWeight: FontWeight.w700)),
    ]);
  }
}

/// Icônes de la barre d'onglets — tracés identiques à l'app web (contour, plein quand l'onglet est actif)
const _navPaths = {
  'rencontres': '<path d="M12 20.3c-.3 0-.6-.1-.8-.3C8.6 17.8 3 13.6 3 9.2 3 6.4 5.1 4.3 7.7 4.3c1.7 0 3.2.9 4.3 2.4 1.1-1.5 2.6-2.4 4.3-2.4 2.6 0 4.7 2.1 4.7 4.9 0 4.4-5.6 8.6-8.2 10.8-.2.2-.5.3-.8.3z"/>',
  'likes': '<path d="M12 3.6l2.5 5.2 5.7.8-4.1 4 1 5.7L12 16.6l-5.1 2.7 1-5.7-4.1-4 5.7-.8z"/>',
  'messages': '<path d="M5 4.5h14a2.5 2.5 0 0 1 2.5 2.5v8.5A2.5 2.5 0 0 1 19 18h-7.2l-4.6 3.3a.6.6 0 0 1-.95-.5V18H5a2.5 2.5 0 0 1-2.5-2.5V7A2.5 2.5 0 0 1 5 4.5z"/><path class="ln" d="M7.5 9.5h9M7.5 13h5.5"/>',
  'salons': '<circle cx="9" cy="8.5" r="3.2"/><path d="M2.8 19.5c.5-3.3 3.1-5.5 6.2-5.5s5.7 2.2 6.2 5.5"/><circle cx="16.8" cy="7.6" r="2.5"/><path d="M16.5 12.6c2.6.1 4.4 2 4.8 4.9"/>',
  'profil': '<circle cx="12" cy="12" r="9.3"/><circle class="ln" cx="12" cy="10" r="3.3"/><path class="ln" d="M6.2 18.4c1.2-2.4 3.3-3.7 5.8-3.7s4.6 1.3 5.8 3.7"/>',
};

class NavIcon extends StatelessWidget {
  final String k;
  final bool on;
  final Color color;
  final Color inner;
  const NavIcon(this.k, {super.key, required this.on, required this.color, required this.inner});
  String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  @override
  Widget build(BuildContext context) {
    final fill = on && k != 'salons';
    var body = _navPaths[k] ?? '';
    body = body.replaceAll('class="ln"', 'stroke="${fill ? _hex(inner) : _hex(color)}" fill="none"');
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${fill ? _hex(color) : 'none'}" stroke="${_hex(color)}" '
        'stroke-width="${on ? 1.9 : 1.7}" stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    return SvgPicture.string(svg, width: 25, height: 25);
  }
}

/// Image protégée (/media/:id) chargée avec le cookie de session
class MediaImage extends StatefulWidget {
  final String? id;
  final BoxFit fit;
  final double? width, height;
  const MediaImage(this.id, {super.key, this.fit = BoxFit.cover, this.width, this.height});
  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  static Map<String, String>? _headers;
  @override
  void initState() {
    super.initState();
    if (_headers == null) Api.I.mediaHeaders().then((h) { _headers = h; if (mounted) setState(() {}); });
  }
  @override
  Widget build(BuildContext context) {
    final ph = _Placeholder(width: widget.width, height: widget.height);
    if (widget.id == null || _headers == null) return ph;
    return Image.network(Api.I.mediaUrl(widget.id), headers: _headers!.isEmpty ? null : _headers, fit: widget.fit, width: widget.width, height: widget.height,
        gaplessPlayback: true, errorBuilder: (_, _, _) => ph, loadingBuilder: (c, w, p) => p == null ? w : ph);
  }
}

class _Placeholder extends StatelessWidget {
  final double? width, height;
  const _Placeholder({this.width, this.height});
  @override
  Widget build(BuildContext context) => Container(width: width, height: height,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9B1235), Color(0xFF3A0613)])),
      child: Icon(Icons.person_rounded, color: Colors.white24, size: (width ?? 80) * .45));
}

class Avatar extends StatelessWidget {
  final String? id;
  final double size;
  final bool online;
  const Avatar(this.id, {super.key, this.size = 46, this.online = false});
  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipOval(child: MediaImage(id, width: size, height: size)),
        if (online) Positioned(right: 1, bottom: 1, child: Container(width: size * .26, height: size * .26,
            decoration: BoxDecoration(color: LvColors.online, shape: BoxShape.circle, border: Border.all(color: LvColors.of(context).panel, width: 2)))),
      ]);
}

/// Pastille de compteur (messages non lus, likes…)
class CountBadge extends StatelessWidget {
  final int n;
  const CountBadge(this.n, {super.key});
  @override
  Widget build(BuildContext context) => n <= 0 ? const SizedBox.shrink() : Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5), constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(color: LvColors.red, borderRadius: BorderRadius.circular(99), border: Border.all(color: LvColors.of(context).panel, width: 1.6)),
      child: Text(n > 99 ? '99+' : '$n', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)));
}

class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets padding;
  const SectionCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final c = LvColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: padding,
      decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(tr(title!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        child,
      ]),
    );
  }
}

class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: const BoxDecoration(color: LvColors.red, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, size: size * .72, color: Colors.white));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 54, color: LvColors.of(context).field),
        const SizedBox(height: 14),
        Text(tr(text), textAlign: TextAlign.center, style: TextStyle(color: LvColors.of(context).mute, fontSize: 15)),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ])));
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tr(msg)), backgroundColor: error ? LvColors.redDark : null, duration: const Duration(seconds: 3)));
}

/// Exécute une action réseau et affiche l'erreur éventuelle
Future<T?> guard<T>(BuildContext context, Future<T> Function() fn, {String? ok}) async {
  try {
    final r = await fn();
    if (ok != null && context.mounted) toast(context, ok);
    return r;
  } on ApiError catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
    return null;
  }
}

Future<bool> confirmDialog(BuildContext context, String text, {String ok = 'Valider', bool danger = false}) async {
  final r = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        content: Text(tr(text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Annuler'))),
          FilledButton(style: danger ? FilledButton.styleFrom(backgroundColor: LvColors.redDark, minimumSize: const Size(0, 42)) : FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => Navigator.pop(c, true), child: Text(tr(ok))),
        ],
      ));
  return r == true;
}

class Pill extends StatelessWidget {
  final String text;
  final Color? bg, fg;
  const Pill(this.text, {super.key, this.bg, this.fg});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg ?? LvColors.of(context).soft, borderRadius: BorderRadius.circular(99), border: bg == null ? Border.all(color: LvColors.of(context).line) : null),
      child: Text(tr(text), style: TextStyle(fontSize: 12.5, color: fg ?? LvColors.of(context).ink, fontWeight: FontWeight.w500)));
}
