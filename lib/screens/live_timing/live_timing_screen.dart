import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/common/glassmorphism_container.dart';
import '../../widgets/live_timing/live_timing_table.dart';
import '../../widgets/live_timing/debug_sections.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../../services/backend_service.dart';
import '../../theme/racing_theme.dart';

/// Page LiveTiming avec design racing timing board
class LiveTimingScreen extends StatefulWidget {
  final VoidCallback? onBackToConfig;

  const LiveTimingScreen({super.key, this.onBackToConfig});

  @override
  State<LiveTimingScreen> createState() => _LiveTimingScreenState();
}

class _LiveTimingScreenState extends State<LiveTimingScreen> {
  final LiveTimingWebSocketService _wsService = LiveTimingWebSocketService();
  bool _backendHealthy = false;
  bool _timingActive = false;
  Map<String, dynamic>? _lastTimingData;
  Map<String, dynamic>? _circuitStatus;
  String? _errorMessage;
  String? _lastRawMessage;
  Map<String, Map<String, dynamic>> _driversData = {};
  String? _currentCircuitName;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  Future<void> _checkBackendHealth() async {
    final healthy = await BackendService.checkHealth();
    if (mounted) {
      setState(() {
        _backendHealthy = healthy;
        if (!healthy) {
          _errorMessage = 'Backend non disponible';
        }
      });
    }
  }

  Future<void> _connectToTiming(String circuitId) async {
    if (!_backendHealthy) {
      await _checkBackendHealth();
      if (!_backendHealthy) return;
    }

    try {
      // Obtenir le statut du circuit
      final status = await BackendService.getCircuitStatus(circuitId);
      if (mounted) {
        setState(() {
          _circuitStatus = status;
          _timingActive = status?['timing_active'] ?? false;
        });
      }

      // Se connecter au WebSocket
      final connected = await _wsService.connect(circuitId);
      if (connected && mounted) {
        // Écouter les données en temps réel
        _wsService.stream?.listen((data) {
          if (mounted) {
            setState(() {
              _lastTimingData = data;
              _errorMessage = null;
              // Stocker aussi le message brut pour affichage debug
              _lastRawMessage = data.toString();
              // CORRECTION : Utiliser le cache accumulé au lieu des données partielles
              _driversData = _wsService.allKartsData;
              print(
                '📊 TABLEAU: Affichage ${_driversData.length} karts (cache accumulé)',
              );
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur de connexion: $e';
        });
      }
    }
  }

  Future<void> _startTiming(String circuitId) async {
    setState(() {
      _errorMessage = null;
    });

    // 1. Démarrer le timing backend
    final timingSuccess = await BackendService.startTiming(circuitId);
    if (!timingSuccess) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible de démarrer le timing backend';
        });
      }
      return;
    }

    // 2. Mettre à jour l'état timing
    if (mounted) {
      setState(() {
        _timingActive = true;
        _errorMessage = null;
      });
    }

    // 3. Se connecter au WebSocket (sans bloquer l'état timing)
    try {
      await _connectToTiming(circuitId);
    } catch (e) {
      // Timing reste actif même si WebSocket échoue
      if (mounted) {
        setState(() {
          _errorMessage = 'Timing démarré mais connexion WebSocket échouée';
        });
      }
    }
  }

  Future<void> _stopTiming(String circuitId) async {
    final success = await BackendService.stopTiming(circuitId);
    if (success && mounted) {
      setState(() {
        _timingActive = false;
        _lastTimingData = null;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() {
        _errorMessage = 'Impossible d\'arrêter le timing';
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
              horizontal: 20, // → 20px à gauche et à droite
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
        _buildCompactButton(
          icon: Icons.play_arrow,
          label: 'START',
          isEnabled: _backendHealthy && !_timingActive,
          color: RacingTheme.excellent,
          onPressed: () => _startTiming(circuitId),
        ),
        const SizedBox(width: 8),
        _buildCompactButton(
          icon: Icons.stop,
          label: 'STOP',
          isEnabled: _backendHealthy && _timingActive,
          color: RacingTheme.bad,
          onPressed: () => _stopTiming(circuitId),
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
          isActive: _timingActive,
          label: 'TIM',
          activeColor: RacingTheme.racingGold,
        ),
        const SizedBox(width: 8),
        _buildStatusLED(
          isActive: _wsService.isConnected,
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
    if (_errorMessage == null) return const SizedBox.shrink();

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
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _errorMessage = null),
              icon: const Icon(Icons.close, color: Colors.red),
            ),
          ],
        ),
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

          return SingleChildScrollView(
            child: Column(
              children: [
                // Message d'erreur
                _buildErrorMessage(),

                // Contrôles de timing avec nom du circuit intégré
                _buildTimingControls(selectedCircuitId),

                // Tableau de timing principal
                LiveTimingTable(
                  driversData: _driversData,
                  isConnected: _wsService.isConnected,
                ),

                // Sections de debug pliables
                DebugSections(
                  lastTimingData: _lastTimingData,
                  lastRawMessage: _lastRawMessage,
                ),

                // Espace en bas pour le scrolls
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
