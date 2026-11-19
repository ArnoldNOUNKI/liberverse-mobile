// Liberverse — application mobile (Flutter). Utilise la même API et les mêmes comptes que https://liberverse.fr
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api.dart';
import 'core/i18n.dart';
import 'core/lock.dart';
import 'core/state.dart';
import 'core/theme.dart';
import 'screens/age_gate.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding.dart';
import 'screens/welcome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting();
  await Api.I.init();
  await I18n.I.init();
  final state = AppState();
  await state.init();
  final prefs = await SharedPreferences.getInstance();
  final ageOk = prefs.getBool('age_ok') ?? false;
  final logged = await state.restore();
  Api.I.onUnauthorized = () { if (state.me != null) state.logout(); };
  runApp(ChangeNotifierProvider.value(value: state, child: LiberverseApp(ageOk: ageOk, logged: logged)));
}

class LiberverseApp extends StatefulWidget {
  final bool ageOk, logged;
  const LiberverseApp({super.key, required this.ageOk, required this.logged});
  @override
  State<LiberverseApp> createState() => _LiberverseAppState();
}

class _LiberverseAppState extends State<LiberverseApp> {
  late bool ageOk = widget.ageOk;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Liberverse',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // Accueil et écran 18+ toujours sombres ; espace membre clair par défaut, sombre ou selon l'appareil
      themeMode: s.me == null ? ThemeMode.light : s.themeMode,
      builder: (c, child) => Directionality(textDirection: I18n.I.rtl ? TextDirection.rtl : TextDirection.ltr, child: AppLock(child: child!)),
      home: !ageOk
          ? AgeGate(onAccept: () async { (await SharedPreferences.getInstance()).setBool('age_ok', true); setState(() => ageOk = true); })
          : s.me == null
              ? const WelcomeScreen()
              : s.ready ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
