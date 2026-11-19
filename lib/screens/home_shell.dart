// Barre d'onglets principale (mêmes onglets et icônes que l'app web) avec pastilles de compteurs
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'discover.dart';
import 'likes.dart';
import 'matches.dart';
import 'my_profile.dart';
import 'salons.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  static const tabs = [['rencontres', 'Rencontres'], ['likes', 'Likes'], ['messages', 'Messages'], ['salons', 'Salons'], ['profil', 'Profil']];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final c = LvColors.of(context);
    int badge(String k) => k == 'messages' ? s.unread : k == 'likes' ? s.likesCount : k == 'salons' ? s.salonUnread : 0;
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(() => tab = 0); },
      child: Scaffold(
        body: Column(children: [
          if ((s.ref['announcement'] ?? '') != '') SafeArea(bottom: false, child: Container(width: double.infinity, color: c.redLight, padding: const EdgeInsets.all(10),
              child: Text('📣 ${s.ref['announcement']}', style: const TextStyle(fontSize: 13)))),
          Expanded(child: IndexedStack(index: tab, children: [
            DiscoverScreen(active: tab == 0),
            LikesScreen(active: tab == 1),
            MatchesScreen(active: tab == 2),
            SalonsScreen(active: tab == 3),
            const MyProfileScreen(),
          ])),
        ]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) { setState(() => tab = i); if (i != 4) s.refreshBadges(); },
            destinations: [
              for (var i = 0; i < tabs.length; i++) NavigationDestination(
                label: tr(tabs[i][1]),
                icon: Badge(isLabelVisible: badge(tabs[i][0]) > 0, backgroundColor: Colors.transparent, alignment: const AlignmentDirectional(1.6, -1.4),
                    label: CountBadge(badge(tabs[i][0])), child: NavIcon(tabs[i][0], on: false, color: badge(tabs[i][0]) > 0 ? scheme.primary : c.mute, inner: c.panel)),
                selectedIcon: Badge(isLabelVisible: badge(tabs[i][0]) > 0, backgroundColor: Colors.transparent, alignment: const AlignmentDirectional(1.6, -1.4),
                    label: CountBadge(badge(tabs[i][0])), child: NavIcon(tabs[i][0], on: true, color: scheme.primary, inner: c.panel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
