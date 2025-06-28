import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/enhanced_lap_statistics_service.dart';
import 'services/performance_monitoring_service.dart';
import 'navigation/auth_gate.dart';
import 'theme/racing_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 🚀 PHASE 2B: Initialiser le cache multi-niveaux
  await EnhancedLapStatisticsService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KMRS Racing',
      debugShowCheckedModeBanner: false,
      theme: RacingTheme.theme,
      home: const AuthGate(),
    );
  }
}
