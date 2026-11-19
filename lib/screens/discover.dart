// Rencontres : cartes à glisser (droite = j'aime, gauche = passer, haut = super-like) ou grille, filtres, match.
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'chat.dart';
import 'filters.dart';
import 'membership.dart';
import 'profile_view.dart';

typedef Json = Map<String, dynamic>;

String? primaryPhoto(Map p) {
  final ph = (p['photos'] as List?) ?? [];
  if (ph.isEmpty) return null;
  return (ph.firstWhere((x) => x['is_primary'] == true, orElse: () => ph.first))['id'];
}

/// Swipe commun aux cartes, à la grille et au profil détaillé. Retourne true si l'action a été enregistrée.
Future<bool> doSwipe(BuildContext context, Map p, String action) async {
  final s = context.read<AppState>();
  if (action == 'super' && ((s.plan?['daily_super'] ?? 0) as int) <= 0) { premiumPrompt(context, 'Le super-like est réservé aux adhésions Premium et Prestige'); return false; }
  HapticFeedback.selectionClick();
  try {
    final r = await Api.I.post('/discover/swipe', {'target_id': p['id'], 'action': action});
    if (!context.mounted) return true;
    if (r['match'] == true) {
      HapticFeedback.heavyImpact();
      showMatch(context, Json.from(r['profile'] ?? p), r['match_id']);
      s.refreshBadges();
    } else if (action == 'like') {
      toast(context, 'Like envoyé ♥');
    } else if (action == 'super') {
      toast(context, 'Super-like envoyé ★');
    }
    return true;
  } on ApiError catch (e) {
    if (!context.mounted) return false;
    if (e.upgrade) { premiumPrompt(context, e.message); } else { toast(context, e.message, error: true); }
    return e.status == 409; // déjà évalué : on passe au suivant
  }
}

void premiumPrompt(BuildContext context, String msg) async {
  if (await confirmDialog(context, '${tr(msg)}\n\n${tr('Découvrir les adhésions Premium et Prestige ?')}', ok: 'Voir les offres') && context.mounted) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembershipScreen()));
  }
}

void showMatch(BuildContext context, Json p, String? matchId) {
  final s = context.read<AppState>();
  final mine = ((s.me?['media'] as List?) ?? []).cast<Map>().where((m) => m['kind'] == 'profile' && m['is_primary'] == true).map((m) => m['id'] as String?).firstOrNull;
  showGeneralDialog(context: context, barrierDismissible: false, barrierColor: Colors.black87, pageBuilder: (c, _, _) => Material(color: Colors.transparent, child: Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('C’est un match'), style: const TextStyle(fontFamily: kSerif, fontSize: 40, color: Colors.white, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text('${tr('Vous vous plaisez mutuellement avec')} ${p['display_name']}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE8D8DD))),
          const SizedBox(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: LvColors.gold, width: 3)), child: Avatar(mine, size: 104)),
            Transform.translate(offset: const Offset(-14, 0), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: LvColors.gold, width: 3)), child: Avatar(primaryPhoto(p), size: 104))),
          ]),
          const SizedBox(height: 30),
          SizedBox(width: double.infinity, child: FilledButton.icon(icon: const Icon(Icons.chat_bubble_rounded), label: Text(tr('Envoyer un message')), onPressed: () {
            Navigator.pop(c);
            if (matchId != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(match: {...p, 'match_id': matchId})));
          })),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Continuer'), style: const TextStyle(color: Colors.white70))),
        ]),
      ))));
}

