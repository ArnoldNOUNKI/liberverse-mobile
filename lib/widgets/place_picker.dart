// Pays → région → département → ville (listes alphabétiques du serveur, recherche intégrée) + remplissage par la position GPS.
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';

class Place {
  String country, region, department, city;
  double? lat, lng;
  Place({this.country = 'FR', this.region = '', this.department = '', this.city = '', this.lat, this.lng});
  Map<String, dynamic> toJson() => {'country': country, 'region': region, 'department': department, 'city': city, if (lat != null) 'lat': lat, if (lng != null) 'lng': lng};
}

class PlacePicker extends StatefulWidget {
  final Place value;
  final bool geo; // bouton « ma position »
  final bool any; // filtres : « Tous » autorisé
  final bool autoLocate;
  final ValueChanged<Place>? onChanged;
  const PlacePicker({super.key, required this.value, this.geo = true, this.any = false, this.autoLocate = false, this.onChanged});
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  static List? _countries;
  List<String> regions = [], depts = [];
  bool locating = false;
  String? geoMsg;
  Place get p => widget.value;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoLocate && p.city.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => locate(silent: true));
  }

  Future<void> _load() async {
    _countries ??= await Api.I.get('/places/countries', auth401: false).catchError((_) => []);
    if (p.country.isNotEmpty) {
      regions = List<String>.from(await Api.I.get('/places/regions', query: {'country': p.country}, auth401: false));
      depts = List<String>.from(await Api.I.get('/places/departments', query: {'country': p.country, 'region': p.region}, auth401: false));
    } else { regions = []; depts = []; }
    if (mounted) setState(() {});
  }

  void _changed() { widget.onChanged?.call(p); setState(() {}); }

  String _countryName(String code) {
    final c = (_countries ?? []).firstWhere((x) => x['code'] == code, orElse: () => null);
    return c == null ? code : c['name'];
  }

  Future<void> locate({bool silent = false}) async {
    setState(() { locating = true; geoMsg = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw ApiError(0, 'Accès à la position refusé — choisissez votre ville dans les listes');
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)));
      final r = await Api.I.get('/places/reverse', query: {'lat': pos.latitude, 'lng': pos.longitude}, auth401: false);
      p..country = r['country']..region = r['region'] ?? ''..department = r['dept'] ?? ''..city = r['name']
        ..lat = (pos.latitude * 100).round() / 100..lng = (pos.longitude * 100).round() / 100;
      geoMsg = '📍 ${r['name']}${(r['dept'] ?? '') != '' ? ', ${r['dept']}' : ''} — ${tr('vous pouvez corriger ci-dessous')}';
      await _load();
      _changed();
    } on ApiError catch (e) {
      if (!silent) geoMsg = tr(e.message);
    } catch (_) {
      if (!silent) geoMsg = tr('Position indisponible pour le moment');
    }
    if (mounted) setState(() => locating = false);
  }

  Future<String?> _pick(String title, List<String> items, {String? anyLabel, List<String>? labels}) => showModalBottomSheet<String>(
        context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => _SearchList(title: title, items: items, labels: labels, anyLabel: anyLabel));

  @override
  Widget build(BuildContext context) {
    final fr = p.country == 'FR';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.geo) OutlinedButton.icon(
          onPressed: locating ? null : () => locate(),
          icon: locating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(tr(locating ? 'Localisation en cours…' : 'Remplir avec ma position actuelle'))),
      if (geoMsg != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(geoMsg!, style: TextStyle(fontSize: 12.5, color: LvColors.of(context).mute))),
      const SizedBox(height: 10),
      _Field(label: tr('Pays'), value: p.country.isEmpty ? (widget.any ? tr('Tous les pays') : '') : _countryName(p.country), onTap: () async {
        final list = _countries ?? [];
        final v = await _pick(tr('Pays'), [for (final c in list) c['code'] as String], labels: [for (final c in list) c['name'] as String], anyLabel: widget.any ? tr('Tous les pays') : null);
        if (v == null) return;
        p..country = v..region = ''..department = ''..city = ''..lat = null..lng = null;
        await _load(); _changed();
      }),
      if (regions.isNotEmpty) _Field(label: tr(fr ? 'Région' : 'Région / État'), value: p.region.isEmpty ? (widget.any ? tr('Toutes les régions') : '') : p.region, onTap: () async {
        final v = await _pick(tr('Région'), regions, anyLabel: widget.any ? tr('Toutes les régions') : null);
        if (v == null) return;
        p..region = v..department = ''..city = ''..lat = null..lng = null;
        await _load(); _changed();
      }),
      if (depts.isNotEmpty) _Field(label: tr(fr ? 'Département' : 'Province / district'), value: p.department.isEmpty ? (widget.any ? tr('Tous') : '') : p.department, onTap: () async {
        final v = await _pick(tr('Département'), depts, anyLabel: widget.any ? tr('Tous') : null);
        if (v == null) return;
        p..department = v..city = ''..lat = null..lng = null; _changed();
      }),
      _Field(label: tr('Ville'), value: p.city.isEmpty ? (widget.any ? tr('Toutes les villes') : '') : p.city, enabled: p.country.isNotEmpty, onTap: () async {
        final v = await showModalBottomSheet<Map>(context: context, isScrollControlled: true, useSafeArea: true,
            builder: (_) => _CityList(country: p.country, region: p.region, department: p.department, any: widget.any));
        if (v == null) return;
        p.city = v['name'] ?? '';
        if ((v['region'] ?? '') != '' && p.region.isEmpty) p.region = v['region'];
        if ((v['dept'] ?? '') != '' && p.department.isEmpty) p.department = v['dept'];
        p..lat = null..lng = null; _changed();
      }),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  final bool enabled;
  const _Field({required this.label, required this.value, required this.onTap, this.enabled = true});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
        borderRadius: BorderRadius.circular(12), onTap: enabled ? onTap : null,
        child: InputDecorator(decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.expand_more_rounded)),
            child: Text(value.isEmpty ? tr(enabled ? 'Choisir…' : 'Choisissez d’abord le pays') : value,
                style: TextStyle(fontSize: 15.5, color: value.isEmpty ? LvColors.of(context).mute : null)))));
}

