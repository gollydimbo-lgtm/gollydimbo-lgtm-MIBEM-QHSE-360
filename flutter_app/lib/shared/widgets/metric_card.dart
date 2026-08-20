import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MetricCard(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: valueColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Palette cohérente pour les statuts NC/Action/Risque/Sécurité à travers
/// toute l'app.
Color statusColor(String status) {
  switch (status) {
    case 'OUVERTE':
      return Colors.orange;
    case 'EN_ANALYSE':
    case 'EN_COURS':
      return Colors.blue;
    case 'ACTION_EN_COURS':
      return Colors.indigo;
    case 'A_VERIFIER':
      return Colors.purple;
    case 'TERMINEE':
      return Colors.teal;
    case 'CLOTUREE':
    case 'CLOTURE':
      return Colors.green;
    case 'REJETEE':
    case 'REJETE':
      return Colors.grey;
    case 'EN_RETARD':
      return Colors.red;
    // ---- Risques ----
    case 'IDENTIFIE':
      return Colors.orange;
    case 'EVALUE':
      return Colors.blue;
    case 'TRAITEMENT_REQUIS':
      return Colors.deepOrange;
    case 'TRAITEMENT_EN_COURS':
      return Colors.indigo;
    case 'ACCEPTE':
      return Colors.teal;
    case 'MAITRISE':
      return Colors.green;
    // ---- Événements sécurité ----
    case 'SIGNALE':
      return Colors.orange;
    case 'EN_EXAMEN':
      return Colors.blue;
    case 'EN_INVESTIGATION':
      return Colors.indigo;
    case 'ACTION_REQUISE':
      return Colors.deepOrange;
    case 'RESOLU':
      return Colors.teal;
    default:
      return Colors.grey;
  }
}

Color severityColor(String severity) {
  switch (severity) {
    case 'CRITIQUE':
    case 'CATASTROPHIQUE':
      return Colors.red;
    case 'MAJEURE':
      return Colors.orange;
    case 'MODEREE':
      return Colors.amber.shade700;
    case 'MINEURE':
    case 'NEGLIGEABLE':
      return Colors.blueGrey;
    default:
      return Colors.amber.shade700;
  }
}

/// Palette dédiée aux niveaux de risque (FAIBLE/MODERE/ELEVE/CRITIQUE),
/// distincte de severityColor pour éviter toute confusion avec les
/// sévérités NC/événements sécurité qui utilisent une échelle différente.
Color riskLevelColor(String? level) {
  switch (level) {
    case 'CRITIQUE':
      return Colors.red;
    case 'ELEVE':
      return Colors.orange;
    case 'MODERE':
      return Colors.amber.shade700;
    case 'FAIBLE':
      return Colors.green;
    default:
      return Colors.grey;
  }
}
