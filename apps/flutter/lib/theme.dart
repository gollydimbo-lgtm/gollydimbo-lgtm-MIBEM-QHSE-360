import 'package:flutter/material.dart';

/// Palette et thème repris à l'identique du tableau de bord web
/// "QHSE Manager Pro" : c'est la même identité visuelle qui doit maintenant
/// porter toute l'application Flutter, pas seulement une page isolée.
class QhseColors {
  static const bg = Color(0xFF0B0F19);
  static const card = Color(0xFF111827);
  static const cardAlt = Color(0xFF151B2B);
  static const border = Color(0xFF1F2937);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9CA3AF);

  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
  static const blue = Color(0xFF3B82F6);
}

ThemeData buildQhseTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: QhseColors.bg,
    colorScheme: base.colorScheme.copyWith(
      surface: QhseColors.card,
      primary: QhseColors.blue,
      secondary: QhseColors.blue,
      error: QhseColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: QhseColors.bg,
      foregroundColor: QhseColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: QhseColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: QhseColors.border)),
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
    listTileTheme: const ListTileThemeData(iconColor: QhseColors.textSecondary, textColor: QhseColors.textPrimary),
    dividerTheme: const DividerThemeData(color: QhseColors.border),
    textTheme: base.textTheme.apply(bodyColor: QhseColors.textPrimary, displayColor: QhseColors.textPrimary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: QhseColors.cardAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QhseColors.border)),
      labelStyle: const TextStyle(color: QhseColors.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: QhseColors.blue, foregroundColor: Colors.white)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: QhseColors.textPrimary, side: const BorderSide(color: QhseColors.border))),
    dialogTheme: const DialogThemeData(backgroundColor: QhseColors.card),
    chipTheme: base.chipTheme.copyWith(backgroundColor: QhseColors.cardAlt, side: const BorderSide(color: QhseColors.border)),
  );
}

/// Une carte chiffrée unique — brique de base des mini-tableaux de bord.
class KpiStat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const KpiStat(this.label, this.value, {this.color = QhseColors.blue, this.icon = Icons.insights_outlined});
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
              Text(s.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: QhseColors.textPrimary)),
            ]),
          );
        },
      ),
    );
  }
}

