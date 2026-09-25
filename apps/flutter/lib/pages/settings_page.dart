import 'package:flutter/material.dart';
import '../services/api.dart';
import '../i18n/i18n.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('settingsPage.adresseEnregistree'))));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(t('settingsPage.titre'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t('settingsPage.description'),
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: urlCtrl,
          decoration: InputDecoration(labelText: t('settingsPage.urlApi'), border: const OutlineInputBorder(), hintText: 'http://192.168.1.20:3000/api/v4'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          OutlinedButton.icon(
            onPressed: testing ? null : test,
            icon: testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
            label: Text(t('settingsPage.testerConnexion')),
          ),
          const SizedBox(width: 12),
          if (testOk == true) const Icon(Icons.check_circle, color: Colors.green),
          if (testOk == false) const Icon(Icons.error, color: Colors.red),
          if (testOk == true) Text(' ${t('settingsPage.serveurJoignable')}', style: const TextStyle(color: Colors.green)),
          if (testOk == false) Text(' ${t('settingsPage.serveurInjoignable')}', style: const TextStyle(color: Colors.red)),
        ]),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: Text(t('settingsPage.enregistrer')))),
      ],
    ),
  );
}
