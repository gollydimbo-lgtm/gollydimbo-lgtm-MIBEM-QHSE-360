import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';

const kRoles = ['ADMINISTRATEUR', 'RESPONSABLE_QHSE', 'ASSISTANT_QHSE', 'CONTROLEUR_QUALITE', 'CHEF_PRODUCTION', 'OPERATEUR', 'AUDITEUR', 'CONSULTATION'];
const kRoleLabels = {
  'ADMINISTRATEUR': 'Administrateur (accès complet)', 'RESPONSABLE_QHSE': 'Responsable QHSE', 'ASSISTANT_QHSE': 'Assistant QHSE',
  'CONTROLEUR_QUALITE': 'Contrôleur qualité', 'CHEF_PRODUCTION': 'Chef de production', 'OPERATEUR': 'Opérateur (terrain)',
  'AUDITEUR': 'Auditeur', 'CONSULTATION': 'Consultation seule',
};

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final api = Api();
  List<dynamic>? users;
  String? error;
  String? currentEmail;

  @override
  void initState() {
    super.initState();
    _load();
    api.currentUser().then((u) => setState(() => currentEmail = u?['email']));
  }

  Future<void> _load() async {
    setState(() { error = null; });
    try {
      final r = await api.get('/users');
      setState(() => users = r as List<dynamic>);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> _confirmAndDelete(String label, String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer définitivement « $label » ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer', style: TextStyle(color: QhseColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(path);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleStatus(Map u) async {
    try {
      await api.patch('/users/${u['id']}/status', {'status': u['status'] == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openCreateDialog() async {
    final firstName = TextEditingController(), lastName = TextEditingController(), email = TextEditingController(), password = TextEditingController();
    String role = 'CONSULTATION';
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: const Text('Nouvel utilisateur'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: firstName, decoration: const InputDecoration(labelText: 'Prénom')),
            TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            TextField(controller: password, decoration: const InputDecoration(labelText: 'Mot de passe temporaire (8 caractères min.)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role, isExpanded: true,
              items: kRoles.map((r) => DropdownMenuItem(value: r, child: Text(kRoleLabels[r] ?? r))).toList(),
              onChanged: (v) => setD(() => role = v ?? role),
              decoration: const InputDecoration(labelText: 'Rôle (définit l\'accès)'),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                await api.post('/users', {
                  'firstName': firstName.text.trim(), 'lastName': lastName.text.trim(),
                  'email': email.text.trim(), 'password': password.text, 'role': role,
                });
                if (context.mounted) Navigator.pop(c);
                _load();
              } catch (e) {
                setD(() => formError = '$e');
              }
            },
            child: const Text('Créer'),
          ),
        ],
      )),
    );
  }

  Future<void> _openResetPasswordDialog(Map u) async {
    final password = TextEditingController();
    String? formError;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text('Réinitialiser — ${u['firstName']} ${u['lastName']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: password, decoration: const InputDecoration(labelText: 'Nouveau mot de passe (8 caractères min.)')),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                await api.patch('/users/${u['id']}/reset-password', {'newPassword': password.text});
                if (context.mounted) Navigator.pop(c);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe réinitialisé.')));
              } catch (e) {
                setD(() => formError = '$e');
              }
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs'), actions: [
        IconButton(icon: const Icon(Icons.person_add_alt_1), tooltip: 'Nouvel utilisateur', onPressed: _openCreateDialog),
      ]),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: const TextStyle(color: QhseColors.red))))
          : users == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: users!.length,
                    itemBuilder: (c, i) {
                      final u = users![i] as Map;
                      final roles = (u['roles'] as List?)?.map((r) => kRoleLabels[r['role']?['name']] ?? r['role']?['name'] ?? '').join(', ') ?? '—';
                      final active = u['status'] == 'ACTIVE';
                      final isSelf = u['email'] == currentEmail;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${u['firstName']} ${u['lastName']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: (active ? QhseColors.green : QhseColors.red).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                child: Text(active ? 'Conforme' : 'Non conforme', style: TextStyle(color: active ? QhseColors.green : QhseColors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(u['email'] ?? '', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
                            Text(roles, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 12, children: [
                              InkWell(onTap: () => _openResetPasswordDialog(u), child: const Text('Réinitialiser mdp', style: TextStyle(color: QhseColors.blue, fontSize: 12))),
                              InkWell(onTap: () => _toggleStatus(u), child: Text(active ? 'Désactiver' : 'Activer', style: TextStyle(color: active ? QhseColors.red : QhseColors.green, fontSize: 12))),
                              if (!isSelf)
                                InkWell(onTap: () => _confirmAndDelete('${u['firstName']} ${u['lastName']}', '/users/${u['id']}'), child: const Text('Supprimer', style: TextStyle(color: QhseColors.red, fontSize: 12))),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
