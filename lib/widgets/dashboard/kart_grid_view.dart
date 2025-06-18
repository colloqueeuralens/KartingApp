import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/session_service.dart';

/// Classe pour transporter les données du kart pendant le drag & drop
class KartData {
  final String docId;
  final int number;
  final String perf;
  final int fromColumn;

  const KartData({
    required this.docId,
    required this.number,
    required this.perf,
    required this.fromColumn,
  });
}

/// Grille & gestion des karts
class KartGridView extends StatefulWidget {
  final int numColumns, numRows;
  final List<Color> columnColors;
  final bool readOnly;

  const KartGridView({
    super.key,
    required this.numColumns,
    required this.numRows,
    required this.columnColors,
    required this.readOnly,
  });

  @override
  State<KartGridView> createState() => _KartGridViewState();
}

class _KartGridViewState extends State<KartGridView> {
  Set<int> _hoveredColumns = <int>{};
  bool _isMovingKart = false;
  int _lastValidPercentage = 0;
  bool _lastValidIsOptimal = false;
  int _lastKartCount = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> _colStream(int c) =>
      SessionService.getColumnStream(c, limit: widget.numRows);

  Stream<List<QuerySnapshot<Map<String, dynamic>>>> get _allCols =>
      CombineLatestStream.list(List.generate(widget.numColumns, (c) => _colStream(c)));

  Future<void> _addKart(int col, int num, String perf) {
    if (widget.readOnly) return Future.value();
    return SessionService.addKart(col, num, perf);
  }

  Future<void> _editKart(int col, String docId, int num, String perf) {
    if (widget.readOnly) return Future.value();
    return SessionService.editKart(col, docId, num, perf);
  }

