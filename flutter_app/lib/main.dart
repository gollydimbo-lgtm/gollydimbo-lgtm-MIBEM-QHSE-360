import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth_service.dart';
import 'core/api_client.dart';
import 'features/auth/login_page.dart';
import 'features/home_shell.dart';

void main() {
  runApp(const MibemQhseApp());
}

class MibemQhseApp extends StatelessWidget {
  const MibemQhseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'MIBEM QHSE 360',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF0B3A67),
              useMaterial3: true,
            ),
            // ApiClient dépend d'AuthService (token courant) : reconstruit
            // automatiquement si la session change (login/logout/refresh).
            home: Provider<ApiClient>(
              create: (_) => ApiClient(auth),
              child: _buildHome(auth),
            ),
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
