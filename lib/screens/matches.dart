// Messages : nouveaux matchs en haut (carrousel), conversations en dessous (comme les apps de rencontre)
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'chat.dart';
import 'discover.dart';

class MatchesScreen extends StatefulWidget {
  final bool active;
  const MatchesScreen({super.key, required this.active});
  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Map<String, dynamic>>? matches;
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(MatchesScreen old) { super.didUpdateWidget(old); if (widget.active && !old.active) load(); }
  Future<void> load() async {
    try { final r = await Api.I.get('/matches'); if (mounted) setState(() => matches = List<Map<String, dynamic>>.from((r as List).map((x) => Map<String, dynamic>.from(x)))); } catch (_) {}
  }
  void open(Map<String, dynamic> m) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(match: m))).then((_) { load(); if (mounted) context.read<AppState>().refreshBadges(); });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final fresh = (matches ?? []).where((m) => m['last'] == null).toList();
    final convs = (matches ?? []).where((m) => m['last'] != null).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Messages'))),
      body: matches == null ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: matches!.isEmpty
          ? ListView(children: [SizedBox(height: 420, child: EmptyState(icon: Icons.chat_bubble_outline_rounded, text: 'Pas encore de match. Direction les rencontres !'))])
          : ListView(children: [
              if (fresh.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: Text(tr('Nouveau match'), style: TextStyle(color: c.mute, fontWeight: FontWeight.w600))),
                SizedBox(height: 104, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                  for (final m in fresh) GestureDetector(onTap: () => open(m), child: SizedBox(width: 78, child: Column(children: [
                    Container(padding: const EdgeInsets.all(2.5), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: LvColors.red, width: 2)), child: Avatar(primaryPhoto(m), size: 62)),
                    const SizedBox(height: 5),
                    Text(m['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ]))),
                ])),
                Divider(height: 1, color: c.line),
              ],
              for (final m in convs) ListTile(
                onTap: () => open(m),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Avatar(primaryPhoto(m), size: 52, online: m['online'] == true),
                title: Text(m['display_name'], style: TextStyle(fontWeight: (m['unread'] ?? 0) > 0 ? FontWeight.w800 : FontWeight.w600)),
                subtitle: Text(
                  '${m['last']['sender_id'] == s.myId ? '${tr('Vous :')} ' : ''}${m['last']['body'] ?? (m['last']['has_media'] == true ? tr('📎 Pièce jointe') : '')}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: (m['unread'] ?? 0) > 0 ? c.ink : c.mute),
                ),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(hhmm(m['last']['created_at']), style: TextStyle(fontSize: 11.5, color: c.mute)),
                  const SizedBox(height: 4),
                  CountBadge(m['unread'] ?? 0),
                ]),
              ),
            ])),
    );
  }
}
