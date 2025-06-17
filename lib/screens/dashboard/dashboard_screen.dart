import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/dashboard/kart_grid_view.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';

/// Dashboard (mobile & web)
class DashboardScreen extends StatelessWidget {
  final bool readOnly;
  final VoidCallback? onBackToConfig;

  const DashboardScreen({
    super.key,
    this.readOnly = false,
    this.onBackToConfig,
  });

  static const Map<String, Color> _nameToColor = {
    'Bleu': Colors.blue,
    'Blanc': Colors.white,
    'Rouge': Colors.red,
    'Vert': Colors.green,
    'Jaune': Colors.yellow,
  };

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KMRS Racing'),
        automaticallyImplyLeading: false,
        actions: readOnly
            ? []
            : AppBarActions.getActions(context, onBackToConfig: onBackToConfig),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SessionService.getSessionStream(),
        builder: (ctx, cfgSnap) {
          if (cfgSnap.hasError) {
            return Center(child: Text('Erreur config : ${cfgSnap.error}'));
          }
          if (!cfgSnap.hasData || cfgSnap.data!.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = cfgSnap.data!.data()!;
          final cols = (data['numColumns'] as int?) ?? 3;
          final rows = (data['numRows'] as int?) ?? 3;
          final names = List<String>.from(
            (data['columnColors'] as List<dynamic>?) ??
                ['Bleu', 'Blanc', 'Rouge'],
          );
          final colors = names
              .map((n) => _nameToColor[n] ?? Colors.grey)
              .toList();
          final selectedCircuitId = data['selectedCircuitId'] as String?;

          return Column(
            children: [
              // Affichage du nom du circuit sélectionné
              if (selectedCircuitId != null)
                FutureBuilder<String?>(
                  future: CircuitService.getCircuitName(selectedCircuitId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
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
                          '${snapshot.data}',
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
              // Grille des karts
              Expanded(
                child: KartGridView(
                  numColumns: cols,
                  numRows: rows,
                  columnColors: colors,
                  readOnly: readOnly,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
