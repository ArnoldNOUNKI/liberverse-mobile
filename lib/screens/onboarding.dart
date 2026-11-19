// Parcours d'activation : e-mail à confirmer → photo + selfie de vérification → adhésion
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/photos.dart';
import 'membership.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final idx = {'email': 1, 'verify': 2, 'subscribe': 3}[s.step] ?? 1;
    return Scaffold(
      appBar: AppBar(title: const LiberLogo(size: 19), actions: [
        IconButton(tooltip: tr('Se déconnecter'), icon: const Icon(Icons.logout_rounded), onPressed: () => s.logout()),
      ]),
      body: RefreshIndicator(onRefresh: s.loadMe, child: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 30), children: [
        Row(children: [for (var i = 1; i <= 3; i++) Expanded(child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: i <= idx ? LvColors.red : c.line, borderRadius: BorderRadius.circular(9))))]),
        const SizedBox(height: 18),
        if (s.step == 'email') const _EmailStep(),
        if (s.step == 'verify') const _VerifyStep(),
        if (s.step == 'subscribe') ...[
          Text(tr('Choisissez votre adhésion pour accéder aux rencontres.'), style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          const PlansList(),
        ],
      ])),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep();
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Confirmez votre adresse e-mail'), style: const TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('${tr('Un lien a été envoyé à')} ${s.user['email']}', style: TextStyle(color: LvColors.of(context).mute)),
      const SizedBox(height: 16),
      Row(children: [
        OutlinedButton(onPressed: () => guard(context, () => Api.I.post('/auth/resend-verification'), ok: 'Lien renvoyé'), child: Text(tr('Renvoyer le lien'))),
        const SizedBox(width: 10),
        FilledButton(onPressed: () => s.loadMe(), style: FilledButton.styleFrom(minimumSize: const Size(0, 46)), child: Text(tr('Continuer'))),
      ]),
    ]));
  }
}

class _VerifyStep extends StatefulWidget {
  const _VerifyStep();
  @override
  State<_VerifyStep> createState() => _VerifyStepState();
}

class _VerifyStepState extends State<_VerifyStep> {
  bool busy = false;
  Future<void> upload(String path, {Map<String, String> fields = const {}, bool selfie = false}) async {
    final f = await pickImage(context, front: selfie);
    if (f == null || !mounted) return;
    setState(() => busy = true);
    final ok = await guard(context, () => Api.I.upload(path, f, fields: fields), ok: selfie ? 'Selfie envoyé à la modération' : 'Photo ajoutée');
    if (ok != null && mounted) await context.read<AppState>().loadMe();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final photos = ((s.me?['media'] as List?) ?? []).where((m) => m['kind'] == 'profile').toList();
    final status = s.user['verification_status'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Vérification de votre profil'), style: const TextStyle(fontFamily: kSerif, fontSize: 26, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(tr('Pour protéger la communauté, chaque membre est vérifié par notre équipe avant d’accéder aux rencontres.'), style: TextStyle(color: c.mute)),
      const SizedBox(height: 16),
      if (status == 'rejected' && s.user['verification_note'] != null)
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: c.redLight, borderRadius: BorderRadius.circular(12)),
            child: Text('${tr('Vérification refusée :')} ${s.user['verification_note']}')),
      SectionCard(title: '1 · Vos photos de profil', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (photos.isNotEmpty) SizedBox(height: 96, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final m in photos) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: MediaImage(m['id'], width: 78, height: 96))),
        ])),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: busy ? null : () => upload('/me/photos', fields: {'kind': 'profile'}), icon: const Icon(Icons.add_a_photo_rounded), label: Text(tr('Ajouter une photo'))),
      ])),
      SectionCard(title: '2 · Selfie de vérification', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (status == 'pending') Text(tr('Votre selfie est entre les mains de la modération (en général sous 24 h). Vous recevrez un e-mail.'))
        else ...[
          Text(tr('Prenez-vous en photo (les deux partenaires pour un couple) en tenant une feuille où est écrit à la main :')),
          const SizedBox(height: 10),
          Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(border: Border.all(color: LvColors.red, width: 1.5), borderRadius: BorderRadius.circular(12)),
              child: Text('LIBERVERSE · ${s.user['verification_code'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2, color: LvColors.red)))),
          const SizedBox(height: 8),
          Text(tr('Ce selfie n’est jamais visible des autres membres. Visage visible, sans filtre.'), style: TextStyle(color: c.mute, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy || photos.isEmpty ? null : () => upload('/me/verification', selfie: true), icon: const Icon(Icons.photo_camera_front_rounded), label: Text(tr('Envoyer mon selfie'))),
          if (photos.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('Ajoutez d’abord au moins une photo de profil'), style: TextStyle(color: c.mute, fontSize: 12.5))),
        ],
      ])),
    ]);
  }
}
