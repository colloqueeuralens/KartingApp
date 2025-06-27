import 'package:flutter/material.dart';
import 'dart:ui';
import '../../services/kmrs_service.dart';
import '../../models/kmrs_models.dart';
import '../../theme/racing_theme.dart';
import '../common/glassmorphism_section_card.dart';

/// Stints List Page KMRS - Gestion et historique des relais
/// Interface de gestion complète des relais avec modification/suppression
class KmrsStintsPage extends StatelessWidget {
  final KmrsService kmrsService;
  final Function(StintData) onStintUpdated;
  final Function(String) onStintRemoved;

  const KmrsStintsPage({
    super.key,
    required this.kmrsService,
    required this.onStintUpdated,
    required this.onStintRemoved,
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
                  _buildStintsList(),
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
    final totalStints = session?.stints.length ?? 0;
    
    return GlassmorphismSectionCardCompact(
      title: 'Gestion des Relais',
      subtitle: 'Historique et gestion de tous les relais',
      icon: Icons.list_alt,
      accentColor: Colors.purple,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.purple.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.schedule,
                        color: Colors.purple,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total relais: $totalStints',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gérez et modifiez les relais existants',
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

  Widget _buildStintsList() {
    final session = kmrsService.currentSession;
    final stints = session?.stints ?? [];
    final pilots = session?.pilots ?? [];

    if (stints.isEmpty) {
      return GlassmorphismSectionCardCompact(
        title: 'Aucun Relais',
        subtitle: 'Aucun relais enregistré pour le moment',
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
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun relais enregistré pour le moment',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Utilisez la Main Page pour ajouter des relais',
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
      children: stints.asMap().entries.map((entry) {
        final index = entry.key;
        final stint = entry.value;
        final pilot = pilots.firstWhere(
          (p) => p.id == stint.pilotId,
          orElse: () => PilotData.create('Pilote inconnu'),
        );
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildStintCard(stint, pilot, index + 1),
        );
      }).toList(),
    );
  }

  Widget _buildStintCard(StintData stint, PilotData pilot, int stintNumber) {
    final statusColor = _getStatusColor(stint.status);
    
    return GlassmorphismSectionCardCompact(
      title: 'Relais #$stintNumber',
      subtitle: pilot.name,
      icon: Icons.timer,
      accentColor: statusColor,
      children: [
        // Informations principales
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Durée: ${_formatDuration(stint.actualDuration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pit stop: ${_formatDuration(stint.pitStopDuration)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            stint.status.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Statistiques détaillées
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              _buildStatItem('Tours', stint.lapCount.toString()),
                              _buildStatItem('Meilleur tour', _formatDuration(stint.bestLapTime)),
                              _buildStatItem('Temps moyen', _formatDuration(stint.averageLapTime)),
                            ],
                          ),
                          if (stint.notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Notes: ${stint.notes}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
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
                            color: statusColor,
                            onPressed: () => _editStint(stint),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Supprimer',
                            icon: Icons.delete,
                            color: Colors.red,
                            onPressed: () => _deleteStint(stint),
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

  Widget _buildStatItem(String label, String value) {
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

  Color _getStatusColor(StintStatus status) {
    switch (status) {
      case StintStatus.planned:
        return Colors.blue;
      case StintStatus.active:
        return RacingTheme.racingGreen;
      case StintStatus.completed:
        return Colors.purple;
      case StintStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _editStint(StintData stint) {
    // TODO: Implémenter l'édition de relais
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

  void _deleteStint(StintData stint) {
    onStintRemoved(stint.id);
  }
}