import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/widgets/metric_card.dart';
import 'safety_event_create_page.dart';

// Reflète services/safetyEventTransitions.ts côté backend.
const Map<String, List<String>> _kAllowedTransitions = {
  'SIGNALE': ['EN_EXAMEN', 'REJETE'],
  'EN_EXAMEN': ['EN_INVESTIGATION', 'ACTION_REQUISE', 'REJETE'],
  'EN_INVESTIGATION': ['ACTION_REQUISE', 'RESOLU'],
  'ACTION_REQUISE': ['RESOLU'],
  'RESOLU': ['CLOTURE', 'EN_INVESTIGATION'],
  'CLOTURE': [],
  'REJETE': [],
};

class SafetyEventsPage extends StatefulWidget {
  const SafetyEventsPage({super.key});

  @override
  State<SafetyEventsPage> createState() => _SafetyEventsPageState();
}

class _SafetyEventsPageState extends State<SafetyEventsPage> {
  List<SafetyEventSummary> _items = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

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
      final json = await api.get('/api/safety-events', query: _statusFilter != null ? {'status': _statusFilter!} : null);
      setState(() => _items = (json as List).map((e) => SafetyEventSummary.fromJson(e)).toList());
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(SafetyEventSummary event, String toStatus) async {
    try {
      final api = context.read<ApiClient>();
      await api.patch('/api/safety-events/${event.id}/status', {'toStatus': toStatus});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SafetyEventCreatePage()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Événements sécurité'),
        actions: [
          DropdownButton<String?>(
            value: _statusFilter,
            underline: const SizedBox.shrink(),
            hint: const Padding(padding: EdgeInsets.only(right: 8), child: Text('Tous statuts')),
            items: const [
              DropdownMenuItem(value: null, child: Text('Tous statuts')),
              DropdownMenuItem(value: 'SIGNALE', child: Text('Signalés')),
              DropdownMenuItem(value: 'EN_EXAMEN', child: Text('En examen')),
              DropdownMenuItem(value: 'EN_INVESTIGATION', child: Text('En investigation')),
              DropdownMenuItem(value: 'ACTION_REQUISE', child: Text('Action requise')),
              DropdownMenuItem(value: 'RESOLU', child: Text('Résolus')),
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
        label: const Text('Signaler'),
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

  Widget _buildCard(SafetyEventSummary event) {
    final transitions = _kAllowedTransitions[event.status] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(event.reference, style: const TextStyle(fontWeight: FontWeight.bold))),
                StatusChip(event.severity, severityColor(event.severity)),
                const SizedBox(width: 6),
                StatusChip(event.status, statusColor(event.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '${event.type} · signalé le ${_dateFormat.format(event.reportedAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (transitions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: transitions.map((t) => OutlinedButton(onPressed: () => _transition(event, t), child: Text(_labelFor(t)))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(String status) {
    switch (status) {
      case 'EN_EXAMEN':
        return 'Passer en examen';
      case 'EN_INVESTIGATION':
        return 'Démarrer investigation';
      case 'ACTION_REQUISE':
        return 'Action requise';
      case 'RESOLU':
        return 'Marquer résolu';
      case 'CLOTURE':
        return 'Clôturer';
      case 'REJETE':
        return 'Rejeter';
      default:
        return status;
    }
  }
}
