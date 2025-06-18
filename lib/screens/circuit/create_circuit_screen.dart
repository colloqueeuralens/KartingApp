import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../services/circuit_service.dart';

/// Page de création de circuit
class CreateCircuitScreen extends StatefulWidget {
  const CreateCircuitScreen({super.key});

  @override
  State<CreateCircuitScreen> createState() => _CreateCircuitScreenState();
}

class _CreateCircuitScreenState extends State<CreateCircuitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _liveTimingController = TextEditingController();
  final _wssController = TextEditingController();

  List<String?> _cValues = List.filled(14, null);
  bool _loading = false;
  bool _advancedMode = false;

  Future<void> _showAddChoiceDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un choix'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom du choix',
            hintText: 'Ex: Nouvelle section',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await CircuitService.addSecteurChoice(result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Choix "$result" ajouté avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _liveTimingController.dispose();
    _wssController.dispose();
    super.dispose();
  }

  Future<void> _saveCircuit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Validation supplémentaire pour l'URL WebSocket
      final wssUrl = _wssController.text.trim();
      if (wssUrl.isNotEmpty &&
          !wssUrl.startsWith('ws://') &&
          !wssUrl.startsWith('wss://')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'L\'URL WebSocket doit commencer par ws:// ou wss://',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Configuration automatique en mode simple
      List<String?> cValuesToSave = _cValues;
      if (!_advancedMode) {
        // Configuration Apex Timing standard
        cValuesToSave = [
          'Position',
          'Numéro',
          'Pilote',
          'Temps au tour',
          'Écart',
          'Meilleur temps',
          'Statut',
          'Tours',
          'Vitesse',
          'Secteur 1',
          'Secteur 2',
          'Secteur 3',
          'Pit',
          'Dernier tour',
        ];
      }

      await CircuitService.createCircuit(
        nom: _nameController.text.trim(),
        liveTimingUrl: _liveTimingController.text.trim(),
        wssUrl: wssUrl,
        cValues: cValuesToSave,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Circuit "${_nameController.text.trim()}" créé avec succès !',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Attendre un peu pour que l'utilisateur voie le message
        await Future.delayed(const Duration(milliseconds: 1500));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Erreur lors de la création: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Circuit'),
        actions: AppBarActions.getResponsiveActions(context),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section informations de base
            Card(
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
                          'Informations de base',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du circuit',
                        hintText: 'Ex: Karting de Berck',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _liveTimingController,
                      decoration: const InputDecoration(
                        labelText: 'Live Timing URL',
                        hintText: 'https://www.apex-timing.com/live-timing/...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'URL requise' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section WebSocket
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Configuration WebSocket',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL pour recevoir les données en temps réel',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _wssController,
                      decoration: const InputDecoration(
                        labelText: 'WebSocket URL',
                        hintText: 'wss://www.apex-timing.com:7733/',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.power),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'WebSocket requis' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section configuration des secteurs avec mode simple/avancé
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Configuration des colonnes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: _advancedMode,
                          onChanged: (value) =>
                              setState(() => _advancedMode = value),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _advancedMode ? 'Avancé' : 'Simple',
                          style: TextStyle(
                            color: _advancedMode
                                ? Colors.purple
                                : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _advancedMode
                          ? 'Configuration détaillée des 14 colonnes (C1-C14)'
                          : 'Configuration automatique pour les circuits standards',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    if (!_advancedMode) ...[
                      // Mode simple - Présélections
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.blue,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mode simple activé',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configuration automatique basée sur les standards Apex Timing',
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children:
                                  [
                                        'Position',
                                        'Numéro',
                                        'Pilote',
                                        'Temps',
                                        'Écart',
                                        'Meilleur tour',
                                      ]
                                      .map(
                                        (label) => Chip(
                                          label: Text(label),
                                          backgroundColor: Colors.blue
                                              .withValues(alpha: 0.1),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Mode avancé - Configuration détaillée
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mapping des colonnes (C1-C14):',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showAddChoiceDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: CircuitService.getSecteurChoicesStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text('Erreur: ${snapshot.error}'),
                                ],
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final choices = snapshot.data!.docs
                              .map((doc) => doc.data()['nom'] as String)
                              .toList();

                          if (choices.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(height: 8),
                                  Text('Aucun choix disponible'),
                                  Text(
                                    'Cliquez sur "Ajouter" pour créer des options',
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: List.generate(14, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'C${index + 1}',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Icon(
                                      Icons.pin_drop,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  value: _cValues[index],
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        '(Optionnel)',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ...choices
                                        .map(
                                          (choice) => DropdownMenuItem(
                                            value: choice,
                                            child: Text(choice),
                                          ),
                                        )
                                        .toList(),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _cValues[index] = value;
                                    });
                                  },
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bouton de création avec meilleur feedback
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveCircuit,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_circle),
                label: Text(
                  _loading ? 'Création en cours...' : 'Créer le circuit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
