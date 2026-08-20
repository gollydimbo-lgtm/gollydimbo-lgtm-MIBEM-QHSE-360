import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';

/// Valeur saisie pour un point de contrôle donné, avant envoi à l'API.
class _PointAnswer {
  String result = 'CONFORME'; // CONFORME | OBSERVATION | NON_CONFORME | NON_APPLICABLE
  final TextEditingController numericController = TextEditingController();
  final TextEditingController textController = TextEditingController();
  final TextEditingController observationController = TextEditingController();
  String? choice;
  bool photoTaken = false;
}

class ControlCapturePage extends StatefulWidget {
  const ControlCapturePage({super.key});

  @override
  State<ControlCapturePage> createState() => _ControlCapturePageState();
}

class _ControlCapturePageState extends State<ControlCapturePage> {
  ReferenceData? _reference;
  ProductionLine? _selectedLine;
  ControlTemplate? _template;
  final Map<String, _PointAnswer> _answers = {};

  bool _loadingReference = true;
  bool _loadingTemplate = false;
  bool _submitting = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  Future<void> _loadReference() async {
    setState(() => _loadingReference = true);
    try {
      final api = context.read<ApiClient>();
      final json = await api.get('/api/reference-data');
      setState(() => _reference = ReferenceData.fromJson(json));
    } catch (e) {
      setState(() => _error = 'Chargement des données de référence impossible : $e');
    } finally {
      if (mounted) setState(() => _loadingReference = false);
    }
  }

  Future<void> _onLineSelected(ProductionLine? line) async {
    setState(() {
      _selectedLine = line;
      _template = null;
      _answers.clear();
      _successMessage = null;
    });
    if (line == null) return;

    setState(() => _loadingTemplate = true);
    try {
      final api = context.read<ApiClient>();
      final json = await api.get('/api/control-templates/line/${line.id}');
      final templates = (json as List).map((t) => ControlTemplate.fromJson(t)).toList();
      if (templates.isEmpty) {
        setState(() => _error = 'Aucune checklist active pour cette ligne.');
        return;
      }
      final template = templates.first;
      setState(() {
        _template = template;
        for (final point in template.points) {
          _answers[point.id] = _PointAnswer();
        }
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Chargement de la checklist impossible : $e');
    } finally {
      if (mounted) setState(() => _loadingTemplate = false);
    }
  }

  Future<void> _submit() async {
    final template = _template;
    if (template == null) return;

    setState(() {
      _submitting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final api = context.read<ApiClient>();
      final results = template.points.map((point) {
        final answer = _answers[point.id]!;
        // Calculé à part : si le parsing échoue, la clé ne doit pas du tout
        // être envoyée (envoyer `null` explicitement fait échouer la
        // validation côté serveur, qui distingue "absent" de "nul").
        final numericValue = point.type == ControlPointType.numerique
            ? double.tryParse(answer.numericController.text.replaceAll(',', '.'))
            : null;
        return {
          'controlPointId': point.id,
          'result': answer.result,
          if (numericValue != null) 'numericValue': numericValue,
          if (point.type == ControlPointType.texte && answer.textController.text.isNotEmpty)
            'textValue': answer.textController.text,
          if (point.type == ControlPointType.choixMultiple && answer.choice != null)
            'textValue': answer.choice,
          if (answer.observationController.text.isNotEmpty)
            'observation': answer.observationController.text,
        };
      }).toList();

      await api.post('/api/controls', {
        'productionLineId': _selectedLine!.id,
        'results': results,
      });

      final nonConformCount =
          template.points.where((p) => _answers[p.id]!.result == 'NON_CONFORME').length;

      setState(() {
        _successMessage = nonConformCount > 0
            ? 'Contrôle enregistré. $nonConformCount non-conformité(s) créée(s) avec action(s) corrective(s) associée(s).'
            : 'Contrôle enregistré. Aucune non-conformité détectée.';
        _template = null;
        _selectedLine = null;
        _answers.clear();
      });
    } catch (e) {
      setState(() => _error = 'Envoi impossible : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingReference) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Nouveau contrôle terrain', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_successMessage != null)
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
            ),
          ),
        if (_error != null)
          Card(
            color: Colors.red.shade50,
            child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!)),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ProductionLine>(
          value: _selectedLine,
          decoration: const InputDecoration(labelText: 'Ligne de production', border: OutlineInputBorder()),
          items: (_reference?.productionLines ?? [])
              .map((l) => DropdownMenuItem(value: l, child: Text('${l.code} — ${l.name}')))
              .toList(),
          onChanged: _onLineSelected,
        ),
        const SizedBox(height: 20),
        if (_loadingTemplate) const Center(child: CircularProgressIndicator()),
        if (_template != null) ..._buildForm(_template!),
      ],
    );
  }

  List<Widget> _buildForm(ControlTemplate template) {
    return [
      Text(template.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ...template.points.map(_buildPointCard),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox(
                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle),
        label: const Text('Enregistrer le contrôle'),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    ];
  }

  Widget _buildPointCard(ControlPoint point) {
    final answer = _answers[point.id]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(point.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (point.isCritical)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.priority_high, color: Colors.red, size: 18),
                  ),
              ],
            ),
            if (point.unit != null && (point.minValue != null || point.maxValue != null))
              Text(
                'Tolérance : ${point.minValue ?? '—'} à ${point.maxValue ?? '—'} ${point.unit}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 10),
            _buildValueInput(point, answer),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CONFORME', label: Text('Conforme'), icon: Icon(Icons.check, size: 16)),
                ButtonSegment(value: 'OBSERVATION', label: Text('Observation'), icon: Icon(Icons.visibility, size: 16)),
                ButtonSegment(value: 'NON_CONFORME', label: Text('Non conforme'), icon: Icon(Icons.close, size: 16)),
              ],
              selected: {answer.result},
              onSelectionChanged: (v) => setState(() => answer.result = v.first),
            ),
            if (answer.result == 'NON_CONFORME') ...[
              const SizedBox(height: 8),
              TextField(
                controller: answer.observationController,
                decoration: const InputDecoration(
                  labelText: 'Observation / description de la non-conformité',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput(ControlPoint point, _PointAnswer answer) {
    switch (point.type) {
      case ControlPointType.numerique:
        return TextField(
          controller: answer.numericController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Le clavier numérique n'est qu'une suggestion : un clavier physique
          // (PC Windows) peut quand même taper des lettres sans ce filtre.
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
          decoration: InputDecoration(
            labelText: 'Valeur mesurée${point.unit != null ? ' (${point.unit})' : ''}',
            border: const OutlineInputBorder(),
          ),
        );
      case ControlPointType.texte:
        return TextField(
          controller: answer.textController,
          decoration: const InputDecoration(labelText: 'Constat', border: OutlineInputBorder()),
        );
      case ControlPointType.choixMultiple:
        return DropdownButtonFormField<String>(
          value: answer.choice,
          decoration: const InputDecoration(labelText: 'Sélection', border: OutlineInputBorder()),
          items: point.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => answer.choice = v),
        );
      case ControlPointType.photo:
        // La capture réelle (caméra + upload multipart + GPS) est prévue
        // pour le lot "mode hors ligne" ; ce bouton pose la structure UI.
        return OutlinedButton.icon(
          onPressed: () => setState(() => answer.photoTaken = true),
          icon: Icon(answer.photoTaken ? Icons.check_circle : Icons.camera_alt),
          label: Text(answer.photoTaken ? 'Photo capturée' : 'Prendre une photo'),
        );
      case ControlPointType.booleen:
        return const SizedBox.shrink();
    }
  }
}
