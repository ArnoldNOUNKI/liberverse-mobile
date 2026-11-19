// Paramètres : confidentialité, localisation, notifications, langue et monnaie, apparence, discrétion, compte
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/lock.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/place_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? lock;
  bool lockAvailable = false;
  Place? loc;

  @override
  void initState() {
    super.initState();
    LockPrefs.enabled().then((v) => setState(() => lock = v));
    LockPrefs.available().then((v) => setState(() => lockAvailable = v));
  }

  Future<void> setting(AppState s, String k, bool v) async {
    if (await guard(context, () => Api.I.put('/me/settings', {k: v}), ok: 'Paramètre enregistré') != null) await s.loadMe();
  }

  Future<void> useGps(AppState s) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { if (mounted) toast(context, 'Accès à la position refusé — indiquez votre ville', error: true); return; }
    final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
    if (!mounted) return;
    if (await guard(context, () => Api.I.put('/me/location', {'lat': p.latitude, 'lng': p.longitude}), ok: 'Position enregistrée (approximative)') != null) await s.loadMe();
  }

  Widget sw(String title, String sub, bool v, ValueChanged<bool>? on) => SwitchListTile(contentPadding: EdgeInsets.zero, value: v, onChanged: on,
      title: Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: sub.isEmpty ? null : Text(tr(sub), style: const TextStyle(fontSize: 12.5)));

  Future<String?> _ask(String title, List<List<String>> fields) async {
    final ctrls = [for (final _ in fields) TextEditingController()];
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (c) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr(title), style: const TextStyle(fontFamily: kSerif, fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (var i = 0; i < fields.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10),
                child: TextField(controller: ctrls[i], obscureText: fields[i][1] == 'password', keyboardType: fields[i][1] == 'email' ? TextInputType.emailAddress : null,
                    decoration: InputDecoration(labelText: tr(fields[i][0])))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Valider'))),
          ])));
    return ok == true ? ctrls.map((c) => c.text).join('\u0000') : null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final st = Map<String, dynamic>.from(s.user['settings'] ?? {});
    final location = Map<String, dynamic>.from(s.user['location'] ?? {});
    loc ??= Place(country: s.user['country'] ?? 'FR', region: s.user['region'] ?? '', department: s.user['department'] ?? '', city: s.user['city'] ?? '');
    final rates = Map<String, dynamic>.from(s.fx?['rates'] ?? {'EUR': 1});
    return Scaffold(
      appBar: AppBar(title: Text(tr('Paramètres'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        SectionCard(title: 'Confidentialité', child: Column(children: [
          sw('Afficher mon statut « en ligne »', 'Sinon, personne ne voit quand vous êtes connecté·e', st['show_online'] == true, (v) => setting(s, 'show_online', v)),
          sw('Afficher mon âge', 'Votre âge reste utilisé pour les filtres, sans être affiché', st['show_age'] == true, (v) => setting(s, 'show_age', v)),
          sw('Afficher ma ville', 'Masquée sur votre carte et exclue des recherches par ville', st['show_city'] == true, (v) => setting(s, 'show_city', v)),
          sw('Accepter les invitations aux salons', 'Vos matchs peuvent vous inviter dans leurs salons', st['allow_salon_invites'] == true, (v) => setting(s, 'allow_salon_invites', v)),
          sw('Mode incognito', 'Seuls les profils que vous avez likés peuvent vous voir', s.user['incognito'] == true, s.plan?['incognito'] == true ? (v) => setting(s, 'incognito', v) : null),
        ])),
        SectionCard(title: 'Localisation', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(location['set'] == true ? (location['source'] == 'gps' ? tr('Position de l’appareil') : '${tr('Position depuis votre ville :')} ${location['city'] ?? ''}') : tr('Aucune position enregistrée'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(tr('Approximative (à 1 km près), jamais affichée : seule une distance arrondie est montrée aux autres membres'), style: TextStyle(color: c.mute, fontSize: 12.5)),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: () => useGps(s), icon: const Icon(Icons.my_location_rounded), label: Text(tr('📍 Utiliser la position de l’appareil').replaceFirst('📍 ', ''))),
          const SizedBox(height: 12),
          Text(tr('Ou choisissez votre ville dans les listes :'), style: TextStyle(color: c.mute, fontSize: 13)),
          const SizedBox(height: 8),
          PlacePicker(value: loc!, geo: false),
          OutlinedButton(onPressed: () async {
            if (await guard(context, () => Api.I.post('/me/location/city', loc!.toJson())) != null) await s.loadMe();
          }, child: Text(tr('Utiliser cette ville'))),
          if (location['set'] == true) TextButton(onPressed: () async { await guard(context, () => Api.I.delete('/me/location'), ok: 'Position effacée'); await s.loadMe(); }, child: Text(tr('Effacer'))),
          sw('Afficher la distance', 'Les autres voient « à 12 km » sur votre profil', st['show_distance'] == true, (v) => setting(s, 'show_distance', v)),
        ])),
        SectionCard(title: 'Notifications par e-mail', child: Column(children: [
          Text(tr('E-mails discrets : aucun pseudo, aucune photo, aucun contenu.'), style: TextStyle(color: c.mute, fontSize: 12.5)),
          sw('Nouveau match', '', st['notif_matches'] == true, (v) => setting(s, 'notif_matches', v)),
          sw('Nouveau message', 'Seulement si vous n’êtes pas connecté·e, au plus une fois par demi-heure', st['notif_messages'] == true, (v) => setting(s, 'notif_messages', v)),
          sw('Nouveau like', 'Au plus une fois par heure', st['notif_likes'] == true, (v) => setting(s, 'notif_likes', v)),
          sw('Salons', 'Invitations et nouvelles soirées', st['notif_salons'] == true, (v) => setting(s, 'notif_salons', v)),
        ])),
        SectionCard(title: 'Langue et monnaie', child: Column(children: [
          DropdownButtonFormField<String>(initialValue: I18n.I.auto ? '' : I18n.I.lang, decoration: InputDecoration(labelText: tr('Langue de l’interface')),
              items: [DropdownMenuItem(value: '', child: Text(tr('Automatique (appareil)'))), for (final e in kLanguages.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => s.setLang(v == '' ? null : v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: s.user['currency'] ?? '', isExpanded: true, decoration: InputDecoration(labelText: tr('Monnaie d’affichage')),
              items: [DropdownMenuItem(value: '', child: Text(tr('Automatique (selon mon pays)'))), for (final k in (rates.keys.toList()..sort())) DropdownMenuItem(value: k, child: Text(k))],
              onChanged: (v) async { await guard(context, () => Api.I.put('/me/prefs', {'currency': v == '' ? null : v})); s.fx = null; await s.loadMe(); }),
          const SizedBox(height: 6),
          Text(tr('Prix indicatifs convertis au taux du jour — le paiement est effectué en euros.'), style: TextStyle(color: c.mute, fontSize: 12.5)),
        ])),
        SectionCard(title: 'Apparence', child: SegmentedButton<String>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(selectedBackgroundColor: LvColors.red, selectedForegroundColor: Colors.white),
          segments: [ButtonSegment(value: 'light', label: Text(tr('Clair')), icon: const Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: 'dark', label: Text(tr('Sombre')), icon: const Icon(Icons.dark_mode_outlined)),
            ButtonSegment(value: 'system', label: Text(tr('Système')), icon: const Icon(Icons.brightness_auto_outlined))],
          selected: {s.themeName}, onSelectionChanged: (v) => s.setTheme(v.first),
        )),
        SectionCard(title: 'Discrétion sur cet appareil', child: Column(children: [
          sw('Verrouillage par empreinte / Face ID', lockAvailable ? 'Demandé à l’ouverture de l’app et après 30 secondes en arrière-plan' : 'Indisponible sur cet appareil', lock == true,
              lockAvailable ? (v) async { final ok = await LockPrefs.setEnabled(v); if (!context.mounted) return; if (!ok) toast(context, 'Déverrouillage annulé', error: true); setState(() => lock = ok ? v : lock); } : null),
        ])),
        SectionCard(title: 'Compte', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Adresse e-mail')), subtitle: Text(s.user['email'] ?? ''), trailing: TextButton(child: Text(tr('Modifier')), onPressed: () async {
            final r = await _ask('Changer d’e-mail', [['Nouvelle adresse', 'email'], ['Mot de passe actuel', 'password']]);
            if (r == null || !context.mounted) return;
            final v = r.split('\u0000');
            if (await guard(context, () => Api.I.put('/me/email', {'email': v[0], 'password': v[1]}), ok: 'Adresse modifiée') != null) await s.loadMe();
          })),
          ListTile(contentPadding: EdgeInsets.zero, title: Text(tr('Mot de passe')), trailing: TextButton(child: Text(tr('Modifier')), onPressed: () async {
            final r = await _ask('Mot de passe', [['Mot de passe actuel', 'password'], ['Nouveau (8 car. min.)', 'password']]);
            if (r == null || !context.mounted) return;
            final v = r.split('\u0000');
            await guard(context, () => Api.I.put('/me/password', {'current': v[0], 'password': v[1]}), ok: 'Mot de passe modifié');
          })),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => s.logout().then((_) { if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst); }), icon: const Icon(Icons.logout_rounded), label: Text(tr('Se déconnecter'))),
          const SizedBox(height: 8),
          TextButton(style: TextButton.styleFrom(foregroundColor: LvColors.red), onPressed: () async {
            if (!await confirmDialog(context, 'Votre profil, vos photos, fichiers et messages seront définitivement effacés.', ok: 'Supprimer définitivement', danger: true) || !context.mounted) return;
            final r = await _ask('Supprimer mon compte', [['Mot de passe', 'password']]);
            if (r == null || !context.mounted) return;
            if (await guard(context, () => Api.I.delete('/me', {'password': r})) != null) {
              await s.logout();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          }, child: Text(tr('Supprimer mon compte'))),
        ])),
      ]),
    );
  }
}
