import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import '../i18n/i18n.dart';

/// Panneau d'erreur de chargement réutilisable (audit finding #29) — à
/// afficher à la place d'un écran vide silencieux quand un load() échoue
/// silencieusement. Reprend le style déjà utilisé dans EpiLibraryTab.
/// Le message distingue une vraie panne réseau (ApiException.networkError)
/// d'une autre erreur serveur, avec un bouton pour réessayer.
class LoadErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const LoadErrorView({super.key, required this.error, required this.onRetry});

  String get _message {
    final e = error;
    if (e is ApiException) {
      return e.networkError
          ? t('loadErrorView.erreurReseau')
          : e.message;
    }
    return t('loadErrorView.erreurGenerique');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 36, color: QhseColors.red),
            const SizedBox(height: 12),
            Text(_message, textAlign: TextAlign.center, style: TextStyle(color: QhseColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(t('loadErrorView.reessayer'))),
          ],
        ),
      ),
    );
  }
}
