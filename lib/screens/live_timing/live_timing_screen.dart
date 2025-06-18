import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
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
    final success = await BackendService.startTiming(circuitId);
    if (success && mounted) {
      setState(() {
        _timingActive = true;
        _errorMessage = null;
      });
      // Reconnecter au WebSocket après avoir démarré le timing
      await _connectToTiming(circuitId);
    } else if (mounted) {
      setState(() {
        _errorMessage = 'Impossible de démarrer le timing';
      });
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RacingTheme.checkeredGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RacingTheme.racingShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header avec statut
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _backendHealthy
                          ? Icons.satellite_alt
                          : Icons.signal_wifi_off,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONTRÔLE TIMING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _backendHealthy
                                    ? RacingTheme.excellent
                                    : RacingTheme.bad,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _backendHealthy
                                  ? 'Backend connecté'
                                  : 'Backend hors ligne',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _timingActive
                                    ? RacingTheme.excellent
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _timingActive ? 'Timing actif' : 'Timing inactif',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Boutons de contrôle racing
              Row(
                children: [
                  Expanded(
                    child: _RacingControlButton(
                      icon: Icons.play_arrow,
                      label: 'START',
                      isEnabled: _backendHealthy && !_timingActive,
                      color: RacingTheme.excellent,
                      onPressed: () => _startTiming(circuitId),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RacingControlButton(
                      icon: Icons.stop,
                      label: 'STOP',
                      isEnabled: _backendHealthy && _timingActive,
                      color: RacingTheme.bad,
                      onPressed: () => _stopTiming(circuitId),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bouton WebSocket
              SizedBox(
                width: double.infinity,
                child: _RacingControlButton(
                  icon: _wsService.isConnected ? Icons.wifi : Icons.wifi_off,
                  label: _wsService.isConnected
                      ? 'WEBSOCKET CONNECTÉ'
                      : 'CONNECTER WEBSOCKET',
                  isEnabled: true,
                  color: _wsService.isConnected
                      ? RacingTheme.racingBlue
                      : RacingTheme.racingYellow,
                  onPressed: () => _connectToTiming(circuitId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimingData() {
    if (_lastTimingData == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade800, Colors.grey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: RacingTheme.darkShadow,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.timer_off, size: 48, color: Colors.white70),
                  SizedBox(height: 16),
                  Text(
                    'AUCUNE DONNÉE REÇUE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'En attente des données de timing...',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final data = _lastTimingData!['data'] as Map<String, dynamic>? ?? {};
    final mappedData = data['mapped_data'] as Map<String, dynamic>? ?? {};
    final rawData = data['raw_data'] as Map<String, dynamic>? ?? {};
    final timestamp = data['timestamp'] as String?;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RacingTheme.racingBlack,
            RacingTheme.racingBlack.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: RacingTheme.racingShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: RacingTheme.racingGreen.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header du timing board
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.speed,
                      color: RacingTheme.racingGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'TIMING BOARD - DONNÉES LIVE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (timestamp != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        DateTime.parse(
                          timestamp,
                        ).toLocal().toString().substring(11, 19),
                        style: const TextStyle(
                          color: RacingTheme.racingGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Données mappées avec style F1
              if (mappedData.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: RacingTheme.racingYellow.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.data_array,
                            color: RacingTheme.racingYellow,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'DONNÉES MAPPÉES (C1-C14)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: RacingTheme.racingYellow,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...mappedData.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RacingTheme.racingBlue.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: RacingTheme.racingBlue,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${entry.value}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Données brutes avec style terminal
              if (rawData.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.terminal,
                            color: RacingTheme.racingGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'DONNÉES BRUTES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: RacingTheme.racingGreen,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rawData.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: RacingTheme.racingGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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

          // Auto-connecter au circuit sélectionné
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_wsService.currentCircuitId != selectedCircuitId) {
              _connectToTiming(selectedCircuitId);
            }
          });

          return Column(
            children: [
              // Affichage du nom du circuit sélectionné
              FutureBuilder<String?>(
                future: CircuitService.getCircuitName(selectedCircuitId),
                builder: (context, circuitSnapshot) {
                  if (circuitSnapshot.hasData && circuitSnapshot.data != null) {
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

              // Message d'erreur
              _buildErrorMessage(),

              // Contrôles de timing
              _buildTimingControls(selectedCircuitId),

              // Données de timing en temps réel
              Expanded(child: SingleChildScrollView(child: _buildTimingData())),
            ],
          );
        },
      ),
    );
  }
}

/// Widget de bouton de contrôle racing pour live timing
class _RacingControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final Color color;
  final VoidCallback onPressed;

  const _RacingControlButton({
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_RacingControlButton> createState() => _RacingControlButtonState();
}

class _RacingControlButtonState extends State<_RacingControlButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isEnabled
          ? (_) {
              setState(() => _isPressed = true);
              _animationController.forward();
            }
          : null,
      onTapUp: widget.isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              _animationController.reverse();
              widget.onPressed();
            }
          : null,
      onTapCancel: widget.isEnabled
          ? () {
              setState(() => _isPressed = false);
              _animationController.reverse();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: widget.isEnabled
                    ? LinearGradient(
                        colors: [
                          widget.color,
                          widget.color.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : LinearGradient(
                        colors: [Colors.grey.shade600, Colors.grey.shade700],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: widget.isEnabled && _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
