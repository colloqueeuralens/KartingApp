import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../../services/backend_service.dart';

/// Page LiveTiming avec intégration backend
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
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _backendHealthy ? Icons.cloud_done : Icons.cloud_off,
                  color: _backendHealthy ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _backendHealthy ? 'Backend connecté' : 'Backend hors ligne',
                  style: TextStyle(
                    color: _backendHealthy ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_backendHealthy) ...[
                  Icon(
                    _timingActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _timingActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timingActive ? 'Timing actif' : 'Timing inactif',
                    style: TextStyle(
                      color: _timingActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _backendHealthy && !_timingActive
                        ? () => _startTiming(circuitId)
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Démarrer Timing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _backendHealthy && _timingActive
                        ? () => _stopTiming(circuitId)
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Arrêter Timing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _connectToTiming(circuitId),
              icon: Icon(_wsService.isConnected ? Icons.sync : Icons.sync_disabled),
              label: Text(_wsService.isConnected ? 'Connecté WebSocket' : 'Connecter WebSocket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingData() {
    if (_lastTimingData == null) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucune donnée de timing reçue',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final data = _lastTimingData!['data'] as Map<String, dynamic>? ?? {};
    final mappedData = data['mapped_data'] as Map<String, dynamic>? ?? {};
    final rawData = data['raw_data'] as Map<String, dynamic>? ?? {};
    final timestamp = data['timestamp'] as String?;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Données en temps réel',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (timestamp != null)
                  Text(
                    DateTime.parse(timestamp).toLocal().toString().substring(11, 19),
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            const Divider(),
            if (mappedData.isNotEmpty) ...[
              const Text(
                'Données mappées (C1-C14):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...mappedData.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(': ${entry.value}'),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 16),
            ],
            if (rawData.isNotEmpty) ...[
              const Text(
                'Données brutes:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rawData.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
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
        title: const Text('Live Timing'),
        automaticallyImplyLeading: false,
        actions: AppBarActions.getActions(
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
                  Text('Veuillez sélectionner un circuit dans la configuration'),
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
              Expanded(
                child: SingleChildScrollView(
                  child: _buildTimingData(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
