import 'package:flutter/material.dart';

/// Palette et thème repris à l'identité du tableau de bord web
/// "Gestion QHSE 360" : c'est la même identité visuelle qui porte toute
/// l'application Flutter. Contrairement à avant, les couleurs ne sont plus
/// figées à la compilation — elles changent réellement selon le mode
/// clair/sombre choisi, via [QhseColors.apply].
class QhseColors {
  static const Map<String, Color> _dark = {
    'bg': Color(0xFF0B0F19),
    'card': Color(0xFF111827),
    'cardAlt': Color(0xFF151B2B),
    'border': Color(0xFF1F2937),
    'textPrimary': Colors.white,
    'textSecondary': Color(0xFF9CA3AF),
  };
  static const Map<String, Color> _light = {
    'bg': Color(0xFFF3F4F6),
    'card': Colors.white,
    'cardAlt': Color(0xFFF9FAFB),
    'border': Color(0xFFE5E7EB),
    'textPrimary': Color(0xFF111827),
    'textSecondary': Color(0xFF6B7280),
  };

  static Color bg = _dark['bg']!;
  static Color card = _dark['card']!;
  static Color cardAlt = _dark['cardAlt']!;
  static Color border = _dark['border']!;
  static Color textPrimary = _dark['textPrimary']!;
  static Color textSecondary = _dark['textSecondary']!;

  // Les couleurs sémantiques (rouge/ambre/vert/bleu) restent identiques dans
  // les deux modes — c'est la même convention que le tableau de bord web.
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const blue = Color(0xFF3B82F6);

  static void apply(bool dark) {
    final p = dark ? _dark : _light;
    bg = p['bg']!;
    card = p['card']!;
    cardAlt = p['cardAlt']!;
    border = p['border']!;
    textPrimary = p['textPrimary']!;
    textSecondary = p['textSecondary']!;
  }
}

/// Mode clair/sombre actuel, partagé par toute l'application. Le bouton ☀️/🌙
/// dans la barre latérale bascule cette valeur ; [QhseApp] écoute ce
/// notifieur et reconstruit toute l'interface avec la palette à jour.
final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

ThemeData buildQhseTheme() {
  final base = ThemeData(brightness: isDarkMode.value ? Brightness.dark : Brightness.light, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: QhseColors.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: QhseColors.card,
      primary: QhseColors.blue,
      secondary: QhseColors.blue,
      error: QhseColors.red,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: QhseColors.bg,
      foregroundColor: QhseColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: QhseColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: QhseColors.border)),
      margin: const EdgeInsets.only(bottom: 10),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: QhseColors.card,
      indicatorColor: QhseColors.blue.withOpacity(0.18),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected) ? QhseColors.blue : QhseColors.textSecondary,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? QhseColors.blue : QhseColors.textSecondary,
          )),
    ),
    listTileTheme: ListTileThemeData(iconColor: QhseColors.textSecondary, textColor: QhseColors.textPrimary),
    dividerTheme: DividerThemeData(color: QhseColors.border),
    textTheme: base.textTheme.apply(bodyColor: QhseColors.textPrimary, displayColor: QhseColors.textPrimary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: QhseColors.cardAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: QhseColors.border)),
      labelStyle: TextStyle(color: QhseColors.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: QhseColors.blue, foregroundColor: Colors.white)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: QhseColors.textPrimary, side: BorderSide(color: QhseColors.border))),
    dialogTheme: DialogThemeData(backgroundColor: QhseColors.card),
    chipTheme: base.chipTheme.copyWith(backgroundColor: QhseColors.cardAlt, side: BorderSide(color: QhseColors.border)),
  );
}

/// Une carte chiffrée unique — brique de base des mini-tableaux de bord.
/// [color] et [icon] sont volontairement obligatoires (jamais de valeur par
/// défaut ici) car une valeur par défaut devrait être figée à la
/// compilation, ce qui empêcherait la bascule clair/sombre de fonctionner.
class KpiStat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const KpiStat(this.label, this.value, {required this.color, required this.icon});
}

/// Rangée de cartes KPI en haut d'une page — l'équivalent Flutter des cartes
/// du tableau de bord web. Se place tout en haut d'un ListView, avant le
/// contenu détaillé de la page.
class KpiBar extends StatelessWidget {
  final List<KpiStat> stats;
  const KpiBar(this.stats, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final s = stats[i];
          return Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: s.color.withOpacity(0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(s.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.color), maxLines: 2, overflow: TextOverflow.ellipsis)),
                Icon(s.icon, size: 16, color: s.color),
              ]),
              Text(s.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
            ]),
          );
        },
      ),
    );
  }
}
