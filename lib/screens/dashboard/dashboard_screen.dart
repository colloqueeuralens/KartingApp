import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/dashboard/kart_grid_view.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../../theme/racing_theme.dart';

/// Dashboard (mobile & web) avec thème racing
class DashboardScreen extends StatefulWidget {
  final bool readOnly;
  final VoidCallback? onBackToConfig;

  const DashboardScreen({
    super.key,
    this.readOnly = false,
    this.onBackToConfig,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  static const Map<String, Color> _nameToColor = {
    'Bleu': Colors.blue,
    'Blanc': Colors.white,
    'Rouge': Colors.red,
    'Vert': Colors.green,
    'Jaune': Colors.yellow,
  };

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Widget _buildRacingHeader(String? circuitName) {
    return AnimatedBuilder(
      animation: _headerAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _headerAnimation.value)),
          child: Opacity(
            opacity: _headerAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: RacingTheme.racingGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: RacingTheme.racingShadow,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Racing stripes background
                      CustomPaint(
                        painter: RacingStripesPainter(),
                        child: Container(),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Racing dashboard header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.sports_motorsports,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'KMRS RACING DASHBOARD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      if (circuitName != null)
                                        Text(
                                          circuitName.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Racing timer icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.timer,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RacingTheme.checkeredGradient,
            ),
            child: const Icon(
              Icons.sports_motorsports,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Configuration requise',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: RacingTheme.racingBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configurez votre session de karting',
            style: TextStyle(
              fontSize: 16,
              color: RacingTheme.racingBlack.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          if (!widget.readOnly)
            ElevatedButton.icon(
              onPressed: widget.onBackToConfig,
              icon: const Icon(Icons.settings),
              label: const Text('Configurer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.dashboard, color: Colors.white),
            const SizedBox(width: 8),
            const Text('KMRS Racing Dashboard'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: widget.readOnly
            ? []
            : AppBarActions.getResponsiveActions(
                context,
                onBackToConfig: widget.onBackToConfig,
              ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SessionService.getSessionStream(),
        builder: (ctx, cfgSnap) {
          if (cfgSnap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: RacingTheme.bad),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur de configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: RacingTheme.bad,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${cfgSnap.error}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!cfgSnap.hasData || cfgSnap.data!.data() == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      RacingTheme.racingRed,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement de la configuration...',
                    style: TextStyle(
                      fontSize: 16,
                      color: RacingTheme.racingBlack,
                    ),
                  ),
                ],
              ),
            );
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

          // Si pas de configuration, afficher l'état vide
          if (cols == 0 || rows == 0) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Header racing avec nom du circuit
              if (selectedCircuitId != null)
                FutureBuilder<String?>(
                  future: CircuitService.getCircuitName(selectedCircuitId),
                  builder: (context, snapshot) {
                    return _buildRacingHeader(snapshot.data);
                  },
                )
              else
                _buildRacingHeader(null),

              // Grille des karts
              Expanded(
                child: KartGridView(
                  numColumns: cols,
                  numRows: rows,
                  columnColors: colors,
                  readOnly: widget.readOnly,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter pour les rayures de racing
class RacingStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const stripeHeight = 3.0;
    const spacing = 12.0;

    // Rayures diagonales
    for (double y = -size.width; y < size.height + size.width; y += spacing) {
      paint.color = Colors.white.withValues(alpha: 0.1);
      final path = Path();
      path.moveTo(0, y);
      path.lineTo(size.width, y - size.width * 0.3);
      path.lineTo(size.width, y - size.width * 0.3 + stripeHeight);
      path.lineTo(0, y + stripeHeight);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
