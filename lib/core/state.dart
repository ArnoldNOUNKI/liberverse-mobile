// État global : membre connecté, référentiels, compteurs (messages, likes, salons), apparence, langue, monnaie.
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'i18n.dart';

typedef Json = Map<String, dynamic>;

class AppState extends ChangeNotifier {
  Json? me; // réponse de GET /me
  Json ref = {};
  ThemeMode themeMode = ThemeMode.light;
  int unread = 0, likesCount = 0, salonUnread = 0;
  Json? fx; // taux de change (affichage indicatif, paiement en euros)
  String currency = 'EUR';
  Timer? _poll;

  Json get user => (me?['user'] as Json?) ?? {};
  Json? get plan => me?['plan'] as Json?;
  String get step => me?['step'] ?? 'email';
  bool get ready => step == 'ready';
  String get myId => user['id'] ?? '';

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    themeMode = _mode(p.getString('theme') ?? 'light');
    try { ref = Json.from(await Api.I.get('/ref', auth401: false)); } catch (_) {}
  }

  static ThemeMode _mode(String t) => t == 'dark' ? ThemeMode.dark : t == 'system' ? ThemeMode.system : ThemeMode.light;
  String get themeName => themeMode == ThemeMode.dark ? 'dark' : themeMode == ThemeMode.system ? 'system' : 'light';

  /// Session existante ? (true si connecté)
  Future<bool> restore() async {
    try { await loadMe(); return true; } on ApiError { return false; }
  }

  Future<void> loadMe() async {
    me = Json.from(await Api.I.get('/me', auth401: false));
    final t = user['theme'] as String?;
    if (t != null) { themeMode = _mode(t); (await SharedPreferences.getInstance()).setString('theme', t); }
    final l = user['lang'] as String?;
    if (l != null && l != I18n.I.lang && I18n.I.auto) await I18n.I.setLang(l);
    await _loadFx();
    notifyListeners();
    if (ready) { refreshBadges(); _poll ??= Timer.periodic(const Duration(seconds: 25), (_) => refreshBadges()); }
  }

  Future<void> refreshBadges() async {
    try {
      final r = await Future.wait([Api.I.get('/matches/unread'), Api.I.get('/discover/likes/count'), Api.I.get('/salons')]);
      unread = (r[0]['n'] ?? 0) as int;
      likesCount = (r[1]['count'] ?? r[1]['n'] ?? 0) as int;
      salonUnread = ((r[2]['salons'] as List?) ?? []).fold<int>(0, (s, x) => s + ((x['my_status'] == 'active' ? x['unread'] : 0) as int? ?? 0));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTheme(String t) async {
    themeMode = _mode(t);
    (await SharedPreferences.getInstance()).setString('theme', t);
    notifyListeners();
    if (me != null) { try { await Api.I.put('/me/theme', {'theme': t}); } catch (_) {} }
  }

  Future<void> setLang(String? l) async {
    await I18n.I.setLang(l);
    notifyListeners();
    if (me != null) { try { await Api.I.put('/me/prefs', {'lang': l}); } catch (_) {} }
  }

  Future<void> _loadFx() async {
    try {
      fx ??= Json.from(await Api.I.get('/fx', auth401: false));
      final cc = (user['country'] as String?) ?? WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? 'FR';
      final c = (user['currency'] as String?) ?? (fx!['currencies']?[cc] as String?) ?? 'EUR';
      currency = (fx!['rates'] as Map?)?.containsKey(c) == true ? c : 'EUR';
    } catch (_) { currency = 'EUR'; }
  }

  /// « 19,90 € (≈ 13 054 FCFA) »
  String price(int cents) {
    final loc = I18n.I.locale;
    final eur = NumberFormat.simpleCurrency(locale: loc, name: 'EUR').format(cents / 100);
    if (currency == 'EUR' || fx == null) return eur;
    final rate = (fx!['rates'][currency] as num?)?.toDouble() ?? 1;
    final v = cents / 100 * rate;
    final f = NumberFormat.simpleCurrency(locale: loc, name: currency, decimalDigits: v >= 1000 ? 0 : 2).format(v);
    return '$eur (≈ $f)';
  }

  Future<void> logout() async {
    try { await Api.I.post('/auth/logout'); } catch (_) {}
    await Api.I.clearSession();
    _poll?.cancel(); _poll = null;
    me = null; unread = likesCount = salonUnread = 0;
    notifyListeners();
  }

  String profileType(String? k) => tr((ref['profile_types']?[k] ?? '') as String);
}

/// « il y a 5 min » dans la langue de l'app
String ago(String? iso) {
  if (iso == null) return tr('jamais');
  final d = DateTime.tryParse(iso); if (d == null) return '';
  final s = DateTime.now().difference(d).inSeconds;
  final fr = I18n.I.lang == 'fr';
  String f(int n, String u) => fr ? 'il y a $n $u' : '$n $u';
  if (s < 60) return fr ? 'à l’instant' : 'now';
  if (s < 3600) return f(s ~/ 60, 'min');
  if (s < 86400) return f(s ~/ 3600, 'h');
  return f(s ~/ 86400, fr ? 'j' : 'd');
}

String hhmm(String? iso) { final d = DateTime.tryParse(iso ?? ''); return d == null ? '' : DateFormat.Hm(I18n.I.locale).format(d.toLocal()); }
String dateLong(String? iso) { final d = DateTime.tryParse(iso ?? ''); return d == null ? '' : DateFormat.yMMMMEEEEd(I18n.I.locale).add_Hm().format(d.toLocal()); }
