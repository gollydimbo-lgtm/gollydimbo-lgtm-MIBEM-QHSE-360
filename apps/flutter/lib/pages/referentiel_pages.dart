import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';

String _genCode(String prefix) => '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

class FieldSpec {
  final String key;
  final String label;
  final String type; // text | number | date | select | checkbox | multiline
  final List<String>? options;
  final bool required;
  final String? defaultValue;
  const FieldSpec(this.key, this.label, {this.type = 'text', this.options, this.required = false, this.defaultValue});
}

/// Page générique : liste + création + modification + suppression, pour un
/// module dont le modèle est simple (pas de relation à sélectionner). Reprend
/// exactement le même comportement que les formulaires du tableau de bord
/// web (code généré automatiquement, confirmation avant suppression).
class SimpleCrudPage extends StatefulWidget {
  final String title;
  final String endpoint; // ex. '/business/reclamations'
  final String codePrefix; // ex. 'REC'
  final List<FieldSpec> fields;
  final String Function(Map item) titleOf;
  final String Function(Map item) subtitleOf;
  final Color Function(Map item)? chipColor;
  final String Function(Map item)? chipLabel;
  final List<KpiStat> Function(List<dynamic> items)? kpiBuilder;

  const SimpleCrudPage({
    super.key, required this.title, required this.endpoint, required this.codePrefix, required this.fields,
    required this.titleOf, required this.subtitleOf, this.chipColor, this.chipLabel, this.kpiBuilder,
  });

  @override
  State<SimpleCrudPage> createState() => _SimpleCrudPageState();
}

class _SimpleCrudPageState extends State<SimpleCrudPage> {
  final api = Api();
  List<dynamic>? items;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final r = await api.get(widget.endpoint);
      setState(() => items = r as List<dynamic>);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> _confirmDelete(Map item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('referentielPages.confirmerSuppression')),
        content: Text(t('referentielPages.confirmerSuppressionTexte', {'label': widget.titleOf(item)})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('referentielPages.annuler'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t('referentielPages.supprimer'), style: const TextStyle(color: QhseColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('${widget.endpoint}/${item['id']}');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openForm({Map? record}) async {
    final editing = record != null;
    final values = <String, dynamic>{};
    for (final f in widget.fields) {
      values[f.key] = editing ? record[f.key] : (f.defaultValue ?? (f.type == 'checkbox' ? false : (f.type == 'number' ? '' : '')));
    }
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(editing ? t('referentielPages.modifier') : t('referentielPages.nouveau')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final f in widget.fields) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildField(f, values, setD),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('referentielPages.annuler'))),
          FilledButton(
            onPressed: () async {
              final payload = <String, dynamic>{};
              for (final f in widget.fields) {
                var v = values[f.key];
                if (f.type == 'number' && v != null && v != '') v = num.tryParse('$v');
                if (f.type == 'number' && (v == '' )) v = null;
                payload[f.key] = v;
              }
              try {
                if (editing) {
                  await api.patch('${widget.endpoint}/${record['id']}', payload);
                } else {
                  payload['code'] = _genCode(widget.codePrefix);
                  await api.post(widget.endpoint, payload);
                }
                if (context.mounted) Navigator.pop(c);
                _load();
              } catch (e) {
                setD(() => formError = '$e');
              }
            },
            child: Text(editing ? t('referentielPages.enregistrer') : t('referentielPages.creer')),
          ),
        ],
      )),
    );
  }

  Widget _buildField(FieldSpec f, Map<String, dynamic> values, void Function(void Function()) setD) {
    switch (f.type) {
      case 'select':
        return DropdownButtonFormField<String>(
          value: values[f.key] as String?, isExpanded: true,
          items: (f.options ?? []).map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setD(() => values[f.key] = v),
          decoration: InputDecoration(labelText: f.label),
        );
      case 'checkbox':
        return CheckboxListTile(
          value: values[f.key] == true, title: Text(f.label), controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setD(() => values[f.key] = v ?? false),
        );
      case 'date':
        final current = values[f.key] is String && (values[f.key] as String).isNotEmpty ? DateTime.tryParse(values[f.key]) : null;
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: current ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
            if (picked != null) setD(() => values[f.key] = picked.toIso8601String());
          },
          child: InputDecorator(
            decoration: InputDecoration(labelText: f.label),
            child: Text(current != null ? '${current.day}/${current.month}/${current.year}' : t('referentielPages.choisirUneDate')),
          ),
        );
      case 'multiline':
        return TextFormField(
          initialValue: values[f.key]?.toString() ?? '', maxLines: 3,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => values[f.key] = v,
        );
      case 'number':
        return TextFormField(
          initialValue: values[f.key]?.toString() ?? '', keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => values[f.key] = v,
        );
      default:
        return TextFormField(
          initialValue: values[f.key]?.toString() ?? '',
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => values[f.key] = v,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(icon: const Icon(Icons.add), tooltip: t('referentielPages.nouveau'), onPressed: () => _openForm()),
      ]),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: const TextStyle(color: QhseColors.red))))
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(children: [
                    if (widget.kpiBuilder != null) Padding(padding: const EdgeInsets.only(top: 12), child: KpiBar(widget.kpiBuilder!(items!))),
                    Expanded(
                      child: items!.isEmpty
                          ? ListView(children:  [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t('referentielPages.aucunElement'), style: TextStyle(color: QhseColors.textSecondary))))])
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: items!.length,
                              itemBuilder: (c, i) {
                                final item = items![i] as Map;
                                return Card(
                                  child: ListTile(
                                    title: Text(widget.titleOf(item)),
                                    subtitle: Text(widget.subtitleOf(item), style: TextStyle(color: QhseColors.textSecondary)),
                                    trailing: widget.chipLabel != null
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: (widget.chipColor?.call(item) ?? QhseColors.blue).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                            child: Text(widget.chipLabel!(item), style: TextStyle(color: widget.chipColor?.call(item) ?? QhseColors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                                          )
                                        : null,
                                    onTap: () => _openForm(record: item),
                                    onLongPress: () => _confirmDelete(item),
                                  ),
                                );
                              },
                            ),
                    ),
                  ]),
                ),
    );
  }
}

