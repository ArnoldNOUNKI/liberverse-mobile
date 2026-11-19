// Connexion, mot de passe oublié et inscription en 3 étapes (fenêtres sur fond blanc, comme le site)
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/place_picker.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false, hide = true;
  String? err;

  Future<void> login() async {
    setState(() { busy = true; err = null; });
    try {
      await Api.I.post('/auth/login', {'email': email.text.trim(), 'password': pass.text});
      if (!mounted) return;
      await context.read<AppState>().loadMe();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiError catch (e) { setState(() => err = tr(e.message)); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> forgot() async {
    final c = TextEditingController(text: email.text);
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Mot de passe oublié'), style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            TextField(controller: c, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('E-mail'))),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Recevoir un lien'))),
          ])));
    if (ok != true || !mounted) return;
    await guard(context, () => Api.I.post('/auth/forgot', {'email': c.text.trim()}), ok: 'Si un compte existe pour cette adresse, un lien vient d’être envoyé.');
  }

  @override
  Widget build(BuildContext context) => Theme(data: buildTheme(Brightness.light), child: Scaffold(
        appBar: AppBar(),
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          const Align(alignment: Alignment.centerLeft, child: LiberLogo(size: 20)),
          const SizedBox(height: 26),
          Text(tr('Connexion'), style: const TextStyle(fontFamily: kSerif, fontSize: 32, fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: tr('E-mail'))),
          const SizedBox(height: 12),
          TextField(controller: pass, obscureText: hide, autofillHints: const [AutofillHints.password], onSubmitted: (_) => login(),
              decoration: InputDecoration(labelText: tr('Mot de passe'),
                  suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded), onPressed: () => setState(() => hide = !hide)))),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: LvColors.red))),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : login, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(tr('Se connecter'))),
          TextButton(onPressed: forgot, child: Text(tr('Mot de passe oublié ?'))),
        ]),
      ));
}

class RegisterScreen extends StatefulWidget {
  final String code, sponsor;
  const RegisterScreen({super.key, required this.code, required this.sponsor});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int step = 1;
  String profileType = '';
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  DateTime? birth, birth2;
  final place = Place();
  final showMe = <String>{};
  bool consentTerms = false, consentSensitive = false, busy = false;
  String? err;

  bool get couple => profileType.startsWith('couple');
  String _d(DateTime? d) => d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> pickDate(bool second) async {
    final now = DateTime.now(), max = DateTime(now.year - 18, now.month, now.day);
    final d = await showDatePicker(context: context, firstDate: DateTime(1930), lastDate: max, initialDate: (second ? birth2 : birth) ?? DateTime(now.year - 30));
    if (d != null) setState(() => second ? birth2 = d : birth = d);
  }