class DiscoverScreen extends StatefulWidget {
  final bool active;
  const DiscoverScreen({super.key, required this.active});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool grid = false, loading = true;
  List<Json> deck = [], gridItems = [];
  int page = 1, total = 0;
  Json limits = {};
  Offset drag = Offset.zero;
  Offset? flyTo;

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    setState(() => loading = true);
    try {
      if (grid) {
        page = 1;
        final r = await Api.I.get('/discover/search', query: {'page': 1});
        gridItems = List<Json>.from(r['profiles']); total = r['total'] ?? gridItems.length;
      } else {
        final r = await Api.I.get('/discover');
        deck = List<Json>.from(r['profiles']);
      }
      limits = Json.from(await Api.I.get('/discover/limits'));
    } on ApiError catch (e) { if (mounted) toast(context, e.message, error: true); }
    if (mounted) setState(() => loading = false);
  }

  Future<void> moreGrid() async {
    if (gridItems.length >= total) return;
    final r = await Api.I.get('/discover/search', query: {'page': ++page});
    setState(() => gridItems.addAll(List<Json>.from(r['profiles'])));
  }

  Future<void> swipeTop(String action) async {
    if (deck.isEmpty || flyTo != null) return;
    final p = deck.first;
    final w = MediaQuery.of(context).size.width;
    setState(() => flyTo = action == 'like' ? Offset(w * 1.5, drag.dy) : action == 'pass' ? Offset(-w * 1.5, drag.dy) : Offset(0, -900));
    final ok = await doSwipe(context, p, action);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() { if (ok) deck.removeAt(0); flyTo = null; drag = Offset.zero; });
    try { limits = Json.from(await Api.I.get('/discover/limits')); } catch (_) {}
    if (deck.length < 4 && ok) {
      try { final r = await Api.I.get('/discover'); final ids = deck.map((x) => x['id']).toSet(); deck.addAll(List<Json>.from(r['profiles']).where((x) => !ids.contains(x['id']))); } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void openProfile(Json p) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileViewScreen(id: p['id']))).then((_) => grid ? reload() : null);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final nf = ((s.user['filters'] as Map?) ?? {}).entries.where((e) => e.value != null && e.value != '' && e.value != false && e.value != 0 && !(e.value is List && (e.value as List).isEmpty)).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Rencontres')),
        actions: [
          SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact, selectedBackgroundColor: LvColors.red, selectedForegroundColor: Colors.white),
            showSelectedIcon: false,
            segments: [ButtonSegment(value: false, icon: const Icon(Icons.style_rounded, size: 18), tooltip: tr('Cartes')), ButtonSegment(value: true, icon: const Icon(Icons.grid_view_rounded, size: 18), tooltip: tr('Grille'))],
            selected: {grid}, onSelectionChanged: (v) { setState(() => grid = v.first); reload(); },
          ),
          IconButton(tooltip: tr('Filtres'), onPressed: () async {
            final changed = await openFilters(context);
            if (changed == true) reload();
          }, icon: Badge(isLabelVisible: nf > 0, label: Text('$nf'), backgroundColor: LvColors.red, child: const Icon(Icons.tune_rounded))),
          const SizedBox(width: 6),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : grid ? _grid(c) : _cards(c, s),
    );
  }

  Widget _cards(LvColors c, AppState s) {
    if (deck.isEmpty) {
      return EmptyState(icon: Icons.favorite_border_rounded, text: 'Plus de profil à découvrir pour l’instant', action: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        OutlinedButton(onPressed: () async { if (await openFilters(context) == true) reload(); }, child: Text(tr('Modifier mes filtres'))),
        OutlinedButton(onPressed: () async { await guard(context, () => Api.I.post('/discover/reset-passes')); reload(); }, child: Text(tr('↺ Revoir les profils passés'))),
      ]));
    }
    final w = MediaQuery.of(context).size.width;
    final top = deck.first;
    final off = flyTo ?? drag;
    final likeO = (off.dx / 110).clamp(0.0, 1.0), nopeO = (-off.dx / 110).clamp(0.0, 1.0), supO = (-off.dy / 130).clamp(0.0, 1.0);
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Row(children: [
        Text('${limits['likes_left'] == -1 || limits['likes_left'] == null ? tr('illimité') : limits['likes_left']} ${tr('likes restants')}', style: TextStyle(color: c.mute, fontSize: 12.5)),
        const Spacer(),
        Text('★ ${limits['super_left'] ?? 0}', style: const TextStyle(color: LvColors.goldDeep, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ])),
      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: Stack(children: [
        if (deck.length > 1) Positioned.fill(child: Transform.scale(scale: .95, child: Opacity(opacity: .9, child: _CardFace(p: deck[1])))),
        Positioned.fill(child: GestureDetector(
          onTap: () => openProfile(top),
          onPanUpdate: (d) => setState(() => drag += d.delta),
          onPanEnd: (_) {
            if (drag.dx > 110) { swipeTop('like'); } else if (drag.dx < -110) { swipeTop('pass'); } else if (drag.dy < -130) { swipeTop('super'); } else { setState(() => drag = Offset.zero); }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: flyTo != null ? 260 : (drag == Offset.zero ? 200 : 0)),
            curve: Curves.easeOut,
            transform: Matrix4.identity()..translateByDouble(off.dx, off.dy, 0, 1)..rotateZ(off.dx / w * .35),
            transformAlignment: Alignment.bottomCenter,
            child: Stack(children: [
              Positioned.fill(child: _CardFace(p: top)),
              Positioned(top: 26, left: 22, child: Opacity(opacity: likeO, child: _Stamp(tr('J’AIME'), const Color(0xFF2EB872), -.25))),
              Positioned(top: 26, right: 22, child: Opacity(opacity: nopeO, child: _Stamp(tr('NON'), LvColors.red, .25))),
              Positioned(bottom: 150, left: 0, right: 0, child: Center(child: Opacity(opacity: supO, child: _Stamp('SUPER ★', LvColors.goldDeep, 0)))),
            ]),
          ),
        )),
      ]))),
      Padding(padding: const EdgeInsets.fromLTRB(0, 14, 0, 6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _RoundBtn(icon: Icons.close_rounded, size: 58, bg: c.panel, fg: c.mute, onTap: () => swipeTop('pass')),
        const SizedBox(width: 18),
        _RoundBtn(icon: Icons.star_rounded, size: 50, bg: ((s.plan?['daily_super'] ?? 0) as int) > 0 ? LvColors.goldDeep : c.field, fg: Colors.white, onTap: () => swipeTop('super')),
        const SizedBox(width: 18),
        _RoundBtn(icon: Icons.favorite_rounded, size: 70, bg: LvColors.red, fg: Colors.white, onTap: () => swipeTop('like')),
      ])),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(tr('Glissez à droite pour aimer, à gauche pour passer, vers le haut pour un super-like.'),
          textAlign: TextAlign.center, style: TextStyle(color: c.mute, fontSize: 11.5))),
    ]);
  }

  Widget _grid(LvColors c) {
    if (gridItems.isEmpty) return EmptyState(icon: Icons.grid_view_rounded, text: 'Aucun profil ne correspond. Élargissez vos filtres.');
    return RefreshIndicator(onRefresh: reload, child: NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) moreGrid(); return false; },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .72, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: gridItems.length,
        itemBuilder: (_, i) {
          final p = gridItems[i];
          return GestureDetector(onTap: () => openProfile(p), child: Stack(children: [
            Positioned.fill(child: _CardFace(p: p, compact: true)),
            if (p['matched'] == true) Positioned(top: 8, left: 8, child: Pill('♥ Match', bg: LvColors.red, fg: Colors.white))
            else if (p['my_action'] == null) Positioned(right: 8, bottom: 8, child: Column(children: [
              _RoundBtn(icon: Icons.star_rounded, size: 34, bg: LvColors.goldDeep, fg: Colors.white, onTap: () async { if (await doSwipe(context, p, 'super')) setState(() => p['my_action'] = 'super'); }),
              const SizedBox(height: 6),
              _RoundBtn(icon: Icons.favorite_rounded, size: 44, bg: LvColors.red, fg: Colors.white, onTap: () async { if (await doSwipe(context, p, 'like')) setState(() => p['my_action'] = 'like'); }),
              const SizedBox(height: 6),
              _RoundBtn(icon: Icons.close_rounded, size: 34, bg: Colors.white, fg: c.mute, onTap: () async { if (await doSwipe(context, p, 'pass')) setState(() => gridItems.removeAt(i)); }),
            ]))
            else Positioned(top: 8, right: 8, child: Pill(p['my_action'] == 'pass' ? 'Passé' : '♥ Liké', bg: Colors.black45, fg: Colors.white)),
          ]));
        },
      ),
    ));
  }
}

