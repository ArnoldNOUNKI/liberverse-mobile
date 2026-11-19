// Mon profil : aperçu, présentation, envies, ville, photos de profil et album privé ; accès aux paramètres, parrainage, adhésion
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/photos.dart';
import '../widgets/place_picker.dart';
import 'membership.dart';
import 'referral.dart';
import 'settings.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final name = TextEditingController(), bio = TextEditingController();
  late Set<String> interests;
  late Place place;
  bool dirty = false, busy = false;
  String? _loadedFor;

  void _fill(AppState s) {
    final u = s.user;
    if (_loadedFor == u['id'] && !dirty) return;
    _loadedFor = u['id'];
    name.text = u['display_name'] ?? '';
    bio.text = u['bio'] ?? '';
    interests = Set<String>.from(u['interests'] ?? []);
    place = Place(country: u['country'] ?? 'FR', region: u['region'] ?? '', department: u['department'] ?? '', city: u['city'] ?? '');
  }

  Future<void> save(AppState s) async {
    setState(() => busy = true);
    final u = s.user;
    final ok = await guard(context, () => Api.I.put('/me', {
      'display_name': name.text.trim(), 'bio': bio.text.trim(), 'interests': interests.toList(), 'show_me': u['show_me'], 'age_min': u['age_min'], 'age_max': u['age_max'],
      'incognito': u['incognito'], 'country': place.country, 'region': place.region, 'department': place.department, 'city': place.city,
    }), ok: 'Profil enregistré');
    if (ok != null) { dirty = false; await s.loadMe(); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> addPhoto(AppState s, String kind) async {
    final f = await pickImage(context);
    if (f == null || !mounted) return;
    if (await guard(context, () => Api.I.upload('/me/photos', f, fields: {'kind': kind}), ok: 'Photo ajoutée') != null) await s.loadMe();
  }

  void photoMenu(AppState s, Map m) => showModalBottomSheet(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (m['kind'] == 'profile' && m['is_primary'] != true) ListTile(leading: const Icon(Icons.star_rounded), title: Text(tr('Photo principale')), onTap: () async {
          Navigator.pop(c); await guard(context, () => Api.I.post('/me/photos/${m['id']}/primary')); await s.loadMe();
        }),
        ListTile(leading: const Icon(Icons.delete_outline_rounded, color: LvColors.red), title: Text(tr('Supprimer'), style: const TextStyle(color: LvColors.red)), onTap: () async {
          Navigator.pop(c);
          if (await confirmDialog(context, 'Supprimer cette photo ?', danger: true, ok: 'Supprimer') && mounted) { await guard(context, () => Api.I.delete('/me/photos/${m['id']}')); await s.loadMe(); }
        }),
      ])));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    _fill(s);
    final media = ((s.me?['media'] as List?) ?? []).cast<Map>();
    final photos = media.where((m) => m['kind'] == 'profile').toList();
    final priv = media.where((m) => m['kind'] == 'private').toList();
    final primary = photos.where((m) => m['is_primary'] == true).map((m) => m['id'] as String?).firstOrNull ?? (photos.isNotEmpty ? photos.first['id'] as String? : null);
    final allInterests = List<String>.from(s.ref['interests'] ?? []);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Mon profil')), actions: [
        IconButton(tooltip: tr('Paramètres'), icon: const Icon(Icons.settings_outlined), onPressed: () => push(const SettingsScreen())),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: LvColors.red, width: 2)), child: Avatar(primary, size: 78)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text(s.user['display_name'] ?? '', style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w700))),
              if (s.user['verification_status'] == 'approved') ...[const SizedBox(width: 6), const VerifiedTick()]]),
            Text('${s.profileType(s.user['profile_type'])} · ${s.user['age'] ?? ''} ${tr('ans')}', style: TextStyle(color: c.mute)),
            const SizedBox(height: 6),
            Pill(s.plan == null ? 'Sans adhésion' : s.plan!['name'], bg: s.plan == null ? null : LvColors.goldDeep, fg: s.plan == null ? null : Colors.white),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => push(const ReferralScreen()), icon: const Icon(Icons.card_giftcard_rounded, size: 18), label: Text(tr('Parrainage')))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => push(const MembershipScreen()), icon: const Icon(Icons.diamond_outlined, size: 18), label: Text(tr('Adhésion')))),
        ]),
        const SizedBox(height: 16),
        SectionCard(title: 'Photos de profil', child: _photoGrid(s, photos, 'profile', 9)),
        SectionCard(title: 'Présentation', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: name, maxLength: 30, onChanged: (_) => setState(() => dirty = true), decoration: InputDecoration(labelText: tr('Pseudo'), counterText: '')),
          const SizedBox(height: 12),
          TextField(controller: bio, minLines: 3, maxLines: 8, maxLength: 1500, onChanged: (_) => setState(() => dirty = true),
              decoration: InputDecoration(labelText: tr('Bio'), hintText: tr('Ce que vous aimez, ce que vous recherchez, vos limites…'), alignLabelWithHint: true)),
          Text(tr('Envies'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final i in allInterests) FilterChip(label: Text(tr(i)), selected: interests.contains(i),
              labelStyle: TextStyle(color: interests.contains(i) ? Colors.white : null),
              onSelected: (v) => setState(() { v ? interests.add(i) : interests.remove(i); dirty = true; }))]),
        ])),
        SectionCard(title: 'Adresse (ville)', child: PlacePicker(value: place, onChanged: (_) => setState(() => dirty = true))),
        SectionCard(title: 'Album privé', child: s.plan?['private_album'] == true || s.user['role'] != 'member'
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr('— visible uniquement de vos matchs'), style: TextStyle(color: c.mute, fontSize: 13)), const SizedBox(height: 8), _photoGrid(s, priv, 'private', 30)])
            : Text(tr('L’album privé est inclus dans Premium et Prestige'), style: TextStyle(color: c.mute))),
      ]),
      floatingActionButton: dirty ? FloatingActionButton.extended(backgroundColor: LvColors.red, foregroundColor: Colors.white,
          onPressed: busy ? null : () => save(s), icon: const Icon(Icons.check_rounded), label: Text(tr('Enregistrer'))) : null,
    );
  }

  Widget _photoGrid(AppState s, List<Map> items, String kind, int max) => GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .8,
        children: [
          for (final m in items) GestureDetector(onTap: () => photoMenu(s, m), child: Stack(fit: StackFit.expand, children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: MediaImage(m['id'])),
            if (m['is_primary'] == true) Positioned(left: 6, bottom: 6, child: Pill('principale', bg: LvColors.red, fg: Colors.white)),
            if (m['hidden'] == true) Positioned(right: 6, top: 6, child: Pill('masquée', bg: Colors.black54, fg: Colors.white)),
          ])),
          if (items.length < max) InkWell(borderRadius: BorderRadius.circular(14), onTap: () => addPhoto(s, kind), child: DottedBox(child: Icon(Icons.add_a_photo_outlined, color: LvColors.of(context).mute))),
        ],
      );
}

class DottedBox extends StatelessWidget {
  final Widget child;
  const DottedBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: LvColors.of(context).soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: LvColors.of(context).field, width: 1.4)),
      child: Center(child: child));
}
