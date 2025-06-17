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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
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
      await CircuitService.createCircuit(
        nom: _nameController.text.trim(),
        liveTimingUrl: _liveTimingController.text.trim(),
        wssUrl: _wssController.text.trim(),
        cValues: _cValues,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Circuit créé avec succès')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
        actions: AppBarActions.getActions(context),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du circuit',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Nom requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _liveTimingController,
              decoration: const InputDecoration(
                labelText: 'Live Timing URL',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'URL requise' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _wssController,
              decoration: const InputDecoration(
                labelText: 'WSS (WebSocket)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'WebSocket requis' : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Configuration des secteurs:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddChoiceDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un choix'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: CircuitService.getSecteurChoicesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Erreur: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                
                final choices = snapshot.data!.docs
                    .map((doc) => doc.data()['nom'] as String)
                    .toList();
                
                return Column(
                  children: List.generate(14, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'C${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        value: _cValues[index],
                        items: choices
                            .map((choice) => DropdownMenuItem(
                                  value: choice,
                                  child: Text(choice),
                                ))
                            .toList(),
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _saveCircuit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Créer le circuit'),
            ),
          ],
        ),
      ),
    );
  }
}