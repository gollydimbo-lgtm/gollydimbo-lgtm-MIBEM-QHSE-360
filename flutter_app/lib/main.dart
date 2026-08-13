import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth_service.dart';
import 'core/api_client.dart';
import 'core/server_config_service.dart';
import 'features/auth/login_page.dart';
import 'features/home_shell.dart';
import 'features/settings/server_setup_page.dart';

void main() {
  runApp(const MibemQhseApp());
}

class MibemQhseApp extends StatelessWidget {
  const MibemQhseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServerConfigService(),
      child: Consumer<ServerConfigService>(
        builder: (context, serverConfig, _) {
          return MaterialApp(
            title: 'MIBEM QHSE 360',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF0B3A67),
              useMaterial3: true,
            ),
            home: _buildRoot(serverConfig),
          );
        },
      ),
    );
  }

  Widget _buildRoot(ServerConfigService serverConfig) {
    if (serverConfig.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Tant qu'aucune adresse serveur n'est enregistrée, impossible d'aller
    // plus loin : on force la configuration avant tout accès à l'app.
    if (!serverConfig.isConfigured) {
      return const ServerSetupPage();
    }

    // AuthService et ApiClient ne sont créés qu'une fois le serveur connu.
    // AuthService lit serverConfig.baseUrl dynamiquement à chaque appel
    // (pas de valeur figée) : changer d'adresse depuis les paramètres n'a
    // donc pas besoin de reconstruire tout l'arbre de widgets.
    return ChangeNotifierProvider<AuthService>(
      create: (_) => AuthService(serverConfig),
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return Provider<ApiClient>(
            create: (_) => ApiClient(auth),
            child: _buildHome(auth),
          );
        },
      ),
    );
  }

  Widget _buildHome(AuthService auth) {
    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? const HomeShell() : const LoginPage();
  }
}