class _SearchList extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String>? labels;
  final String? anyLabel;
  const _SearchList({required this.title, required this.items, this.labels, this.anyLabel});
  @override
  State<_SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<_SearchList> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final labels = widget.labels ?? widget.items;
    final idx = [for (var i = 0; i < labels.length; i++) if (q.isEmpty || labels[i].toLowerCase().contains(q.toLowerCase())) i];
    return SizedBox(height: MediaQuery.of(context).size.height * .82, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(autofocus: false, onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(hintText: widget.title, prefixIcon: const Icon(Icons.search_rounded)))),
      Expanded(child: ListView(children: [
        if (widget.anyLabel != null && q.isEmpty) ListTile(title: Text(widget.anyLabel!, style: const TextStyle(fontWeight: FontWeight.w600)), onTap: () => Navigator.pop(context, '')),
        for (final i in idx) ListTile(title: Text(labels[i]), onTap: () => Navigator.pop(context, widget.items[i])),
      ])),
    ]));
  }
}

class _CityList extends StatefulWidget {
  final String country, region, department;
  final bool any;
  const _CityList({required this.country, required this.region, required this.department, required this.any});
  @override
  State<_CityList> createState() => _CityListState();
}

class _CityListState extends State<_CityList> {
  List cities = [];
  bool loading = true;
  String q = '';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      cities = await Api.I.get('/places/cities', query: {'country': widget.country, 'region': widget.region, 'department': widget.department, 'q': q}, auth401: false);
    } catch (_) { cities = []; }
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) => SizedBox(height: MediaQuery.of(context).size.height * .82, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(onChanged: (v) { q = v; _load(); },
            decoration: InputDecoration(hintText: tr('Rechercher une ville…'), prefixIcon: const Icon(Icons.search_rounded)))),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: cities.isEmpty && !loading ? EmptyState(icon: Icons.location_city_rounded, text: 'Aucune ville trouvée à proximité') : ListView(children: [
          if (widget.any && q.isEmpty) ListTile(title: Text(tr('Toutes les villes'), style: const TextStyle(fontWeight: FontWeight.w600)), onTap: () => Navigator.pop(context, {'name': ''})),
          for (final c in cities) ListTile(title: Text(c['name']), subtitle: widget.department.isEmpty && (c['dept'] ?? '') != '' ? Text(c['dept']) : null,
              onTap: () => Navigator.pop(context, Map.from(c))),
        ])),
      ]));
}
