import 'package:flutter/material.dart';
import 'dart:ui';
import '../../services/kmrs_service.dart';
import '../../theme/racing_theme.dart';
import '../common/glassmorphism_section_card.dart';

/// RACING Page KMRS - Interface 16x22 reproduisant la zone d'impression Excel
/// Affichage optimisé pour la course avec données temps réel
class KmrsRacingPage extends StatelessWidget {
  final KmrsService kmrsService;

  const KmrsRacingPage({
    super.key,
    required this.kmrsService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RacingTheme.racingBlack,
              Colors.grey[900]!,
            ],
          ),
        ),
        child: ListenableBuilder(
          listenable: kmrsService,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRacingGrid(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final racingData = kmrsService.racingData;
    
    return GlassmorphismSectionCardCompact(
      title: 'Interface de Course',
      subtitle: 'Données temps réel optimisées pour la course',
      icon: Icons.sports_motorsports,
      accentColor: Colors.red,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.speed,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Position: ${racingData.position} | Tour: ${racingData.currentLap}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dernier tour: ${_formatDuration(racingData.lastLapTime)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
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
      ],
    );
  }

  Widget _buildRacingGrid() {
    final racingData = kmrsService.racingData;
    final gridData = racingData.gridData;

    return GlassmorphismSectionCardCompact(
      title: 'Grille de Course 16x22',
      subtitle: 'Interface optimisée pour le suivi temps réel',
      icon: Icons.grid_on,
      accentColor: Colors.red,
      children: [
        Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 800),
                  child: Table(
                    border: TableBorder.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    defaultColumnWidth: const FixedColumnWidth(60),
                    children: gridData.asMap().entries.map((rowEntry) {
                      final rowIndex = rowEntry.key;
                      final rowData = rowEntry.value;
                      
                      return TableRow(
                        decoration: BoxDecoration(
                          color: rowIndex == 0 
                            ? Colors.red.withValues(alpha: 0.2) // Header
                            : rowIndex % 2 == 1 
                              ? Colors.white.withValues(alpha: 0.05) // Alternate rows
                              : Colors.transparent,
                        ),
                        children: rowData.asMap().entries.map((cellEntry) {
                          final cellIndex = cellEntry.key;
                          final cellValue = cellEntry.value;
                          
                          return Container(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              cellValue.toString(),
                              style: TextStyle(
                                color: rowIndex == 0 ? Colors.red : Colors.white,
                                fontSize: 12,
                                fontWeight: rowIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
  }
}
