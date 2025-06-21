import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../services/circuit_service.dart';
import '../../theme/racing_theme.dart';

/// Écran de configuration manuelle des mappings de colonnes pour un circuit
class ConfigureCircuitMappingsScreen extends StatefulWidget {
  final String circuitId;
  final String circuitName;
  final Map<String, dynamic> currentMappings;

  const ConfigureCircuitMappingsScreen({
    super.key,
    required this.circuitId,
    required this.circuitName,
    required this.currentMappings,
  });

  @override
  State<ConfigureCircuitMappingsScreen> createState() => _ConfigureCircuitMappingsScreenState();
}

class _ConfigureCircuitMappingsScreenState extends State<ConfigureCircuitMappingsScreen> {
  late Map<String, String?> _mappings;
  bool _loading = false;
  List<String> _secteurChoices = [];

  @override
  void initState() {
    super.initState();
    _initializeMappings();
    _loadSecteurChoices();
  }

  void _initializeMappings() {
    _mappings = {};
    for (int i = 1; i <= 14; i++) {
      final key = 'c$i';
      final value = widget.currentMappings[key];
      _mappings[key] = (value == null || value == 'Non utilisé' || value.toString().trim().isEmpty) 
        ? null 
        : value.toString();
    }
  }

  Future<void> _loadSecteurChoices() async {
    try {
      final snapshot = await CircuitService.getSecteurChoicesStream().first;
      final choices = snapshot.docs
          .map((doc) => doc.data()['nom'] as String)
          .toList();
      
      setState(() {
        _secteurChoices = ['Non utilisé', ...choices];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des choix: $e')),
        );
      }
    }
  }

  Future<void> _saveConfiguration() async {
    setState(() => _loading = true);
    
    try {
      // Convertir les mappings en format attendu par le service
      final mappingsToSave = <String, String>{};
      for (final entry in _mappings.entries) {
        mappingsToSave[entry.key] = entry.value ?? 'Non utilisé';
      }
      
      await CircuitService.updateCircuitMappings(widget.circuitId, mappingsToSave);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Configuration du circuit "${widget.circuitName}" mise à jour !'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Retourner à l'écran précédent après un court délai
        await Future.delayed(const Duration(milliseconds: 1500));
        Navigator.of(context).pop(true); // true indique que la configuration a été sauvegardée
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Erreur lors de la sauvegarde: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildColumnMappingCard(String columnKey, int columnIndex) {
    final currentValue = _mappings[columnKey];
    final hasValue = currentValue != null && currentValue != 'Non utilisé';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Indicateur de colonne
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasValue ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasValue ? Colors.green : Colors.orange,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  columnKey.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasValue ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Dropdown de sélection
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colonne ${columnIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentValue ?? 'Non utilisé',
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        hint: const Text('Sélectionner un mapping'),
                        items: _secteurChoices.map((choice) {
                          return DropdownMenuItem(
                            value: choice,
                            child: Text(
                              choice,
                              style: TextStyle(
                                color: choice == 'Non utilisé' 
                                  ? Colors.grey.shade600 
                                  : Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _mappings[columnKey] = value == 'Non utilisé' ? null : value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Indicateur de statut
            const SizedBox(width: 12),
            Icon(
              hasValue ? Icons.check_circle : Icons.warning,
              color: hasValue ? Colors.green : Colors.orange,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final configuredCount = _mappings.values.where((v) => v != null && v != 'Non utilisé').length;
    final requiredCount = 3; // Minimum recommandé
    final isValid = configuredCount >= requiredCount;
    
    return Card(
      color: isValid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.warning,
                  color: isValid ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Résumé de la configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('• Colonnes configurées: $configuredCount/14'),
            Text('• Minimum recommandé: $requiredCount colonnes'),
            const SizedBox(height: 8),
            Text(
              isValid 
                ? '✅ Configuration valide pour utilisation' 
                : '⚠️ Configuration insuffisante (minimum $requiredCount colonnes)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
              ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configuration des mappings'),
            Text(
              widget.circuitName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: AppBarActions.getResponsiveActions(context),
      ),
      body: _secteurChoices.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Carte d'information
                    Card(
                      color: Colors.blue.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Configuration manuelle requise',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ce circuit nécessite une configuration manuelle des mappings de colonnes. '
                              'Sélectionnez le type de données pour chaque colonne C1-C14.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Résumé de configuration
                    _buildSummaryCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Configuration des colonnes
                    const Text(
                      'Configuration des colonnes (C1-C14)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Liste des mappings
                    ...List.generate(14, (index) {
                      final columnKey = 'c${index + 1}';
                      return _buildColumnMappingCard(columnKey, index);
                    }),
                  ],
                ),
              ),
              
              // Boutons d'action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _saveConfiguration,
                        icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                        label: Text(_loading ? 'Sauvegarde...' : 'Sauvegarder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RacingTheme.racingGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}