// Salons : invitations, mes salons, découverte (recherche, catégories), création
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'salon.dart';

const kVisibility = {'public': 'Public', 'request': 'Sur demande', 'secret': 'Secret'};

class SalonsScreen extends StatefulWidget {
  final bool active;
  const SalonsScreen({super.key, required this.active});
  @override
  State<SalonsScreen> createState() => _SalonsScreenState();
}

class _SalonsScreenState extends State<SalonsScreen> {
  List salons = [];
  int canCreate = 0;
  bool loading = true;
  String q = '', cat = '';
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(SalonsScreen old) { super.didUpdateWidget(old); if (widget.active && !old.active) load(); }
  Future<void> load() async {
    try {
      final r = await Api.I.get('/salons', query: {if (q.isNotEmpty) 'q': q, if (cat.isNotEmpty) 'category': cat});
      if (mounted) setState(() { salons = r['salons']; canCreate = r['can_create'] ?? 0; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }
  void open(Map s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalonScreen(id: s['id']))).then((_) { load(); if (mounted) context.read<AppState>().refreshBadges(); });

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final c = LvColors.of(context);
    final cats = Map<String, dynamic>.from(st.ref['salon_categories'] ?? {});
    final invited = salons.where((s) => s['my_status'] == 'invited').toList();
    final mine = salons.where((s) => s['my_status'] == 'active' || s['my_status'] == 'pending').toList();
    final other = salons.where((s) => s['my_status'] == null).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Salons'))),
      floatingActionButton: canCreate > 0 ? FloatingActionButton.extended(backgroundColor: LvColors.red, foregroundColor: Colors.white,
          onPressed: () async { if (await createSalon(context) == true) load(); }, icon: const Icon(Icons.add_rounded), label: Text(tr('Créer un salon'))) : null,
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 90), children: [
        TextField(onSubmitted: (v) { q = v; load(); }, decoration: InputDecoration(hintText: tr('Rechercher un salon, une ville…'), prefixIcon: const Icon(Icons.search_rounded))),
        const SizedBox(height: 8),
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(tr('Toutes catégories')), selected: cat.isEmpty, labelStyle: TextStyle(color: cat.isEmpty ? Colors.white : null), onSelected: (_) { cat = ''; load(); })),
          for (final e in cats.entries) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(tr(e.value)), selected: cat == e.key,
              labelStyle: TextStyle(color: cat == e.key ? Colors.white : null), onSelected: (_) { cat = e.key; load(); })),
        ])),
        if (invited.isNotEmpty) ...[_h(tr('Invitations')), for (final s in invited) _SalonCard(s: s, cats: cats, onTap: () => open(s), invite: true, onChanged: load)],
        if (mine.isNotEmpty) ...[_h(tr('Mes salons')), for (final s in mine) _SalonCard(s: s, cats: cats, onTap: () => open(s))],
        _h(tr('Découvrir')),
        if (other.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(tr('Aucun autre salon pour ces critères. Et si vous créiez le vôtre ?'), textAlign: TextAlign.center, style: TextStyle(color: c.mute))),
        for (final s in other) _SalonCard(s: s, cats: cats, onTap: () => open(s)),
      ])),
    );
  }
  Widget _h(String t) => Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 8), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)));
}

class _SalonCard extends StatelessWidget {
  final Map s;
  final Map cats;
  final VoidCallback onTap;
  final bool invite;
  final VoidCallback? onChanged;
  const _SalonCard({required this.s, required this.cats, required this.onTap, this.invite = false, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = LvColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: invite ? LvColors.red : c.line, width: invite ? 2 : 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: invite ? null : onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 120, child: Stack(fit: StackFit.expand, children: [
          MediaImage(s['cover_id']),
          Positioned(top: 10, left: 10, child: Pill(kVisibility[s['visibility']] ?? '', bg: Colors.black54, fg: Colors.white)),
          if ((s['unread'] ?? 0) > 0 && s['my_status'] == 'active') Positioned(top: 10, right: 10, child: CountBadge(s['unread'])),
          if (s['my_status'] == 'pending') Positioned(top: 10, right: 10, child: Pill('demande envoyée', bg: Colors.black54, fg: Colors.white)),
        ])),
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['name'], style: const TextStyle(fontFamily: kSerif, fontSize: 19, fontWeight: FontWeight.w700)),
          Text('${tr(cats[s['category']] ?? '')}${s['city'] != null ? ' · ${s['city']}' : ''} · ${s['members']} ${tr('Membres').toLowerCase()}', style: TextStyle(color: c.mute, fontSize: 12.5)),
          if ((s['description'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 4), child: Text(s['description'], maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (invite) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async { await guard(context, () => Api.I.post('/salons/${s['id']}/leave')); onChanged?.call(); }, child: Text(tr('Décliner')))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () async { if (await guard(context, () => Api.I.post('/salons/${s['id']}/join'), ok: 'Bienvenue dans le salon') != null) { onChanged?.call(); onTap(); } }, child: Text(tr('Accepter')))),
          ])),
        ])),
      ])),
    );
  }
}

Future<bool?> createSalon(BuildContext context, {Map? edit}) {
  final cats = Map<String, dynamic>.from(context.read<AppState>().ref['salon_categories'] ?? {});
  final name = TextEditingController(text: edit?['name']), desc = TextEditingController(text: edit?['description']),
      city = TextEditingController(text: edit?['city']), rules = TextEditingController(text: edit?['rules']);
  String cat = edit?['category'] ?? cats.keys.first, vis = edit?['visibility'] ?? 'public';
  return showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (c) => StatefulBuilder(builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr(edit == null ? 'Créer un salon' : 'Réglages'), style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: InputDecoration(labelText: tr('Nom'), hintText: tr('ex. Apéros complices — Metz'))),
          const SizedBox(height: 10),
          TextField(controller: desc, maxLines: 3, decoration: InputDecoration(labelText: tr('Description'))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: cat, decoration: InputDecoration(labelText: tr('Catégorie')),
              items: [for (final e in cats.entries) DropdownMenuItem(value: e.key, child: Text(tr(e.value)))], onChanged: (v) => set(() => cat = v!)),
          const SizedBox(height: 10),
          TextField(controller: city, decoration: InputDecoration(labelText: tr('Ville / région'))),
          const SizedBox(height: 10),
          TextField(controller: rules, maxLines: 2, decoration: InputDecoration(labelText: tr('Règles (facultatif)'))),
          const SizedBox(height: 12),
          Text(tr('Visibilité'), style: const TextStyle(fontWeight: FontWeight.w700)),
          RadioGroup<String>(groupValue: vis, onChanged: (v) => set(() => vis = v!), child: Column(children: [
            for (final o in [['public', 'Public — on rejoint librement'], ['request', 'Sur demande — vous validez'], ['secret', 'Secret — sur invitation']])
              RadioListTile<String>(contentPadding: EdgeInsets.zero, dense: true, value: o[0], title: Text(tr(o[1]))),
          ])),
          const SizedBox(height: 8),
          FilledButton(onPressed: () async {
            final body = {'name': name.text.trim(), 'description': desc.text.trim(), 'category': cat, 'city': city.text.trim(), 'rules': rules.text.trim(), 'visibility': vis};
            final r = await guard(c, () => edit == null ? Api.I.post('/salons', body) : Api.I.put('/salons/${edit['id']}', body), ok: edit == null ? 'Salon créé' : 'Salon mis à jour');
            if (r != null && c.mounted) Navigator.pop(c, true);
          }, child: Text(tr(edit == null ? 'Créer' : 'Enregistrer'))),
        ])),
      )));
}
