// « Ils vous ont liké » : visible avec Premium / Prestige, sinon aperçu flouté et invitation à passer à l'offre supérieure
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'discover.dart';
import 'membership.dart';
import 'profile_view.dart';

class LikesScreen extends StatefulWidget {
  final bool active;
  const LikesScreen({super.key, required this.active});
  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  Map<String, dynamic>? data;
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(LikesScreen old) { super.didUpdateWidget(old); if (widget.active && !old.active) load(); }
  Future<void> load() async {
    try { final r = await Api.I.get('/discover/likes'); if (mounted) setState(() => data = Map<String, dynamic>.from(r)); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profiles = (data?['profiles'] as List?) ?? [];
    final locked = data?['locked'] == true;
    return Scaffold(
      appBar: AppBar(title: Text('${tr('Ils vous ont liké')}${data != null ? ' (${data!['count'] ?? profiles.length})' : ''}')),
      body: data == null ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: locked
          ? ListView(padding: const EdgeInsets.all(20), children: [
              SizedBox(height: 260, child: GridView.count(physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, children: [
                for (var i = 0; i < ((data!['count'] ?? 0) as int).clamp(3, 6); i++) ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: const MediaImage(null))),
              ])),
              const SizedBox(height: 16),
              Text(tr('Passez en Premium ou Prestige pour les découvrir et matcher instantanément.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembershipScreen())), child: Text(tr('Voir les offres'))),
            ])
          : profiles.isEmpty
              ? ListView(children: [SizedBox(height: 420, child: EmptyState(icon: Icons.star_border_rounded, text: 'Aucun like en attente pour l’instant.'))])
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .72, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: profiles.length,
                  itemBuilder: (_, i) {
                    final p = Map<String, dynamic>.from(profiles[i]);
                    return profileTile(context, p,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileViewScreen(id: p['id']))).then((_) => load()),
                        overlay: Positioned(right: 8, bottom: 8, child: Material(color: LvColors.red, shape: const CircleBorder(), elevation: 3, child: InkWell(
                            customBorder: const CircleBorder(), onTap: () async { if (await doSwipe(context, p, 'like')) load(); },
                            child: const SizedBox(width: 44, height: 44, child: Icon(Icons.favorite_rounded, color: Colors.white, size: 22))))));
                  })),
    );
  }
}
