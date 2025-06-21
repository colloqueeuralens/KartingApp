import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/dashboard/racing_kart_grid_view.dart';
import '../../widgets/dashboard/optimal_moment_indicator.dart';
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

  // État de l'indicateur de performance
  bool _isOptimal = false;
  int _percentage = 0;
  int _threshold = 100;

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
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Widget _buildHeaderWithIndicator(String? circuitName) {
    return AnimatedBuilder(
      animation: _headerAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - _headerAnimation.value)),
          child: Opacity(
            opacity: _headerAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: OptimalMomentIndicator(
                isOptimal: _isOptimal,
                percentage: _percentage,
                threshold: _threshold,
                circuitName: circuitName,
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
              // Row combinant header et indicateur de performance
              if (selectedCircuitId != null)
                FutureBuilder<String?>(
                  future: CircuitService.getCircuitName(selectedCircuitId),
                  builder: (context, snapshot) {
                    return _buildHeaderWithIndicator(snapshot.data);
                  },
                )
              else
                _buildHeaderWithIndicator(null),

              // Grille des karts avec style racing
              Expanded(
                child: RacingKartGridView(
                  numColumns: cols,
                  numRows: rows,
                  columnColors: colors,
                  readOnly: widget.readOnly,
                  onPerformanceUpdate: (isOptimal, percentage, threshold) {
                    setState(() {
                      _isOptimal = isOptimal;
                      _percentage = percentage;
                      _threshold = threshold;
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
