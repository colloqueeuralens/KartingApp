import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../services/session_service.dart';
import '../../services/circuit_service.dart';
import '../circuit/create_circuit_screen.dart';

/// Écran de configuration (mobile uniquement)
class ConfigScreen extends StatefulWidget {
  final VoidCallback? onConfigSaved;

  const ConfigScreen({super.key, this.onConfigSaved});
  
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  int _numColumns = 3, _numRows = 3;
  bool _loading = false;
  String? _selectedCircuitId;

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
    _loadConfiguration();
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
          message = '$importedCount circuit${importedCount > 1 ? 's' : ''} importé${importedCount > 1 ? 's' : ''} avec succès!';
          backgroundColor = Colors.green;
        } else if (importedCount > 0 && skippedCount > 0) {
          message = '$importedCount circuit${importedCount > 1 ? 's' : ''} importé${importedCount > 1 ? 's' : ''}, $skippedCount ignoré${skippedCount > 1 ? 's' : ''} (doublons)';
          backgroundColor = Colors.orange;
        } else if (importedCount == 0 && skippedCount > 0) {
          message = 'Aucun circuit importé - tous sont des doublons ($skippedCount ignorés)';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KMRS Racing'),
        automaticallyImplyLeading: false,
        actions: AppBarActions.getActions(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nombre de colonnes :', style: TextStyle(fontSize: 16)),
            DropdownButton<int>(
              value: _numColumns,
              items: [2, 3, 4]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
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
            const SizedBox(height: 16),
            const Text(
              'Couleurs des colonnes :',
              style: TextStyle(fontSize: 16),
            ),
            ...List.generate(_numColumns, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text('Colonne ${i + 1} :'),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _columnColors[i],
                      items: _availableColors.keys
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _columnColors[i] = v!),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _availableColors[_columnColors[i]],
                        border: Border.all(),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Karts par colonne :', style: TextStyle(fontSize: 16)),
            DropdownButton<int>(
              value: _numRows,
              items: [1, 2, 3]
                  .map(
                    (n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n kart${n > 1 ? 's' : ''}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _numRows = v!),
            ),
            const SizedBox(height: 24),
            // Section Circuit
            const Text('Circuit :', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: CircuitService.getCircuitsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Erreur: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                
                final circuits = snapshot.data!.docs;
                
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Sélectionner un circuit'),
                            value: circuits.any((doc) => doc.id == _selectedCircuitId) 
                                ? _selectedCircuitId 
                                : null,
                            items: [
                              ...circuits.map((doc) => DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(
                                      doc.data()['nom'] ?? 'Circuit sans nom',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCircuitId = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const CreateCircuitScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Nouveau'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _showJsonImportDialog,
                            icon: const Icon(Icons.paste),
                            label: const Text('Importer circuits (JSON)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        try {
                          // 1) Sauvegarde de la config
                          await SessionService.updateConfiguration(
                            numColumns: _numColumns,
                            numRows: _numRows,
                            columnColors: _columnColors,
                            selectedCircuitId: _selectedCircuitId,
                          );

                          // 2) Réinitialisation des karts
                          await SessionService.clearKartEntries(_numColumns);

                          // 3) Navigation via callback
                          if (widget.onConfigSaved != null) {
                            widget.onConfigSaved!();
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
                      },
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Valider'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}