import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import '../../services/session_service.dart';
import '../../services/optimistic_state_service.dart';
import '../../services/global_live_timing_service.dart';
import '../../services/lap_statistics_service.dart';
import '../../services/enhanced_lap_statistics_service.dart';
import '../../services/debouncing_service.dart';
import '../../models/lap_statistics_models.dart';
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
  final Function(bool isOptimal, int percentage, int threshold)? onPerformanceUpdate;

  const RacingKartGridView({
    super.key,
    required this.numColumns,
    required this.numRows,
    required this.columnColors,
    required this.readOnly,
    this.onPerformanceUpdate,
  });

  @override
  State<RacingKartGridView> createState() => _RacingKartGridViewState();
}

class _RacingKartGridViewState extends State<RacingKartGridView>
    with TickerProviderStateMixin, DebouncingMixin {
  Set<int> _hoveredColumns = <int>{};
  bool _isMovingKart = false;
  int _lastValidPercentage = 0;
  bool _lastValidIsOptimal = false;
  int _lastKartCount = 0;
  
  // Cache pour éviter les callbacks inutiles
  int? _lastCachedPct;
  bool? _lastCachedIsOpt;
  int? _lastCachedThreshold;
  
  // Debouncing pour drag & drop
  Timer? _dragDebounceTimer;
  
  // Cache pour optimiser la détection des doublons
  String? _lastKartSignature;
  bool _hasDuplicatesCache = false;
  
  // Service d'état optimiste pour UI instantanée
  final OptimisticStateService _optimisticService = OptimisticStateService();

  @override
  void initState() {
    super.initState();
    // Écouter les changements d'état optimiste pour rebuild automatique
    _optimisticService.addListener(_onOptimisticStateChanged);
    // Écouter les changements du service Live Timing global
    GlobalLiveTimingService.instance.addListener(_onLiveTimingChanged);
  }

  void _onLiveTimingChanged() {
    if (mounted) {
      setState(() {
        // Rebuild quand les données Live Timing changent
      });
    }
  }

  void _onOptimisticStateChanged() {
    if (mounted) {
      // 🚀 OPTIMISATION: Debounce les rebuilds pour éviter les cycles et améliorer les performances
      debounce(
        'optimistic_rebuild',
        const Duration(milliseconds: 16), // 60 FPS max
        () {
          if (mounted) {
            setState(() {
              // Rebuild automatique quand l'état optimiste change
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    // Clear hovered columns to avoid mouse tracking issues
    _hoveredColumns.clear();
    _dragDebounceTimer?.cancel();
    // Arrêter l'écoute de l'état optimiste
    _optimisticService.removeListener(_onOptimisticStateChanged);
    // Arrêter l'écoute du service Live Timing global
    GlobalLiveTimingService.instance.removeListener(_onLiveTimingChanged);
    
    // 🚀 OPTIMISATION: Annuler tous les debounces de ce widget
    cancelAllDebounces();
    
    super.dispose();
  }

  /// Retourne une couleur visible pour le texte selon la luminance de la couleur de fond
  Color _getVisibleColor(Color backgroundColor) {
    // Calculer la luminance de la couleur de fond
    final luminance = backgroundColor.computeLuminance();

    // Si la couleur est trop claire (luminance > 0.8), utiliser gris foncé
    // Sinon, utiliser la couleur originale
    return luminance > 0.8 ? Colors.grey.shade700 : backgroundColor;
  }

  /// Retourne une couleur visible pour les slots vides selon la luminance de la couleur de colonne
  Color _getVisibleColorForSlot(Color columnColor) {
    // Calculer la luminance de la couleur de colonne
    final luminance = columnColor.computeLuminance();

    // Si la couleur est trop claire (luminance > 0.8), utiliser gris
    // Sinon, utiliser la couleur originale de la colonne
    return luminance > 0.8 ? Colors.grey : columnColor;
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

    // 🎯 FEEDBACK HAPTIC INSTANTANÉ pour sensation premium
    HapticFeedback.lightImpact();

    // 🚀 MOUVEMENT OPTIMISTE INSTANTANÉ - UI update ATOMIQUE
    setState(() {
      _isMovingKart = true;
      // Appliquer le mouvement optimiste pendant le setState pour éviter la duplication
      _optimisticService.moveKartOptimistically(
        docId: kartData.docId,
        fromColumn: kartData.fromColumn,
        toColumn: toColumn,
        number: kartData.number,
        perf: kartData.perf,
      );
    });

    // Annuler tout mouvement Firebase en cours
    _dragDebounceTimer?.cancel();

    // Debouncing ultra-optimisé pour Firebase en arrière-plan
    _dragDebounceTimer = Timer(const Duration(milliseconds: 20), () async {
      await _actuallyMoveKart(context, kartData, toColumn);
    });
  }

  Future<void> _actuallyMoveKart(
    BuildContext context,
    KartData kartData,
    int toColumn,
  ) async {
    try {
      // Firebase transaction en arrière-plan
      await SessionService.moveKart(
        kartData.fromColumn,
        toColumn,
        kartData.docId,
        kartData.number,
        kartData.perf,
      );
      
      // ✅ Confirmer le mouvement optimiste (Firebase réussi)
      _optimisticService.confirmMove(kartData.docId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kart ${kartData.number} déplacé vers la colonne ${toColumn + 1}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      // ❌ Rollback du mouvement optimiste (Firebase échoué)
      _optimisticService.rollbackMove(kartData.docId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du déplacement: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              onPressed: () => _actuallyMoveKart(context, kartData, toColumn),
            ),
          ),
        );
      }
    } finally {
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
    final globalService = GlobalLiveTimingService.instance;
    final isLiveTimingActive = globalService.isActive;
    
    int? selNum = initialNumber;
    String? selPerf = initialPerf;
    const opts = ['++', '+', '~', '-', '--', '?'];

    // Obtenir les karts disponibles depuis Live Timing ou fallback classique
    List<int> availableNumbers;
    Map<int, String> kartTeamNames = {};
    Map<int, String> kartIdsMapping = {}; // Mapping numéro → ID réel
    Map<int, Last10LapsStats> kartStatsCache = {}; // Cache des statistiques

    if (isLiveTimingActive) {
      // Mode Live Timing : utiliser seulement les karts présents en course
      final availableKarts = globalService.availableKarts;
      final blocked = Set<int>.from(usedNumbers);
      if (initialNumber != null) blocked.remove(initialNumber);
      
      availableNumbers = availableKarts
          .where((kart) => !blocked.contains(kart.number))
          .map((kart) => kart.number)
          .toList();
      
      // Mapper les noms d'équipes et les IDs réels
      for (final kart in availableKarts) {
        if (kart.teamName != null) {
          kartTeamNames[kart.number] = kart.teamName!;
        }
        kartIdsMapping[kart.number] = kart.id; // Stocker l'ID réel
      }
    } else {
      // Mode classique : tous les numéros 1-99
      final blocked = Set<int>.from(usedNumbers);
      if (initialNumber != null) blocked.remove(initialNumber);
      availableNumbers = List.generate(99, (i) => i + 1)
          .where((n) => !blocked.contains(n))
          .toList();
    }

    // Variable pour éviter le chargement multiple
    bool _isLoadingStats = false;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) {
          // 🚀 CACHE INTELLIGENT OPTIMISÉ - Production Ready avec Debug
          
          if (isLiveTimingActive && availableNumbers.isNotEmpty && !_isLoadingStats) {
            _isLoadingStats = true;
            
            // 🔄 INVALIDER LE CACHE avant de charger pour avoir les données les plus récentes
            EnhancedLapStatisticsService.invalidateAllStats();
            LapStatisticsService.invalidateAllStats();
            
            // 🎯 SMART CACHE: Charger progressivement avec cache intelligent
            Future.microtask(() async {
              for (final kartNumber in availableNumbers) { // 🔥 TOUS LES KARTS - Limite supprimée
                try {
                  final kartId = kartIdsMapping[kartNumber];
                  
                  if (kartId != null) {
                    // 🚀 OPTIMISATION MULTI-NIVEAUX: Utilise le cache intelligent L1→L2→L3
                    // Fallback sur cache original si erreur
                    try {
                      final stats = await EnhancedLapStatisticsService.getLast10LapsStatsAdaptive(kartId);
                      kartStatsCache[kartNumber] = stats;
                    } catch (e) {
                      final stats = await LapStatisticsService.getLast10LapsStats(kartId);
                      kartStatsCache[kartNumber] = stats;
                    }
                    
                    // 🎨 Déclencher un rebuild du dialog seulement si monté
                    if (dCtx.mounted) {
                      setDialog(() {});
                    }
                  }
                } catch (e) {
                  // 🛡️ En cas d'erreur, utiliser des statistiques vides (fallback gracieux)
                  kartStatsCache[kartNumber] = Last10LapsStats.empty();
                }
                
                // 🎯 Micro-pause pour éviter la surcharge Firebase
                await Future.delayed(const Duration(milliseconds: 50));
              }
              _isLoadingStats = false;
            });
          }
          return GlassmorphismDialog(
            title: initialNumber == null
                ? 'Ajouter un kart (col ${col + 1})'
                : 'Modifier Kart (col ${col + 1})',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicateur de mode Live Timing - Compact
                if (isLiveTimingActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.live_tv, color: Colors.green, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Karts en course (Live Timing)',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Démarrez Live Timing pour voir les équipes',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Dropdown numéro enrichi avec responsivité améliorée
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isWeb = screenWidth > 600;
                    
                    return Container(
                      constraints: BoxConstraints(
                        maxWidth: isWeb ? 650 : double.infinity, // 🖥️ Web: largeur augmentée pour plus d'espace
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButton<int>(
                        isExpanded: true,
                        hint: Text(isLiveTimingActive 
                            ? 'Sélectionner un kart en course'
                            : 'Numéro de kart'),
                        value: selNum,
                        underline: const SizedBox.shrink(),
                        items: availableNumbers.map((n) {
                          final teamName = kartTeamNames[n]; // 📊 Vraies données Live Timing
                          final stats = kartStatsCache[n];
                          return DropdownMenuItem(
                            value: n,
                            child: Builder(
                              builder: (context) {
                                // 📱 Responsive adaptatif selon la largeur d'écran
                                final screenWidth = MediaQuery.of(context).size.width;
                                
                                // Calcul des flex ratios adaptatifs
                                int leftFlex, rightFlex;
                                if (screenWidth > 800) {
                                  // 🖥️ Web large : 40% numéro/équipe, 60% statistiques
                                  leftFlex = 2; rightFlex = 3;
                                } else if (screenWidth > 600) {
                                  // 💻 Web moyen : 45% numéro/équipe, 55% statistiques  
                                  leftFlex = 9; rightFlex = 11;
                                } else {
                                  // 📱 Mobile : 35% numéro/équipe, 65% statistiques
                                  leftFlex = 7; rightFlex = 13;
                                }
                                
                                return Row(
                                  children: [
                                    // Partie gauche : Numéro + Équipe
                                    Expanded(
                                      flex: leftFlex,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$n',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11, // 🎯 Unifié à 11px
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (teamName != null)
                                            Flexible(
                                              child: Text(
                                                teamName,
                                                style: TextStyle(
                                                  fontSize: 11, // 🎯 Unifié à 11px
                                                  color: Colors.grey[700],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Partie droite : Statistiques - DONNÉES RÉELLES avec Debug
                                    if (isLiveTimingActive) ...[
                                      if (stats != null && stats.hasValidData) // 📊 DONNÉES RÉELLES
                                        Expanded(
                                          flex: rightFlex,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              _buildCompactStat("Moy", stats.averageTime),
                                              const SizedBox(width: 4),
                                              _buildCompactStat("Best", stats.bestTime),
                                              const SizedBox(width: 4), 
                                              _buildCompactStat("Worst", stats.worstTime),
                                            ],
                                          ),
                                        )
                                      else
                                        // 🔍 AFFICHAGE INTELLIGENT: Gestion des différents états
                                        Expanded(
                                          flex: rightFlex,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                _getStatsDisplayText(stats),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: _getStatsDisplayColor(stats),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setDialog(() => selNum = v),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Dropdown performance avec largeur unifiée
                Builder(
                  builder: (context) {
                    final isWeb = MediaQuery.of(context).size.width > 600;
                    
                    return Container(
                      constraints: BoxConstraints(
                        maxWidth: isWeb ? 650 : double.infinity, // 🖥️ Même largeur que le dropdown numéro
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Performance'),
                        value: selPerf,
                        underline: const SizedBox.shrink(),
                        items: opts
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Center(
                                  child: PerformanceIndicator(performance: p),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialog(() => selPerf = v),
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              GlassmorphismButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
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
                      Icon(Icons.delete, color: Colors.white, size: 14),
                      SizedBox(width: 3),
                      Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      initialNumber == null ? 'Ajouter' : 'Modifier',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
            child: const Text('Annuler', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                Icon(Icons.delete, color: Colors.white, size: 14),
                SizedBox(width: 3),
                Text('Supprimer', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget helper ultra-compact pour les statistiques des 10 derniers tours
  Widget _buildCompactStat(String label, String value) {
    // 📱 Responsive : polices unifiées et harmonieuses
    final isWeb = MediaQuery.of(context).size.width > 600;
    
    return Text(
      "$label: $value",
      style: TextStyle(
        fontSize: isWeb ? 11 : 8, // 🎨 Web: 11px (unifié), 📱 Mobile: 8px (compact)
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontFamily: 'SF Mono', // Police monospace pour alignement
      ),
    );
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
        
        // 🚀 OPTIMISATION UI INSTANTANÉE : Appliquer les positions optimistes
        final adjustedColsData = _buildOptimisticColumnsData(colsData);
        
        final allKarts = <Map<String, dynamic>>[];
        final kartNumbers = <int>[];

        for (var docs in adjustedColsData) {
          for (var d in docs) {
            final data = d.data();
            allKarts.add(data);
            kartNumbers.add(data['number'] as int);
          }
        }

        final usedNumbers = kartNumbers.toSet();

        // Calculer les bonnes performances
        int good = 0;
        for (int colIndex = 0; colIndex < adjustedColsData.length; colIndex++) {
          final docs = adjustedColsData[colIndex];
          if (docs.isNotEmpty) {
            final firstKart = docs.first.data();
            final p = firstKart['perf'] as String;
            
            if (p == '++' || p == '+') {
              good++;
            }
          }
        }

        final currentKartCount = kartNumbers.length;
        final calculatedPct = currentKartCount > 0
            ? (good * 100 / widget.numColumns).round()
            : 0;

        final threshold = widget.numColumns == 2
            ? 100
            : widget.numColumns == 3
            ? 66
            : widget.numColumns == 4
            ? 75
            : 100;

        // Détection d'état transitoire optimisée avec cache
        final hasTemporaryDuplicates = _updateDuplicateDetection(kartNumbers);
        final isTransitionalState = _isMovingKart || hasTemporaryDuplicates;

        final int pct;
        final bool isOpt;

        if (isTransitionalState) {
          // Pendant drag & drop : garder l'affichage stable (dernières valeurs valides)
          pct = _lastValidPercentage;
          isOpt = _lastValidIsOptimal;
        } else {
          // État stable : utiliser le calcul en temps réel
          pct = calculatedPct;
          isOpt = pct >= threshold;
          
          // Mettre à jour le cache seulement dans les états stables
          _lastValidPercentage = pct;
          _lastValidIsOptimal = isOpt;
          _lastKartCount = currentKartCount;
        }

        // 🚀 OPTIMISATION: Debounce les notifications de performance pour éviter le spam
        if (widget.onPerformanceUpdate != null) {
          // Ne déclencher le callback que si les valeurs ont vraiment changé
          if (pct != _lastCachedPct || isOpt != _lastCachedIsOpt || threshold != _lastCachedThreshold) {
            _lastCachedPct = pct;
            _lastCachedIsOpt = isOpt;
            _lastCachedThreshold = threshold;
            
            // Debounce les callbacks pour éviter les appels excessifs
            debounce(
              'performance_update',
              const Duration(milliseconds: 100), // Limite à 10 updates/sec max
              () {
                if (mounted && widget.onPerformanceUpdate != null) {
                  widget.onPerformanceUpdate!(isOpt, pct, threshold);
                }
              },
            );
          }
        }

        return Row(
                children: List.generate(widget.numColumns, (col) {
                  final docs = adjustedColsData[col];
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
                        if (mounted) {
                          setState(() {
                            _hoveredColumns.remove(col);
                          });
                        }
                      },
                      onMove: (details) {
                        if (!_hoveredColumns.contains(col) && mounted) {
                          setState(() {
                            _hoveredColumns.add(col);
                          });
                        }
                      },
                      onLeave: (data) {
                        if (mounted) {
                          setState(() {
                            _hoveredColumns.remove(col);
                          });
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? Colors.blue.withValues(alpha: 0.2)
                                : widget.columnColors[col].withValues(
                                    alpha: 0.2,
                                  ),
                            border: isHovered
                                ? Border.all(color: Colors.blue, width: 2)
                                : Border.all(
                                    color: _getVisibleColor(
                                      widget.columnColors[col],
                                    ).withValues(alpha: 0.3),
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
                                  color: _getVisibleColorForSlot(
                                    widget.columnColors[col],
                                  ).withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      color: _getVisibleColor(
                                        widget.columnColors[col],
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Colonne ${col + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getVisibleColor(
                                          widget.columnColors[col],
                                        ),
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

                                      final isKartOptimal =
                                          (perf == '++' || perf == '+');
                                      final showPulse =
                                          isKartOptimal && isOpt && pct < 100;
                                      
                                      // 🚀 Vérifier si ce kart est en mouvement optimiste
                                      final isPendingOptimistic = _optimisticService.isPendingMove(doc.id);

                                      final kartCard = Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        // 🚀 Indicateur visuel pour mouvement optimiste en cours
                                        decoration: isPendingOptimistic
                                            ? BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.blue.withValues(alpha: 0.5),
                                                    blurRadius: 8,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              )
                                            : null,
                                        child: RacingKartCard(
                                          kartNumber: number.toString(),
                                          performance: perf,
                                          color:
                                              RacingTheme.getPerformanceColor(
                                                perf,
                                              ),
                                          isOptimalMoment:
                                              isKartOptimal && isOpt,
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
                                                  onConfirm: (n, p) =>
                                                      _editKart(
                                                        col,
                                                        doc.id,
                                                        n,
                                                        p,
                                                      ),
                                                  onDelete: () => _deleteKart(
                                                    context,
                                                    col,
                                                    doc.id,
                                                  ),
                                                ),
                                        ),
                                      );

                                      return widget.readOnly
                                          ? kartCard
                                          : Draggable<KartData>(
                                              data: kartData,
                                              feedback: Material(
                                                elevation: 8,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: RacingKartCard(
                                                  kartNumber: number.toString(),
                                                  performance: perf,
                                                  color:
                                                      RacingTheme.getPerformanceColor(
                                                        perf,
                                                      ),
                                                  isOptimalMoment: false,
                                                  showPulse: false,
                                                ),
                                              ),
                                              childWhenDragging: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
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
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: EmptyKartSlot(
                                          color: _getVisibleColorForSlot(
                                            widget.columnColors[col],
                                          ),
                                          showPulse:
                                              isHovered && !widget.readOnly,
                                          onTap: widget.readOnly
                                              ? null
                                              : () => _showKartDialog(
                                                  context,
                                                  col,
                                                  usedNumbers: usedNumbers,
                                                  onConfirm: (n, p) =>
                                                      _addKart(col, n, p),
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
              );
      },
    );
  }

  /// Optimise la détection des doublons avec cache pour éviter les recalculs
  bool _updateDuplicateDetection(List<int> kartNumbers) {
    final currentSignature = kartNumbers.join(',');
    if (_lastKartSignature != currentSignature) {
      _lastKartSignature = currentSignature;
      _hasDuplicatesCache = kartNumbers.toSet().length != kartNumbers.length;
    }
    return _hasDuplicatesCache;
  }

  /// 🚀 CORE OPTIMISATION : Construit les données de colonnes avec positions optimistes (ATOMIQUE)
  List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _buildOptimisticColumnsData(
    List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> originalColsData,
  ) {
    // 🚀 APPROCHE ATOMIQUE : Créer une map globale de tous les karts d'abord
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> allKartsById = {};
    final Map<String, int> originalKartColumns = {};

    // Phase 1: Indexer tous les karts existants
    for (int col = 0; col < originalColsData.length; col++) {
      for (final doc in originalColsData[col]) {
        allKartsById[doc.id] = doc;
        originalKartColumns[doc.id] = col;
      }
    }

    // Phase 2: Créer les colonnes finales avec positions optimistes
    final adjustedData = List.generate(
      widget.numColumns,
      (col) => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    );

    // Phase 3: Placer chaque kart dans sa position finale (optimiste ou originale)
    for (final entry in allKartsById.entries) {
      final docId = entry.key;
      final doc = entry.value;
      final originalCol = originalKartColumns[docId]!;
      
      // Vérifier s'il y a une position optimiste pour ce kart
      final optimisticPos = _optimisticService.getOptimisticPosition(docId);
      
      if (optimisticPos != null) {
        // 🚀 Kart en mouvement optimiste : placer UNIQUEMENT dans la nouvelle colonne
        final targetCol = optimisticPos.column;
        final modifiedDoc = _createOptimisticDocument(doc, optimisticPos);
        
        // Insérer en première position (plus récent)
        adjustedData[targetCol].insert(0, modifiedDoc);
        
        // ⚠️ CRITIQUE: Continue pour éviter double placement dans position originale
        continue;
      }
      
      // 🛡️ PROTECTION CIBLÉE : Masquer seulement les conflits de position
      final kartNumber = doc.data()['number'] as int;
      final shouldMask = _optimisticService.shouldMaskFirebaseKart(kartNumber, originalCol);
      
      if (shouldMask) {
      } else {
        adjustedData[originalCol].add(doc);
      }
    }

    // 🚀 DÉDUPLICATION PAR NUMÉRO : Éliminer les doublons dans chaque colonne
    for (int col = 0; col < adjustedData.length; col++) {
      if (adjustedData[col].length <= 1) continue; // Pas de doublons possibles
      
      final Map<int, List<QueryDocumentSnapshot<Map<String, dynamic>>>> kartsByNumber = {};
      
      // Grouper les karts par numéro dans cette colonne
      for (final doc in adjustedData[col]) {
        final kartNumber = doc.data()['number'] as int;
        kartsByNumber.putIfAbsent(kartNumber, () => []).add(doc);
      }
      
      // Reconstruire la colonne en éliminant les doublons
      adjustedData[col].clear();
      
      for (final entry in kartsByNumber.entries) {
        final kartNumber = entry.key;
        final duplicates = entry.value;
        
        if (duplicates.length == 1) {
          // Pas de doublon, garder tel quel
          adjustedData[col].add(duplicates.first);
        } else {
          // 🚀 PRÉVENTION DUPLICATION VISUELLE : Priorité ABSOLUE à l'optimiste
          QueryDocumentSnapshot<Map<String, dynamic>>? optimisticKart;
          QueryDocumentSnapshot<Map<String, dynamic>>? firebaseKart;
          
          for (final doc in duplicates) {
            final isOptimistic = doc.data().containsKey('_isOptimistic');
            if (isOptimistic) {
              optimisticKart = doc;
            } else {
              firebaseKart = doc;
            }
          }
          
          // 🛡️ GARANTIE ZÉRO DUPLICATION : Si optimiste existe, SEUL lui est affiché
          final kartToKeep = optimisticKart ?? firebaseKart!;
          adjustedData[col].add(kartToKeep);
        }
      }
      
      // Retrier par timestamp pour maintenir l'ordre
      adjustedData[col].sort((a, b) {
        final aTime = a.data()['timestamp'] as Timestamp?;
        final bTime = b.data()['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // DESC order (plus récent en premier)
      });
    }

    return adjustedData;
  }

  /// Crée un document avec données optimistes pour affichage instantané
  QueryDocumentSnapshot<Map<String, dynamic>> _createOptimisticDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> originalDoc,
    OptimisticKartPosition optimisticPos,
  ) {
    // Créer un wrapper de document qui utilise les données optimistes
    return _OptimisticDocumentSnapshot(
      originalDoc: originalDoc,
      optimisticPosition: optimisticPos,
      // 🚀 Timestamp optimiste factice pour maintenir l'ordre cohérent
      optimisticTimestamp: DateTime.now(),
    );
  }

  /// Obtenir le texte d'affichage pour les statistiques selon l'état
  String _getStatsDisplayText(Last10LapsStats? stats) {
    if (stats == null) {
      return "Chargement...";
    }
    
    // Vérifier si c'est le cas "Manque de données" (moins de 10 tours)
    if (stats.averageTime == 'Manque de données') {
      return "Manque de données";
    }
    
    // Vérifier si c'est le cas "pas de données"
    if (!stats.hasValidData) {
      return "Aucune donnée";
    }
    
    return "Données invalides";
  }

  /// Obtenir la couleur d'affichage pour les statistiques selon l'état
  Color _getStatsDisplayColor(Last10LapsStats? stats) {
    if (stats == null) {
      return Colors.blue; // Chargement en cours
    }
    
    // Vérifier si c'est le cas "Manque de données" (moins de 10 tours)
    if (stats.averageTime == 'Manque de données') {
      return Colors.amber; // Couleur d'avertissement pour manque de données
    }
    
    // Autres cas (pas de données, erreurs)
    return Colors.orange;
  }
}

/// Wrapper de document optimiste pour affichage UI instantané
class _OptimisticDocumentSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final QueryDocumentSnapshot<Map<String, dynamic>> originalDoc;
  final OptimisticKartPosition optimisticPosition;
  final DateTime optimisticTimestamp;

  _OptimisticDocumentSnapshot({
    required this.originalDoc,
    required this.optimisticPosition,
    required this.optimisticTimestamp,
  });

  @override
  String get id => originalDoc.id;

  @override
  Map<String, dynamic> data() {
    // Retourner les données originales avec timestamp optimiste pour tri cohérent
    final originalData = originalDoc.data();
    return {
      ...originalData,
      // 🚀 Override timestamp pour maintenir ordre cohérent (plus récent = en haut)
      'timestamp': Timestamp.fromDate(optimisticTimestamp),
      '_isOptimistic': true, // Marqueur pour debug
    };
  }

  @override
  DocumentReference<Map<String, dynamic>> get reference => originalDoc.reference;

  @override
  bool get exists => originalDoc.exists;

  @override
  SnapshotMetadata get metadata => originalDoc.metadata;

  @override
  Object? operator [](Object field) => originalDoc[field];

  @override
  Object? get(Object field) => originalDoc.get(field);
}