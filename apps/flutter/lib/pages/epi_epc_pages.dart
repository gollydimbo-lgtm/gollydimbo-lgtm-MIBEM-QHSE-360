import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/api.dart';
import '../theme.dart';

// --- Catégories (réutilisé pour EPI et EPC — une seule entrée : le nom) ---
class CategoryListTab extends StatefulWidget {
  final String endpoint;
  final String label;
  const CategoryListTab({super.key, required this.endpoint, required this.label});
  @override
  State<CategoryListTab> createState() => _CategoryListTabState();
}

class _CategoryListTabState extends State<CategoryListTab> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { items = List.from(await api.get(widget.endpoint)); } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final name = TextEditingController(text: record?['name'] ?? '');
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvelle catégorie ${widget.label}' : 'Modifier la catégorie'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('${widget.endpoint}/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                if (record != null) await api.patch('${widget.endpoint}/${record['id']}', {'name': name.text});
                else await api.post(widget.endpoint, {'name': name.text});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('Catégorie'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucune catégorie', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((c) => Card(child: ListTile(title: Text(c['name'] ?? ''), onTap: () => _openForm(record: c)))),
        ],
      ),
    );
  }
}

// --- Personnel ---
class EmployeeTab extends StatefulWidget {
  const EmployeeTab({super.key});
  @override
  State<EmployeeTab> createState() => _EmployeeTabState();
}

class _EmployeeTabState extends State<EmployeeTab> {
  final api = Api();
  List items = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { items = List.from(await api.get('/epi/employees')); } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final matricule = TextEditingController(text: record?['matricule'] ?? '');
    final firstName = TextEditingController(text: record?['firstName'] ?? '');
    final lastName = TextEditingController(text: record?['lastName'] ?? '');
    final department = TextEditingController(text: record?['department'] ?? '');
    final position = TextEditingController(text: record?['position'] ?? '');
    bool active = record?['active'] ?? true;
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvel employé' : "Modifier l'employé"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: matricule, decoration: const InputDecoration(labelText: 'Matricule')),
            TextField(controller: firstName, decoration: const InputDecoration(labelText: 'Prénom')),
            TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: department, decoration: const InputDecoration(labelText: 'Département')),
            TextField(controller: position, decoration: const InputDecoration(labelText: 'Poste')),
            if (record != null) CheckboxListTile(value: active, title: const Text('Actif'), onChanged: (v) => setD(() => active = v ?? true), controlAffinity: ListTileControlAffinity.leading),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/employees/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {'matricule': matricule.text, 'firstName': firstName.text, 'lastName': lastName.text, 'department': department.text, 'position': position.text, if (record != null) 'active': active};
              try {
                if (record != null) await api.patch('/epi/employees/${record['id']}', payload);
                else await api.post('/epi/employees', payload);
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.person_add_alt_1, size: 16), label: const Text('Employé'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucun employé enregistré', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((e) => Card(child: ListTile(
                title: Text('${e['firstName']} ${e['lastName']}'),
                subtitle: Text('${e['matricule']} • ${e['department'] ?? '—'} • ${e['position'] ?? '—'}'),
                trailing: Icon(Icons.circle, size: 10, color: e['active'] == true ? QhseColors.green : QhseColors.red),
                onTap: () => _openForm(record: e),
              ))),
        ],
      ),
    );
  }
}

// --- Bibliothèque EPC ---
class EpcLibraryTab extends StatefulWidget {
  const EpcLibraryTab({super.key});
  @override
  State<EpcLibraryTab> createState() => _EpcLibraryTabState();
}

