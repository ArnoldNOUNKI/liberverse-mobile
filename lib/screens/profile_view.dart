// Profil détaillé d'un membre : photos, présentation, envies, actions (passer / super-like / j'aime / écrire), signalement, blocage
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'chat.dart';
import 'discover.dart';

Future<void> reportSheet(BuildContext context, {required String userId, String? matchId}) async {
  final reasons = Map<String, dynamic>.from(context.read<AppState>().ref['report_reasons'] ?? {});
  String reason = reasons.keys.first;
  final details = TextEditingController();
  final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Signaler ce profil'), style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RadioGroup<String>(groupValue: reason, onChanged: (v) => set(() => reason = v!), child: Column(children: [
            for (final e in reasons.entries) RadioListTile<String>(contentPadding: EdgeInsets.zero, dense: true, value: e.key, title: Text(tr(e.value))),
          ])),
          TextField(controller: details, maxLines: 3, decoration: InputDecoration(labelText: tr('Détails (facultatif)'))),
          const SizedBox(height: 8),
          Text(tr('La modération peut consulter vos échanges avec ce membre pour traiter le signalement.'), style: TextStyle(fontSize: 12.5, color: LvColors.of(c).mute)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Signaler'))),
        ]))));
  if (ok == true && context.mounted) {
    await guard(context, () => Api.I.post('/discover/report', {'user_id': userId, 'match_id': matchId, 'reason': reason, 'details': details.text}), ok: 'Signalement transmis à la modération');
  }
}

class ProfileViewScreen extends StatefulWidget {
  final String id;
  const ProfileViewScreen({super.key, required this.id});
  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Map<String, dynamic>? p;
  int photo = 0;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final r = await guard(context, () => Api.I.get('/discover/profile/${widget.id}'));
    if (r == null) { if (mounted) Navigator.pop(context); return; }
    if (mounted) setState(() => p = Map<String, dynamic>.from(r));
  }

  Future<void> act(String a) async {
    if (await doSwipe(context, p!, a) && mounted) {
      if (a == 'pass') { Navigator.pop(context); } else { load(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final photos = (p!['photos'] as List).where((x) => x['kind'] != 'private').toList();
    final priv = (p!['photos'] as List).where((x) => x['kind'] == 'private').toList();
    final h = MediaQuery.of(context).size.height * .6;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: h, pinned: true, backgroundColor: c.bg, foregroundColor: Colors.white,
          leading: Padding(padding: const EdgeInsets.all(6), child: CircleAvatar(backgroundColor: Colors.black38, child: BackButton(color: Colors.white))),
          actions: [Padding(padding: const EdgeInsets.all(6), child: CircleAvatar(backgroundColor: Colors.black38, child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            onSelected: (v) async {
              if (v == 'report') reportSheet(context, userId: p!['id']);
              if (v == 'block' && await confirmDialog(context, 'Bloquer ce membre ? Il ne vous verra plus et la conversation sera fermée.', ok: 'Bloquer', danger: true) && context.mounted) {
                final ok = await guard(context, () => Api.I.post('/discover/block', {'user_id': p!['id']}), ok: 'Membre bloqué');
                if (ok != null && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(tr('Signaler'))), PopupMenuItem(value: 'block', child: Text(tr('Bloquer')))],
          )))],
          flexibleSpace: FlexibleSpaceBar(background: Stack(fit: StackFit.expand, children: [
            PageView(onPageChanged: (i) => setState(() => photo = i), children: [
              if (photos.isEmpty) const MediaImage(null),
              for (final ph in photos) MediaImage(ph['id']),
            ]),
            if (photos.length > 1) Positioned(top: MediaQuery.of(context).padding.top + 6, left: 60, right: 60, child: Row(children: [
              for (var i = 0; i < photos.length; i++) Expanded(child: Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: i == photo ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(3)))),
            ])),
          ])),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 120), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('${p!['display_name']}${p!['age'] != null ? ', ${p!['age']}' : ''}', style: const TextStyle(fontFamily: kSerif, fontSize: 30, fontWeight: FontWeight.w700))),
            if (p!['verified'] == true) ...[const SizedBox(width: 8), const VerifiedTick(size: 20)],
          ]),
          const SizedBox(height: 4),
          Text([s.profileType(p!['profile_type']), if (p!['partner_age'] != null) '${p!['age']} & ${p!['partner_age']}', if (p!['city'] != null) p!['city'],
            if (p!['distance'] != null) '${tr('à')} ${p!['distance']} km', p!['online'] == true ? tr('En ligne') : '${tr('Vu')} ${ago(p!['last_seen'])}'].join(' · '),
              style: TextStyle(color: c.mute)),
          if ((p!['bio'] ?? '') != '') ...[const SizedBox(height: 18), Text(tr('Présentation'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6), Text(p!['bio'], style: const TextStyle(fontSize: 15.5, height: 1.45))],
          if (((p!['interests'] as List?) ?? []).isNotEmpty) ...[const SizedBox(height: 18), Text(tr('Envies'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: [for (final i in p!['interests']) Pill(i)])],
          if (priv.isNotEmpty) ...[const SizedBox(height: 18), Text(tr('Album privé'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 8),
            SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal, children: [for (final ph in priv) Padding(padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: MediaImage(ph['id'], width: 90, height: 110)))]))]
          else if ((p!['private_locked'] ?? 0) > 0) ...[const SizedBox(height: 14), Text('🔒 ${tr('Album privé')} — ${tr('visible uniquement de vos matchs')}', style: TextStyle(color: c.mute))],
        ]))),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 10), child: p!['matched'] == true
          ? FilledButton.icon(icon: const Icon(Icons.chat_bubble_rounded), label: Text(tr('Envoyer un message')), onPressed: () async {
              final ms = await Api.I.get('/matches');
              final m = (ms as List).firstWhere((x) => x['id'] == p!['id'], orElse: () => null);
              if (m != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(match: Map<String, dynamic>.from(m))));
            })
          : p!['my_action'] != null
              ? Text(tr('Vous avez déjà liké ce profil — le match se fera s’il vous like aussi.'), textAlign: TextAlign.center, style: TextStyle(color: c.mute))
              : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  OutlinedButton.icon(onPressed: () => act('pass'), icon: const Icon(Icons.close_rounded), label: Text(tr('Passer'))),
                  IconButton.filled(style: IconButton.styleFrom(backgroundColor: LvColors.goldDeep), onPressed: () => act('super'), icon: const Icon(Icons.star_rounded, color: Colors.white)),
                  FilledButton.icon(onPressed: () => act('like'), icon: const Icon(Icons.favorite_rounded), label: Text(tr('J’aime')), style: FilledButton.styleFrom(minimumSize: const Size(0, 48))),
                ]))),
    );
  }
}
