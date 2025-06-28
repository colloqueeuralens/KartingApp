import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/live_timing_models.dart';
import 'debouncing_service.dart';
import 'pagination_service.dart';

/// Service pour stocker et gérer l'historique des tours Live Timing
class LiveTimingStorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'live_timing_sessions';
  
  // Cache en mémoire pour performance
  static LiveTimingSession? _currentSession;
  static final Map<String, LiveTimingHistory> _localCache = {};
  
  // Services de pagination par kart
  static final Map<String, LapsPaginationService> _lapsPaginators = {};
  
  // Stream controller pour notifier les changements
  static final StreamController<LiveTimingSession> _sessionController = 
      StreamController<LiveTimingSession>.broadcast();
  
  /// Stream des mises à jour de session
  static Stream<LiveTimingSession> get sessionStream => _sessionController.stream;
  
  /// Session actuelle
  static LiveTimingSession? get currentSession => _currentSession;

  /// Démarrer une nouvelle session de timing
  static Future<LiveTimingSession> startSession(String circuitId) async {
    try {
      // NETTOYER COMPLÈTEMENT l'état précédent avant de créer une nouvelle session
      _currentSession = null;
      _localCache.clear();
      
      final session = LiveTimingSession.create(circuitId: circuitId);
      
      // Stocker dans Firebase
      await _firestore
          .collection(_collectionName)
          .doc(session.sessionId)
          .set(session.toMap());
      
      // Mettre à jour le cache local avec la nouvelle session
      _currentSession = session;
      
      // Notifier les listeners avec la session vide
      _sessionController.add(session);
      
      return session;
    } catch (e) {
      throw Exception('Erreur lors du démarrage de la session: $e');
    }
  }

  /// Arrêter la session actuelle
  static Future<void> stopSession() async {
    if (_currentSession == null) return;
    
    try {
      // Marquer comme inactive dans Firebase
      await _firestore
          .collection(_collectionName)
          .doc(_currentSession!.sessionId)
          .update({'isActive': false});
      
      // Nettoyer le cache
      _currentSession = null;
      _localCache.clear();
      
    } catch (e) {
      throw Exception('Erreur lors de l\'arrêt de la session: $e');
    }
  }

  /// Stocker un nouveau tour avec protection contre les doublons
  static Future<void> storeLap(LiveLapData lap) async {
    if (_currentSession == null) {
      throw Exception('Aucune session active pour stocker le tour');
    }


    try {
      // PROTECTION CONTRE LES DOUBLONS: Vérifier si le tour existe déjà en base
      final existingLapDoc = await _firestore
          .collection(_collectionName)
          .doc(_currentSession!.sessionId)
          .collection('laps')
          .doc(lap.id)
          .get();
      
      // Si le tour existe déjà ET a le même temps, ne pas le re-stocker
      if (existingLapDoc.exists) {
        final existingData = existingLapDoc.data()!;
        final existingLapTime = existingData['lapTime'] as String?;
        if (existingLapTime == lap.lapTime) {
          return;
        }
      }
      
      // Mettre à jour la session avec le nouveau tour (déduplication automatique)
      _currentSession = _currentSession!.addLapForKart(lap.kartId, lap);
      
      // Mettre à jour le cache local (déduplication automatique)
      if (_localCache.containsKey(lap.kartId)) {
        final oldCount = _localCache[lap.kartId]!.totalLaps;
        _localCache[lap.kartId] = _localCache[lap.kartId]!.addLap(lap);
        final newCount = _localCache[lap.kartId]!.totalLaps;
      } else {
        _localCache[lap.kartId] = LiveTimingHistory.create(lap.kartId).addLap(lap);
      }
      
      
      // Stocker le tour individuel dans Firebase (l'ID unique empêche les doublons)
      await _firestore
          .collection(_collectionName)
          .doc(_currentSession!.sessionId)
          .collection('laps')
          .doc(lap.id)
          .set(lap.toMap());
      
      // Mettre à jour les métadonnées de l'historique du kart
      await _firestore
          .collection(_collectionName)
          .doc(_currentSession!.sessionId)
          .collection('karts_summary')
          .doc(lap.kartId)
          .set(_localCache[lap.kartId]!.toMap());
      
      // Notifier les listeners
      _sessionController.add(_currentSession!);
      
    } catch (e) {
      throw Exception('Erreur lors du stockage du tour: $e');
    }
  }

  /// Récupérer l'historique d'un kart
  static Future<LiveTimingHistory?> getKartHistory(String kartId) async {
    try {
      // Vérifier d'abord le cache local
      if (_localCache.containsKey(kartId)) {
        return _localCache[kartId];
      }
      
      if (_currentSession == null) return null;
      
      // Récupérer depuis Firebase
      final doc = await _firestore
          .collection(_collectionName)
          .doc(_currentSession!.sessionId)
          .collection('karts_summary')
          .doc(kartId)
          .get();
      
      if (doc.exists) {
        final history = LiveTimingHistory.fromMap(doc.data()!);
        _localCache[kartId] = history;
        return history;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Récupérer tous les tours d'un kart avec optimisations (pagination + debouncing)
  static Future<List<LiveLapData>> getKartLaps(String kartId, {int? limit}) async {
    
    // Si aucune session courante, retourner une liste vide
    if (_currentSession == null) {
      return [];
    }
    
    // 🚀 OPTIMISATION: Utiliser debouncing pour éviter les appels multiples
    final debounceKey = 'get_kart_laps_$kartId';
    
    // Vérifier si on a un résultat récent en cache
    final cachedResult = DebouncingService.getLastResult<List<LiveLapData>>(debounceKey);
    if (cachedResult != null && !DebouncingService.isActive(debounceKey)) {
      return cachedResult;
    }
    
    // Créer un Completer pour attendre le résultat du debouncing
    final completer = Completer<List<LiveLapData>>();
    
    FirebaseDebouncer.debounceGetKartLaps(
      kartId,
      () => _fetchKartLapsOptimized(kartId, limit: limit),
      (result) {
        final laps = result.cast<LiveLapData>();
        if (!completer.isCompleted) {
          completer.complete(laps);
        }
      },
    );
    
    return completer.future;
  }
  
  /// Récupérer les tours avec pagination optimisée
  static Future<List<LiveLapData>> _fetchKartLapsOptimized(String kartId, {int? limit}) async {
    if (_currentSession == null) return [];
    
    try {
      // 📄 PAGINATION: Utiliser le service de pagination pour ce kart
      final paginatorKey = '${_currentSession!.sessionId}_$kartId';
      
      if (!_lapsPaginators.containsKey(paginatorKey)) {
        _lapsPaginators[paginatorKey] = PaginationFactory.createLapsPagination(
          _currentSession!.sessionId,
          kartId,
        );
      }
      
      final paginator = _lapsPaginators[paginatorKey]!;
      
      // Si limit spécifié et petit, utiliser la requête directe optimisée
      if (limit != null && limit <= 15) {
        return await _fetchKartLapsDirectOptimized(kartId, limit: limit);
      }
      
      // Sinon utiliser la pagination pour gros datasets
      final firstPage = await paginator.getPage(1);
      final laps = firstPage.map((data) => LiveLapData.fromMap(data)).toList();
      
      return laps;
    } catch (e) {
      return [];
    }
  }
  
  /// Récupération directe optimisée pour petites quantités de données
  static Future<List<LiveLapData>> _fetchKartLapsDirectOptimized(String kartId, {int? limit}) async {
    if (_currentSession == null) {
      return [];
    }
    
    final sessionId = _currentSession!.sessionId;
    
    try {
      // Requête simplifiée SANS orderBy pour éviter le besoin d'index composite
      // On triera en mémoire après récupération
      Query query = _firestore
          .collection(_collectionName)
          .doc(sessionId)
          .collection('laps')
          .where('kartId', isEqualTo: kartId);
          // .orderBy('lapNumber', descending: true); // TEMPORAIREMENT DÉSACTIVÉ - index requis
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      
      final laps = <LiveLapData>[];
      for (final doc in snapshot.docs) {
        try {
          final lap = LiveLapData.fromFirestore(doc);
          laps.add(lap);
        } catch (e) {
          continue;
        }
      }
      
      // Trier en mémoire : plus récents en premier
      laps.sort((a, b) => b.lapNumber.compareTo(a.lapNumber));
      
      // Appliquer la limite après tri
      if (limit != null && laps.length > limit) {
        return laps.take(limit).toList();
      }
      
      return laps;
    } catch (e) {
      return [];
    }
  }

  /// Récupérer toutes les sessions
  static Future<List<LiveTimingSession>> getAllSessions({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('raceStart', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => LiveTimingSession.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Charger une session existante
  static Future<LiveTimingSession?> loadSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(sessionId)
          .get();
      
      if (doc.exists) {
        final session = LiveTimingSession.fromMap(doc.data()!);
        _currentSession = session;
        
        // Charger les historiques des karts dans le cache
        final kartsSnapshot = await _firestore
            .collection(_collectionName)
            .doc(sessionId)
            .collection('karts_summary')
            .get();
        
        _localCache.clear();
        for (final kartDoc in kartsSnapshot.docs) {
          final history = LiveTimingHistory.fromMap(kartDoc.data());
          _localCache[history.kartId] = history;
        }
        
        _sessionController.add(session);
        return session;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtenir les statistiques de la session actuelle
  static Map<String, dynamic> getSessionStatistics() {
    if (_currentSession == null) {
      return {
        'totalKarts': 0,
        'totalLaps': 0,
        'sessionDuration': '00:00:00',
        'overallBestLap': '',
        'mostActivekart': '',
      };
    }

    final histories = _localCache.values.toList();
    if (histories.isEmpty) {
      return {
        'totalKarts': 0,
        'totalLaps': 0,
        'sessionDuration': _formatDuration(DateTime.now().difference(_currentSession!.raceStart)),
        'overallBestLap': '',
        'mostActiveKart': '',
      };
    }

    final totalLaps = histories.fold<int>(0, (sum, history) => sum + history.totalLaps);
    
    // Trouver le meilleur tour global
    String overallBestLap = '';
    for (final history in histories) {
      if (history.bestLapTime.isNotEmpty && history.bestLapTime != '--:--') {
        if (overallBestLap.isEmpty || 
            LiveTimingHistory.compareLapTimes(history.bestLapTime, overallBestLap) < 0) {
          overallBestLap = history.bestLapTime;
        }
      }
    }
    
    // Trouver le kart le plus actif
    String mostActiveKart = '';
    int maxLaps = 0;
    for (final history in histories) {
      if (history.totalLaps > maxLaps) {
        maxLaps = history.totalLaps;
        mostActiveKart = history.kartId;
      }
    }

    return {
      'totalKarts': histories.length,
      'totalLaps': totalLaps,
      'sessionDuration': _formatDuration(DateTime.now().difference(_currentSession!.raceStart)),
      'overallBestLap': overallBestLap.isEmpty ? '--:--' : overallBestLap,
      'mostActiveKart': mostActiveKart.isEmpty ? 'Aucun' : mostActiveKart,
    };
  }

  /// Exporter les données de session en format Map pour sauvegarde/partage
  static Map<String, dynamic> exportSessionData() {
    if (_currentSession == null) return {};
    
    return {
      'session': _currentSession!.toMap(),
      'statistics': getSessionStatistics(),
      'exportTimestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Nettoyer les anciennes sessions (garder seulement les N plus récentes)
  static Future<void> cleanupOldSessions({int keepCount = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('raceStart', descending: true)
          .get();
      
      if (snapshot.docs.length > keepCount) {
        final toDelete = snapshot.docs.skip(keepCount);
        final batch = _firestore.batch();
        
        for (final doc in toDelete) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
      }
    } catch (e) {
      // Ignore les erreurs de nettoyage
    }
  }

  /// Formater une durée en HH:MM:SS
  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  /// Dispose du service (nettoyage)
  static void dispose() {
    _sessionController.close();
    _currentSession = null;
    _localCache.clear();
  }
}