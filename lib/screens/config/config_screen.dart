import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../../theme/racing_theme.dart';
import '../circuit/create_circuit_screen.dart';
import '../circuit/configure_circuit_mappings_screen.dart';

/// Écran de configuration avec design racing et interface multi-étapes
class ConfigScreen extends StatefulWidget {
  final VoidCallback? onConfigSaved;

  const ConfigScreen({super.key, this.onConfigSaved});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with TickerProviderStateMixin {
  int _numColumns = 3, _numRows = 3;
  bool _loading = false;
  String? _selectedCircuitId;
  int _currentStep = 0;

  late AnimationController _stepController;
  late Animation<double> _stepAnimation;

  final Map<String, Color> _availableColors = {
    'Bleu': Colors.blue,
    'Blanc': Colors.white,
    'Rouge': Colors.red,
    'Vert': Colors.green,
    'Jaune': Colors.yellow,
  };
  List<String> _columnColors = ['Bleu', 'Blanc', 'Rouge'];

  @override
  void initState() {
    super.initState();

    _stepController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _stepAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _stepController, curve: Curves.easeInOut),
    );

    _loadConfiguration();
    _stepController.forward();
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    try {
      final doc = await SessionService.getSession();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _numColumns = data['numColumns'] ?? 3;
          _numRows = data['numRows'] ?? 3;
          _columnColors = List<String>.from(
            data['columnColors'] ?? ['Bleu', 'Blanc', 'Rouge'],
          );
          _selectedCircuitId = data['selectedCircuitId'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e')),
        );
      }
    }
  }

  Future<void> _showJsonImportDialog() async {
    final controller = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Importer circuits depuis JSON'),
          content: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.4,
            constraints: const BoxConstraints(maxHeight: 400),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Collez votre JSON ici...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final jsonContent = controller.text.trim();
                if (jsonContent.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez entrer du contenu JSON'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _importJsonContent(jsonContent);
              },
              child: const Text('Importer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importJsonContent(String jsonContent) async {
    try {
      print('Début de l\'import JSON...');
      print('Taille du contenu: ${jsonContent.length} caractères');

      setState(() => _loading = true);

      final result = await CircuitService.importCircuitsFromJson(jsonContent);
      final importedCount = result['imported']!;
      final skippedCount = result['skipped']!;

      print('Import terminé avec succès');

      if (mounted) {
        String message;
        Color backgroundColor;

        if (importedCount > 0 && skippedCount == 0) {
          message =
              '$importedCount circuit${importedCount > 1 ? 's' : ''} importé${importedCount > 1 ? 's' : ''} avec succès!';
          backgroundColor = Colors.green;
        } else if (importedCount > 0 && skippedCount > 0) {
          message =
              '$importedCount circuit${importedCount > 1 ? 's' : ''} importé${importedCount > 1 ? 's' : ''}, $skippedCount ignoré${skippedCount > 1 ? 's' : ''} (doublons)';
          backgroundColor = Colors.orange;
        } else if (importedCount == 0 && skippedCount > 0) {
          message =
              'Aucun circuit importé - tous sont des doublons ($skippedCount ignorés)';
          backgroundColor = Colors.orange;
        } else {
          message = 'Aucun circuit trouvé dans le fichier JSON';
          backgroundColor = Colors.grey;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Erreur lors de l\'import: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'import: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _stepController.reset();
      _stepController.forward();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _stepController.reset();
      _stepController.forward();
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['Configuration', 'Circuit', 'Validation'][index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? Colors.grey.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return AnimatedBuilder(
      animation: _stepAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - _stepAnimation.value), 0),
          child: Opacity(
            opacity: _stepAnimation.value,
            child: Column(
              children: [
                // Configuration de la grille
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.grid_view,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Configuration de la grille',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Nombre de colonnes
                        const Text(
                          'Nombre de colonnes :',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                            child: DropdownButton<int>(
                              value: _numColumns,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              items: [2, 3, 4].map((n) {
                                return DropdownMenuItem(
                                  value: n,
                                  child: Text('$n colonne${n > 1 ? 's' : ''}'),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() {
                                _numColumns = v!;
                                _columnColors = List.generate(
                                  _numColumns,
                                  (i) => i < _columnColors.length
                                      ? _columnColors[i]
                                      : _availableColors.keys.first,
                                );
                              }),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Karts par colonne
                        const Text(
                          'Karts par colonne :',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                            child: DropdownButton<int>(
                              value: _numRows,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              items: [1, 2, 3].map((n) {
                                return DropdownMenuItem(
                                  value: n,
                                  child: Text('$n kart${n > 1 ? 's' : ''}'),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _numRows = v!),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Couleurs des colonnes
                        const Text(
                          'Couleurs des colonnes :',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_numColumns, (i) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Text(
                                    'Colonne ${i + 1} :',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _columnColors[i],
                                        isExpanded: true,
                                        items: _availableColors.keys.map((
                                          name,
                                        ) {
                                          return DropdownMenuItem(
                                            value: name,
                                            child: Text(name),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(
                                          () => _columnColors[i] = v!,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _availableColors[_columnColors[i]],
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep2() {
    return AnimatedBuilder(
      animation: _stepAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - _stepAnimation.value), 0),
          child: Opacity(
            opacity: _stepAnimation.value,
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.track_changes,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sélection du circuit',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: CircuitService.getCircuitsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('Erreur: ${snapshot.error}');
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final circuits = snapshot.data!.docs;

                            return Column(
                              children: [
                                // Liste des circuits avec indicateurs de statut
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: circuits.length,
                                    itemBuilder: (context, index) {
                                      final doc = circuits[index];
                                      final circuitData = doc.data();
                                      final circuitName = circuitData['nom'] ?? 'Circuit sans nom';
                                      final needsConfiguration = CircuitService.hasNullMappings(circuitData);
                                      final isSelected = doc.id == _selectedCircuitId;

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        color: isSelected 
                                          ? Colors.blue.withValues(alpha: 0.1) 
                                          : needsConfiguration 
                                            ? Colors.orange.withValues(alpha: 0.05)
                                            : null,
                                        child: ListTile(
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: needsConfiguration 
                                                ? Colors.orange.withValues(alpha: 0.1)
                                                : Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: needsConfiguration ? Colors.orange : Colors.green,
                                              ),
                                            ),
                                            child: Icon(
                                              needsConfiguration ? Icons.warning : Icons.check_circle,
                                              color: needsConfiguration ? Colors.orange : Colors.green,
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(
                                            circuitName,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          subtitle: Text(
                                            needsConfiguration 
                                              ? '⚠️ Configuration requise'
                                              : '✅ Prêt à utiliser',
                                            style: TextStyle(
                                              color: needsConfiguration ? Colors.orange.shade700 : Colors.green.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (needsConfiguration)
                                                TextButton.icon(
                                                  onPressed: () async {
                                                    final result = await Navigator.of(context).push<bool>(
                                                      MaterialPageRoute(
                                                        builder: (context) => ConfigureCircuitMappingsScreen(
                                                          circuitId: doc.id,
                                                          circuitName: circuitName,
                                                          currentMappings: circuitData,
                                                        ),
                                                      ),
                                                    );
                                                    
                                                    // Si la configuration a été sauvegardée, on peut rafraîchir
                                                    if (result == true) {
                                                      // Le StreamBuilder se rafraîchira automatiquement
                                                    }
                                                  },
                                                  icon: const Icon(Icons.settings, size: 16),
                                                  label: const Text('Configurer'),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.orange.shade700,
                                                  ),
                                                ),
                                              Radio<String>(
                                                value: doc.id,
                                                groupValue: _selectedCircuitId,
                                                onChanged: needsConfiguration 
                                                  ? null // Désactiver la sélection si configuration requise
                                                  : (value) {
                                                      setState(() {
                                                        _selectedCircuitId = value;
                                                      });
                                                    },
                                              ),
                                            ],
                                          ),
                                          onTap: needsConfiguration 
                                            ? null 
                                            : () {
                                                setState(() {
                                                  _selectedCircuitId = doc.id;
                                                });
                                              },
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Aide contextuelle sur les statuts
                                if (circuits.any((doc) => CircuitService.hasNullMappings(doc.data())))
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.info, color: Colors.blue, size: 16),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Statuts des circuits',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '• ✅ Prêt à utiliser : Configuration automatique détectée\n'
                                          '• ⚠️ Configuration requise : Mappings manuels nécessaires',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                // Boutons d'action
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const CreateCircuitScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Nouveau circuit'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _loading
                                            ? null
                                            : _showJsonImportDialog,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Import JSON'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep3() {
    return AnimatedBuilder(
      animation: _stepAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - _stepAnimation.value), 0),
          child: Opacity(
            opacity: _stepAnimation.value,
            child: Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Validation de la configuration',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Résumé de la configuration
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Résumé de votre configuration :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• Grille: $_numColumns colonnes × $_numRows karts',
                              ),
                              Text('• Couleurs: ${_columnColors.join(', ')}'),
                              if (_selectedCircuitId != null)
                                FutureBuilder<String?>(
                                  future: CircuitService.getCircuitName(
                                    _selectedCircuitId!,
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Text(
                                        '• Circuit: ${snapshot.data}',
                                      );
                                    }
                                    return const Text(
                                      '• Circuit: Chargement...',
                                    );
                                  },
                                )
                              else
                                const Text('• Circuit: Aucun sélectionné'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.settings, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Configuration Racing'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: AppBarActions.getResponsiveActions(context),
      ),
      body: Column(
        children: [
          // Indicateur d'étapes
          _buildStepIndicator(),

          // Contenu de l'étape actuelle
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_currentStep == 0) _buildStep1(),
                  if (_currentStep == 1) _buildStep2(),
                  if (_currentStep == 2) _buildStep3(),
                ],
              ),
            ),
          ),

          // Boutons de navigation
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
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Précédent'),
                    ),
                  ),

                if (_currentStep > 0) const SizedBox(width: 16),

                Expanded(
                  child: _currentStep < 2
                      ? ElevatedButton.icon(
                          onPressed: _nextStep,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Suivant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RacingTheme.racingGreen,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  try {
                                    await SessionService.updateConfiguration(
                                      numColumns: _numColumns,
                                      numRows: _numRows,
                                      columnColors: _columnColors,
                                      selectedCircuitId: _selectedCircuitId,
                                    );
                                    await SessionService.clearKartEntries(
                                      _numColumns,
                                    );

                                    if (widget.onConfigSaved != null) {
                                      widget.onConfigSaved!();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.error,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text('Erreur: $e'),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: RacingTheme.bad,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _loading = false);
                                  }
                                },
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_loading ? 'Validation...' : 'Valider'),
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
