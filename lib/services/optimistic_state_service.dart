import 'package:flutter/foundation.dart';

/// Position optimiste d'un kart pour UI instantanée
class OptimisticKartPosition {
  final int column;
  final String docId;
  final int number;
  final String perf;
  final bool isPending;
  final DateTime timestamp;

  const OptimisticKartPosition({
    required this.column,
    required this.docId,
    required this.number,
    required this.perf,
    this.isPending = true,
    required this.timestamp,
  });

  OptimisticKartPosition copyWith({
    int? column,
    bool? isPending,
  }) {
    return OptimisticKartPosition(
      column: column ?? this.column,
      docId: docId,
      number: number,
      perf: perf,
      isPending: isPending ?? this.isPending,
      timestamp: timestamp,
    );
  }
}

/// Service de gestion d'état optimiste pour drag & drop ultra-rapide
class OptimisticStateService extends ChangeNotifier {
  static final OptimisticStateService _instance = OptimisticStateService._internal();
  factory OptimisticStateService() => _instance;
  OptimisticStateService._internal();

  /// Cache des positions optimistes des karts
  final Map<String, OptimisticKartPosition> _optimisticPositions = {};
  
  /// Mouvements en attente de confirmation Firebase
  final Set<String> _pendingMoves = {};

  /// Obtenir la position optimiste d'un kart (si elle existe)
  OptimisticKartPosition? getOptimisticPosition(String docId) {
    return _optimisticPositions[docId];
  }

  /// Vérifier si un kart a une position optimiste
  bool hasOptimisticPosition(String docId) {
    return _optimisticPositions.containsKey(docId);
  }

  /// Vérifier si un mouvement est en cours
  bool isPendingMove(String docId) {
    return _pendingMoves.contains(docId);
  }

  /// Déplacer un kart de manière optimiste (UI instantanée)
  void moveKartOptimistically({
    required String docId,
    required int fromColumn,
    required int toColumn,
    required int number,
    required String perf,
  }) {
    if (fromColumn == toColumn) return;

    print('🚀 OPTIMISTIC: Kart $number Col${fromColumn + 1} → Col${toColumn + 1} (instantané, position: PREMIÈRE)');
    
    // Créer la position optimiste
    final optimisticPosition = OptimisticKartPosition(
      column: toColumn,
      docId: docId,
      number: number,
      perf: perf,
      timestamp: DateTime.now(),
    );

    // Stocker dans le cache optimiste
    _optimisticPositions[docId] = optimisticPosition;
    _pendingMoves.add(docId);

    // Notifier l'UI immédiatement
    notifyListeners();

    // Auto-cleanup après timeout de sécurité
    _scheduleCleanup(docId);
  }

  /// Confirmer le mouvement (quand Firebase répond)
  void confirmMove(String docId) {
    if (_optimisticPositions.containsKey(docId)) {
      final position = _optimisticPositions[docId]!;
      _optimisticPositions[docId] = position.copyWith(isPending: false);
      _pendingMoves.remove(docId);
      
      print('✅ OPTIMISTIC: Kart confirmé pour docId $docId');
      
      // Nettoyer après un délai pour permettre l'animation
      Future.delayed(const Duration(milliseconds: 500), () {
        _optimisticPositions.remove(docId);
        notifyListeners();
      });
    }
  }

  /// Annuler le mouvement optimiste (en cas d'erreur Firebase)
  void rollbackMove(String docId) {
    if (_optimisticPositions.containsKey(docId)) {
      print('❌ OPTIMISTIC: Rollback pour docId $docId');
      _optimisticPositions.remove(docId);
      _pendingMoves.remove(docId);
      notifyListeners();
    }
  }

  /// Nettoyer les mouvements obsolètes
  void _scheduleCleanup(String docId) {
    Future.delayed(const Duration(seconds: 10), () {
      if (_optimisticPositions.containsKey(docId)) {
        final position = _optimisticPositions[docId]!;
        if (position.isPending) {
          print('⚠️ OPTIMISTIC: Timeout cleanup pour docId $docId');
          rollbackMove(docId);
        }
      }
    });
  }

  /// Nettoyer tout l'état optimiste
  void clearAll() {
    _optimisticPositions.clear();
    _pendingMoves.clear();
    notifyListeners();
  }

  /// Obtenir le nombre de mouvements en attente
  int get pendingMovesCount => _pendingMoves.length;

  /// Debug: Afficher l'état actuel
  void debugPrintState() {
    print('📊 OPTIMISTIC STATE:');
    print('   - Positions: ${_optimisticPositions.length}');
    print('   - Pending: ${_pendingMoves.length}');
    for (final entry in _optimisticPositions.entries) {
      final pos = entry.value;
      print('   - ${entry.key}: Col${pos.column + 1} (pending: ${pos.isPending})');
    }
  }
}