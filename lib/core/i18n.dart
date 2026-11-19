// Traductions : mêmes dictionnaires que le site (https://liberverse.fr/i18n/<langue>.json, « texte français → traduction »).
// Les textes de l'app sont écrits en français et passés dans tr() ; une correction de traduction sur le site profite aussi à l'app.
import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

const Map<String, String> kLanguages = {
  'fr': 'Français', 'en': 'English', 'es': 'Español', 'de': 'Deutsch', 'it': 'Italiano',
  'pt': 'Português', 'nl': 'Nederlands', 'ar': 'العربية', 'sw': 'Kiswahili',
};

class I18n {
  I18n._();
  static final I18n I = I18n._();

  String lang = 'fr';
  bool auto = true;
  Map<String, String> _dict = {};

  bool get rtl => lang == 'ar';
  String get locale => lang == 'fr' ? 'fr_FR' : lang;

  static String deviceLang() {
    for (final l in PlatformDispatcher.instance.locales) {
      if (kLanguages.containsKey(l.languageCode)) return l.languageCode;
    }
    return 'fr';
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('lang');
    auto = saved == null;
    lang = saved ?? deviceLang();
    final cached = p.getString('dict_$lang');
    if (cached != null) _dict = Map<String, String>.from(jsonDecode(cached));
    _refresh(); // mise à jour en arrière-plan
  }

  Future<void> _refresh() async {
    if (lang == 'fr') { _dict = {}; return; }
    try {
      final d = await Api.I.getPublic('/i18n/$lang.json');
      if (d is Map) {
        _dict = d.map((k, v) => MapEntry(k.toString(), v.toString()));
        (await SharedPreferences.getInstance()).setString('dict_$lang', jsonEncode(_dict));
      }
    } catch (_) {}
  }

  /// null = langue de l'appareil
  Future<void> setLang(String? l) async {
    final p = await SharedPreferences.getInstance();
    if (l == null) { await p.remove('lang'); auto = true; lang = deviceLang(); }
    else { await p.setString('lang', l); auto = false; lang = l; }
    final cached = p.getString('dict_$lang');
    _dict = cached != null ? Map<String, String>.from(jsonDecode(cached)) : {};
    await _refresh();
  }

  String tr(String fr) {
    if (lang == 'fr') return fr;
    return _dict[fr] ?? _dict[fr.trim()] ?? fr;
  }
}

/// Raccourci : tr('Texte en français')
String tr(String fr) => I18n.I.tr(fr);
