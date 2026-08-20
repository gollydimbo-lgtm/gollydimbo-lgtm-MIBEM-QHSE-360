import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';

const _kRiskCategories = {
  'SECURITE': 'Sécurité',
  'SANTE': 'Santé',
  'QUALITE': 'Qualité',
  'ENVIRONNEMENT': 'Environnement',
  'SECURITE_ALIMENTAIRE': 'Sécurité alimentaire',
  'OPERATIONNEL': 'Opérationnel',
  'INCENDIE': 'Incendie',
  'CHIMIQUE': 'Chimique',
  'ELECTRIQUE': 'Électrique',
  'MECANIQUE': 'Mécanique',
  'ERGONOMIQUE': 'Ergonomique',
  'AUTRE': 'Autre',
};

const _kScaleLabels = {
  1: '1 — Très faible',
  2: '2 — Faible',
  3: '3 — Moyen',
  4: '4 — Élevé',
  5: '5 — Très élevé',
};

class RiskCreatePage extends StatefulWidget {
  const RiskCreatePage({super.key});

  @override
  State<RiskCreatePage> createState() => _RiskCreatePageState();
}

class _RiskCreatePageState extends State<RiskCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'SECURITE';
  int _severity = 3;
  int _probability = 3;
  int? _exposure;
  ReferenceData? _reference;
  ProductionLine? _selectedLine;

  bool _loadingReference = true;
  bool _submitting = false;
  String? _error;

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

  int get _score => _severity * _probability * (_exposure ?? 1);

  String get _previewLevel {
    if (_score <= 10) return 'FAIBLE';
    if (_score <= 25) return 'MODERE';
    if (_score <= 50) return 'ELEVE';
    return 'CRITIQUE';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final result = await api.post('/api/risks', {
        'title': _titleController.text,
        if (_descriptionController.text.isNotEmpty) 'description': _descriptionController.text,
        'category': _category,
        if (_selectedLine != null) 'productionLineId': _selectedLine!.id,
        'severity': _severity,
        'probability': _probability,
        if (_exposure != null) 'exposure': _exposure,
      });

      if (!mounted) return;
      final autoActionId = result['autoActionId'];
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          autoActionId != null
              ? 'Risque créé (niveau $_previewLevel). Une action corrective a été générée automatiquement.'
              : 'Risque créé (niveau $_previewLevel).',
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
      appBar: AppBar(title: const Text('Nouveau risque')),
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
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Intitulé du risque', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optionnel)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                    items: _kRiskCategories.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
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
                  Text('Évaluation initiale', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _severity,
                    decoration: const InputDecoration(labelText: 'Gravité', border: OutlineInputBorder()),
                    items: _kScaleLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _severity = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _probability,
                    decoration: const InputDecoration(labelText: 'Probabilité', border: OutlineInputBorder()),
                    items: _kScaleLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _probability = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _exposure,
                    decoration: const InputDecoration(
                      labelText: 'Exposition (optionnel)',
                      border: OutlineInputBorder(),
                      helperText: 'Laisser vide = exposition neutre (1)',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      ..._kScaleLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) => setState(() => _exposure = v),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: riskLevelColor(_previewLevel).withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.analytics_outlined, color: riskLevelColor(_previewLevel)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Score $_score → niveau $_previewLevel'
                              '${(_previewLevel == "ELEVE" || _previewLevel == "CRITIQUE") ? " — une action corrective sera créée automatiquement" : ""}',
                              style: TextStyle(color: riskLevelColor(_previewLevel), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Créer le risque'),
                  ),
                ],
              ),
            ),
    );
  }
}
