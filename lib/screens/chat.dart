// Conversation privée avec un match : bulles, accusés de lecture, photos jointes (Premium), menu (profil, signaler, retirer le match)
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/photos.dart';
import 'discover.dart';
import 'profile_view.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> match; // profil + match_id
  const ChatScreen({super.key, required this.match});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgs = <Map<String, dynamic>>[];
  final draft = TextEditingController();
  final scroll = ScrollController();
  bool closed = false, sending = false;
  int readUpto = 0;
  Timer? poll;
  String get mid => widget.match['match_id'];

  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 4), (_) => load());
  }
  @override
  void dispose() { poll?.cancel(); super.dispose(); }

  Future<void> load() async {
    try {
      final after = msgs.isEmpty ? 0 : msgs.last['id'];
      final r = await Api.I.get('/matches/$mid/messages', query: {'after': after});
      final add = List<Map<String, dynamic>>.from((r['messages'] as List).map((x) => Map<String, dynamic>.from(x)));
      if (!mounted) return;
      setState(() { msgs.addAll(add); closed = r['closed'] == true; readUpto = r['other_read_upto'] ?? 0; });
      if (add.isNotEmpty) _bottom();
    } catch (_) {}
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) { if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut); });

  Future<void> send() async {
    final t = draft.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    final r = await guard(context, () => Api.I.post('/matches/$mid/messages', {'body': t}));
    if (r != null && mounted) { draft.clear(); setState(() => msgs.add(Map<String, dynamic>.from(r))); _bottom(); }
    if (mounted) setState(() => sending = false);
  }

  Future<void> attach() async {
    final s = context.read<AppState>();
    if (s.plan?['attachments'] != true) { premiumPrompt(context, 'L’envoi de photos et fichiers est inclus dans Premium et Prestige'); return; }
    final f = await pickImage(context);
    if (f == null || !mounted) return;
    final r = await guard(context, () => Api.I.upload('/matches/$mid/messages', f, fields: {'body': draft.text.trim()}));
    if (r != null && mounted) { draft.clear(); setState(() => msgs.add(Map<String, dynamic>.from(r))); _bottom(); }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = LvColors.of(context);
    final m = widget.match;
    final list = msgs.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileViewScreen(id: m['id']))), child: Row(children: [
          Avatar(primaryPhoto(m), size: 38, online: m['online'] == true),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m['display_name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: null)),
            Text(m['online'] == true ? tr('En ligne') : '${tr('Vu')} ${ago(m['last_seen'])}', style: TextStyle(fontSize: 12, color: c.mute, fontFamily: null, fontWeight: FontWeight.w400)),
          ])),
        ])),
        actions: [PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (v) async {
            if (v == 'profile') Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileViewScreen(id: m['id'])));
            if (v == 'report') reportSheet(context, userId: m['id'], matchId: mid);
            if (v == 'unmatch' && await confirmDialog(context, 'Retirer ce match ? La conversation sera fermée pour vous deux.', ok: 'Retirer le match', danger: true) && context.mounted) {
              if (await guard(context, () => Api.I.delete('/matches/$mid')) != null && context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'profile', child: Text(tr('Voir le profil'))),
            PopupMenuItem(value: 'report', child: Text(tr('Signaler'))),
            PopupMenuItem(value: 'unmatch', child: Text(tr('Retirer le match'), style: const TextStyle(color: LvColors.red))),
          ],
        )],
      ),
      body: Column(children: [
        Expanded(child: msgs.isEmpty
            ? EmptyState(icon: Icons.waving_hand_outlined, text: 'Lancez la conversation ✨')
            : ListView.builder(
                controller: scroll, reverse: true, padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount: list.length,
                itemBuilder: (_, i) {
                  final g = list[i];
                  final me = g['sender_id'] == s.myId;
                  final img = g['media_id'] != null && (g['mime'] ?? '').toString().startsWith('image/');
                  return Align(alignment: me ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart, child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                    padding: img ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(14, 9, 14, 7),
                    decoration: BoxDecoration(
                      color: g['removed_by_mod'] == true ? c.soft : me ? LvColors.red : c.panel,
                      border: me ? null : Border.all(color: c.line),
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(me ? 18 : 5), bottomRight: Radius.circular(me ? 5 : 18)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      if (g['removed_by_mod'] == true) Text(tr('Message retiré par la modération'), style: TextStyle(fontStyle: FontStyle.italic, color: c.mute))
                      else ...[
                        if (img) GestureDetector(onTap: () => _viewer(context, g['media_id']), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: MediaImage(g['media_id'], width: 220, height: 260))),
                        if (g['media_id'] != null && !img) Text('📎 ${g['original_name'] ?? tr('Pièce jointe')}', style: TextStyle(color: me ? Colors.white : c.ink)),
                        if ((g['body'] ?? '') != '') Padding(padding: img ? const EdgeInsets.fromLTRB(8, 6, 8, 2) : EdgeInsets.zero,
                            child: Text(g['body'], style: TextStyle(color: me ? Colors.white : c.ink, fontSize: 15.5, height: 1.3))),
                      ],
                      const SizedBox(height: 2),
                      Text('${hhmm(g['created_at'])}${me && (g['id'] as int) <= readUpto ? ' · ${tr('Lu')}' : ''}', style: TextStyle(fontSize: 10.5, color: me ? Colors.white70 : c.mute)),
                    ]),
                  ));
                })),
        if (closed) Container(width: double.infinity, padding: const EdgeInsets.all(14), color: c.soft, child: Text(tr('Cette conversation est fermée'), textAlign: TextAlign.center, style: TextStyle(color: c.mute)))
        else SafeArea(top: false, child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(color: c.panel, border: Border(top: BorderSide(color: c.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(onPressed: attach, icon: Icon(Icons.add_photo_alternate_rounded, color: c.mute)),
            Expanded(child: TextField(controller: draft, minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: tr('Votre message…'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.field)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.field)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)))),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: sending ? null : send, style: IconButton.styleFrom(backgroundColor: LvColors.red), icon: const Icon(Icons.send_rounded, color: Colors.white)),
          ]),
        )),
      ]),
    );
  }

  void _viewer(BuildContext context, String id) => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => Scaffold(
      backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: InteractiveViewer(child: Center(child: MediaImage(id, fit: BoxFit.contain))))));
}
