import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/session_service.dart';
import '../../theme/racing_theme.dart';
import 'racing_kart_card.dart';
import 'empty_kart_slot.dart';
import '../common/glassmorphism_container.dart';

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

/// Grille de karts avec style racing amélioré
class RacingKartGridView extends StatefulWidget {
  final int numColumns, numRows;
  final List<Color> columnColors;
  final bool readOnly;

  const RacingKartGridView({
    super.key,
    required this.numColumns,
    required this.numRows,
    required this.columnColors,
    required this.readOnly,
  });

  @override
  State<RacingKartGridView> createState() => _RacingKartGridViewState();
}

class _RacingKartGridViewState extends State<RacingKartGridView>
    with TickerProviderStateMixin {
  Set<int> _hoveredColumns = <int>{};
  bool _isMovingKart = false;
  int _lastValidPercentage = 0;
  bool _lastValidIsOptimal = false;
  int _lastKartCount = 0;
  bool _showOptimalNotification = false;

  late AnimationController _notificationController;

  @override
  void initState() {
    super.initState();
    _notificationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _colStream(int c) =>
      SessionService.getColumnStream(c, limit: widget.numRows);

  Stream<List<QuerySnapshot<Map<String, dynamic>>>> get _allCols =>
      CombineLatestStream.list(
        List.generate(widget.numColumns, (c) => _colStream(c)),
      );

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

  Future<void> _moveKart(
    BuildContext context,
    KartData kartData,
    int toColumn,
  ) async {
    if (widget.readOnly) return;
    if (kartData.fromColumn == toColumn) return;

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
            content: Text(
              'Kart ${kartData.number} déplacé vers la colonne ${toColumn + 1}',
            ),
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
    final available = List.generate(99, (i) => i + 1)
        .where((n) => !blocked.contains(n))
        .toList();
    int? selNum = initialNumber;
    String? selPerf = initialPerf;
    const opts = ['++', '+', '~', '-', '--', '?'];

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) {
          return GlassmorphismDialog(
            title: initialNumber == null
                ? 'Ajouter un kart (col ${col + 1})'
                : 'Modifier Kart (col ${col + 1})',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown numéro
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButton<int>(
                    isExpanded: true,
                    hint: const Text('Numéro de kart'),
                    value: selNum,
                    underline: const SizedBox.shrink(),
                    items: available
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setDialog(() => selNum = v),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Dropdown performance avec style racing
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Performance'),
                    value: selPerf,
                    underline: const SizedBox.shrink(),
                    items: opts.map((p) => DropdownMenuItem(
                      value: p,
                      child: Center(
                        child: PerformanceIndicator(performance: p),
                      ),
                    )).toList(),
                    onChanged: (v) => setDialog(() => selPerf = v),
                  ),
                ),
              ],
            ),
            actions: [
              GlassmorphismButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Annuler', style: TextStyle(color: Colors.white)),
              ),
              if (onDelete != null)
                GlassmorphismButton(
                  color: Colors.red,
                  onPressed: () {
                    Navigator.pop(dCtx);
                    _showDeleteConfirmation(ctx, initialNumber!, onDelete);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Supprimer', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              GlassmorphismButton(
                color: Colors.green,
                onPressed: selNum != null && selPerf != null
                    ? () {
                        onConfirm(selNum!, selPerf!);
                        Navigator.pop(dCtx);
                      }
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      initialNumber == null ? Icons.add : Icons.edit,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      initialNumber == null ? 'Ajouter' : 'Modifier',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext ctx,
    int kartNumber,
    VoidCallback onConfirmDelete,
  ) {
    showDialog(
      context: ctx,
      builder: (dCtx) => GlassmorphismDialog(
        title: 'Confirmer la suppression',
        child: Text(
          'Êtes-vous sûr de vouloir supprimer le Kart $kartNumber ?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          GlassmorphismButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white)),
          ),
          GlassmorphismButton(
            color: Colors.red,
            onPressed: () {
              Navigator.pop(dCtx);
              onConfirmDelete();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Supprimer', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _checkOptimalMoment(bool isOptimal, bool wasOptimal) {
    if (isOptimal && !wasOptimal && !_showOptimalNotification) {
      // Déclenchement du moment optimal
      setState(() {
        _showOptimalNotification = true;
      });
      
      // Auto-hide après 5 secondes
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showOptimalNotification = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      stream: _allCols,
      builder: (ctx, snapCols) {
        if (snapCols.hasError) {
          return Center(child: Text('Erreur karts : ${snapCols.error}'));
        }
        if (!snapCols.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final colsData = snapCols.data!.map((s) => s.docs).toList();
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

        // Calculer les bonnes performances
        int good = 0;
        for (int colIndex = 0; colIndex < colsData.length; colIndex++) {
          final docs = colsData[colIndex];
          if (docs.isNotEmpty) {
            final firstKart = docs.first.data();
            final number = firstKart['number'] as int;
            final p = firstKart['perf'] as String;
            final appearances = kartNumbers.where((n) => n == number).length;

            if (appearances == 1 && (p == '++' || p == '+')) {
              good++;
            }
          }
        }

        final currentKartCount = kartNumbers.length;
        final calculatedPct = currentKartCount > 0
            ? (good * 100 / widget.numColumns).round()
            : 0;

        // Détection d'état transitoire
        final hasTemporaryDuplicates = kartNumbers.toSet().length != kartNumbers.length;
        final isTransitionalState = _isMovingKart ||
            (currentKartCount == 0 && _lastKartCount > 0) ||
            (calculatedPct == 0 && _lastValidPercentage > 0) ||
            hasTemporaryDuplicates ||
            (currentKartCount > widget.numColumns);

        final threshold = widget.numColumns == 2 ? 100 :
            widget.numColumns == 3 ? 66 :
            widget.numColumns == 4 ? 75 : 100;

        final int pct;
        final bool isOpt;

        if (isTransitionalState) {
          pct = _lastValidPercentage;
          isOpt = _lastValidIsOptimal;
        } else {
          pct = calculatedPct;
          isOpt = pct >= threshold;

          // Vérifier si moment optimal atteint
          _checkOptimalMoment(isOpt, _lastValidIsOptimal);

          if (currentKartCount > 0 || (currentKartCount == 0 && _lastKartCount == 0)) {
            _lastValidPercentage = pct;
            _lastValidIsOptimal = isOpt;
            _lastKartCount = currentKartCount;
          }
        }

        return Stack(
          children: [
            Column(
              children: [
                // Indicateur de moment optimal (style original)
                _buildOptimalMomentIndicator(isOpt, pct, threshold),
                
                // Grille des karts
                Expanded(
                  child: Row(
                    children: List.generate(widget.numColumns, (col) {
                      final docs = colsData[col];
                      final isHovered = _hoveredColumns.contains(col);

                      return Expanded(
                        child: DragTarget<KartData>(
                          onWillAccept: (data) {
                            if (widget.readOnly) return false;
                            if (data == null) return false;
                            if (data.fromColumn == col) return false;
                            return docs.length < widget.numRows;
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
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? Colors.blue.withOpacity(0.2)
                                    : widget.columnColors[col].withOpacity(0.05),
                                border: isHovered
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : Border.all(
                                        color: widget.columnColors[col].withOpacity(0.3),
                                        width: 1,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  // Header colonne
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: widget.columnColors[col].withOpacity(0.1),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.flag,
                                          color: widget.columnColors[col],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Colonne ${col + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: widget.columnColors[col],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Liste des karts
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: widget.numRows,
                                      itemBuilder: (_, i) {
                                        if (i < docs.length) {
                                          // Kart existant
                                          final doc = docs[i];
                                          final data = doc.data();
                                          final number = data['number'] as int;
                                          final perf = data['perf'] as String;
                                          final kartData = KartData(
                                            docId: doc.id,
                                            number: number,
                                            perf: perf,
                                            fromColumn: col,
                                          );

                                          final isKartOptimal = (perf == '++' || perf == '+');
                                          final showPulse = isKartOptimal && isOpt && pct < 100;

                                          final kartCard = Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            child: RacingKartCard(
                                              kartNumber: number.toString(),
                                              performance: perf,
                                              color: RacingTheme.getPerformanceColor(perf),
                                              isOptimalMoment: isKartOptimal && isOpt,
                                              showPulse: showPulse,
                                              onTap: widget.readOnly
                                                  ? null
                                                  : () => _showKartDialog(
                                                      context,
                                                      col,
                                                      usedNumbers: usedNumbers,
                                                      initialNumber: number,
                                                      initialPerf: perf,
                                                      docId: doc.id,
                                                      onConfirm: (n, p) => _editKart(col, doc.id, n, p),
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
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: RacingKartCard(
                                                      kartNumber: number.toString(),
                                                      performance: perf,
                                                      color: RacingTheme.getPerformanceColor(perf),
                                                      isOptimalMoment: false,
                                                      showPulse: false,
                                                    ),
                                                  ),
                                                  childWhenDragging: Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                                    child: RacingKartCard(
                                                      kartNumber: number.toString(),
                                                      performance: perf,
                                                      color: Colors.grey,
                                                      isOptimalMoment: false,
                                                      showPulse: false,
                                                    ),
                                                  ),
                                                  child: kartCard,
                                                );
                                        } else {
                                          // Slot vide
                                          return Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            child: EmptyKartSlot(
                                              color: widget.columnColors[col],
                                              showPulse: isHovered && !widget.readOnly,
                                              onTap: widget.readOnly
                                                  ? null
                                                  : () => _showKartDialog(
                                                      context,
                                                      col,
                                                      usedNumbers: usedNumbers,
                                                      onConfirm: (n, p) => _addKart(col, n, p),
                                                    ),
                                            ),
                                          );
                                        }
                                      },
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
            ),
            
            // Notification glassmorphism moment optimal
            if (_showOptimalNotification)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: OptimalMomentNotification(
                  isVisible: _showOptimalNotification,
                  onDismiss: () {
                    setState(() {
                      _showOptimalNotification = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOptimalMomentIndicator(
    bool isOptimal,
    int percentage,
    int threshold,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isOptimal
            ? RacingTheme.successGradient
            : LinearGradient(
                colors: [RacingTheme.bad, RacingTheme.poor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isOptimal
            ? RacingTheme.racingShadow
            : RacingTheme.darkShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Racing pattern background
              if (isOptimal)
                Positioned.fill(
                  child: CustomPaint(
                    painter: CheckeredPatternPainter(opacity: 0.2),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Racing lights row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final lightOn =
                            isOptimal || index < (percentage / 20).floor();
                        return Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightOn
                                ? (isOptimal
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.7))
                                : Colors.white.withOpacity(0.3),
                            boxShadow: lightOn
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Status message
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOptimal ? Icons.flag : Icons.timer,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isOptimal ? 'C\'EST LE MOMENT !' : 'ATTENDRE...',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Percentage display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'SEUIL: $threshold%',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Progress bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withOpacity(0.3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (percentage / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for checkered pattern (optimal state)
class CheckeredPatternPainter extends CustomPainter {
  final double opacity;

  CheckeredPatternPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const squareSize = 12.0;
    
    // S'assurer que l'opacity est dans la plage valide
    final validOpacity = opacity.clamp(0.0, 1.0);

    for (double x = 0; x < size.width; x += squareSize * 2) {
      for (double y = 0; y < size.height; y += squareSize * 2) {
        // White squares
        paint.color = Colors.white.withOpacity(validOpacity);
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        canvas.drawRect(
          Rect.fromLTWH(x + squareSize, y + squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckeredPatternPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}