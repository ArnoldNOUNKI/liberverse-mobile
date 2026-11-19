// Un salon : discussion de groupe, soirées (inscription), membres et demandes, à propos / réglages
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'salons.dart';

class SalonScreen extends StatefulWidget {
  final String id;
  const SalonScreen({super.key, required this.id});
  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  Map<String, dynamic>? d;
  final msgs = <Map<String, dynamic>>[];
  final draft = TextEditingController();
  Timer? poll;

  Map get salon => d!['salon'];
  Map? get me => d!['me'];
  bool get active => me?['status'] == 'active';
  bool get mod => active && ['owner', 'moderator'].contains(me?['role']);

  @override
  void initState() { super.initState(); load(); poll = Timer.periodic(const Duration(seconds: 5), (_) { if (active) loadMsgs(); }); }
  @override
  void dispose() { poll?.cancel(); super.dispose(); }

  Future<void> load() async {
    final r = await guard(context, () => Api.I.get('/salons/${widget.id}'));
    if (r == null) { if (mounted) Navigator.pop(context); return; }
    if (!mounted) return;
    setState(() => d = Map<String, dynamic>.from(r));
    if (active) loadMsgs();
  }

  Future<void> loadMsgs() async {
    try {
      final r = await Api.I.get('/salons/${widget.id}/messages', query: {'after': msgs.isEmpty ? 0 : msgs.last['id']});
      final add = (r['messages'] as List).map((x) => Map<String, dynamic>.from(x)).toList();
      if (add.isNotEmpty && mounted) setState(() => msgs.addAll(add));
    } catch (_) {}
  }

