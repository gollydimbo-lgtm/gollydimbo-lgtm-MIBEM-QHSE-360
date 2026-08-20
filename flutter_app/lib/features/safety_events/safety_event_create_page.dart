import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';

const _kEventTypes = {
  'SITUATION_DANGEREUSE': 'Situation dangereuse',
  'CONDITION_DANGEREUSE': 'Condition dangereuse',
  'ACTE_DANGEREUX': 'Acte dangereux',
  'PRESQU_ACCIDENT': 'Presqu\'accident',
  'INCIDENT': 'Incident',
  'ACCIDENT': 'Accident',
};

const _kSeverities = {
  'NEGLIGEABLE': 'Négligeable',
  'MINEURE': 'Mineure',
  'MODEREE': 'Modérée',
  'MAJEURE': 'Majeure',
  'CATASTROPHIQUE': 'Catastrophique',
};

const _kProbabilities = {
  'RARE': 'Rare',
  'PEU_PROBABLE': 'Peu probable',
  'POSSIBLE': 'Possible',
  'PROBABLE': 'Probable',
  'QUASI_CERTAIN': 'Quasi certain',
};

class SafetyEventCreatePage extends StatefulWidget {
  const SafetyEventCreatePage({super.key});

  @override
  State<SafetyEventCreatePage> createState() => _SafetyEventCreatePageState();
}

class _SafetyEventCreatePageState extends State<SafetyEventCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String _type = 'SITUATION_DANGEREUSE';
  String _severity = 'MODEREE';
  String? _probability;
  ReferenceData? _reference;
  ProductionLine? _selectedLine;

  bool _loadingReference = true;
  bool _submitting = false;
  String? _error;

  bool get _isSevere => _severity == 'MAJEURE' || _severity == 'CATASTROPHIQUE';

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  Future<void> _loadReference() async {
    try {
      final api = context.read<ApiClient>();
      final json = await api.get('/api/reference-data');
      setState(() => _reference = ReferenceData.fromJson(json));
    } catch (e) {
      setState(() => _error = 'Chargement impossible : $e');
    } finally {
      if (mounted) setState(() => _loadingReference = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final result = await api.post('/api/safety-events', {
        'type': _type,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'severity': _severity,
        if (_probability != null) 'probability': _probability,
        if (_selectedLine != null) 'productionLineId': _selectedLine!.id,
        if (_locationController.text.isNotEmpty) 'locationDescription': _locationController.text,
      });

      if (!mounted) return;
      final autoActionId = result['autoActionId'];
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          autoActionId != null
              ? 'Événement signalé. Investigation et action corrective déclenchées automatiquement (gravité élevée).'
              : 'Événement signalé.',
        ),
      ));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un événement sécurité')),
      body: _loadingReference
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!)),
                    ),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Type d\'événement', border: OutlineInputBorder()),
                    items: _kEventTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 3,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Localisation (optionnel)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductionLine>(
                    value: _selectedLine,
                    decoration: const InputDecoration(labelText: 'Ligne concernée (optionnel)', border: OutlineInputBorder()),
                    items: (_reference?.productionLines ?? [])
                        .map((l) => DropdownMenuItem(value: l, child: Text('${l.code} — ${l.name}')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLine = v),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _severity,
                    decoration: const InputDecoration(labelText: 'Gravité', border: OutlineInputBorder()),
                    items: _kSeverities.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _severity = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _probability,
                    decoration: const InputDecoration(labelText: 'Probabilité (optionnel)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      ..._kProbabilities.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) => setState(() => _probability = v),
                  ),
                  if (_isSevere) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Gravité élevée : une investigation et une action corrective seront ouvertes automatiquement.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Signaler l\'événement'),
                  ),
                ],
              ),
            ),
    );
  }
}
