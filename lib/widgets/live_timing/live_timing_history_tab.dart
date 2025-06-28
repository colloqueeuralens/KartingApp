import 'package:flutter/material.dart';
import '../../models/live_timing_models.dart';
import '../../services/live_timing_storage_service.dart';
import '../../services/backend_service.dart';
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
        // NETTOYER COMPLÈTEMENT l'état lors d'une nouvelle session
        setState(() {
          _kartsHistory = session.kartsHistory;
          // Si c'est une nouvelle session (vide), réinitialiser complètement
          if (session.kartsHistory.isEmpty) {
            _selectedKartId = null;
            _laps.clear();
          }
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
      // Stratégie hybride : essayer le cache local de la session courante EN PREMIER pour la rapidité
      List<LiveLapData> laps = [];
      
      // 1. Essayer le cache local (historique de la session courante)
      if (_kartsHistory.containsKey(kartId)) {
        final history = _kartsHistory[kartId]!;
        laps = history.allLaps;
      }
      
      // 2. Si pas de tours dans le cache OU très peu, compléter avec Firebase
      if (laps.isEmpty) {
        laps = await LiveTimingStorageService.getKartLaps(kartId);
      }
      
      // DÉDUPLICATION - Éliminer les doublons basés sur kartId + numéro de tour
      laps = _deduplicateLaps(laps);
      
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
    // Liste élargie de clés possibles pour les noms d'équipes et pilotes
    // PRIORITÉ AUX ÉQUIPES d'abord, puis aux pilotes
    final possibleNameKeys = [
      // Clés d'équipes (priorité haute) - 'Equipe' EN PREMIER pour données réelles
      'Equipe', 'Team', 'Équipe', 'Club', 'Sponsor', 'Organisation', 'Team Name', 'Nom Équipe',
      'Nom Team', 'TeamName', 'EquipeName', 'Squad', 'Crew', 'Écurie',
      // Clés de pilotes (priorité plus basse)
      'Nom', 'Name', 'Pilot', 'Driver', 'Pilote', 'Participant', 
      'Player', 'Usuario', 'Nom Pilote', 'Driver Name', 'Pilot Name'
    ];
    
    // 1. Essayer dans l'historique des tours (méthode originale)
    if (_kartsHistory.containsKey(kartId)) {
      final history = _kartsHistory[kartId]!;
      if (history.allLaps.isNotEmpty) {
        // Chercher dans les données de timing du premier tour
        final timingData = history.allLaps.first.allTimingData;
        
        for (final key in possibleNameKeys) {
          if (timingData.containsKey(key) && timingData[key] != null) {
            final name = timingData[key].toString().trim();
            if (_isValidName(name)) {
              return name;
            }
          }
        }
        
        // Chercher aussi dans les tours plus récents au cas où
        for (final lap in history.allLaps.take(3)) {
          for (final key in possibleNameKeys) {
            if (lap.allTimingData.containsKey(key) && lap.allTimingData[key] != null) {
              final name = lap.allTimingData[key].toString().trim();
              if (_isValidName(name)) {
                return name;
              }
            }
          }
        }
      }
    }
    
    // 2. Essayer de trouver des noms depuis d'autres sources
    // Si on a le kartId qui correspond à un numéro de kart de la simulation
    try {
      final kartNumber = int.tryParse(kartId);
      if (kartNumber != null && kartNumber >= 1 && kartNumber <= 8) {
        // Noms du simulateur (correspondant à live_timing_simulator.dart)
        const simulatorNames = [
          'MARTIN', 'DUBOIS', 'BERNARD', 'THOMAS', 
          'ROBERT', 'PETIT', 'DURAND', 'LEROY'
        ];
        if (kartNumber <= simulatorNames.length) {
          return simulatorNames[kartNumber - 1];
        }
      }
    } catch (e) {
      // Ignore les erreurs de parsing
    }
    
    // 3. Fallback avec un nom plus user-friendly
    return 'Kart $kartId'; // Plus user-friendly que juste l'ID
  }
  
  /// Dédupliquer les tours basé sur numéro de tour (défense finale côté UI)
  List<LiveLapData> _deduplicateLaps(List<LiveLapData> laps) {
    if (laps.isEmpty) return laps;
    
    // Utiliser une Map pour déduplication automatique basée sur le numéro de tour
    final Map<int, LiveLapData> uniqueLaps = {};
    
    for (final lap in laps) {
      final lapNumber = lap.lapNumber;
      
      // Garder seulement un tour par numéro de tour
      // En cas de doublon, privilégier le tour avec le timestamp le plus récent
      if (!uniqueLaps.containsKey(lapNumber) || 
          lap.timestamp.isAfter(uniqueLaps[lapNumber]!.timestamp)) {
        uniqueLaps[lapNumber] = lap;
      }
    }
    
    // Retourner les tours triés par numéro de tour
    final result = uniqueLaps.values.toList();
    result.sort((a, b) => a.lapNumber.compareTo(b.lapNumber));
    
    return result;
  }

  /// Vérifier si un nom est valide (équipes ou pilotes)
  bool _isValidName(String name) {
    // Nettoyage basique
    final cleanName = name.trim();
    
    // Vérifications de base
    if (cleanName.isEmpty || 
        cleanName == '--' || 
        cleanName == '---' ||
        cleanName.toLowerCase() == 'null' ||
        cleanName.toLowerCase() == 'undefined' ||
        cleanName == '0') {
      return false;
    }
    
    // Pour les équipes, accepter même si c'est principalement des chiffres
    // Car "TEAM 123" ou "SAPIAN 42" sont des noms d'équipes valides
    
    // Rejeter seulement si c'est UNIQUEMENT des chiffres ET moins de 4 caractères
    // (pour éviter les IDs courts comme "1", "42" mais accepter "1234" qui pourrait être un nom d'équipe)
    if (RegExp(r'^\d+$').hasMatch(cleanName) && cleanName.length < 4) {
      return false;
    }
    
    // Accepter tout le reste (noms d'équipes, de pilotes, etc.)
    return true;
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          const Text(
            'Kart :',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final kartsList = _kartsHistory.keys.toList();
              final kartsCount = kartsList.length;
              final totalGap = (kartsCount - 1) * 12.0;
              final availableWidth = constraints.maxWidth - totalGap;
              final cardWidth = (availableWidth / kartsCount).clamp(60.0, 120.0);
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: kartsList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final kartId = entry.value;
                  final isSelected = kartId == _selectedKartId;
                  final history = _kartsHistory[kartId]!;
                  final pilotName = _getPilotName(kartId);
                  
                  return Container(
                    width: cardWidth,
                    height: 72,
                    margin: EdgeInsets.only(
                      right: index < kartsCount - 1 ? 12 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => _loadKartLaps(kartId),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              pilotName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${history.totalLaps} tours',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLapsTable() {
    // Différencier entre "aucun kart sélectionné" et "kart sélectionné mais pas de tours"
    if (_selectedKartId == null) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_off,
                  size: 64,
                  color: Colors.white54,
                ),
                SizedBox(height: 16),
                Text(
                  'Sélectionnez un kart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Si un kart est sélectionné mais pas de tours
    if (_laps.isEmpty && !_isLoading) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.white54,
                ),
                SizedBox(height: 16),
                Text(
                  'Aucun tour enregistré',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ce kart n\'a pas encore effectué de tours',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContentTitle(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 32),
            _buildTableContainer(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTitle() {
    final pilotName = _selectedKartId != null ? _getPilotName(_selectedKartId!) : "";
    return Text(
      'HISTORIQUE DES TOURS - $pilotName',
      style: const TextStyle(
        color: Color(0xFF22C55E),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
  
  Widget _buildStatsRow() {
    if (_laps.isEmpty) return const SizedBox.shrink();
    
    final bestLap = _getBestLap();
    final averageTime = _getAverageTime();
    final lastLap = _laps.first;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Meilleur tour',
            bestLap?.lapTime ?? '--:--:---',
            true,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            'Temps moyen',
            averageTime,
            false,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            'Dernier tour',
            lastLap.lapTime,
            false,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String label, String value, bool isBest) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isBest ? const Color(0xFF22C55E) : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Mono',
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    return Expanded(
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: _buildTableBody(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '#',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'TEMPS',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ÉCART',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTableBody() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withValues(alpha: 0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: ListView.builder(
        itemCount: _laps.length,
        itemBuilder: (context, index) {
          final lap = _laps[index];
          return _buildTableRow(lap, index);
        },
      ),
    );
  }
  
  Widget _buildTableRow(LiveLapData lap, int index) {
    final bestLap = _getBestLap();
    final isBestLap = bestLap != null && lap.lapTime == bestLap.lapTime;
    final gap = _calculateGap(lap, bestLap);
    final isEven = index % 2 == 0;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: isEven 
            ? const Color(0xFF374151).withValues(alpha: 0.2)
            : const Color(0xFF1F2937).withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '#${lap.lapNumber}',
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              lap.lapTime,
              style: TextStyle(
                color: isBestLap ? const Color(0xFF22C55E) : Colors.white,
                fontSize: 13,
                fontWeight: isBestLap ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'SF Mono',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              gap,
              style: TextStyle(
                color: _getGapColor(gap),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Mono',
              ),
            ),
          ),
          SizedBox(
            width: 18,
            height: 18,
            child: GestureDetector(
              onTap: () => _showLapDetails(lap),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF6B7280),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'i',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
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
  
  /// Obtenir le meilleur tour de la liste
  LiveLapData? _getBestLap() {
    if (_laps.isEmpty) return null;
    
    LiveLapData? best;
    for (final lap in _laps) {
      if (lap.lapTime.isEmpty || lap.lapTime == '--:--' || lap.lapTime == '0:00.000') {
        continue;
      }
      
      if (best == null) {
        best = lap;
      } else {
        try {
          final currentDuration = _parseLapTime(lap.lapTime);
          final bestDuration = _parseLapTime(best.lapTime);
          if (currentDuration < bestDuration) {
            best = lap;
          }
        } catch (e) {
          // Ignorer les erreurs de parsing
        }
      }
    }
    return best;
  }
  
  /// Calculer le temps moyen
  String _getAverageTime() {
    if (_laps.isEmpty) return '--:--:---';
    
    final validLaps = _laps.where((lap) => 
      lap.lapTime.isNotEmpty && 
      lap.lapTime != '--:--' && 
      lap.lapTime != '0:00.000'
    ).toList();
    
    if (validLaps.isEmpty) return '--:--:---';
    
    try {
      Duration totalDuration = Duration.zero;
      for (final lap in validLaps) {
        totalDuration += _parseLapTime(lap.lapTime);
      }
      
      final avgDuration = Duration(
        milliseconds: totalDuration.inMilliseconds ~/ validLaps.length,
      );
      
      return _formatDuration(avgDuration);
    } catch (e) {
      return '--:--:---';
    }
  }
  
  /// Calculer l'écart par rapport au meilleur tour
  String _calculateGap(LiveLapData lap, LiveLapData? bestLap) {
    if (bestLap == null || lap.lapTime == bestLap.lapTime) {
      return '-';
    }
    
    if (lap.lapTime.isEmpty || lap.lapTime == '--:--' || lap.lapTime == '0:00.000') {
      return '-';
    }
    
    try {
      final lapDuration = _parseLapTime(lap.lapTime);
      final bestDuration = _parseLapTime(bestLap.lapTime);
      final gap = lapDuration - bestDuration;
      
      if (gap.isNegative) return '-';
      
      final gapSeconds = gap.inMilliseconds / 1000.0;
      return '+${gapSeconds.toStringAsFixed(3)}';
    } catch (e) {
      return '-';
    }
  }
  
  /// Obtenir la couleur pour l'écart
  Color _getGapColor(String gap) {
    if (gap == '-') return const Color(0xFF9CA3AF);
    if (gap.startsWith('+')) return const Color(0xFFEF4444);
    if (gap.startsWith('+-')) return const Color(0xFF22C55E);
    return const Color(0xFF9CA3AF);
  }
  
  /// Parser un temps de tour vers Duration
  Duration _parseLapTime(String lapTime) {
    if (lapTime.isEmpty || lapTime == '--:--' || lapTime == '0:00.000') {
      return Duration.zero;
    }

    try {
      final parts = lapTime.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      } else {
        final secondsParts = lapTime.split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(seconds: seconds, milliseconds: milliseconds);
      }
    } catch (e) {
      return Duration.zero;
    }
  }
  
  /// Formater une Duration vers String
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
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