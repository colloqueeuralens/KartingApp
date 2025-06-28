import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/live_timing_storage_service.dart';
import '../../services/circuit_service.dart';
import '../../theme/racing_theme.dart';

/// Onglet des statistiques et export pour Live Timing
class LiveTimingStatsTab extends StatefulWidget {
  final bool isConnected;

  const LiveTimingStatsTab({
    super.key,
    required this.isConnected,
  });

  @override
  State<LiveTimingStatsTab> createState() => _LiveTimingStatsTabState();
}

class _LiveTimingStatsTabState extends State<LiveTimingStatsTab> {
  Map<String, dynamic> _sessionStats = {};
  bool _isLoading = false;
  Map<String, String> _circuitNames = {};

  @override
  void initState() {
    super.initState();
    _loadSessionStats();
    
    // Écouter les mises à jour de session
    LiveTimingStorageService.sessionStream.listen((_) {
      if (mounted) {
        _loadSessionStats();
      }
    });
  }

  void _loadSessionStats() async {
    setState(() => _isLoading = true);
    
    // Charger les statistiques
    _sessionStats = LiveTimingStorageService.getSessionStatistics();
    
    // Charger le nom du circuit si nécessaire
    final session = LiveTimingStorageService.currentSession;
    if (session != null && !_circuitNames.containsKey(session.circuitId)) {
      final circuitName = await CircuitService.getCircuitName(session.circuitId);
      if (circuitName != null && mounted) {
        setState(() {
          _circuitNames[session.circuitId] = circuitName;
        });
      }
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSessionOverview(),
          const SizedBox(height: 20),
          _buildStatisticsCards(),
          const SizedBox(height: 20),
          _buildExportSection(),
        ],
      ),
    );
  }

  Widget _buildSessionOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: RacingTheme.racingGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'VUE D\'ENSEMBLE DE LA SESSION',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (widget.isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RacingTheme.racingGreen,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: RacingTheme.racingGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'EN COURS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            _buildOverviewContent(),
        ],
      ),
    );
  }

  Widget _buildOverviewContent() {
    final session = LiveTimingStorageService.currentSession;
    if (session == null) {
      return const Text(
        'Aucune session active',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      );
    }

    return Column(
      children: [
        // Ligne unique avec Circuit, Durée et Début
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                'Circuit',
                _getCircuitDisplayName(session.circuitId),
                Icons.location_on,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoTile(
                'Durée',
                _sessionStats['sessionDuration'] ?? '00:00:00',
                Icons.timer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoTile(
                'Début',
                _formatDate(session.raceStart),
                Icons.flag,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Karts',
                _sessionStats['totalKarts']?.toString() ?? '0',
                Icons.directions_car,
                RacingTheme.racingBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Tours',
                _sessionStats['totalLaps']?.toString() ?? '0',
                Icons.replay,
                RacingTheme.racingGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Meilleur Tour',
                _sessionStats['overallBestLap']?.toString() ?? '--:--',
                Icons.speed,
                RacingTheme.excellent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Kart le + Actif',
                _sessionStats['mostActiveKart']?.toString() ?? 'Aucun',
                Icons.star,
                RacingTheme.racingGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.download,
                color: RacingTheme.racingGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'EXPORT DES DONNÉES',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Exportez les données de cette session pour analyse externe ou archivage.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildExportButton(
                  'Export JSON',
                  Icons.code,
                  RacingTheme.racingBlue,
                  _exportAsJson,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExportButton(
                  'Export CSV',
                  Icons.table_chart,
                  RacingTheme.racingGreen,
                  _exportAsCsv,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsJson() {
    try {
      final exportData = LiveTimingStorageService.exportSessionData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      _showExportDialog('Export JSON', jsonString);
    } catch (e) {
      _showErrorDialog('Erreur lors de l\'export JSON: $e');
    }
  }

  void _exportAsCsv() {
    try {
      final session = LiveTimingStorageService.currentSession;
      if (session == null) {
        _showErrorDialog('Aucune session active à exporter');
        return;
      }

      final csvData = _generateCsvData(session.kartsHistory);
      _showExportDialog('Export CSV', csvData);
    } catch (e) {
      _showErrorDialog('Erreur lors de l\'export CSV: $e');
    }
  }

  String _generateCsvData(Map<String, dynamic> kartsHistory) {
    final lines = <String>[];
    lines.add('Kart,Tour,Temps,Timestamp,Meilleur Tour');

    kartsHistory.forEach((kartId, history) {
      if (history is Map<String, dynamic> && history['allLaps'] != null) {
        final laps = history['allLaps'] as List<dynamic>;
        for (final lap in laps) {
          if (lap is Map<String, dynamic>) {
            lines.add([
              kartId,
              lap['lapNumber']?.toString() ?? '',
              lap['lapTime']?.toString() ?? '',
              lap['timestamp']?.toString() ?? '',
              history['bestLapTime']?.toString() ?? '',
            ].join(','));
          }
        }
      }
    });

    return lines.join('\n');
  }

  void _showExportDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RacingTheme.racingBlack,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RacingTheme.racingBlack,
        title: const Text(
          'Erreur',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:'
           '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Obtenir le nom d'affichage du circuit
  String _getCircuitDisplayName(String circuitId) {
    return _circuitNames[circuitId] ?? circuitId;
  }
}