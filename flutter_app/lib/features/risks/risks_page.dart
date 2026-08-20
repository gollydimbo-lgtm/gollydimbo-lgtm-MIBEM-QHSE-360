import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/widgets/metric_card.dart';
import 'risk_create_page.dart';

// Reflète services/riskTransitions.ts côté backend.
const Map<String, List<String>> _kAllowedTransitions = {
  'IDENTIFIE': ['EVALUE'],
  'EVALUE': ['TRAITEMENT_REQUIS', 'ACCEPTE', 'MAITRISE'],
  'TRAITEMENT_REQUIS': ['TRAITEMENT_EN_COURS'],
  'TRAITEMENT_EN_COURS': ['MAITRISE', 'EVALUE'],
  'ACCEPTE': ['CLOTURE', 'EVALUE'],
  'MAITRISE': ['CLOTURE', 'EVALUE'],
  'CLOTURE': [],
};

class RisksPage extends StatefulWidget {
  const RisksPage({super.key});

  @override
  State<RisksPage> createState() => _RisksPageState();
}

class _RisksPageState extends State<RisksPage> {
  List<RiskSummary> _items = [];
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
      final json = await api.get('/api/risks', query: _statusFilter != null ? {'status': _statusFilter!} : null);
      setState(() => _items = (json as List).map((e) => RiskSummary.fromJson(e)).toList());
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(RiskSummary risk, String toStatus) async {
    try {
      final api = context.read<ApiClient>();
      await api.patch('/api/risks/${risk.id}/status', {'toStatus': toStatus});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RiskCreatePage()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risques'),
        actions: [
          DropdownButton<String?>(
            value: _statusFilter,
            underline: const SizedBox.shrink(),
            hint: const Padding(padding: EdgeInsets.only(right: 8), child: Text('Tous statuts')),
            items: const [
              DropdownMenuItem(value: null, child: Text('Tous statuts')),
              DropdownMenuItem(value: 'IDENTIFIE', child: Text('Identifiés')),
              DropdownMenuItem(value: 'EVALUE', child: Text('Évalués')),
              DropdownMenuItem(value: 'TRAITEMENT_REQUIS', child: Text('Traitement requis')),
              DropdownMenuItem(value: 'TRAITEMENT_EN_COURS', child: Text('Traitement en cours')),
              DropdownMenuItem(value: 'MAITRISE', child: Text('Maîtrisés')),
              DropdownMenuItem(value: 'CLOTURE', child: Text('Clôturés')),
            ],
            onChanged: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau risque'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Padding(padding: const EdgeInsets.all(20), child: Text('Erreur : $_error')),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                itemCount: _items.length,
                itemBuilder: (context, i) => _buildCard(_items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(RiskSummary risk) {
    final transitions = _kAllowedTransitions[risk.status] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(risk.reference, style: const TextStyle(fontWeight: FontWeight.bold))),
                if (risk.initialLevel != null) StatusChip(risk.initialLevel!, riskLevelColor(risk.initialLevel)),
                const SizedBox(width: 6),
                StatusChip(risk.status, statusColor(risk.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(risk.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '${risk.category} · identifié le ${_dateFormat.format(risk.identifiedAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (transitions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: transitions.map((t) => OutlinedButton(onPressed: () => _transition(risk, t), child: Text(_labelFor(t)))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(String status) {
    switch (status) {
      case 'EVALUE':
        return 'Évaluer';
      case 'TRAITEMENT_REQUIS':
        return 'Traitement requis';
      case 'TRAITEMENT_EN_COURS':
        return 'Démarrer traitement';
      case 'ACCEPTE':
        return 'Accepter';
      case 'MAITRISE':
        return 'Marquer maîtrisé';
      case 'CLOTURE':
        return 'Clôturer';
      default:
        return status;
    }
  }
}
