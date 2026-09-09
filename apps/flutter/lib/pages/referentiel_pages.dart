import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

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
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer définitivement « ${widget.titleOf(item)} » ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
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
        title: Text(editing ? 'Modifier' : 'Nouveau'),
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
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
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
            child: Text(editing ? 'Enregistrer' : 'Créer'),
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
            child: Text(current != null ? '${current.day}/${current.month}/${current.year}' : 'Choisir une date'),
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
        IconButton(icon: const Icon(Icons.add), tooltip: 'Nouveau', onPressed: () => _openForm()),
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
                          ? ListView(children:  [Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun élément pour le moment', style: TextStyle(color: QhseColors.textSecondary))))])
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

// --- Les 7 modules, chacun défini en quelques lignes grâce au composant générique ci-dessus ---

class ProcessusPage extends StatelessWidget {
  const ProcessusPage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Processus & indicateurs — Processus', endpoint: '/business/processus', codePrefix: 'PROC',
        fields: const [
          FieldSpec('nom', 'Nom du processus', required: true),
          FieldSpec('proprietaire', 'Propriétaire'),
          FieldSpec('objectifs', 'Objectifs', type: 'multiline'),
          FieldSpec('kpi', 'KPI'),
        ],
        titleOf: (i) => i['nom'] ?? '—', subtitleOf: (i) => i['proprietaire'] ?? 'Propriétaire non défini',
        kpiBuilder: (items) => [
          KpiStat('Processus cartographiés', '${items.length}', color: QhseColors.blue, icon: Icons.account_tree_outlined),
          KpiStat('Avec propriétaire', '${items.where((i) => (i['proprietaire'] ?? '').toString().isNotEmpty).length}', color: QhseColors.green, icon: Icons.person_outline),
        ],
      );
}

class IndicateursQualitePage extends StatelessWidget {
  const IndicateursQualitePage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Processus & indicateurs — Indicateurs', endpoint: '/business/indicateurs-qualite', codePrefix: 'IND',
        fields: const [
          FieldSpec('indicateur', 'Indicateur', required: true),
          FieldSpec('actuel', 'Valeur actuelle', type: 'number', required: true),
          FieldSpec('cible', 'Cible', type: 'number', required: true),
          FieldSpec('unite', 'Unité (%, ...)'),
          FieldSpec('sensInverse', 'Sens inverse (atteint si actuel ≤ cible)', type: 'checkbox'),
        ],
        titleOf: (i) => i['indicateur'] ?? '—',
        subtitleOf: (i) => '${i['actuel']}${i['unite'] ?? ''} / ${i['cible']}${i['unite'] ?? ''}',
        kpiBuilder: (items) {
          final dansLaCible = items.where((i) {
            final actuel = (i['actuel'] as num?) ?? 0;
            final cible = (i['cible'] as num?) ?? 0;
            return i['sensInverse'] == true ? actuel <= cible : actuel >= cible;
          }).length;
          return [
            KpiStat('Indicateurs suivis', '${items.length}', color: QhseColors.blue, icon: Icons.insights_outlined),
            KpiStat('Dans la cible', '$dansLaCible', color: QhseColors.green, icon: Icons.check_circle_outline),
            KpiStat('Hors cible', '${items.length - dansLaCible}', color: QhseColors.red, icon: Icons.error_outline),
          ];
        },
      );
}

class ReclamationsPage extends StatelessWidget {
  const ReclamationsPage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Réclamations clients', endpoint: '/business/reclamations', codePrefix: 'REC',
        fields: const [
          FieldSpec('client', 'Client', required: true),
          FieldSpec('motif', 'Motif', required: true),
          FieldSpec('description', 'Description', type: 'multiline'),
          FieldSpec('date', 'Date', type: 'date'),
          FieldSpec('gravite', 'Gravité', type: 'select', options: ['Faible', 'Modérée', 'Élevée'], defaultValue: 'Faible'),
          FieldSpec('statut', 'Statut', type: 'select', options: ['OPEN', 'CLOSED'], defaultValue: 'OPEN'),
        ],
        titleOf: (i) => i['client'] ?? '—', subtitleOf: (i) => i['motif'] ?? '',
        chipLabel: (i) => i['statut'] == 'CLOSED' ? 'Clôturée' : 'Ouverte',
        chipColor: (i) => i['statut'] == 'CLOSED' ? QhseColors.green : QhseColors.amber,
        kpiBuilder: (items) => [
          KpiStat('Réclamations', '${items.length}', color: QhseColors.amber, icon: Icons.notifications_outlined),
          KpiStat('En cours', '${items.where((i) => i['statut'] != 'CLOSED').length}', color: QhseColors.blue, icon: Icons.hourglass_empty),
          KpiStat('Gravité élevée', '${items.where((i) => i['gravite'] == 'Élevée').length}', color: QhseColors.red, icon: Icons.warning_amber_outlined),
        ],
      );
}

class FournisseursPage extends StatelessWidget {
  const FournisseursPage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Fournisseurs', endpoint: '/business/fournisseurs', codePrefix: 'FOUR',
        fields: const [
          FieldSpec('nom', 'Nom', required: true),
          FieldSpec('categorie', 'Catégorie'),
          FieldSpec('scoreQualite', 'Score qualité (0-100)', type: 'number'),
          FieldSpec('derniereEvaluation', 'Dernière évaluation', type: 'date'),
          FieldSpec('statut', 'Statut', type: 'select', options: ['HOMOLOGUE', 'SOUS_SURVEILLANCE', 'PLAN_ACTION_REQUIS'], defaultValue: 'HOMOLOGUE'),
        ],
        titleOf: (i) => i['nom'] ?? '—', subtitleOf: (i) => i['categorie'] ?? '',
        chipLabel: (i) => i['statut'] == 'HOMOLOGUE' ? 'Conforme' : i['statut'] == 'SOUS_SURVEILLANCE' ? 'Surveillance' : 'Non conforme',
        chipColor: (i) => i['statut'] == 'HOMOLOGUE' ? QhseColors.green : i['statut'] == 'SOUS_SURVEILLANCE' ? QhseColors.amber : QhseColors.red,
        kpiBuilder: (items) => [
          KpiStat('Fournisseurs évalués', '${items.length}', color: QhseColors.blue, icon: Icons.local_shipping_outlined),
          KpiStat('Sous surveillance', '${items.where((i) => i['statut'] != 'HOMOLOGUE').length}', color: QhseColors.amber, icon: Icons.warning_amber_outlined),
        ],
      );
}

