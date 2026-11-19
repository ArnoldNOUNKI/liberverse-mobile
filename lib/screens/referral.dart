// Parrainage : 5 invitations par membre, codes à usage unique valables 30 jours, partage
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final inv = Map<String, dynamic>.from(s.me?['invites'] ?? {});
    final codes = ((inv['codes'] as List?) ?? []).where((x) => x['revoked'] != true).toList();
    final filleuls = (inv['filleuls'] as List?) ?? [];
    final remaining = (inv['remaining'] ?? 0) as int;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Parrainage'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Text(tr('Chaque invitation est un code à usage unique, valable 30 jours. Vous êtes garant·e des personnes que vous cooptez : 5 personnes maximum.'), style: TextStyle(color: c.mute)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: SectionCard(child: Column(children: [Text('$remaining', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: LvColors.red)), Text(tr('Invitations disponibles'), textAlign: TextAlign.center, style: TextStyle(color: c.mute, fontSize: 12.5))]))),
          const SizedBox(width: 10),
          Expanded(child: SectionCard(child: Column(children: [Text('${filleuls.length}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), Text(tr('Filleuls'), style: TextStyle(color: c.mute, fontSize: 12.5))]))),
        ]),
        FilledButton.icon(onPressed: remaining <= 0 ? null : () async {
          final r = await guard(context, () => Api.I.post('/me/invites', {}));
          if (r != null && context.mounted) { await Clipboard.setData(ClipboardData(text: '${r['code']}  —  $kBaseUrl/?code=${r['code']}')); if (context.mounted) toast(context, 'Lien copié'); await s.loadMe(); }
        }, icon: const Icon(Icons.add_rounded), label: Text(tr('+ Créer une invitation').replaceFirst('+ ', ''))),
        const SizedBox(height: 18),
        SectionCard(title: 'Mes codes', child: codes.isEmpty ? Text(tr('Aucun code pour l’instant.'), style: TextStyle(color: c.mute)) : Column(children: [
          for (final k in codes) ListTile(contentPadding: EdgeInsets.zero,
            title: Text(k['code'], style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            subtitle: Text((k['uses'] ?? 0) >= (k['max_uses'] ?? 1) ? tr('utilisé') : tr('en attente')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: tr('Copier le lien'), icon: const Icon(Icons.copy_rounded), onPressed: () async {
                await Clipboard.setData(ClipboardData(text: '$kBaseUrl/?code=${k['code']}')); if (context.mounted) toast(context, 'Lien copié');
              }),
              if ((k['uses'] ?? 0) == 0) IconButton(tooltip: tr('Supprimer'), icon: const Icon(Icons.delete_outline_rounded), onPressed: () async {
                await guard(context, () => Api.I.delete('/me/invites/${k['code']}')); await s.loadMe();
              }),
            ])),
        ])),
        SectionCard(title: 'Mes filleuls', child: filleuls.isEmpty ? Text(tr('Personne pour l’instant.'), style: TextStyle(color: c.mute)) : Column(children: [
          for (final f in filleuls) ListTile(contentPadding: EdgeInsets.zero, title: Text(f['display_name']), subtitle: Text(s.profileType(f['profile_type'])),
              trailing: f['verification_status'] == 'approved' ? const VerifiedTick() : Pill('En cours d’examen')),
        ])),
      ]),
    );
  }
}