class _EpcLibraryTabState extends State<EpcLibraryTab> {
  final api = Api();
  List items = [];
  List categories = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/epc'));
      categories = List.from(await api.get('/epi/epc-categories'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final code = TextEditingController(text: record?['code'] ?? '');
    final name = TextEditingController(text: record?['name'] ?? '');
    final location = TextEditingController(text: record?['location'] ?? '');
    final zone = TextEditingController(text: record?['zone'] ?? '');
    final manufacturer = TextEditingController(text: record?['manufacturer'] ?? '');
    String? categoryId = record?['categoryId'];
    String status = record?['status'] ?? 'ACTIVE';
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvel EPC' : "Modifier l'EPC"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, enabled: record == null, decoration: const InputDecoration(labelText: 'Code')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Désignation')),
            DropdownButtonFormField<String>(
              value: categoryId, isExpanded: true,
              items: categories.map<DropdownMenuItem<String>>((cat) => DropdownMenuItem(value: cat['id'] as String, child: Text(cat['name']))).toList(),
              onChanged: (v) => setD(() => categoryId = v),
              decoration: const InputDecoration(labelText: 'Catégorie'),
            ),
            TextField(controller: location, decoration: const InputDecoration(labelText: 'Localisation')),
            TextField(controller: zone, decoration: const InputDecoration(labelText: 'Zone')),
            TextField(controller: manufacturer, decoration: const InputDecoration(labelText: 'Fabricant')),
            DropdownButtonFormField<String>(
              value: status,
              items: const [DropdownMenuItem(value: 'ACTIVE', child: Text('Actif')), DropdownMenuItem(value: 'MAINTENANCE', child: Text('En maintenance')), DropdownMenuItem(value: 'NON_CONFORME', child: Text('Non conforme')), DropdownMenuItem(value: 'HORS_SERVICE', child: Text('Hors service'))],
              onChanged: (v) => setD(() => status = v ?? 'ACTIVE'),
              decoration: const InputDecoration(labelText: 'Statut'),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/epc/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {'name': name.text, 'categoryId': categoryId, 'location': location.text, 'zone': zone.text, 'manufacturer': manufacturer.text, 'status': status};
              try {
                if (record != null) await api.patch('/epi/epc/${record['id']}', payload);
                else await api.post('/epi/epc', {'code': code.text, ...payload});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('EPC'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucun EPC enregistré', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((e) => Card(child: ListTile(
                title: Text('${e['code']} — ${e['name']}'),
                subtitle: Text('${e['category']?['name'] ?? '—'} • ${e['location'] ?? '—'}'),
                trailing: Icon(Icons.circle, size: 10, color: e['status'] == 'NON_CONFORME' ? QhseColors.red : e['status'] == 'ACTIVE' ? QhseColors.green : QhseColors.amber),
                onTap: () => _openForm(record: e),
              ))),
        ],
      ),
    );
  }
}

// --- Inspections EPI + EPC ---
class InspectionsTab extends StatefulWidget {
  const InspectionsTab({super.key});
  @override
  State<InspectionsTab> createState() => _InspectionsTabState();
}

