import 'package:flutter/material.dart';
import 'dart:ui';
import '../../services/kmrs_service.dart';
import '../../models/kmrs_models.dart';
import '../../theme/racing_theme.dart';
import '../common/glassmorphism_section_card.dart';

/// Rapport Pilotes Page KMRS - Statistiques et analyses des pilotes
/// Interface de rapports détaillés pour chaque pilote
class KmrsPilotsPage extends StatelessWidget {
  final KmrsService kmrsService;
  final Function(PilotData) onPilotUpdated;

  const KmrsPilotsPage({
    super.key,
    required this.kmrsService,
    required this.onPilotUpdated,
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
                  _buildPilotsList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final session = kmrsService.currentSession;
    final totalPilots = session?.pilots.length ?? 0;
    
    return GlassmorphismSectionCardCompact(
      title: 'Statistiques Pilotes',
      subtitle: 'Analyses détaillées des performances pilotes',
      icon: Icons.people,
      accentColor: Colors.teal,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.teal.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: Colors.teal,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Équipe: $totalPilots pilotes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Analyses de performance en temps réel',
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

  Widget _buildPilotsList() {
    final session = kmrsService.currentSession;
    final pilots = session?.pilots ?? [];
    final stints = session?.stints ?? [];

    if (pilots.isEmpty) {
      return GlassmorphismSectionCardCompact(
        title: 'Aucun Pilote',
        subtitle: 'Aucun pilote configuré pour le moment',
        icon: Icons.info,
        accentColor: Colors.orange,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun pilote configuré',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Utilisez la Start Page pour ajouter des pilotes',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: pilots.map((pilot) {
        final pilotStints = stints.where((s) => s.pilotId == pilot.id).toList();
        final stats = KmrsCalculationEngine.calculatePilotStatistics(pilot, pilotStints);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildPilotCard(pilot, stats, pilotStints.length),
        );
      }).toList(),
    );
  }

  Widget _buildPilotCard(PilotData pilot, Map<String, dynamic> stats, int stintsCount) {
    final skillColor = _getSkillColor(pilot.skillLevel);
    
    return GlassmorphismSectionCardCompact(
      title: pilot.name,
      subtitle: 'Surnom: ${pilot.nickname}',
      icon: Icons.person,
      accentColor: skillColor,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: skillColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: skillColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Niveau de skill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Niveau de compétence',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: skillColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: skillColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${(pilot.skillLevel * 100).toInt()}%',
                            style: TextStyle(
                              color: skillColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Statistiques de performance
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn('Relais', stintsCount.toString()),
                              _buildStatColumn('Temps Total', _formatDuration(stats['totalDriveTime'] ?? Duration.zero)),
                              _buildStatColumn('Tours', (stats['totalLaps'] ?? 0).toString()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn('Meilleur Tour', _formatDuration(stats['bestLapTime'] ?? Duration.zero)),
                              _buildStatColumn('Temps Moyen', _formatDuration(stats['averageLapTime'] ?? Duration.zero)),
                              _buildStatColumn('Consistance', '${(stats['consistency'] ?? 0.0).toStringAsFixed(1)}%'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Graphique de performance
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: skillColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: skillColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.trending_up,
                              color: skillColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tendance de Performance',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getPerformanceTrend(stats),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Modifier',
                            icon: Icons.edit,
                            color: skillColor,
                            onPressed: () => _editPilot(pilot),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Détails',
                            icon: Icons.analytics,
                            color: Colors.teal,
                            onPressed: () => _viewDetails(pilot, stats),
                          ),
                        ),
                      ],
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

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }


  Color _getSkillColor(double skillLevel) {
    if (skillLevel >= 0.8) return Colors.green;
    if (skillLevel >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getPerformanceTrend(Map<String, dynamic> stats) {
    final consistency = stats['consistency'] ?? 0.0;
    if (consistency >= 80) return 'Très stable, performance constante';
    if (consistency >= 60) return 'Stable, quelques variations';
    return 'Variable, potentiel d\'amélioration';
  }

  void _editPilot(PilotData pilot) {
    // TODO: Implémenter l'édition de pilote
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewDetails(PilotData pilot, Map<String, dynamic> stats) {
    // TODO: Implémenter la vue détaillée
  }
}