  Future<void> _deleteKart(BuildContext context, int col, String docId) async {
    if (widget.readOnly) return;
    try {
      await SessionService.deleteKart(col, docId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kart supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _moveKart(BuildContext context, KartData kartData, int toColumn) async {
    if (widget.readOnly) return;
    if (kartData.fromColumn == toColumn) return; // Même colonne, pas de mouvement
    
    // Marquer le début du déplacement pour stabiliser l'affichage
    setState(() {
      _isMovingKart = true;
    });
    
    try {
      await SessionService.moveKart(
        kartData.fromColumn,
        toColumn,
        kartData.docId,
        kartData.number,
        kartData.perf,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kart ${kartData.number} déplacé vers la colonne ${toColumn + 1}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du déplacement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Petite pause pour s'assurer que Firestore a terminé la mise à jour
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _isMovingKart = false;
        });
      }
    }
  }

  void _showKartDialog(
    BuildContext ctx,
    int col, {
    required Set<int> usedNumbers,
    int? initialNumber,
    String? initialPerf,
    String? docId,
    required void Function(int, String) onConfirm,
    VoidCallback? onDelete,
  }) {
    final blocked = Set<int>.from(usedNumbers);
    if (initialNumber != null) blocked.remove(initialNumber);
    final available = List.generate(
      99,
      (i) => i + 1,
    ).where((n) => !blocked.contains(n)).toList();
    int? selNum = initialNumber;
    String? selPerf = initialPerf;
    const opts = ['++', '+', '~', '-', '--', '?'];

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) {
          return AlertDialog(
            title: Text(
              initialNumber == null
                  ? 'Ajouter un kart (col ${col + 1})'
                  : 'Modifier Kart (col ${col + 1})',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text('Numéro de kart'),
                  value: selNum,
                  items: available
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => setDialog(() => selNum = v),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Performance'),
                  value: selPerf,
                  items: opts
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, style: const TextStyle(fontSize: 18)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => selPerf = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Annuler'),
              ),
              if (onDelete != null) // Bouton supprimer pour les karts existants
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dCtx);
                    _showDeleteConfirmation(ctx, initialNumber!, onDelete);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: selNum != null && selPerf != null
                    ? () {
                        onConfirm(selNum!, selPerf!);
                        Navigator.pop(dCtx);
                      }
                    : null,
                icon: Icon(initialNumber == null ? Icons.add : Icons.edit),
                label: Text(initialNumber == null ? 'Ajouter' : 'Modifier'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext ctx, int kartNumber, VoidCallback onConfirmDelete) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le Kart $kartNumber ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dCtx);
              onConfirmDelete();
            },
            icon: const Icon(Icons.delete),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      stream: _allCols,
      builder: (ctx, snapCols) {
        if (snapCols.hasError)
          return Center(child: Text('Erreur karts : ${snapCols.error}'));
        if (!snapCols.hasData)
          return const Center(child: CircularProgressIndicator());
        final colsData = snapCols.data!.map((s) => s.docs).toList();
        // Collecter tous les karts et détecter les doublons temporaires
        final allKarts = <Map<String, dynamic>>[];
        final kartNumbers = <int>[];
        
        for (var docs in colsData) {
          for (var d in docs) {
            final data = d.data();
            allKarts.add(data);
            kartNumbers.add(data['number'] as int);
          }
        }
        
        final usedNumbers = kartNumbers.toSet();

        // Calculer les bonnes performances par colonne en évitant les doublons
        int good = 0;
        
        for (int colIndex = 0; colIndex < colsData.length; colIndex++) {
          final docs = colsData[colIndex];
          if (docs.isNotEmpty) {
            final firstKart = docs.first.data();
            final number = firstKart['number'] as int;
            final p = firstKart['perf'] as String;
            
            // Vérifier que ce kart n'apparaît pas en doublon dans d'autres colonnes
            final appearances = kartNumbers.where((n) => n == number).length;
            
            // Compter comme bonne performance seulement si pas de doublon temporaire
            if (appearances == 1 && (p == '++' || p == '+')) {
              good++;
            }
          }
        }

        // Détecter les états transitoires invalides et utiliser le fallback
        final currentKartCount = kartNumbers.length;
        final calculatedPct = currentKartCount > 0 ? (good * 100 / widget.numColumns).round() : 0;
        
        // Détection d'un état transitoire invalide pendant le drag & drop
        final hasTemporaryDuplicates = kartNumbers.toSet().length != kartNumbers.length;
        final isTransitionalState = _isMovingKart || 
          (currentKartCount == 0 && _lastKartCount > 0) ||
          (calculatedPct == 0 && _lastValidPercentage > 0) ||
          hasTemporaryDuplicates ||
          (currentKartCount > widget.numColumns); // Plus de karts que de colonnes = doublons
        
        
        // Calculer le seuil (toujours nécessaire pour l'affichage)
        final threshold = widget.numColumns == 2
            ? 100
            : widget.numColumns == 3
            ? 66
            : widget.numColumns == 4
            ? 75
            : 100;

        final int pct;
        final bool isOpt;
        
        if (isTransitionalState) {
          // Utiliser les dernières valeurs valides pendant la transition
          pct = _lastValidPercentage;
          isOpt = _lastValidIsOptimal;
        } else {
          // État stable - mettre à jour et mémoriser les nouvelles valeurs
          pct = calculatedPct;
          isOpt = pct >= threshold;
          
          // Mémoriser les valeurs valides seulement si elles sont cohérentes
          if (currentKartCount > 0 || (currentKartCount == 0 && _lastKartCount == 0)) {
            _lastValidPercentage = pct;
            _lastValidIsOptimal = isOpt;
            _lastKartCount = currentKartCount;
          }
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOpt
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                border: Border.all(
                  color: isOpt ? Colors.green : Colors.red,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    isOpt ? '🟢 C\'EST LE MOMENT !' : '🔴 ATTENDRE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isOpt ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct% (Seuil: $threshold%)',
                    style: TextStyle(
                      fontSize: 16,
                      color: isOpt ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: List.generate(widget.numColumns, (col) {
                  final docs = colsData[col];
                  final full = docs.length >= widget.numRows;
                  final isHovered = _hoveredColumns.contains(col);
                  
                  return Expanded(
                    child: DragTarget<KartData>(
                      onWillAccept: (data) {
                        // Vérifier si la colonne peut accepter le kart
                        if (widget.readOnly) return false;
                        if (data == null) return false;
                        if (data.fromColumn == col) return false; // Même colonne
                        return docs.length < widget.numRows; // Vérifier si pas pleine
                      },
                      onAccept: (kartData) {
                        _moveKart(context, kartData, col);
                        setState(() {
                          _hoveredColumns.remove(col);
                        });
                      },
                      onMove: (details) {
                        if (!_hoveredColumns.contains(col)) {
                          setState(() {
                            _hoveredColumns.add(col);
                          });
                        }
                      },
                      onLeave: (data) {
                        setState(() {
                          _hoveredColumns.remove(col);
                        });
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? Colors.blue.withValues(alpha: 0.3)
                                : widget.columnColors[col].withValues(alpha: 0.1),
                            border: isHovered
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final doc = docs[i];
                                final data = doc.data();
                                final number = data['number'] as int;
                                final perf = data['perf'] as String;
                                final bgColor = (perf == '++' || perf == '+')
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : (perf == '--' || perf == '-')
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.1);
                                final kartData = KartData(
                                  docId: doc.id,
                                  number: number,
                                  perf: perf,
                                  fromColumn: col,
                                );

                                final kartCard = Card(
                                  color: bgColor,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      'Kart $number',
                                      textAlign: TextAlign.center,
                                    ),
                                    subtitle: Text(
                                      perf,
                                      textAlign: TextAlign.center,
                                    ),
                                    onTap: widget.readOnly
                                        ? null
                                        : () => _showKartDialog(
                                            context,
                                            col,
                                            usedNumbers: usedNumbers,
                                            initialNumber: number,
                                            initialPerf: perf,
                                            docId: doc.id,
                                            onConfirm: (n, p) =>
                                                _editKart(col, doc.id, n, p),
                                            onDelete: () => _deleteKart(context, col, doc.id),
                                          ),
                                  ),
                                );

                                return widget.readOnly
                                    ? kartCard
                                    : Draggable<KartData>(
                                        data: kartData,
                                        feedback: Material(
                                          elevation: 8,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 200,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blue, width: 2),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Kart $number',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    perf,
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Card(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          child: ListTile(
                                            title: Text(
                                              'Kart $number',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                            subtitle: Text(
                                              perf,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                          ),
                                        ),
                                        child: kartCard,
                                      );
                              },
                            ),
                          ),
                          if (!widget.readOnly)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ElevatedButton.icon(
                                onPressed: () => _showKartDialog(
                                  context,
                                  col,
                                  usedNumbers: usedNumbers,
                                  onConfirm: (n, p) => _addKart(col, n, p),
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(full ? 'Nouveau' : 'Ajouter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: full
                                      ? Colors.orange
                                      : Colors.blue,
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              ),
                            ),
                        ],
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}