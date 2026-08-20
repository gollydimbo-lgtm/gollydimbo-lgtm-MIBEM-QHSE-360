import 'package:flutter/material.dart';
import '../services/api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final api = Api();
  final urlCtrl = TextEditingController();
  bool testing = false;
  bool? testOk;

  @override
  void initState() {
    super.initState();
    Api.currentBaseUrl().then((u) => setState(() => urlCtrl.text = u));
  }

  Future<void> test() async {
    setState(() { testing = true; testOk = null; });
    final ok = await api.ping(urlCtrl.text);
    setState(() { testing = false; testOk = ok; });
  }

  Future<void> save() async {
    await Api.setBaseUrl(urlCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adresse serveur enregistrée')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Réglages — Serveur QHSE')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Adresse du serveur QHSE Core V4 (API NestJS). Sur un téléphone Android '
          'connecté au même réseau que le serveur, utilisez son adresse IP locale, '
          'par exemple http://192.168.1.20:3000/api/v4. En émulateur Android, '
          '10.0.2.2 correspond au localhost de votre PC.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(labelText: 'URL de l\'API', border: OutlineInputBorder(), hintText: 'http://192.168.1.20:3000/api/v4'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          OutlinedButton.icon(
            onPressed: testing ? null : test,
            icon: testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
            label: const Text('Tester la connexion'),
          ),
          const SizedBox(width: 12),
          if (testOk == true) const Icon(Icons.check_circle, color: Colors.green),
          if (testOk == false) const Icon(Icons.error, color: Colors.red),
          if (testOk == true) const Text(' Serveur joignable', style: TextStyle(color: Colors.green)),
          if (testOk == false) const Text(' Serveur injoignable', style: TextStyle(color: Colors.red)),
        ]),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: const Text('Enregistrer'))),
      ],
    ),
  );
}
