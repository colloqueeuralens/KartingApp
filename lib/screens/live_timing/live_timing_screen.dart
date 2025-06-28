import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/common/glassmorphism_container.dart';
import '../../widgets/live_timing/live_timing_table.dart';
import '../../widgets/live_timing/live_timing_history_tab.dart';
import '../../widgets/live_timing/live_timing_stats_tab.dart';
import '../../widgets/live_timing/debug_sections.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../../services/backend_service.dart';
import '../../services/global_live_timing_service.dart';
import '../../theme/racing_theme.dart';

/// Page LiveTiming avec design racing timing board - intégrée au service global
class LiveTimingScreen extends StatefulWidget {
  final VoidCallback? onBackToConfig;

  const LiveTimingScreen({super.key, this.onBackToConfig});

  @override
  State<LiveTimingScreen> createState() => _LiveTimingScreenState();
}

class _LiveTimingScreenState extends State<LiveTimingScreen> with TickerProviderStateMixin {
  final GlobalLiveTimingService _globalService = GlobalLiveTimingService.instance;
  bool _backendHealthy = false;
  String? _currentCircuitName;
  
  // Onglets
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    
    // Écouter les changements du service global
    _globalService.addListener(_onGlobalServiceChanged);
    
    _checkBackendHealth();
  }

  void _onGlobalServiceChanged() {
    if (mounted) {
      setState(() {
        // Rebuild automatique quand le service global change
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _globalService.removeListener(_onGlobalServiceChanged);
    super.dispose();
  }

  Future<void> _checkBackendHealth() async {
    final healthy = await BackendService.checkHealth();
    if (mounted) {
      setState(() {
        _backendHealthy = healthy;
      });
    }
  }

  /// Démarrer le Live Timing réel via le service global
  Future<void> _startTiming(String circuitId) async {
    final success = await _globalService.startRealTiming(circuitId);
    if (!success && mounted) {
      setState(() {
        // L'erreur est gérée dans le service global
      });
    }
  }

  /// Arrêter le Live Timing via le service global
  Future<void> _stopTiming() async {
    await _globalService.stopTiming();
  }

  /// Démarrer la simulation via le service global
  Future<void> _startSimulation(String circuitId) async {
    final success = await _globalService.startSimulation(circuitId);
    if (!success && mounted) {
      setState(() {
        // L'erreur est gérée dans le service global
      });
    }
  }

  Widget _buildTimingControls(String circuitId) {
    return GlassmorphismContainer(
      margin: const EdgeInsets.all(16),
      blur: 20,
      opacity: 0.85,
      color: RacingTheme.racingBlack,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 600;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isWideScreen ? 16 : 12,
            ),
            child: isWideScreen
                ? _buildWideLayout(circuitId)
                : _buildCompactLayout(circuitId),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(String circuitId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCircuitInfo(),
        _buildActionButtons(circuitId),
        _buildStatusIndicators(),
      ],
    );
  }

  Widget _buildCompactLayout(String circuitId) {
    return Column(
      children: [
        Row(
          children: [
            // Informations (alignées à gauche)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildCircuitInfo(),
              ),
            ),
            // LEDs (alignées à droite)
            Align(
              alignment: Alignment.centerRight,
              child: _buildStatusIndicators(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Boutons centrés
        Center(child: _buildActionButtons(circuitId)),
      ],
    );
  }

  Widget _buildCircuitInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône + Nom du circuit
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: RacingTheme.racingGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: _currentCircuitName?.toUpperCase() ?? 'CIRCUIT INCONNU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(String circuitId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton START - Live Timing réel
        _buildCompactButton(
          icon: Icons.play_arrow,
          label: 'START',
          isEnabled: _backendHealthy && !_globalService.isActive,
          color: RacingTheme.excellent,
          onPressed: () => _startTiming(circuitId),
        ),
        const SizedBox(width: 8),
        // Bouton SIM - Simulation pour tests
        _buildCompactButton(
          icon: Icons.science,
          label: 'SIM',
          isEnabled: !_globalService.isActive,
          color: RacingTheme.racingBlue,
          onPressed: () => _startSimulation(circuitId),
        ),
        const SizedBox(width: 8),
        // Bouton STOP - Arrêter timing ou simulation
        _buildCompactButton(
          icon: Icons.stop,
          label: 'STOP',
          isEnabled: _globalService.isActive,
          color: RacingTheme.bad,
          onPressed: () => _stopTiming(),
        ),
      ],
    );
  }

  Widget _buildStatusIndicators() {
    return Row(
      children: [
        _buildStatusLED(
          isActive: _backendHealthy,
          label: 'API',
          activeColor: RacingTheme.excellent,
        ),
        const SizedBox(width: 8),
        _buildStatusLED(
          isActive: _globalService.isActive,
          label: 'TIM',
          activeColor: RacingTheme.racingGold,
        ),
        const SizedBox(width: 8),
        _buildStatusLED(
          isActive: _globalService.isConnected,
          label: 'WS',
          activeColor: RacingTheme.racingBlue,
        ),
      ],
    );
  }

  Widget _buildStatusLED({
    required bool isActive,
    required String label,
    required Color activeColor,
  }) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.grey.shade600,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.8),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      spreadRadius: 0,
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? activeColor : Colors.grey.shade400,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade600, Colors.grey.shade700],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    final errorMessage = _globalService.errorMessage;
    if (errorMessage == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            IconButton(
              onPressed: () {
                // Les erreurs du service global se nettoient automatiquement
              },
              icon: const Icon(Icons.close, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: RacingTheme.racingBlack.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: RacingTheme.racingGreen,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: RacingTheme.racingGreen,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.live_tv, size: 20),
            text: 'LIVE',
          ),
          Tab(
            icon: Icon(Icons.history, size: 20),
            text: 'TOURS',
          ),
          Tab(
            icon: Icon(Icons.analytics, size: 20),
            text: 'STATS',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(String selectedCircuitId) {
    return Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          // Onglet LIVE - Contenu temps réel existant
          _buildLiveTab(),
          // Onglet TOURS - Historique des tours
          LiveTimingHistoryTab(
            isConnected: _globalService.isConnected,
          ),
          // Onglet STATS - Statistiques et export
          LiveTimingStatsTab(
            isConnected: _globalService.isConnected,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Tableau de timing principal
          LiveTimingTable(
            driversData: _globalService.driversData,
            isConnected: _globalService.isConnected,
            columnOrder: _globalService.columnOrder, // ⭐ Ordre correct des colonnes
          ),
          
          // Sections de debug pliables
          DebugSections(
            lastTimingData: _globalService.driversData,
            lastRawMessage: _globalService.driversData.toString(),
          ),
          
          // Espace en bas pour le scroll
          const SizedBox(height: 20),
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
            const Icon(Icons.timer, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Live Timing'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: AppBarActions.getResponsiveActions(
          context,
          onBackToConfig: widget.onBackToConfig,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RacingTheme.racingBlack,
              Colors.grey[900]!,
              RacingTheme.racingBlack,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

          if (selectedCircuitId == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 100, color: Colors.orange),
                  SizedBox(height: 20),
                  Text(
                    'Aucun circuit sélectionné',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Veuillez sélectionner un circuit dans la configuration',
                  ),
                ],
              ),
            );
          }

          // Récupérer le nom du circuit (sans auto-connexion)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CircuitService.getCircuitName(selectedCircuitId).then((name) {
              if (mounted && name != null) {
                setState(() {
                  _currentCircuitName = name;
                });
              }
            });
          });

          return Column(
            children: [
              // Message d'erreur
              _buildErrorMessage(),

              // Contrôles de timing avec nom du circuit intégré
              _buildTimingControls(selectedCircuitId),

              // Barre d'onglets
              _buildTabBar(),

              // Contenu des onglets
              _buildTabContent(selectedCircuitId),
            ],
          );
        },
        ),
      ),
    );
  }
}