class _InspectionsTabState extends State<InspectionsTab> {
  final api = Api();
  List epiInsp = [], epcInsp = [], epis = [], epcs = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      epiInsp = List.from(await api.get('/epi/epi-inspections'));
      epcInsp = List.from(await api.get('/epi/epc-inspections'));
      epis = List.from(await api.get('/epi/catalog'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({required bool isEpi}) async {
    String? targetId;
    String result = 'CONFORME';
    final observations = TextEditingController();
    String? formError;
    final options = isEpi ? epis : epcs;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(isEpi ? 'Nouvelle inspection EPI' : 'Nouvelle inspection EPC'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: targetId, isExpanded: true,
              items: options.map<DropdownMenuItem<String>>((o) => DropdownMenuItem(value: o['id'] as String, child: Text(o['name']))).toList(),
              onChanged: (v) => setD(() => targetId = v),
              decoration: InputDecoration(labelText: isEpi ? 'EPI inspecté' : 'EPC inspecté'),
            ),
            DropdownButtonFormField<String>(
              value: result,
              items: const [DropdownMenuItem(value: 'CONFORME', child: Text('Conforme')), DropdownMenuItem(value: 'NON_CONFORME', child: Text('Non conforme')), DropdownMenuItem(value: 'A_SURVEILLER', child: Text('À surveiller')), DropdownMenuItem(value: 'A_REFORMER', child: Text('À réformer'))],
              onChanged: (v) => setD(() => result = v ?? 'CONFORME'),
              decoration: const InputDecoration(labelText: 'Résultat'),
            ),
            TextField(controller: observations, decoration: const InputDecoration(labelText: 'Observations'), maxLines: 2),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (targetId == null) { setD(() => formError = 'Sélectionnez un équipement'); return; }
              try {
                final endpoint = isEpi ? '/epi/epi-inspections' : '/epi/epc-inspections';
                final key = isEpi ? 'epiId' : 'epcId';
                await api.post(endpoint, {key: targetId, 'result': result, 'observations': observations.text});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  Color _resultColor(String? r) => r == 'NON_CONFORME' || r == 'A_REFORMER' ? QhseColors.red : r == 'A_SURVEILLER' ? QhseColors.amber : QhseColors.green;
  String _resultLabel(String? r) => {'CONFORME': 'Conforme', 'NON_CONFORME': 'Non conforme', 'A_SURVEILLER': 'À surveiller', 'A_REFORMER': 'À réformer'}[r] ?? '$r';

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            const Expanded(child: Text('Inspections EPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(onPressed: () => _openForm(isEpi: true), icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle')),
          ]),
          const SizedBox(height: 6),
          if (epiInsp.isEmpty) Padding(padding: EdgeInsets.all(8), child: Text('Aucune inspection EPI', style: TextStyle(color: QhseColors.textSecondary))),
          ...epiInsp.map((i) => Card(child: ListTile(
                title: Text(i['epi']?['name'] ?? '—'),
                subtitle: Text(i['observations'] ?? ''),
                trailing: Text(_resultLabel(i['result']), style: TextStyle(color: _resultColor(i['result']), fontSize: 12, fontWeight: FontWeight.w600)),
              ))),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('Inspections EPC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(onPressed: () => _openForm(isEpi: false), icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle')),
          ]),
          const SizedBox(height: 6),
          if (epcInsp.isEmpty) Padding(padding: EdgeInsets.all(8), child: Text('Aucune inspection EPC', style: TextStyle(color: QhseColors.textSecondary))),
          ...epcInsp.map((i) => Card(child: ListTile(
                title: Text(i['epc']?['name'] ?? '—'),
                subtitle: Text(i['observations'] ?? ''),
                trailing: Text(_resultLabel(i['result']), style: TextStyle(color: _resultColor(i['result']), fontSize: 12, fontWeight: FontWeight.w600)),
              ))),
        ],
      ),
    );
  }
}

// --- Matrice Poste / Risque / EPI / EPC ---
class MatrixTab extends StatefulWidget {
  const MatrixTab({super.key});
  @override
  State<MatrixTab> createState() => _MatrixTabState();
}

class _MatrixTabState extends State<MatrixTab> {
  final api = Api();
  List items = [], epis = [], epcs = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/job-risk-protection'));
      epis = List.from(await api.get('/epi/catalog'));
      epcs = List.from(await api.get('/epi/epc'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm({Map? record}) async {
    final jobTitle = TextEditingController(text: record?['jobTitle'] ?? '');
    final hazard = TextEditingController(text: record?['hazard'] ?? '');
    final riskDescription = TextEditingController(text: record?['riskDescription'] ?? '');
    final preventionMeasure = TextEditingController(text: record?['preventionMeasure'] ?? '');
    String? epiId = record?['epiId'];
    String? epcId = record?['epcId'];
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(record == null ? 'Nouvelle ligne — Poste/Risque/Protection' : 'Modifier la ligne'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: jobTitle, decoration: const InputDecoration(labelText: 'Poste')),
            TextField(controller: hazard, decoration: const InputDecoration(labelText: 'Danger')),
            TextField(controller: riskDescription, decoration: const InputDecoration(labelText: 'Risque')),
            TextField(controller: preventionMeasure, decoration: const InputDecoration(labelText: 'Mesure de prévention')),
            DropdownButtonFormField<String>(
              value: epiId, isExpanded: true,
              items: epis.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epiId = v),
              decoration: const InputDecoration(labelText: 'EPI associé'),
            ),
            DropdownButtonFormField<String>(
              value: epcId, isExpanded: true,
              items: epcs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epcId = v),
              decoration: const InputDecoration(labelText: 'EPC associé'),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          if (record != null) TextButton(
            onPressed: () async {
              try { await api.delete('/epi/job-risk-protection/${record['id']}'); if (context.mounted) Navigator.pop(c); load(); }
              catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Supprimer', style: TextStyle(color: QhseColors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final payload = {'jobTitle': jobTitle.text, 'hazard': hazard.text, 'riskDescription': riskDescription.text, 'preventionMeasure': preventionMeasure.text, 'epiId': epiId, 'epcId': epcId};
              try {
                if (record != null) await api.patch('/epi/job-risk-protection/${record['id']}', payload);
                else await api.post('/epi/job-risk-protection', {'code': 'JRP-${DateTime.now().millisecondsSinceEpoch}', ...payload});
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() => formError = '$e'); }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add, size: 16), label: const Text('Ligne'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucune ligne enregistrée', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((m) => Card(child: ListTile(
                title: Text('${m['jobTitle']} — ${m['hazard']}'),
                subtitle: Text('${m['riskDescription'] ?? ''} • EPI: ${m['epi']?['name'] ?? '—'} • EPC: ${m['epc']?['name'] ?? '—'}'),
                onTap: () => _openForm(record: m),
              ))),
        ],
      ),
    );
  }
}

