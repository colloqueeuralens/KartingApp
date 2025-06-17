import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/live_timing/live_timing_screen.dart';
import '../../navigation/auth_gate.dart';
import '../../navigation/main_navigator.dart';

/// Classe commune pour les actions de l'AppBar
class AppBarActions {
  static List<Widget> getActions(
    BuildContext context, {
    VoidCallback? onBackToConfig,
  }) {
    return [
      // Bouton Dashboard
      IconButton(
        icon: const Icon(Icons.dashboard),
        onPressed: () {
          // Récupérer le callback depuis le contexte si on est dans MainNavigator
          VoidCallback? configCallback = onBackToConfig;
          if (configCallback == null) {
            // Chercher le MainNavigator dans l'arbre des widgets
            final mainNavigator = context
                .findAncestorStateOfType<MainNavigatorState>();
            if (mainNavigator != null) {
              configCallback = mainNavigator.goToConfig;
            }
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  DashboardScreen(onBackToConfig: configCallback),
            ),
            (route) => route.isFirst,
          );
        },
        tooltip: 'Dashboard',
      ),
      // Bouton Live Timing
      IconButton(
        icon: const Icon(Icons.timer),
        onPressed: () {
          // Récupérer le callback depuis le contexte si on est dans MainNavigator
          VoidCallback? configCallback = onBackToConfig;
          if (configCallback == null) {
            final mainNavigator = context
                .findAncestorStateOfType<MainNavigatorState>();
            if (mainNavigator != null) {
              configCallback = mainNavigator.goToConfig;
            }
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  LiveTimingScreen(onBackToConfig: configCallback),
            ),
            (route) => route.isFirst,
          );
        },
        tooltip: 'Live Timing',
      ),
      // Bouton Configuration (mobile uniquement)
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          // Chercher le MainNavigator dans l'arbre des widgets
          final mainNavigator = context
              .findAncestorStateOfType<MainNavigatorState>();
          if (mainNavigator != null) {
            // Utiliser directement la méthode du MainNavigator
            mainNavigator.goToConfig();
          } else {
            // Fallback : navigation directe si pas dans MainNavigator
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigator()),
              (route) => route.isFirst,
            );
          }
        },
        tooltip: 'Configuration',
      ),
      // Bouton Déconnexion
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () async {
          try {
            await FirebaseAuth.instance.signOut();
            // Force la navigation vers AuthGate qui détectera l'état de déconnexion
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthGate()),
                (route) => false,
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
              );
            }
          }
        },
        tooltip: 'Déconnexion',
      ),
    ];
  }
}