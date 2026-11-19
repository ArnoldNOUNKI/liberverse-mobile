// Charte Liberverse (identique au site) : bordeaux velours, noir, blanc, or. Thème clair par défaut, sombre ou selon l'appareil.
import 'package:material_ui/material_ui.dart';

class LvColors extends ThemeExtension<LvColors> {
  final Color ink, mute, line, bg, panel, soft, field, redLight;
  const LvColors({required this.ink, required this.mute, required this.line, required this.bg, required this.panel, required this.soft, required this.field, required this.redLight});

  static const red = Color(0xFF9B1235);
  static const redDark = Color(0xFF7A0E29);
  static const brand = Color(0xFF8E0F30);
  static const night = Color(0xFF10070A);
  static const gold = Color(0xFFE3C48D);
  static const goldDeep = Color(0xFFC9A36A);
  static const rose = Color(0xFFFF8FAB);
  static const online = Color(0xFF2EB872);

  static const light = LvColors(ink: Color(0xFF0A0A0A), mute: Color(0xFF6B5F63), line: Color(0xFFECE3E6), bg: Colors.white, panel: Colors.white, soft: Color(0xFFFBF7F8), field: Color(0xFFD9CDD1), redLight: Color(0xFFFBEEF1));
  static const dark = LvColors(ink: Color(0xFFF4EEF0), mute: Color(0xFFA8999E), line: Color(0xFF2D2226), bg: Color(0xFF0F0B0C), panel: Color(0xFF171113), soft: Color(0xFF1D1517), field: Color(0xFF3D2F33), redLight: Color(0xFF2B0F17));

  static LvColors of(BuildContext c) => Theme.of(c).extension<LvColors>()!;

  @override
  LvColors copyWith() => this;
  @override
  LvColors lerp(ThemeExtension<LvColors>? other, double t) => t < .5 ? this : (other as LvColors? ?? this);
}

const kSerif = 'serif';

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? LvColors.dark : LvColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: LvColors.red, brightness: b).copyWith(
    primary: b == Brightness.dark ? const Color(0xFFE0476F) : LvColors.red,
    onPrimary: Colors.white, surface: c.panel, onSurface: c.ink, secondary: LvColors.goldDeep,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.field));
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    dividerColor: c.line,
    appBarTheme: AppBarTheme(backgroundColor: c.bg, foregroundColor: c.ink, elevation: 0, scrolledUnderElevation: .5, centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: kSerif, fontSize: 24, fontWeight: FontWeight.w600, color: c.ink)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.panel, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border, enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: LvColors.red, width: 1.6)),
      labelStyle: TextStyle(color: c.mute),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: LvColors.red, foregroundColor: Colors.white, minimumSize: const Size(0, 50),
      shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: c.ink, minimumSize: const Size(0, 46), side: BorderSide(color: c.field),
      shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: b == Brightness.dark ? const Color(0xFFF08AA4) : LvColors.red)),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: c.field)), backgroundColor: c.panel,
      selectedColor: LvColors.red, labelStyle: TextStyle(color: c.ink, fontSize: 13.5), secondaryLabelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white, showCheckmark: false,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? LvColors.red : c.field),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.panel, indicatorColor: Colors.transparent, elevation: 0, height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 11.5, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.primary : c.mute)),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: b == Brightness.dark ? const Color(0xFF2B2024) : LvColors.night,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.panel, showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22)))),
    dialogTheme: DialogThemeData(backgroundColor: c.panel, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
  );
}
