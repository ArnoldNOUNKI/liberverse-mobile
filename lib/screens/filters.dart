// Filtres de recherche (mêmes critères que le site) : types de profil, âge, lieu, distance, activité, envies, tri
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/place_picker.dart';
import 'discover.dart' show kmToPos, posToKm;

Future<bool?> openFilters(BuildContext context) => showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _Filters());

class _Filters extends StatefulWidget {
  const _Filters();
  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late Map<String, dynamic> f;
  late Set<String> showMe;
  late RangeValues age;
  late Place place;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    f = {'max_km': 0, 'active': '', 'sort': '', 'new_members': false, 'with_private': false, 'with_bio': false, 'interests': <String>[], ...Map<String, dynamic>.from(u['filters'] ?? {})};
    f['interests'] = List<String>.from(f['interests'] ?? []);
    showMe = Set<String>.from(u['show_me'] ?? []);
    age = RangeValues((u['age_min'] ?? 18).toDouble(), (u['age_max'] ?? 99).toDouble());
    place = Place(country: f['country'] ?? '', region: f['region'] ?? '', department: f['department'] ?? '', city: f['city'] ?? '');
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await Api.I.put('/me/filters', {...f, 'country': place.country, 'region': place.region, 'department': place.department, 'city': place.city,
        'show_me': showMe.toList(), 'age_min': age.start.round(), 'age_max': age.end.round()});
      if (!mounted) return;
      await context.read<AppState>().loadMe();
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message)))); }
    if (mounted) setState(() => busy = false);
  }

  Widget h(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(tr(t), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));

  Widget chips(List<List<String>> opts, bool Function(String) on, void Function(String) tap) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts) ChoiceChip(label: Text(tr(o[1])), selected: on(o[0]), labelStyle: TextStyle(color: on(o[0]) ? Colors.white : null), onSelected: (_) => setState(() => tap(o[0]))),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final types = Map<String, dynamic>.from(s.ref['profile_types'] ?? {});
    final interests = List<String>.from(s.ref['interests'] ?? []);
    final hasLoc = s.user['location']?['set'] == true;
    final km = (f['max_km'] ?? 0) as int;
    return SizedBox(height: MediaQuery.of(context).size.height * .92, child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
        Text(tr('Filtres'), style: const TextStyle(fontFamily: kSerif, fontSize: 26, fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(onPressed: () => setState(() {
          f = {'max_km': 0, 'active': '', 'sort': '', 'new_members': false, 'with_private': false, 'with_bio': false, 'interests': <String>[]};
          showMe = types.keys.toSet(); age = const RangeValues(18, 99); place = Place(country: '');
        }), child: Text(tr('Réinitialiser'))),
      ])),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        h('Je recherche'),
        chips([for (final e in types.entries) [e.key, e.value as String]], (k) => showMe.contains(k), (k) => showMe.contains(k) ? showMe.remove(k) : showMe.add(k)),
        h('Âge'),
        Row(children: [Text('${age.start.round()}'), Expanded(child: RangeSlider(values: age, min: 18, max: 99, divisions: 81, onChanged: (v) => setState(() => age = v))), Text('${age.end.round()}')]),
        h('Localisation'),
        PlacePicker(key: ValueKey(place), value: place, any: true, geo: false, onChanged: (_) => setState(() {})),
        h('Distance'),
        if (!hasLoc) Text(tr('Indiquez votre position pour chercher autour de vous. Elle reste approximative (à 1 km près) et n’est jamais affichée.'), style: TextStyle(color: c.mute, fontSize: 13))
        else ...[
          Row(children: [Text(tr('Distance maximale'), style: TextStyle(color: c.mute)), const Spacer(),
            Text(km > 0 ? '${tr('à moins de')} $km km' : tr('Peu importe'), style: const TextStyle(color: LvColors.red, fontWeight: FontWeight.w700))]),
          Slider(value: kmToPos(km), min: 0, max: 100, onChanged: (v) => setState(() => f['max_km'] = posToKm(v))),
        ],
        h('Activité'),
        chips([['', 'Peu importe'], ['online', 'En ligne'], ['24h', 'Actif 24 h'], ['7d', 'Actif 7 jours'], ['30d', 'Actif 30 jours']], (k) => (f['active'] ?? '') == k, (k) => f['active'] = k),
        h('Profil'),
        for (final o in [['new_members', 'Nouveaux membres', 'Inscrits depuis moins de 30 jours'], ['with_private', 'Avec album privé', ''], ['with_bio', 'Avec une présentation', 'Bio d’au moins quelques lignes']])
          SwitchListTile(contentPadding: EdgeInsets.zero, value: f[o[0]] == true, title: Text(tr(o[1])), subtitle: o[2].isEmpty ? null : Text(tr(o[2])), onChanged: (v) => setState(() => f[o[0]] = v)),
        h('Envies en commun'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final i in interests) FilterChip(label: Text(tr(i)), selected: (f['interests'] as List).contains(i),
            labelStyle: TextStyle(color: (f['interests'] as List).contains(i) ? Colors.white : null),
            onSelected: (v) => setState(() => v ? (f['interests'] as List).add(i) : (f['interests'] as List).remove(i)))]),
        h('Trier par'),
        chips([['', 'Pertinence'], ['distance', 'Les plus proches'], ['new', 'Nouveautés'], ['recent', 'Activité récente']], (k) => (f['sort'] ?? '') == k, (k) => f['sort'] = k),
      ])),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: SizedBox(width: double.infinity,
          child: FilledButton(onPressed: busy ? null : save, child: Text(tr('Afficher les profils')))))),
    ]));
  }
}