// --- Signature électronique — dessin réel au doigt, sans dépendance externe ---
class SignatureCanvas extends StatefulWidget {
  final String label;
  final void Function(String? base64Png) onChanged;
  const SignatureCanvas({super.key, required this.label, required this.onChanged});
  @override
  State<SignatureCanvas> createState() => SignatureCanvasState();
}

class SignatureCanvasState extends State<SignatureCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  Future<String?> capture() async {
    if (_points.where((p) => p != null).isEmpty) return null;
    final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  void clear() { setState(() => _points.clear()); widget.onChanged(null); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(widget.label, style: TextStyle(fontSize: 12, color: QhseColors.textSecondary)),
        TextButton(onPressed: clear, child: const Text('Effacer', style: TextStyle(fontSize: 12))),
      ]),
      RepaintBoundary(
        key: _boundaryKey,
        child: GestureDetector(
          onPanStart: (d) => setState(() => _points.add(d.localPosition)),
          onPanUpdate: (d) { setState(() => _points.add(d.localPosition)); widget.onChanged('pending'); },
          onPanEnd: (_) => setState(() => _points.add(null)),
          child: Container(
            height: 140, width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: CustomPaint(painter: _SignaturePainter(_points)),
          ),
        ),
      ),
    ]);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }
  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

// --- Attribution (dotation) avec signature électronique ---
class AttributionTab extends StatefulWidget {
  const AttributionTab({super.key});
  @override
  State<AttributionTab> createState() => _AttributionTabState();
}

