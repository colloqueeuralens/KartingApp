import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';

/// Page LiveTiming (à développer)
class LiveTimingScreen extends StatelessWidget {
  final VoidCallback? onBackToConfig;

  const LiveTimingScreen({super.key, this.onBackToConfig});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Timing'),
        automaticallyImplyLeading: false,
        actions: AppBarActions.getActions(
          context,
          onBackToConfig: onBackToConfig,
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SessionService.getSessionStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;
          final selectedCircuitId = data['selectedCircuitId'] as String?;

          return Column(
            children: [
              // Affichage du nom du circuit sélectionné
              if (selectedCircuitId != null)
                FutureBuilder<String?>(
                  future: CircuitService.getCircuitName(selectedCircuitId),
                  builder: (context, circuitSnapshot) {
                    if (circuitSnapshot.hasData &&
                        circuitSnapshot.data != null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${circuitSnapshot.data}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              // Contenu principal de la page LiveTiming
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer, size: 100, color: Colors.blue),
                      SizedBox(height: 20),
                      Text(
                        'Live Timing',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('Cette page sera développée plus tard'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
