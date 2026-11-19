// Adhésion : offres (prix en euros + équivalent local), paiement, historique
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class PlansList extends StatefulWidget {
  const PlansList({super.key});
  @override
  State<PlansList> createState() => _PlansListState();
}

class _PlansListState extends State<PlansList> {
  List plans = [];
  String provider = 'demo';
  String? busy;
  @override
  void initState() {
    super.initState();
    Api.I.get('/billing/plans').then((r) { if (mounted) setState(() { plans = r['plans']; provider = r['provider']; }); }).catchError((_) {});
  }

  Future<void> buy(Map p) async {
    setState(() => busy = p['id']);
    final r = await guard(context, () => Api.I.post('/billing/checkout', {'plan_id': p['id']}));
    if (r != null && mounted) {
      if (r['url'] != null) {
        await launchUrl(Uri.parse(r['url']), mode: LaunchMode.externalApplication);
      } else if (r['paid'] == true) {
        toast(context, 'Paiement reçu — bienvenue !');
        await context.read<AppState>().loadMe();
      }
    }
    if (mounted) setState(() => busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    if (plans.isEmpty) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    return Column(children: [
      if (provider == 'demo') Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(tr('Mode démonstration : le paiement est simulé.'), style: TextStyle(color: c.mute, fontSize: 13))),
      for (final p in plans) Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p['id'] == 'premium' ? LvColors.red : (p['id'] as String).startsWith('prestige') ? LvColors.goldDeep : c.line, width: p['id'] == 'premium' ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr(p['name']), style: const TextStyle(fontFamily: kSerif, fontSize: 22, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (p['id'] == 'premium') Pill('LE PLUS CHOISI', bg: LvColors.red, fg: Colors.white),
          ]),
          const SizedBox(height: 4),
          Text(s.price(p['price_cents']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: LvColors.red)),
          Text((p['period_days'] as int) >= 365 ? tr('12 mois — 2 mois offerts') : tr('par mois · sans engagement'), style: TextStyle(color: c.mute, fontSize: 13)),
          const SizedBox(height: 10),
          for (final f in (p['features'] as List)) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            const Icon(Icons.check_rounded, size: 18, color: LvColors.red), const SizedBox(width: 8), Expanded(child: Text(tr(f))),
          ])),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: busy != null ? null : () => buy(p),
            child: busy == p['id'] ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr(s.plan?['id'] == p['id'] ? 'Prolonger' : 'Choisir')),
          )),
        ]),
      ),
      if (s.currency != 'EUR') Text(tr('Prix indicatifs convertis au taux du jour — le paiement est effectué en euros.'), textAlign: TextAlign.center, style: TextStyle(color: c.mute, fontSize: 12.5)),
    ]);
  }
}

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  List history = [];
  @override
  void initState() {
    super.initState();
    Api.I.get('/billing/history').then((r) { if (mounted) setState(() => history = r is List ? r : (r['payments'] ?? [])); }).catchError((_) {});
  }
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mon adhésion'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        SectionCard(title: 'Adhésion en cours', child: s.plan == null
            ? Text(tr('Sans adhésion'), style: TextStyle(color: c.mute))
            : Row(children: [
                Expanded(child: Text(tr(s.plan!['name']), style: const TextStyle(fontFamily: kSerif, fontSize: 22, fontWeight: FontWeight.w700))),
                Text('${tr('Valable jusqu’au')} ${dateLong(s.plan!['expires_at']).split(' ').take(4).join(' ')}', style: TextStyle(color: c.mute, fontSize: 13)),
              ])),
        const PlansList(),
        if (history.isNotEmpty) SectionCard(title: 'Historique', child: Column(children: [
          for (final h in history) ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(tr(h['plan_name'] ?? '')),
              subtitle: Text(dateLong(h['created_at'])), trailing: Text(s.price(h['amount_cents'] ?? 0))),
        ])),
      ]),
    );
  }
}
