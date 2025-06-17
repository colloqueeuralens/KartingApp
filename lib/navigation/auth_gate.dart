import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../services/firebase_service.dart';
import 'main_navigator.dart';

/// Sélectionne Login ou la suite de l'app selon l'état FirebaseAuth
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  
  Future<void> _initializeFirebaseData() async {
    await FirebaseService.ensureConfigExists();
    await FirebaseService.ensureSecteurChoicesExist();
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasData) {
          return FutureBuilder(
            future: _initializeFirebaseData(),
            builder: (context, initSnap) {
              if (initSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return kIsWeb
                  ? const DashboardScreen(readOnly: true)
                  : const MainNavigator();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}