  Future<void> next() async {
    setState(() => err = null);
    if (step == 1) {
      if (profileType.isEmpty) return setState(() => err = tr('Choisissez un type de profil'));
      if (name.text.trim().length < 3) return setState(() => err = tr('Pseudo : 3 à 30 caractères'));
      if (birth == null || (couple && birth2 == null)) return setState(() => err = tr('Date de naissance'));
      if (place.city.isEmpty) return setState(() => err = tr('Choisissez votre ville (ou utilisez votre position)'));
      return setState(() => step = 2);
    }
    if (step == 2) {
      if (showMe.isEmpty) return setState(() => err = tr('Choisissez au moins un type de profil recherché'));
      if (!email.text.contains('@')) return setState(() => err = tr('E-mail invalide'));
      if (pass.text.length < 8) return setState(() => err = tr('Mot de passe : 8 caractères minimum'));
      return setState(() => step = 3);
    }
    if (!consentTerms || !consentSensitive) return setState(() => err = tr('Les deux consentements sont nécessaires'));
    setState(() => busy = true);
    try {
      await Api.I.post('/auth/register', {
        'code': widget.code, 'profile_type': profileType, 'display_name': name.text.trim(), 'birthdate': _d(birth),
        if (couple) 'partner_birthdate': _d(birth2), ...place.toJson(), 'show_me': showMe.toList(),
        'email': email.text.trim(), 'password': pass.text, 'consent_terms': true, 'consent_sensitive': true,
      });
      if (!mounted) return;
      await context.read<AppState>().loadMe();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiError catch (e) { setState(() => err = tr(e.message)); }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final types = Map<String, dynamic>.from(s.ref['profile_types'] ?? {});
    return Theme(data: buildTheme(Brightness.light), child: Builder(builder: (context) {
      final c = LvColors.of(context);
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => step > 1 ? setState(() => step--) : Navigator.pop(context)),
            title: Row(children: [for (var i = 1; i <= 3; i++) Expanded(child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: i <= step ? LvColors.red : c.line, borderRadius: BorderRadius.circular(9))))])),
        body: ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: '${tr('Invité·e par')} '), TextSpan(text: widget.sponsor, style: const TextStyle(color: LvColors.red, fontWeight: FontWeight.w700)),
            TextSpan(text: ' · ${tr('code')} ${widget.code}'),
          ]), style: TextStyle(color: c.mute, fontSize: 13)),
          const SizedBox(height: 10),
          if (step == 1) ...[
            _h(tr('Qui êtes-vous ?')),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final e in types.entries) ChoiceChip(label: Text(tr(e.value)), selected: profileType == e.key,
                labelStyle: TextStyle(color: profileType == e.key ? Colors.white : null), onSelected: (_) => setState(() => profileType = e.key))]),
            const SizedBox(height: 16),
            TextField(controller: name, maxLength: 30, decoration: InputDecoration(labelText: tr('Pseudo'), hintText: tr('ex. Lina & Marc'), counterText: '')),
            const SizedBox(height: 12),
            _dateField(couple ? tr('Date de naissance (partenaire 1)') : tr('Date de naissance'), birth, () => pickDate(false)),
            if (couple) _dateField(tr('Date de naissance (partenaire 2)'), birth2, () => pickDate(true)),
            const SizedBox(height: 8),
            _h(tr('Où êtes-vous ?'), size: 18),
            PlacePicker(value: place, autoLocate: true, onChanged: (_) => setState(() {})),
          ],
          if (step == 2) ...[
            _h(tr('Vous souhaitez rencontrer')),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final e in types.entries) FilterChip(label: Text(tr(e.value)), selected: showMe.contains(e.key),
                labelStyle: TextStyle(color: showMe.contains(e.key) ? Colors.white : null),
                onSelected: (v) => setState(() => v ? showMe.add(e.key) : showMe.remove(e.key)))]),
            const SizedBox(height: 18),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('E-mail (jamais affiché)'))),
            const SizedBox(height: 12),
            TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: tr('Mot de passe'), helperText: tr('8 caractères minimum'))),
          ],
          if (step == 3) ...[
            _h(tr('Dernière étape')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: consentTerms, onChanged: (v) => setState(() => consentTerms = v!),
                title: Text('${tr('Je certifie être majeur·e (ainsi que mon/ma partenaire) et j’accepte les')} ${tr('CGU & confidentialité')}${tr(', y compris la modération des échanges, photos et fichiers par l’équipe Liberverse.')}', style: const TextStyle(fontSize: 14))),
            CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: consentSensitive, onChanged: (v) => setState(() => consentSensitive = v!),
                title: Text(tr('Je consens expressément au traitement de données relatives à ma vie sexuelle, nécessaires au service (art. 9 RGPD). Je peux retirer ce consentement en supprimant mon compte.'), style: const TextStyle(fontSize: 14))),
            Text(tr('Ensuite : confirmation de l’e-mail, photo de profil et selfie de vérification, puis choix de l’adhésion.'), style: TextStyle(color: c.mute, fontSize: 13)),
          ],
          if (err != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(err!, style: const TextStyle(color: LvColors.red))),
          const SizedBox(height: 22),
          FilledButton(onPressed: busy ? null : next, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('${tr(step < 3 ? 'Continuer' : 'Créer mon compte')} →')),
        ]),
      );
    }));
  }

  Widget _h(String t, {double size = 26}) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(t, style: TextStyle(fontFamily: kSerif, fontSize: size, fontWeight: FontWeight.w600)));
  Widget _dateField(String label, DateTime? v, VoidCallback onTap) => Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: InputDecorator(decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_month_rounded)),
          child: Text(v == null ? '—' : DateFormat.yMMMMd(I18n.I.locale).format(v)))));
}
