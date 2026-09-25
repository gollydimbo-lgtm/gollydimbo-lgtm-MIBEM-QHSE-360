import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';

const kRoles = ['ADMINISTRATEUR', 'RESPONSABLE_QHSE', 'ASSISTANT_QHSE', 'CONTROLEUR_QUALITE', 'CHEF_PRODUCTION', 'OPERATEUR', 'AUDITEUR', 'CONSULTATION'];
Map<String, String> get kRoleLabels => {
  'ADMINISTRATEUR': t('usersPage.roleAdministrateur'), 'RESPONSABLE_QHSE': t('usersPage.roleResponsableQhse'), 'ASSISTANT_QHSE': t('usersPage.roleAssistantQhse'),
  'CONTROLEUR_QUALITE': t('usersPage.roleControleurQualite'), 'CHEF_PRODUCTION': t('usersPage.roleChefProduction'), 'OPERATEUR': t('usersPage.roleOperateur'),
  'AUDITEUR': t('usersPage.roleAuditeur'), 'CONSULTATION': t('usersPage.roleConsultation'),
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
        title: Text(t('usersPage.confirmerSuppression')),
        content: Text(t('usersPage.confirmerSuppressionTexte', {'label': label})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('usersPage.annuler'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t('usersPage.supprimer'), style: const TextStyle(color: QhseColors.red))),
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
        title: Text(t('usersPage.nouvelUtilisateur')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: firstName, decoration: InputDecoration(labelText: t('usersPage.prenom'))),
            TextField(controller: lastName, decoration: InputDecoration(labelText: t('usersPage.nom'))),
            TextField(controller: email, decoration: InputDecoration(labelText: t('usersPage.email')), keyboardType: TextInputType.emailAddress),
            TextField(controller: password, decoration: InputDecoration(labelText: t('usersPage.motDePasseTemporaire'))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role, isExpanded: true,
              items: kRoles.map((r) => DropdownMenuItem(value: r, child: Text(kRoleLabels[r] ?? r))).toList(),
              onChanged: (v) => setD(() => role = v ?? role),
              decoration: InputDecoration(labelText: t('usersPage.roleDefinitAcces')),
            ),
            if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('usersPage.annuler'))),
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
            child: Text(t('usersPage.creer')),
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
        title: Text(t('usersPage.reinitialiserTitre', {'firstName': '${u['firstName']}', 'lastName': '${u['lastName']}'})),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: password, decoration: InputDecoration(labelText: t('usersPage.nouveauMotDePasse'))),
          if (formError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(formError!, style: const TextStyle(color: QhseColors.red, fontSize: 12))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('usersPage.annuler'))),
          FilledButton(
            onPressed: () async {
              try {
                await api.patch('/users/${u['id']}/reset-password', {'newPassword': password.text});
                if (context.mounted) Navigator.pop(c);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('usersPage.motDePasseReinitialise'))));
              } catch (e) {
                setD(() => formError = '$e');
              }
            },
            child: Text(t('usersPage.reinitialiser')),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('usersPage.titre')), actions: [
        IconButton(icon: const Icon(Icons.person_add_alt_1), tooltip: t('usersPage.nouvelUtilisateur'), onPressed: _openCreateDialog),
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
                                child: Text(active ? t('usersPage.statutActif') : t('usersPage.statutInactif'), style: TextStyle(color: active ? QhseColors.green : QhseColors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(u['email'] ?? '', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
                            Text(roles, style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 12, children: [
                              InkWell(onTap: () => _openResetPasswordDialog(u), child: Text(t('usersPage.reinitialiserMdp'), style: const TextStyle(color: QhseColors.blue, fontSize: 12))),
                              InkWell(onTap: () => _toggleStatus(u), child: Text(active ? t('usersPage.desactiver') : t('usersPage.activer'), style: TextStyle(color: active ? QhseColors.red : QhseColors.green, fontSize: 12))),
                              if (!isSelf)
                                InkWell(onTap: () => _confirmAndDelete('${u['firstName']} ${u['lastName']}', '/users/${u['id']}'), child: Text(t('usersPage.supprimer'), style: const TextStyle(color: QhseColors.red, fontSize: 12))),
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
