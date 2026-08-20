import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_service.dart';
import '../../core/server_config_service.dart';

/// Écran affiché au tout premier lancement (aucune adresse enregistrée),
/// et accessible ensuite depuis les paramètres pour changer d'adresse sans
/// jamais avoir à reconstruire l'application.
class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<ServerConfigService>().baseUrl;
    _urlController = TextEditingController(text: current ?? 'https://');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await context.read<ServerConfigService>().setBaseUrl(_urlController.text);

    // Si une session existait (accès depuis les paramètres pour changer
    // d'adresse), elle correspond à l'ancien serveur : on la nettoie pour
    // éviter un état incohérent (tokens valides sur un serveur, invalides
    // sur l'autre). Au tout premier lancement, AuthService n'existe pas
    // encore dans l'arbre de widgets — rien à nettoyer dans ce cas.
    try {
      await context.read<AuthService>().logout();
    } catch (_) {
      // Pas d'AuthService disponible : premier lancement, rien à faire.
    }

    if (mounted) Navigator.of(context).maybePop();
  }

  String? _validate(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Adresse requise';
    final uri = Uri.tryParse(v);
    if (uri == null || !uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Doit commencer par http:// ou https://';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3A67),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.dns_outlined, size: 44, color: Color(0xFF0B3A67)),
                      const SizedBox(height: 12),
                      const Text(
                        'Adresse du serveur MIBEM QHSE',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Renseigne l'adresse fournie par ton administrateur QHSE "
                        '(ex. https://mibem-qhse.exemple.com). '
                        'Modifiable ici à tout moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Adresse du serveur',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validate,
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B3A67),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