class VisitesMedicalesPage extends StatelessWidget {
  const VisitesMedicalesPage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Hygiène au travail — Visites médicales', endpoint: '/business/visites-medicales', codePrefix: 'VM',
        fields: const [
          FieldSpec('employeNom', 'Employé', required: true),
          FieldSpec('poste', 'Poste'),
          FieldSpec('aptitude', 'Aptitude', type: 'select', options: ['Apte', 'Apte avec réserves', 'Inapte']),
          FieldSpec('prochaineVisite', 'Prochaine visite', type: 'date'),
        ],
        titleOf: (i) => i['employeNom'] ?? '—',
        subtitleOf: (i) => i['prochaineVisite'] != null ? 'Prochaine visite : ${DateTime.parse(i['prochaineVisite']).day}/${DateTime.parse(i['prochaineVisite']).month}/${DateTime.parse(i['prochaineVisite']).year}' : 'Aucune visite planifiée',
        chipLabel: (i) => i['aptitude'] ?? '—',
        chipColor: (i) => i['aptitude'] == 'Inapte' ? QhseColors.red : i['aptitude'] == 'Apte avec réserves' ? QhseColors.amber : QhseColors.green,
        kpiBuilder: (items) {
          final now = DateTime.now();
          final enRetard = items.where((i) => i['prochaineVisite'] != null && DateTime.parse(i['prochaineVisite']).isBefore(now)).length;
          return [
            KpiStat('Visites enregistrées', '${items.length}', color: QhseColors.blue, icon: Icons.favorite_outline),
            KpiStat('En retard', '$enRetard', color: QhseColors.red, icon: Icons.warning_amber_outlined),
            KpiStat('Inaptes', '${items.where((i) => i['aptitude'] == 'Inapte').length}', color: QhseColors.red, icon: Icons.block),
          ];
        },
      );
}

class VeilleReglementairePage extends StatelessWidget {
  const VeilleReglementairePage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Veille réglementaire', endpoint: '/business/veille-reglementaire', codePrefix: 'VEI',
        fields: const [
          FieldSpec('texte', 'Texte réglementaire', type: 'multiline', required: true),
          FieldSpec('domaine', 'Domaine'),
          FieldSpec('dateApplication', "Date d'application", type: 'date'),
          FieldSpec('statut', 'Statut', type: 'select', options: ['A_TRAITER', 'EN_COURS', 'INTEGREE'], defaultValue: 'A_TRAITER'),
        ],
        titleOf: (i) => i['texte'] ?? '—', subtitleOf: (i) => i['domaine'] ?? '',
        chipLabel: (i) => i['statut'] == 'A_TRAITER' ? 'À traiter' : i['statut'] == 'EN_COURS' ? 'En cours' : 'Intégrée',
        chipColor: (i) => i['statut'] == 'A_TRAITER' ? QhseColors.red : i['statut'] == 'EN_COURS' ? QhseColors.blue : QhseColors.green,
        kpiBuilder: (items) => [
          KpiStat('Textes suivis', '${items.length}', color: QhseColors.blue, icon: Icons.search_outlined),
          KpiStat('À traiter', '${items.where((i) => i['statut'] == 'A_TRAITER').length}', color: QhseColors.red, icon: Icons.priority_high),
          KpiStat('Intégrés', '${items.where((i) => i['statut'] == 'INTEGREE').length}', color: QhseColors.green, icon: Icons.check_circle_outline),
        ],
      );
}

class ObjectifsQhsePage extends StatelessWidget {
  const ObjectifsQhsePage({super.key});
  @override
  Widget build(BuildContext context) => SimpleCrudPage(
        title: 'Objectifs QHSE', endpoint: '/business/objectifs-qhse', codePrefix: 'OBJ',
        fields: const [
          FieldSpec('titre', 'Titre', required: true),
          FieldSpec('pilier', 'Pilier', type: 'select', options: ['Qualité', 'Sécurité', 'Hygiène', 'Environnement']),
          FieldSpec('cible', 'Cible', type: 'number', required: true),
          FieldSpec('actuel', 'Actuel', type: 'number', defaultValue: '0'),
          FieldSpec('unite', 'Unité (%, ...)'),
          FieldSpec('echeance', 'Échéance', type: 'date'),
        ],
        titleOf: (i) => i['titre'] ?? '—',
        subtitleOf: (i) => '${i['actuel']}${i['unite'] ?? ''} / ${i['cible']}${i['unite'] ?? ''}',
        kpiBuilder: (items) {
          final atteints = items.where((i) {
            final actuel = (i['actuel'] as num?) ?? 0;
            final cible = (i['cible'] as num?) ?? 1;
            return cible == 0 ? actuel == 0 : (actuel / cible) >= 0.9;
          }).length;
          return [
            KpiStat('Objectifs suivis', '${items.length}', color: QhseColors.blue, icon: Icons.flag_outlined),
            KpiStat('Atteints (≥90%)', '$atteints', color: QhseColors.green, icon: Icons.emoji_events_outlined),
          ];
        },
      );
}