class _CardFace extends StatelessWidget {
  final Json p;
  final bool compact;
  const _CardFace({required this.p, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final sub = [s.profileType(p['profile_type']), if (p['city'] != null) p['city'], if (p['distance'] != null) '${tr('à')} ${p['distance']} km'].join(' · ');
    return ClipRRect(borderRadius: BorderRadius.circular(compact ? 16 : 22), child: Stack(fit: StackFit.expand, children: [
      MediaImage(primaryPhoto(p)),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE6140508)]))),
      if (p['super_me'] == true) Positioned(top: 12, left: 12, child: Pill('★ vous a super-liké', bg: LvColors.goldDeep, fg: Colors.white)),
      Positioned(left: compact ? 10 : 18, right: compact ? 56 : 18, bottom: compact ? 10 : 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Flexible(child: Text('${p['display_name']}${p['age'] != null ? ', ${p['age']}' : ''}', overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: compact ? null : kSerif, color: Colors.white, fontSize: compact ? 15 : 28, fontWeight: FontWeight.w700))),
          if (p['verified'] == true) ...[const SizedBox(width: 6), VerifiedTick(size: compact ? 14 : 18)],
        ]),
        const SizedBox(height: 2),
        Row(children: [
          if (p['online'] == true) Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: LvColors.online, shape: BoxShape.circle)),
          Flexible(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: compact ? 11.5 : 14))),
        ]),
        if (!compact && (p['bio'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 6),
            child: Text(p['bio'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13.5))),
        if (!compact && ((p['interests'] as List?) ?? []).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in (p['interests'] as List).take(3)) Pill(i, bg: Colors.white24, fg: Colors.white),
        ])),
      ])),
    ]));
  }
}

class _Stamp extends StatelessWidget {
  final String text;
  final Color color;
  final double angle;
  const _Stamp(this.text, this.color, this.angle);
  @override
  Widget build(BuildContext context) => Transform.rotate(angle: angle, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color, width: 3.5), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2))));
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg, fg;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.size, required this.bg, required this.fg, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: bg, shape: const CircleBorder(), elevation: 4, shadowColor: Colors.black26,
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: size, height: size, child: Icon(icon, color: fg, size: size * .48))));
}

// Utilisé par la grille des likes
Widget profileTile(BuildContext context, Json p, {VoidCallback? onTap, Widget? overlay}) => GestureDetector(onTap: onTap,
    child: Stack(children: [Positioned.fill(child: _CardFace(p: p, compact: true)), ?overlay]));

double kmToPos(int km) => km <= 0 ? 0 : math.min(100, math.max(1, (math.pow(km / 500, 1 / 2.2) * 100).roundToDouble()));
int posToKm(double p) {
  if (p <= 0) return 0;
  final v = math.pow(p / 100, 2.2) * 500;
  return math.max(1, v < 20 ? v.round() : v < 100 ? (v / 5).round() * 5 : (v / 10).round() * 10);
}
