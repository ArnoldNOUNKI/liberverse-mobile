// Écran 18+ (affiché une seule fois)
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'welcome.dart';

class AgeGate extends StatelessWidget {
  final VoidCallback onAccept;
  const AgeGate({super.key, required this.onAccept});
  @override
  Widget build(BuildContext context) => Theme(
        data: buildTheme(Brightness.dark),
        child: Scaffold(
          backgroundColor: LvColors.night,
          body: NightBackground(child: SafeArea(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const LiberLogo(size: 26, color: Colors.white, accent: LvColors.gold),
            const SizedBox(height: 28),
            Text(tr('Espace réservé aux adultes'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: kSerif, fontSize: 34, color: Colors.white, height: 1.15)),
            const SizedBox(height: 14),
            Text(tr('Ce site s’adresse à des personnes majeures ayant choisi un mode de vie libertin. En entrant, vous certifiez avoir 18 ans ou plus.'),
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCDB9BF), fontSize: 15, height: 1.5)),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: onAccept, child: Text(tr('J’ai 18 ans ou plus — Entrer')))),
            const SizedBox(height: 10),
            TextButton(onPressed: () => SystemNavigator.pop(), child: Text(tr('Quitter'), style: const TextStyle(color: Color(0xFFCDB9BF)))),
          ])))),
        ),
      );
}
