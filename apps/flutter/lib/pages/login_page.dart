import 'package:flutter/material.dart';
import '../services/api.dart';
import '../main.dart';
import '../i18n/i18n.dart';
import 'settings_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = Api();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = t('loginPage.champsRequis'));
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final r = await api.post('/auth/login', {'email': email.text.trim(), 'password': password.text});
      await api.saveSession(r['accessToken'], r['refreshToken'] as String?, Map<String, dynamic>.from(r['user']));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => error = t('loginPage.identifiantsInvalides'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), tooltip: t('loginPage.reglagesServeur'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_moon, size: 56, color: Colors.indigo),
                const SizedBox(height: 8),
                Text(t('loginPage.appTitre'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text(t('loginPage.appSousTitre'), style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: t('loginPage.email'), prefixIcon: const Icon(Icons.email_outlined), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  onSubmitted: (_) => login(),
                  decoration: InputDecoration(labelText: t('loginPage.motDePasse'), prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder()),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: busy ? null : login,
                    child: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t('loginPage.seConnecter')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
