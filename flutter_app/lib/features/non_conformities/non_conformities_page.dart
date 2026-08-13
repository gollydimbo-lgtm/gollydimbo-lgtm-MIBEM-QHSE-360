import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/widgets/metric_card.dart';

// Transitions autorisées côté UI — reflète la machine à états du backend
// (services/ncTransitions.ts). Le serveur reste la source de vérité :
// si un cas limite change côté API, l'appel PATCH renverra simplement 409.
const Map<String, List<String>> _kAllowedNcTransitions = {
  'OUVERTE': ['EN_ANALYSE', 'REJETEE'],
  'EN_ANALYSE': ['ACTION_EN_COURS', 'REJETEE', 'OUVERTE'],
  'ACTION_EN_COURS': ['A_VERIFIER', 'EN_ANALYSE'],
  'A_VERIFIER': ['CLOTUREE', 'ACTION_EN_COURS'],
  'CLOTUREE': [],
  'REJETEE': [],
};

class NonConformitiesPage extends StatefulWidget {
  const NonConformitiesPage({super.key});

  @override
  State<NonConformitiesPage> createState() => _NonConformitiesPageState();
}

class _NonConformitiesPageState extends State<NonConformitiesPage> {
  List<NonConformitySummary> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

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
        '/api/non-conformities',
        query: _statusFilter != null ? {'status': _statusFilter!} : null,
      );
      setState(() => _items = (json as List).map((e) => NonConformitySummary.fromJson(e)).toList());
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(NonConformitySummary nc, String toStatus) async {
    final comment = await _promptComment(context, 'Commentaire (optionnel)');
    try {
      final api = context.read<ApiClient>();
      await api.patch('/api/non-conformities/${nc.id}/status', {
        'toStatus': toStatus,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
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
                  child: Text('Non-conformités', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                DropdownButton<String?>(
                  value: _statusFilter,
                  hint: const Text('Tous statuts'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous statuts')),
                    DropdownMenuItem(value: 'OUVERTE', child: Text('Ouvertes')),
                    DropdownMenuItem(value: 'EN_ANALYSE', child: Text('En analyse')),
                    DropdownMenuItem(value: 'ACTION_EN_COURS', child: Text('Action en cours')),
                    DropdownMenuItem(value: 'A_VERIFIER', child: Text('À vérifier')),
                    DropdownMenuItem(value: 'CLOTUREE', child: Text('Clôturées')),
                  ],
                  onChanged: (v) {
                    setState(() => _statusFilter = v);
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

  Widget _buildCard(NonConformitySummary nc) {
    final transitions = _kAllowedNcTransitions[nc.status] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(nc.reference, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                StatusChip(nc.severity, severityColor(nc.severity)),
                const SizedBox(width: 6),
                StatusChip(nc.status, statusColor(nc.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(nc.description),
            const SizedBox(height: 6),
            Text(
              '${nc.category} · détectée le ${_dateFormat.format(nc.detectedAt)}'
              '${nc.dueDate != null ? ' · échéance ${_dateFormat.format(nc.dueDate!)}' : ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (transitions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: transitions
                    .map((t) => OutlinedButton(
                          onPressed: () => _transition(nc, t),
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
      case 'EN_ANALYSE':
        return 'Passer en analyse';
      case 'ACTION_EN_COURS':
        return 'Démarrer action';
      case 'A_VERIFIER':
        return 'À vérifier';
      case 'CLOTUREE':
        return 'Clôturer';
      case 'REJETEE':
        return 'Rejeter';
      case 'OUVERTE':
        return 'Rouvrir';
      default:
        return status;
    }
  }
}

Future<String?> _promptComment(BuildContext context, String label) {
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
