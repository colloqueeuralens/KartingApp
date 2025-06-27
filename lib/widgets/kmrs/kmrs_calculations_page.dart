import 'package:flutter/material.dart';
import '../../services/kmrs_service.dart';
import '../../theme/racing_theme.dart';
import '../strategy/strategy_card.dart';

/// Calculations v2 Page KMRS - Moteur de calcul automatique
/// Reproduit les calculs Excel avec formules automatiques
class KmrsCalculationsPage extends StatelessWidget {
  final KmrsService kmrsService;

  const KmrsCalculationsPage({
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
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildCalculationsGrid(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StrategyCard(
      title: 'Calculations v2 - Moteur de Calcul',
      subtitle: 'Calculs automatiques basés sur les données de course',
      icon: Icons.calculate,
      accentColor: Colors.orange,
      child: Row(
        children: [
          Icon(
            Icons.functions,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Tous les calculs sont automatiques et se mettent à jour en temps réel selon vos inputs.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationsGrid() {
    final session = kmrsService.currentSession;
    final calculations = session?.calculations ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildCalculationCard(
          'Consommation Carburant',
          '${_getCalculationValue(calculations, 'fuelConsumption', '0.0')} L',
          Icons.local_gas_station,
          Colors.blue,
        ),
        _buildCalculationCard(
          'Temps Restant',
          _formatDuration(Duration(milliseconds: _getCalculationValue(calculations, 'race.remainingTime', 0))),
          Icons.timer,
          Colors.green,
        ),
        _buildCalculationCard(
          'Tours Totaux',
          _getCalculationValue(calculations, 'race.totalLaps', '0').toString(),
          Icons.flag,
          Colors.purple,
        ),
        _buildCalculationCard(
          'Moyenne au Tour',
          '${_getCalculationValue(calculations, 'averageLapTime', '0')}s',
          Icons.speed,
          Colors.teal,
        ),
        _buildCalculationCard(
          'Efficacité Pilotes',
          '${_getCalculationValue(calculations, 'pilotEfficiency', '0')}%',
          Icons.people,
          Colors.indigo,
        ),
        _buildCalculationCard(
          'Stratégie Optimale',
          _getOptimalStrategy(),
          Icons.psychology,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildCalculationCard(String title, String value, IconData icon, Color color) {
    return StrategyCard(
      title: title,
      icon: icon,
      accentColor: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  T _getCalculationValue<T>(Map<String, dynamic> calculations, String key, T defaultValue) {
    try {
      final keys = key.split('.');
      dynamic value = calculations;
      for (final k in keys) {
        if (value is Map) {
          value = value[k];
        } else {
          return defaultValue;
        }
      }
      return value ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    return '${minutes}min';
  }

  String _getOptimalStrategy() {
    final session = kmrsService.currentSession;
    if (session == null || session.stints.isEmpty) return 'En attente';
    
    final avgStintTime = session.stints
        .map((s) => s.actualDuration.inMinutes)
        .fold(0, (a, b) => a + b) / session.stints.length;
    
    if (avgStintTime > 30) {
      return 'Relais longs';
    } else if (avgStintTime > 20) {
      return 'Relais moyens';
    } else {
      return 'Relais courts';
    }
  }
}