  Future<void> send() async {
    final t = draft.text.trim(); if (t.isEmpty) return;
    final r = await guard(context, () => Api.I.post('/salons/${widget.id}/messages', {'body': t}));
    if (r != null && mounted) { draft.clear(); setState(() => msgs.add(Map<String, dynamic>.from(r))); }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (d == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final c = LvColors.of(context);
    final cats = Map<String, dynamic>.from(st.ref['salon_categories'] ?? {});
    final head = Text('${tr(cats[salon['category']] ?? '')}${salon['city'] != null ? ' · ${salon['city']}' : ''} · ${salon['members_count']} ${tr('Membres').toLowerCase()} · ${tr(kVisibility[salon['visibility']] ?? '')}',
        style: TextStyle(fontSize: 12, color: c.mute));
    if (!active) {
      // Aperçu avant de rejoindre
      return Scaffold(appBar: AppBar(title: Text(salon['name'], style: const TextStyle(fontSize: 20))), body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 180, child: MediaImage(salon['cover_id']))),
        const SizedBox(height: 12), head, const SizedBox(height: 10),
        Text(salon['description'] ?? ''),
        if ((salon['rules'] ?? '') != '') ...[const SizedBox(height: 14), Text(tr('Règles du salon'), style: const TextStyle(fontWeight: FontWeight.w700)), Text(salon['rules'])],
        const SizedBox(height: 20),
        if (me?['status'] == 'pending') Text(tr('demande envoyée'), textAlign: TextAlign.center, style: TextStyle(color: c.mute))
        else FilledButton(onPressed: () async {
          final r = await guard(context, () => Api.I.post('/salons/${widget.id}/join'));
          if (r != null && context.mounted) { toast(context, r['status'] == 'active' ? 'Bienvenue dans le salon' : 'Demande envoyée aux animateurs'); load(); }
        }, child: Text(tr(salon['visibility'] == 'public' || me?['status'] == 'invited' ? 'Rejoindre le salon' : 'Demander à rejoindre'))),
      ]));
    }
    final pending = (d!['pending'] as List?) ?? [];
    return DefaultTabController(length: 4, child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: MediaImage(salon['cover_id'], width: 38, height: 38)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(salon['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, fontFamily: kSerif)), head,
          ])),
        ]),
        bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: LvColors.red, indicatorColor: LvColors.red, tabs: [
          Tab(text: tr('Discussion')), Tab(text: tr('Soirées')),
          Tab(child: Row(children: [Text(tr('Membres')), if (mod && pending.isNotEmpty) ...[const SizedBox(width: 6), CountBadge(pending.length)]])),
          Tab(text: tr('À propos')),
        ]),
      ),
      body: TabBarView(children: [_chat(st, c), _events(c), _members(c), _about(c)]),
    ));
  }

  Widget _chat(AppState st, LvColors c) {
    final list = msgs.reversed.toList();
    return Column(children: [
      Expanded(child: ListView.builder(reverse: true, padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_, i) {
        final g = list[i];
        final mine = g['sender_id'] == st.myId;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          if (!mine) ...[Avatar(g['sender_avatar'], size: 30), const SizedBox(width: 6)],
          Flexible(child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(color: mine ? LvColors.red : c.panel, border: mine ? null : Border.all(color: c.line), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!mine) Text(g['sender_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LvColors.red)),
              if (g['removed_by_mod'] == true) Text(tr('Message retiré par la modération'), style: TextStyle(fontStyle: FontStyle.italic, color: c.mute))
              else if (g['blocked'] == true) Text(tr('Message d’un membre que vous avez bloqué'), style: TextStyle(fontStyle: FontStyle.italic, color: c.mute))
              else ...[
                if (g['media_id'] != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: MediaImage(g['media_id'], width: 200, height: 220)),
                if ((g['body'] ?? '') != '') Text(g['body'], style: TextStyle(color: mine ? Colors.white : c.ink, fontSize: 15)),
              ],
              Align(alignment: Alignment.bottomRight, child: Text(hhmm(g['created_at']), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : c.mute))),
            ]),
          )),
        ]));
      })),
      SafeArea(top: false, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.panel, border: Border(top: BorderSide(color: c.line))), child: Row(children: [
        Expanded(child: TextField(controller: draft, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: tr('Écrire au salon…'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)))),
        const SizedBox(width: 6),
        IconButton.filled(onPressed: send, style: IconButton.styleFrom(backgroundColor: LvColors.red), icon: const Icon(Icons.send_rounded, color: Colors.white)),
      ]))),
    ]);
  }

  Widget _events(LvColors c) {
    final ev = (d!['events'] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (mod) Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton.icon(onPressed: _newEvent, icon: const Icon(Icons.event_rounded), label: Text(tr('Organiser une soirée')))),
      if (ev.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Text(tr('Aucune soirée prévue.'), textAlign: TextAlign.center, style: TextStyle(color: c.mute))),
      for (final e in ev) SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e['title'], style: const TextStyle(fontFamily: kSerif, fontSize: 19, fontWeight: FontWeight.w700)),
        Text(dateLong(e['starts_at']), style: const TextStyle(color: LvColors.red, fontWeight: FontWeight.w600)),
        if ((e['place'] ?? '') != '') Text('📍 ${e['place']}', style: TextStyle(color: c.mute)),
        if ((e['description'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 6), child: Text(e['description'])),
        const SizedBox(height: 8),
        Row(children: [
          Text('${e['going']}${e['max_participants'] != null ? ' / ${e['max_participants']}' : ''} ${tr('Places').toLowerCase()}', style: TextStyle(color: c.mute)),
          const Spacer(),
          if (e['cancelled'] == true) Pill('annulée')
          else FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40), backgroundColor: e['me_going'] == true ? c.field : LvColors.red),
              onPressed: () async { await guard(context, () => Api.I.post('/salons/${widget.id}/events/${e['id']}/rsvp')); load(); },
              child: Text(tr(e['me_going'] == true ? 'Je ne viens plus' : 'Je participe'))),
        ]),
      ])),
    ]);
  }

  Future<void> _newEvent() async {
    final title = TextEditingController(), place = TextEditingController(), desc = TextEditingController(), max = TextEditingController();
    DateTime? when;
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Organiser une soirée'), style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: title, decoration: InputDecoration(labelText: tr('Titre'))),
            const SizedBox(height: 10),
            OutlinedButton.icon(icon: const Icon(Icons.schedule_rounded), label: Text(when == null ? tr('Date et heure') : dateLong(when!.toIso8601String())), onPressed: () async {
              final dd = await showDatePicker(context: c, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now().add(const Duration(days: 7)));
              if (dd == null || !c.mounted) return;
              final t = await showTimePicker(context: c, initialTime: const TimeOfDay(hour: 20, minute: 0));
              if (t != null) set(() => when = DateTime(dd.year, dd.month, dd.day, t.hour, t.minute));
            }),
            const SizedBox(height: 10),
            TextField(controller: place, decoration: InputDecoration(labelText: tr('Lieu (visible des membres du salon)'))),
            const SizedBox(height: 10),
            TextField(controller: max, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Places max'))),
            const SizedBox(height: 10),
            TextField(controller: desc, maxLines: 3, decoration: InputDecoration(labelText: tr('Description'))),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Publier'))),
          ])))));
    if (ok != true || !mounted) return;
    await guard(context, () => Api.I.post('/salons/${widget.id}/events', {'title': title.text.trim(), 'starts_at': when?.toUtc().toIso8601String(),
      'place': place.text.trim(), 'description': desc.text.trim(), 'max_participants': int.tryParse(max.text)}), ok: 'Soirée publiée');
    load();
  }

  Widget _members(LvColors c) {
    final members = (d!['members'] as List?) ?? [];
    final pending = (d!['pending'] as List?) ?? [];
    final owner = me?['role'] == 'owner';
    Future<void> act(String uid, String a) async { await guard(context, () => Api.I.post('/salons/${widget.id}/members/$uid', {'action': a})); load(); }
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (mod && pending.isNotEmpty) SectionCard(title: 'Demandes & invitations', child: Column(children: [
        for (final p in pending) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(p['avatar'], size: 42), const SizedBox(width: 10),
          // Boutons sous le nom : tout reste dans le bloc, sans défilement horizontal
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['display_name'], style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(tr({'pending': 'demande à rejoindre', 'invited': 'invité·e', 'banned': 'banni·e'}[p['status']] ?? ''), style: TextStyle(color: c.mute, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (p['status'] == 'pending') ...[
                OutlinedButton(onPressed: () => act(p['id'], 'reject'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), child: Text(tr('Refuser'))),
                FilledButton(onPressed: () => act(p['id'], 'approve'), style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), child: Text(tr('Accepter'))),
              ],
              if (p['status'] == 'invited') OutlinedButton(onPressed: () => act(p['id'], 'reject'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), child: Text(tr('Annuler l’invitation'))),
              if (p['status'] == 'banned') OutlinedButton(onPressed: () => act(p['id'], 'unban'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), child: Text(tr('Lever le bannissement'))),
            ]),
          ])),
        ])),
      ])),
      SectionCard(title: '${tr('Membres')} (${members.length})', child: Column(children: [
        for (final m in members) ListTile(
          contentPadding: EdgeInsets.zero, leading: Avatar(m['avatar'], size: 42), title: Text(m['display_name']),
          subtitle: Text(m['role'] == 'owner' ? tr('créateur') : m['role'] == 'moderator' ? tr('animateur') : (m['city'] ?? '')),
          trailing: mod && m['id'] != context.read<AppState>().myId && m['role'] != 'owner' && (owner || m['role'] == 'member') ? PopupMenuButton<String>(
            onSelected: (a) async { if (['ban', 'kick', 'transfer'].contains(a) && !await confirmDialog(context, {'ban': 'Bannir ce membre du salon ?', 'kick': 'Exclure ce membre ?', 'transfer': 'Transmettre le salon ? Vous deviendrez animateur.'}[a]!, danger: true)) return; act(m['id'], a); },
            itemBuilder: (_) => [
              if (owner && m['role'] == 'member') PopupMenuItem(value: 'promote', child: Text(tr('Nommer animateur'))),
              if (owner && m['role'] == 'moderator') PopupMenuItem(value: 'demote', child: Text(tr('Retirer animateur'))),
              PopupMenuItem(value: 'kick', child: Text(tr('Exclure'))),
              PopupMenuItem(value: 'ban', child: Text(tr('Bannir du salon'))),
              if (owner) PopupMenuItem(value: 'transfer', child: Text(tr('Transmettre le salon'))),
            ]) : null,
        ),
      ])),
    ]);
  }

  Widget _about(LvColors c) => ListView(padding: const EdgeInsets.all(14), children: [
        ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 170, child: MediaImage(salon['cover_id']))),
        const SizedBox(height: 12),
        Text(salon['description'] ?? '—'),
        const SizedBox(height: 14),
        Text(tr('Règles du salon'), style: const TextStyle(fontWeight: FontWeight.w700)),
        Text((salon['rules'] ?? '') == '' ? '—' : salon['rules']),
        const SizedBox(height: 8),
        Text('${tr('Créé par')} ${salon['owner_name']}', style: TextStyle(color: c.mute)),
        const SizedBox(height: 20),
        if (mod) OutlinedButton.icon(onPressed: () async { if (await createSalon(context, edit: salon) == true) load(); }, icon: const Icon(Icons.settings_rounded), label: Text(tr('Réglages'))),
        const SizedBox(height: 8),
        if (me?['role'] != 'owner') OutlinedButton(onPressed: () async {
          if (await confirmDialog(context, 'Quitter ce salon ?', danger: true) && mounted) { await guard(context, () => Api.I.post('/salons/${widget.id}/leave')); if (mounted) Navigator.pop(context); }
        }, child: Text(tr('Quitter'))),
        TextButton(onPressed: () async {
          final reasons = Map<String, dynamic>.from(context.read<AppState>().ref['report_reasons'] ?? {});
          final r = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in reasons.entries) ListTile(title: Text(tr(e.value)), onTap: () => Navigator.pop(c, e.key)),
          ])));
          if (r != null && mounted) await guard(context, () => Api.I.post('/salons/${widget.id}/report', {'reason': r}), ok: 'Signalement transmis à la modération');
        }, child: Text(tr('Signaler ce salon'))),
      ]);
}
