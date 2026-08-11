import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/widgets/metric_card.dart';

// Reflète services/actionTransitions.ts côté backend, qui reste la source
// de vérité (une transition refusée renvoie 409 avec message explicite).
const Map<String, List<String>> _kAllowedActionTransitions = {
  'OUVERTE': ['EN_COURS'],
  'EN_COURS': ['TERMINEE', 'OUVERTE'],
  'TERMINEE': ['A_VERIFIER'],
  'A_VERIFIER': ['CLOTUREE', 'EN_COURS'],
  'CLOTUREE': [],
  'EN_RETARD': ['EN_COURS', 'TERMINEE'],
};

class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  List<ActionSummary> _items = [];
  bool _loading = true;
  String? _error;
  bool _overdueOnly = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final json = await api.get(
        '/api/actions',
        query: _overdueOnly ? {'overdue': 'true'} : null,
      );
      setState(() => _items = (json as List).map((e) => ActionSummary.fromJson(e)).toList());
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(ActionSummary action, String toStatus) async {
    String? effectiveness;
    if (toStatus == 'CLOTUREE') {
      effectiveness = await _promptRequired(context, "Commentaire d'efficacité (requis pour clôturer)");
      if (effectiveness == null || effectiveness.trim().isEmpty) return; // annulé
    }
    try {
      final api = context.read<ApiClient>();
      await api.patch('/api/actions/${action.id}/status', {
        'toStatus': toStatus,
        if (effectiveness != null) 'effectiveness': effectiveness,
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Actions correctives', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                FilterChip(
                  label: const Text('En retard uniquement'),
                  selected: _overdueOnly,
                  onSelected: (v) {
                    setState(() => _overdueOnly = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : $_error')),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _items.length,
              itemBuilder: (context, i) => _buildCard(_items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ActionSummary action) {
    final transitions = _kAllowedActionTransitions[action.status] ?? [];
    final isLate = action.status == 'EN_RETARD';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isLate ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(action.reference, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                StatusChip(action.priority, severityColor(action.priority == 'CRITIQUE' ? 'CRITIQUE' : 'MAJEURE')),
                const SizedBox(width: 6),
                StatusChip(action.status, statusColor(action.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(action.description),
            const SizedBox(height: 6),
            Text(
              'Échéance : ${_dateFormat.format(action.dueDate)}',
              style: TextStyle(color: isLate ? Colors.red : Colors.grey, fontSize: 12),
            ),
            if (transitions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: transitions
                    .map((t) => OutlinedButton(
                          onPressed: () => _transition(action, t),
                          child: Text(_labelFor(t)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(String status) {
    switch (status) {
      case 'EN_COURS':
        return 'Démarrer';
      case 'TERMINEE':
        return 'Marquer terminée';
      case 'A_VERIFIER':
        return 'À vérifier';
      case 'CLOTUREE':
        return 'Clôturer';
      case 'OUVERTE':
        return 'Rouvrir';
      default:
        return status;
    }
  }
}

Future<String?> _promptRequired(BuildContext context, String label) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(controller: controller, maxLines: 3, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
}
