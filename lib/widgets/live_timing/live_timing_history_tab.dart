import 'package:flutter/material.dart';
import '../../models/live_timing_models.dart';
import '../../services/live_timing_storage_service.dart';
import '../../theme/racing_theme.dart';

/// Onglet d'historique des tours pour Live Timing
class LiveTimingHistoryTab extends StatefulWidget {
  final bool isConnected;

  const LiveTimingHistoryTab({
    super.key,
    required this.isConnected,
  });

  @override
  State<LiveTimingHistoryTab> createState() => _LiveTimingHistoryTabState();
}

class _LiveTimingHistoryTabState extends State<LiveTimingHistoryTab> {
  String? _selectedKartId;
  List<LiveLapData> _laps = [];
  Map<String, LiveTimingHistory> _kartsHistory = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessionHistory();
    
    // Écouter les mises à jour de session en temps réel
    LiveTimingStorageService.sessionStream.listen((session) {
      if (mounted) {
        setState(() {
          _kartsHistory = session.kartsHistory;
        });
        
        // Si un kart est sélectionné, recharger ses tours
        if (_selectedKartId != null) {
          _loadKartLaps(_selectedKartId!);
        }
      }
    });
  }

  Future<void> _loadSessionHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final session = LiveTimingStorageService.currentSession;
      if (session != null) {
        setState(() {
          _kartsHistory = session.kartsHistory;
        });
        
        // Charger les tours du premier kart par défaut
        if (_kartsHistory.isNotEmpty) {
          final firstKart = _kartsHistory.keys.first;
          await _loadKartLaps(firstKart);
        }
      }
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadKartLaps(String kartId) async {
    setState(() {
      _selectedKartId = kartId;
      _isLoading = true;
    });

    try {
      // Essayer d'abord depuis l'historique local (cache)
      List<LiveLapData> laps = [];
      if (_kartsHistory.containsKey(kartId)) {
        final history = _kartsHistory[kartId]!;
        laps = history.allLaps;
      }
      
      // Si pas de tours dans le cache, essayer Firebase
      if (laps.isEmpty) {
        laps = await LiveTimingStorageService.getKartLaps(kartId);
      }
      
      // Inverser l'ordre pour afficher les tours les plus récents en premier
      laps = laps.reversed.toList();
      
      setState(() {
        _laps = laps;
      });
    } catch (e) {
      setState(() {
        _laps = [];
      });
    }

    setState(() => _isLoading = false);
  }

  /// Récupérer le nom du pilote depuis les données de timing
  String _getPilotName(String kartId) {
    if (!_kartsHistory.containsKey(kartId)) {
      return kartId; // Fallback vers kartId si pas d'historique
    }
    
    final history = _kartsHistory[kartId]!;
    if (history.allLaps.isEmpty) {
      return kartId; // Fallback si pas de tours
    }
    
    // Chercher le nom dans les données de timing du premier tour
    final timingData = history.allLaps.first.allTimingData;
    
    // Essayer différentes variantes de clés pour le nom
    for (final key in ['Nom', 'Name', 'Pilot', 'Driver', 'Pilote']) {
      if (timingData.containsKey(key) && timingData[key] != null) {
        final name = timingData[key].toString().trim();
        if (name.isNotEmpty && name != '--' && name.toLowerCase() != 'null') {
          return name;
        }
      }
    }
    
    return kartId; // Fallback vers kartId si aucun nom trouvé
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildKartSelector(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLapsTable(),
        ),
      ],
    );
  }

  Widget _buildKartSelector() {
    if (_kartsHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Aucun historique de tours disponible',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RacingTheme.racingBlack.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: RacingTheme.racingGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Kart : ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _kartsHistory.keys.map((kartId) {
                  final isSelected = kartId == _selectedKartId;
                  final history = _kartsHistory[kartId]!;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _loadKartLaps(kartId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? RacingTheme.racingGreen
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? RacingTheme.racingGreen
                                : Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getPilotName(kartId),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${history.totalLaps} tours',
                              style: TextStyle(
                                color: isSelected 
                                    ? Colors.black87 
                                    : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLapsTable() {
    if (_laps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_off, 
              size: 64, 
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedKartId == null 
                  ? 'Sélectionnez un kart'
                  : 'Aucun tour enregistré',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RacingTheme.racingBlack,
            RacingTheme.racingBlack.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: RacingTheme.racingShadow,
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _laps.length,
              itemBuilder: (context, index) {
                final lap = _laps[index];
                
                return _buildLapCard(lap, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RacingTheme.racingGreen.withValues(alpha: 0.2),
            RacingTheme.racingGreen.withValues(alpha: 0.1),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: RacingTheme.racingGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'HISTORIQUE DES TOURS - ${_selectedKartId != null ? _getPilotName(_selectedKartId!) : ""}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLapCard(LiveLapData lap, int index) {
    final isFirst = index == 0; // Premier tour (plus récent)
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isFirst 
                ? RacingTheme.racingGreen.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            isFirst 
                ? RacingTheme.racingGreen.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.1),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFirst 
              ? RacingTheme.racingGreen.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
          width: isFirst ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFirst 
                ? RacingTheme.racingGreen.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: isFirst ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Numéro de tour (gros et visible)
            Container(
              width: 60,
              decoration: BoxDecoration(
                color: isFirst 
                    ? RacingTheme.racingGreen
                    : RacingTheme.racingBlue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#${lap.lapNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isFirst)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DERNIER',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Informations principales
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Temps de tour
                  Text(
                    lap.lapTime,
                    style: TextStyle(
                      color: isFirst ? RacingTheme.racingGreen : Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Timestamp
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(lap.timestamp),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.white60,
                    size: 20,
                  ),
                  onPressed: () => _showLapDetails(lap),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLapRow(LiveLapData lap, bool isEven, bool isLast) {
    final backgroundColor = isEven
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              )
            : null,
      ),
      child: Row(
        children: [
          // Numéro de tour
          Expanded(
            flex: 1,
            child: Text(
              '#${lap.lapNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Temps de tour
          Expanded(
            flex: 2,
            child: Text(
              lap.lapTime,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Timestamp
          Expanded(
            flex: 2,
            child: Text(
              _formatTimestamp(lap.timestamp),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Données supplémentaires
          Expanded(
            flex: 1,
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white54),
              onPressed: () => _showLapDetails(lap),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}';
  }

  void _showLapDetails(LiveLapData lap) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RacingTheme.racingBlack,
        title: Text(
          'Tour #${lap.lapNumber} - ${lap.kartId}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Temps', lap.lapTime),
            _detailRow('Timestamp', lap.timestamp.toString()),
            if (lap.allTimingData.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Données timing complètes:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...lap.allTimingData.entries.map(
                (entry) => _detailRow(entry.key, entry.value?.toString() ?? ''),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}