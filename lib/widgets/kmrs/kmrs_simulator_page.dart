import 'package:flutter/material.dart';
import '../../services/kmrs_service.dart';
import '../../theme/racing_theme.dart';
import '../strategy/strategy_card.dart';

/// Simulateur Page KMRS - Module de simulation de stratégies
/// Interface de test et simulation de différents scénarios de course
class KmrsSimulatorPage extends StatefulWidget {
  final KmrsService kmrsService;

  const KmrsSimulatorPage({
    super.key,
    required this.kmrsService,
  });

  @override
  State<KmrsSimulatorPage> createState() => _KmrsSimulatorPageState();
}

class _KmrsSimulatorPageState extends State<KmrsSimulatorPage> {
  String _selectedScenario = 'optimal';
  final Map<String, String> _scenarios = {
    'optimal': 'Stratégie Optimale',
    'conservative': 'Stratégie Prudente', 
    'aggressive': 'Stratégie Agressive',
    'fuel_saving': 'Économie Carburant',
    'tire_management': 'Gestion Pneus',
  };

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
          listenable: widget.kmrsService,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildScenarioSelector(),
                            const SizedBox(height: 16),
                            _buildSimulationParameters(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildSimulationResults(),
                            const SizedBox(height: 16),
                            _buildRecommendations(),
                          ],
                        ),
                      ),
                    ],
                  ),
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
      title: 'Simulateur KMRS - Test de Stratégies',
      subtitle: 'Simulation et optimisation des stratégies de course',
      icon: Icons.science,
      accentColor: Colors.indigo,
      child: Row(
        children: [
          Icon(
            Icons.psychology,
            color: Colors.indigo,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Testez différentes stratégies et optimisez vos décisions de course.',
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

  Widget _buildScenarioSelector() {
    return StrategyCard(
      title: 'Scénarios de Test',
      icon: Icons.tune,
      accentColor: Colors.blue,
      child: Column(
        children: [
          ..._scenarios.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Radio<String>(
                  value: entry.key,
                  groupValue: _selectedScenario,
                  onChanged: (value) => setState(() => _selectedScenario = value!),
                  activeColor: Colors.blue,
                ),
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _getScenarioDescription(entry.key),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () => setState(() => _selectedScenario = entry.key),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _runSimulation,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lancer Simulation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationParameters() {
    return StrategyCard(
      title: 'Paramètres',
      icon: Icons.settings,
      accentColor: Colors.green,
      child: Column(
        children: [
          _buildParameterRow('Météo', 'Sec', Icons.wb_sunny),
          _buildParameterRow('Trafic', 'Normal', Icons.traffic),
          _buildParameterRow('Usure pneus', 'Standard', Icons.tire_repair),
          _buildParameterRow('Sécurité', 'Niveau 2', Icons.security),
          _buildParameterRow('Ravitaillement', 'Auto', Icons.local_gas_station),
        ],
      ),
    );
  }

  Widget _buildParameterRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationResults() {
    return StrategyCard(
      title: 'Résultats de Simulation',
      icon: Icons.analytics,
      accentColor: Colors.purple,
      child: Column(
        children: [
          // Graphique de performance simulée
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.show_chart,
                  color: Colors.purple,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Graphique de Performance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Simulation: ${_scenarios[_selectedScenario]}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Métriques de résultats
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2,
            children: [
              _buildMetricCard('Temps Total', '1:23:45', Icons.timer),
              _buildMetricCard('Position', '3ème', Icons.emoji_events),
              _buildMetricCard('Tours', '89', Icons.flag),
              _buildMetricCard('Arrêts', '4', Icons.local_gas_station),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(height: 4),
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
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return StrategyCard(
      title: 'Recommandations',
      icon: Icons.lightbulb,
      accentColor: Colors.amber,
      child: Column(
        children: [
          _buildRecommendationItem(
            'Relais optimal: 25-30 minutes',
            'Basé sur la consommation carburant',
            Icons.schedule,
            Colors.green,
          ),
          _buildRecommendationItem(
            'Changement pilote au tour 45',
            'Performance pilote actuel en baisse',
            Icons.swap_horiz,
            Colors.orange,
          ),
          _buildRecommendationItem(
            'Surveillance des pneus avant',
            'Usure supérieure à la normale',
            Icons.warning,
            Colors.red,
          ),
          _buildRecommendationItem(
            'Ravitaillement recommandé',
            'Niveau carburant critique dans 3 tours',
            Icons.local_gas_station,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getScenarioDescription(String scenario) {
    switch (scenario) {
      case 'optimal':
        return 'Équilibre performance/sécurité';
      case 'conservative':
        return 'Sécurité maximale, moins de risques';
      case 'aggressive':
        return 'Performance maximale, plus de risques';
      case 'fuel_saving':
        return 'Optimisation consommation';
      case 'tire_management':
        return 'Préservation des pneus';
      default:
        return '';
    }
  }

  void _runSimulation() {
    // TODO: Implémenter la logique de simulation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Simulation ${_scenarios[_selectedScenario]} lancée'),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}