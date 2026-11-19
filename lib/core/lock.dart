// Discrétion : verrouillage par empreinte / Face ID à l'ouverture et après 30 s en arrière-plan.
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/common.dart';
import 'i18n.dart';
import 'theme.dart';

class LockPrefs {
  static Future<bool> enabled() async => (await SharedPreferences.getInstance()).getBool('bio_lock') ?? false;
  static Future<bool> setEnabled(bool on) async {
    if (on && !await authenticate()) return false;
    (await SharedPreferences.getInstance()).setBool('bio_lock', on);
    return true;
  }
  static Future<bool> available() async {
    try { return await LocalAuthentication().isDeviceSupported(); } catch (_) { return false; }
  }
  static Future<bool> authenticate() async {
    try {
      return await LocalAuthentication().authenticate(localizedReason: tr('Déverrouiller Liberverse'), persistAcrossBackgrounding: true);
    } catch (_) { return false; }
  }
}

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool locked = false, busy = false;
  DateTime? hiddenAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LockPrefs.enabled().then((on) { if (on) _lock(); });
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) { hiddenAt ??= DateTime.now(); }
    if (s == AppLifecycleState.resumed) {
      final away = hiddenAt == null ? Duration.zero : DateTime.now().difference(hiddenAt!);
      hiddenAt = null;
      if (away.inSeconds > 30 && await LockPrefs.enabled()) _lock();
    }
  }

  Future<void> _lock() async {
    setState(() => locked = true);
    await _unlock();
  }

  Future<void> _unlock() async {
    if (busy) return;
    busy = true;
    final ok = await LockPrefs.authenticate();
    busy = false;
    if (ok && mounted) setState(() => locked = false);
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (locked) Positioned.fill(child: Material(color: LvColors.night, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const LiberIcon(size: 84),
          const SizedBox(height: 16),
          const Text('Liberverse', style: TextStyle(fontFamily: kSerif, fontSize: 26, color: Colors.white)),
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint_rounded), label: Text(tr('Déverrouiller'))),
        ]))),
      ]);
}
