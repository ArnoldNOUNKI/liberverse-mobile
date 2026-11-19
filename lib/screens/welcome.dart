// Accueil (sombre, comme le site) : code d'invitation, connexion, langue.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'auth.dart';

/// Fond nuit avec orbites et points en mouvement (ornement de la page d'accueil du site)
class NightBackground extends StatefulWidget {
  final Widget child;
  const NightBackground({super.key, required this.child});
  @override
  State<NightBackground> createState() => _NightBackgroundState();
}

class _NightBackgroundState extends State<NightBackground> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.1), radius: .9, colors: [Color(0x559B1235), LvColors.night])),
        child: Stack(children: [
          Positioned.fill(child: AnimatedBuilder(animation: a, builder: (_, _) => CustomPaint(painter: _Orbits(a.value)))),
          widget.child,
        ]),
      );
}

class _Orbits extends CustomPainter {
  final double t;
  _Orbits(this.t);
  // (rayon x, rayon y, rotation, vitesse, sens, taille, couleur)
  static const _o = [
    [.62, .2, -.31, 1.6, 1, 3.6, 0xFFE3C48D], [.48, .15, -.31, 2.2, -1, 2.8, 0xFFFF8FAB], [.34, .1, -.31, 3.1, 1, 2.4, 0xFFE3C48D],
    [.56, .16, .21, 1.3, -1, 3.0, 0xFFF7EEF1], [.4, .26, -.84, 1.8, 1, 2.6, 0xFFFF8FAB],
  ];
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * .45);
    final w = math.max(s.width, s.height * .7);
    for (var i = 0; i < _o.length; i++) {
      final o = _o[i];
      final rx = (o[0] as double) * w, ry = (o[1] as double) * w, rot = o[2] as double;
      canvas.save(); canvas.translate(c.dx, c.dy); canvas.rotate(rot);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
          Paint()..style = PaintingStyle.stroke..strokeWidth = .8..color = const Color(0xFFE3C48D).withValues(alpha: i < 3 ? .16 - i * .04 : .06));
      final ang = (t * (o[3] as double) * (o[4] as int) + i * .7) * 2 * math.pi;
      canvas.drawCircle(Offset(rx * math.cos(ang), ry * math.sin(ang)), o[5] as double, Paint()..color = Color(o[6] as int).withValues(alpha: .85));
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(_Orbits o) => o.t != t;
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final code = TextEditingController();
  String? err;
  bool busy = false;
  int? fromPrice;

  @override
  void initState() {
    super.initState();
    Api.I.get('/billing/plans', auth401: false).then((r) {
      final ps = (r['plans'] as List).where((p) => (p['period_days'] as int) < 365).map((p) => p['price_cents'] as int);
      if (ps.isNotEmpty && mounted) setState(() => fromPrice = ps.reduce(math.min));
    }).catchError((_) {});
  }

  Future<void> check() async {
    setState(() { busy = true; err = null; });
    try {
      final r = await Api.I.post('/auth/check-code', {'code': code.text.trim()});
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterScreen(code: r['code'], sponsor: r['sponsor'] ?? '')));
    } on ApiError catch (e) { setState(() => err = tr(e.message)); }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    const muted = Color(0xFFB7A5AB);
    return Theme(data: buildTheme(Brightness.dark), child: Scaffold(
      backgroundColor: LvColors.night,
      body: NightBackground(child: SafeArea(child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: Column(children: [
          const SizedBox(height: 14),
          Row(children: [
            const LiberLogo(size: 21, color: Colors.white, accent: LvColors.gold),
            const Spacer(),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: LvColors.gold, width: 1.4), minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16), backgroundColor: LvColors.gold.withValues(alpha: .06)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: Text(tr('Connexion')),
            ),
          ]),
          SizedBox(height: box.maxHeight * .1),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 22, height: 1, color: LvColors.gold.withValues(alpha: .6)), const SizedBox(width: 10),
            Flexible(child: Text(tr('Cercle privé · sur invitation').toUpperCase(), textAlign: TextAlign.center,
                style: const TextStyle(color: LvColors.gold, fontSize: 11.5, letterSpacing: 2.2, fontWeight: FontWeight.w600))),
            const SizedBox(width: 10), Container(width: 22, height: 1, color: LvColors.gold.withValues(alpha: .6)),
          ]),
          const SizedBox(height: 18),
          // Titre sur 2 lignes, taille ajustée à la largeur de l'écran
          FittedBox(fit: BoxFit.scaleDown, child: Text.rich(TextSpan(children: [
            TextSpan(text: '${tr('L’art de la rencontre')} '),
            TextSpan(text: tr('libertine'), style: const TextStyle(fontStyle: FontStyle.italic, color: LvColors.rose)),
            const TextSpan(text: ',\n'),
            TextSpan(text: tr('en toute discrétion.')),
          ]), textAlign: TextAlign.center, style: const TextStyle(fontFamily: kSerif, fontSize: 34, height: 1.15, color: Color(0xFFF7EEF1)))),
          const SizedBox(height: 14),
          Text(tr('Célibataires et couples, tous genres et orientations. On n’entre que recommandé·e par un membre — chaque profil est vérifié.'),
              textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 15, height: 1.5)),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 5, 5, 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
            child: Row(children: [
              Expanded(child: TextField(controller: code, textCapitalization: TextCapitalization.characters, onSubmitted: (_) => check(),
                  style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 16),
                  decoration: const InputDecoration(hintText: 'LV-XXXX-XXXX', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false,
                      hintStyle: TextStyle(color: Color(0x88B7A5AB), letterSpacing: 2)))),
              FilledButton(onPressed: busy ? null : check, style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22)),
                  child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('${tr('Entrer')} →')),
            ]),
          ),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: LvColors.rose))),
          const SizedBox(height: 10),
          Text(tr('Pas de code ? Demandez-le à un membre qui vous connaît.'), textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 26),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final p in [['✉', 'Cooptation : 5 invitations par membre'], ['✓', 'Profils vérifiés'], ['◌', 'Discrétion totale']])
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white12)),
                  child: Text('${p[0]}  ${tr(p[1])}', style: const TextStyle(color: Color(0xFFF7EEF1), fontSize: 12.5))),
          ]),
          if (fromPrice != null) Padding(padding: const EdgeInsets.only(top: 18),
              child: Text('${tr('Adhésion dès')} ${s.price(fromPrice!)} ${tr('par mois · sans engagement')}', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13))),
          const SizedBox(height: 30),
          DropdownButton<String>(
            value: I18n.I.lang, underline: const SizedBox(), dropdownColor: const Color(0xFF1D1517),
            style: const TextStyle(color: muted, fontSize: 13), icon: const Icon(Icons.language_rounded, color: muted, size: 18),
            items: [for (final e in kLanguages.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => s.setLang(v),
          ),
          Text(tr('Réservé aux personnes majeures'), style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 16),
        ])),
      )))),
    ));
  }
}