// --- Les 6 modules restants, chacun défini en quelques lignes grâce au composant générique ci-dessus ---
// (Processus dispose désormais de son propre module dédié — voir processus_pages.dart)
// (Indicateurs qualité dispose désormais de son propre module dédié — voir indicateurs_pages.dart)
// (Réclamations clients dispose désormais de son propre module dédié — voir reclamations_pages.dart)
// (Fournisseurs dispose désormais de son propre module dédié — voir fournisseurs_pages.dart)
// (Hygiène au travail dispose désormais de son propre module dédié — voir hygiene_pages.dart)

class RegulatoryLegacyCataloguePage extends StatelessWidget {
  const RegulatoryLegacyCataloguePage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: t('referentielPages.veilleReglementaireTitre'), endpoint: '/business/veille-reglementaire', codePrefix: 'VEI',
        fields: [
          FieldSpec('texte', t('referentielPages.texteReglementaire'), type: 'multiline', required: true),
          FieldSpec('domaine', t('referentielPages.domaine')),
          FieldSpec('dateApplication', t('referentielPages.dateApplication'), type: 'date'),
          FieldSpec('statut', t('referentielPages.statut'), type: 'select', options: const ['A_TRAITER', 'EN_COURS', 'INTEGREE'], defaultValue: 'A_TRAITER'),
        ],
        titleOf: (i) => i['texte'] ?? '—', subtitleOf: (i) => i['domaine'] ?? '',
        chipLabel: (i) => i['statut'] == 'A_TRAITER' ? t('referentielPages.statutATraiter') : i['statut'] == 'EN_COURS' ? t('referentielPages.statutEnCours') : t('referentielPages.statutIntegree'),
        chipColor: (i) => i['statut'] == 'A_TRAITER' ? QhseColors.red : i['statut'] == 'EN_COURS' ? QhseColors.blue : QhseColors.green,
        kpiBuilder: (items) => [
          KpiStat(t('referentielPages.kpiTextesSuivis'), '${items.length}', color: QhseColors.blue, icon: Icons.search_outlined),
          KpiStat(t('referentielPages.kpiATraiter'), '${items.where((i) => i['statut'] == 'A_TRAITER').length}', color: QhseColors.red, icon: Icons.priority_high),
          KpiStat(t('referentielPages.kpiIntegres'), '${items.where((i) => i['statut'] == 'INTEGREE').length}', color: QhseColors.green, icon: Icons.check_circle_outline),
        ],
      );
}

