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

/// Palette cohérente pour les statuts NC/Action à travers toute l'app.
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
      return Colors.green;
    case 'REJETEE':
      return Colors.grey;
    case 'EN_RETARD':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Color severityColor(String severity) {
  switch (severity) {
    case 'CRITIQUE':
      return Colors.red;
    case 'MAJEURE':
      return Colors.orange;
    default:
      return Colors.amber.shade700;
  }
}