class _AttributionTabState extends State<AttributionTab> {
  final api = Api();
  List items = [], epis = [], employees = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      items = List.from(await api.get('/epi/assignments'));
      epis = List.from(await api.get('/epi/catalog'));
      employees = List.from(await api.get('/epi/employees'));
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _openForm() async {
    final empKey = GlobalKey<SignatureCanvasState>();
    final respKey = GlobalKey<SignatureCanvasState>();
    String? employeeId, epiId;
    final quantity = TextEditingController(text: '1');
    final size = TextEditingController();
    final reason = TextEditingController();
    final expectedDays = TextEditingController();
    String condition = 'Neuf';
    String? formError;
    bool saving = false;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Nouvelle dotation EPI'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: employeeId, isExpanded: true,
              items: employees.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['firstName']} ${e['lastName']}'))).toList(),
              onChanged: (v) => setD(() => employeeId = v),
              decoration: const InputDecoration(labelText: 'Employé'),
            ),
            DropdownButtonFormField<String>(
              value: epiId, isExpanded: true,
              items: epis.map<DropdownMenuItem<String>>((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name']))).toList(),
              onChanged: (v) => setD(() => epiId = v),
              decoration: const InputDecoration(labelText: 'EPI'),
            ),
            TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité')),
            TextField(controller: size, decoration: const InputDecoration(labelText: 'Taille')),
            TextField(controller: expectedDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée prévue (jours, optionnel)')),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motif')),
            const SizedBox(height: 8),
            SignatureCanvas(key: empKey, label: 'Signature du salarié', onChanged: (_) {}),
            const SizedBox(height: 8),
            SignatureCanvas(key: respKey, label: 'Signature du responsable', onChanged: (_) {}),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: saving ? null : () async {
              if (employeeId == null || epiId == null) { setD(() => formError = 'Employé et EPI obligatoires'); return; }
              setD(() => saving = true);
              final empSig = await empKey.currentState?.capture();
              final respSig = await respKey.currentState?.capture();
              if (empSig == null || respSig == null) { setD(() { saving = false; formError = 'Les deux signatures sont requises'; }); return; }
              final me = await api.currentUser();
              final distributedAt = DateTime.now();
              final days = int.tryParse(expectedDays.text);
              final renewalAt = days != null ? distributedAt.add(Duration(days: days)).toIso8601String() : null;
              try {
                await api.post('/epi/assignments', {
                  'code': 'DOT-${DateTime.now().millisecondsSinceEpoch}',
                  'employeeId': employeeId, 'epiId': epiId, 'quantity': int.tryParse(quantity.text) ?? 1, 'size': size.text,
                  'distributedAt': distributedAt.toIso8601String(), 'renewalAt': renewalAt,
                  'expectedDurationDays': days, 'reason': reason.text, 'condition': condition,
                  'responsibleId': me?['id'], 'employeeSignature': empSig, 'responsibleSignature': respSig,
                });
                if (context.mounted) Navigator.pop(c);
                load();
              } catch (e) { setD(() { saving = false; formError = '$e'; }); }
            },
            child: Text(saving ? 'Enregistrement…' : 'Valider la dotation'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _openForm, icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle dotation'))),
          const SizedBox(height: 8),
          if (items.isEmpty) Padding(padding: EdgeInsets.all(16), child: Text('Aucune dotation enregistrée', style: TextStyle(color: QhseColors.textSecondary))),
          ...items.map((a) => Card(child: ListTile(
                title: Text('${a['code']} — ${a['employee']?['firstName'] ?? ''} ${a['employee']?['lastName'] ?? ''}'),
                subtitle: Text('${a['epi']?['name'] ?? '—'} • qté ${a['quantity']} • ${(a['distributedAt'] ?? '').toString().substring(0, 10)}'),
              ))),
        ],
      ),
    );
  }
}

// --- Renouvellements par paliers (30 / 60 / 90 jours, expirés) ---
class RenewalBucketsTab extends StatefulWidget {
  const RenewalBucketsTab({super.key});
  @override
  State<RenewalBucketsTab> createState() => _RenewalBucketsTabState();
}

class _RenewalBucketsTabState extends State<RenewalBucketsTab> {
  final api = Api();
  Map<String, dynamic> buckets = {'expired': [], 'within30': [], 'within60': [], 'within90': []};
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try { buckets = Map<String, dynamic>.from(await api.get('/epi/renewal-buckets')); } catch (_) {}
    setState(() => loading = false);
  }

  Widget _section(String title, String key, Color color) {
    final list = List.from(buckets[key] ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      const SizedBox(height: 6),
      if (list.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Aucune dotation dans ce palier', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12))),
      ...list.map((r) => Card(child: ListTile(
            title: Text('${r['employee']?['firstName'] ?? ''} ${r['employee']?['lastName'] ?? ''}'),
            subtitle: Text(r['epi']?['name'] ?? '—'),
            trailing: Text((r['renewalAt'] ?? '').toString().substring(0, 10), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ))),
      const SizedBox(height: 16),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('🔴 Expirés', 'expired', QhseColors.red),
          _section('🔴 Sous 30 jours', 'within30', QhseColors.red),
          _section('🟠 Sous 60 jours', 'within60', QhseColors.amber),
          _section('🟡 Sous 90 jours', 'within90', QhseColors.blue),
        ],
      ),
    );
  }
}
