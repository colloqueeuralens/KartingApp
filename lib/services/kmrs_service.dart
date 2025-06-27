import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/kmrs_models.dart';

/// Service principal pour gérer les données KMRS
/// Remplace StrategyService avec fonctionnalités spécifiques KMRS
class KmrsService extends ChangeNotifier {
  static final KmrsService _instance = KmrsService._internal();
  factory KmrsService() => _instance;
  KmrsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  RaceSession? _currentSession;
  bool _isLoading = false;
  String? _error;
  
  // Chronométrage
  DateTime? _raceStartTime;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  bool _isRaceActive = false;
  
  // État temps réel
  RacingData _racingData = RacingData.empty();

  /// Session de course actuelle
  RaceSession? get currentSession => _currentSession;
  
  /// État de chargement
  bool get isLoading => _isLoading;
  
  /// Message d'erreur
  String? get error => _error;
  
  /// Données de course temps réel
  RacingData get racingData => _racingData;
  
  /// État du chronométrage
  bool get isRaceActive => _isRaceActive;
  DateTime? get raceStartTime => _raceStartTime;
  Duration get elapsedTime => _elapsedTime;

  /// Charge ou crée une session KMRS
  Future<void> loadOrCreateSession([String? sessionId]) async {
    try {
      _setLoading(true);
      _setError(null);

      final docId = sessionId ?? 'default';
      final doc = await _firestore.collection('kmrs_sessions').doc(docId).get();
      
      if (doc.exists && doc.data() != null) {
        _currentSession = RaceSession.fromMap(doc.data()!);
      } else {
        _currentSession = _createDefaultSession();
        await saveSession();
      }
      
      _updateRacingData();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de chargement: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Sauvegarde la session dans Firebase
  Future<bool> saveSession() async {
    if (_currentSession == null) return false;

    try {
      await _firestore.collection('kmrs_sessions').doc(_currentSession!.id).set(_currentSession!.toMap());
      return true;
    } catch (e) {
      _setError('Erreur de sauvegarde: $e');
      return false;
    }
  }

  /// Met à jour la configuration de course (Start Page)
  Future<void> updateConfiguration(RaceConfiguration config) async {
    if (_currentSession == null) return;

    try {
      _setLoading(true);
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _currentSession!.startTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: _currentSession!.pilots,
        stints: _currentSession!.stints,
        configuration: config,
        calculations: _currentSession!.calculations,
      );
      
      await saveSession();
      _updateRacingData();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de mise à jour configuration: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Ajoute ou met à jour un pilote
  Future<void> updatePilot(PilotData pilot) async {
    if (_currentSession == null) return;

    try {
      final pilots = List<PilotData>.from(_currentSession!.pilots);
      final existingIndex = pilots.indexWhere((p) => p.id == pilot.id);
      
      if (existingIndex >= 0) {
        pilots[existingIndex] = pilot;
      } else {
        pilots.add(pilot);
      }
      
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _currentSession!.startTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: pilots,
        stints: _currentSession!.stints,
        configuration: _currentSession!.configuration,
        calculations: _currentSession!.calculations,
      );
      
      await saveSession();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de mise à jour pilote: $e');
    }
  }

  /// Supprime un pilote
  Future<void> removePilot(String pilotId) async {
    if (_currentSession == null) return;

    try {
      final pilots = _currentSession!.pilots.where((p) => p.id != pilotId).toList();
      final stints = _currentSession!.stints.where((s) => s.pilotId != pilotId).toList();
      
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _currentSession!.startTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: pilots,
        stints: stints,
        configuration: _currentSession!.configuration,
        calculations: _currentSession!.calculations,
      );
      
      await saveSession();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de suppression pilote: $e');
    }
  }

  /// Démarre la course (Main Page)
  Future<void> startRace() async {
    if (_currentSession == null) return;

    try {
      _raceStartTime = DateTime.now();
      _isRaceActive = true;
      _elapsedTime = Duration.zero;
      
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _raceStartTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: _currentSession!.pilots,
        stints: _currentSession!.stints,
        configuration: _currentSession!.configuration,
        calculations: _currentSession!.calculations,
      );
      
      _startTimer();
      await saveSession();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de démarrage course: $e');
    }
  }

  /// Arrête la course
  Future<void> stopRace() async {
    _isRaceActive = false;
    _timer?.cancel();
    _timer = null;
    
    if (_currentSession != null) {
      await saveSession();
    }
    
    notifyListeners();
  }

  /// Pause/reprend la course
  void toggleRacePause() {
    if (_isRaceActive) {
      _timer?.cancel();
    } else {
      _startTimer();
    }
    _isRaceActive = !_isRaceActive;
    notifyListeners();
  }

  /// Ajoute un nouveau relais (Main Page)
  Future<void> addStint(String pilotId, Duration duration, Duration pitStopTime, {Duration? pitInTime, Duration? pitOutTime, String notes = ''}) async {
    if (_currentSession == null) return;

    try {
      final stintNumber = _currentSession!.stints.length + 1;
      final stint = StintData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pilotId: pilotId,
        stintNumber: stintNumber,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(duration),
        stintDuration: duration,
        pitStopDuration: pitStopTime,
        pitInTime: pitInTime,
        pitOutTime: pitOutTime,
        lapTimes: [],
        notes: notes,
        status: StintStatus.completed,
        isJokerStint: false, // KMRS: Par défaut relais régulier
        telemetry: {},
      );
      
      final stints = List<StintData>.from(_currentSession!.stints);
      stints.add(stint);
      
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _currentSession!.startTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: _currentSession!.pilots,
        stints: stints,
        configuration: _currentSession!.configuration,
        calculations: _currentSession!.calculations,
      );
      
      await saveSession();
      _updateRacingData();
      notifyListeners();
    } catch (e) {
      _setError('Erreur d\'ajout relais: $e');
    }
  }

  /// Met à jour un relais existant
  Future<void> updateStint(StintData updatedStint) async {
    if (_currentSession == null) return;

    try {
      final stints = List<StintData>.from(_currentSession!.stints);
      final index = stints.indexWhere((s) => s.id == updatedStint.id);
      
      if (index >= 0) {
        stints[index] = updatedStint;
        
        _currentSession = RaceSession(
          id: _currentSession!.id,
          sessionName: _currentSession!.sessionName,
          createdAt: _currentSession!.createdAt,
          startTime: _currentSession!.startTime,
          totalDuration: _currentSession!.totalDuration,
          circuitName: _currentSession!.circuitName,
          pilots: _currentSession!.pilots,
          stints: stints,
          configuration: _currentSession!.configuration,
          calculations: _currentSession!.calculations,
        );
        
        await saveSession();
        _updateRacingData();
        notifyListeners();
      }
    } catch (e) {
      _setError('Erreur de mise à jour relais: $e');
    }
  }

  /// Supprime un relais
  Future<void> removeStint(String stintId) async {
    if (_currentSession == null) return;

    try {
      final stints = _currentSession!.stints.where((s) => s.id != stintId).toList();
      
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _currentSession!.startTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: _currentSession!.pilots,
        stints: stints,
        configuration: _currentSession!.configuration,
        calculations: _currentSession!.calculations,
      );
      
      await saveSession();
      _updateRacingData();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de suppression relais: $e');
    }
  }

  /// Calcule et met à jour toutes les statistiques
  Future<void> recalculateAll() async {
    if (_currentSession == null) return;

    try {
      _setLoading(true);
      
      final calculations = <String, dynamic>{};
      
      // Calculs pour chaque pilote
      for (final pilot in _currentSession!.pilots) {
        calculations[pilot.id] = KmrsCalculationEngine.calculatePilotStatistics(pilot, _currentSession!.stints);
      }
      
      // Calculs globaux
      calculations['race'] = {
        'totalStints': _currentSession!.stints.length,
        'totalLaps': _currentSession!.stints.map((s) => s.lapCount).fold(0, (a, b) => a + b),
        'elapsedTime': _elapsedTime.inMilliseconds,
        'remainingTime': _raceStartTime != null
          ? KmrsCalculationEngine.calculateRemainingTime(_raceStartTime!, Duration(hours: _currentSession!.configuration.raceDurationHours.round())).inMilliseconds
          : 0,
      };
      
      _currentSession = RaceSession(
        id: _currentSession!.id,
        sessionName: _currentSession!.sessionName,
        createdAt: _currentSession!.createdAt,
        startTime: _currentSession!.startTime,
        totalDuration: _currentSession!.totalDuration,
        circuitName: _currentSession!.circuitName,
        pilots: _currentSession!.pilots,
        stints: _currentSession!.stints,
        configuration: _currentSession!.configuration,
        calculations: calculations,
      );
      
      await saveSession();
      _updateRacingData();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de recalcul: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Réinitialise complètement la session
  Future<void> resetSession() async {
    try {
      _setLoading(true);
      await stopRace();
      
      _currentSession = _createDefaultSession();
      _raceStartTime = null;
      _elapsedTime = Duration.zero;
      _racingData = RacingData.empty();
      
      await saveSession();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de réinitialisation: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Méthodes privées
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  RaceSession _createDefaultSession() {
    return RaceSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionName: 'Session KMRS ${DateTime.now().day}/${DateTime.now().month}',
      createdAt: DateTime.now(),
      circuitName: 'Circuit par défaut',
      pilots: [], // Commencer avec aucun pilote par défaut
      stints: [],
      configuration: RaceConfiguration.defaultConfig(),
      calculations: {},
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_raceStartTime != null && _isRaceActive) {
        _elapsedTime = DateTime.now().difference(_raceStartTime!);
        _updateRacingData();
        notifyListeners();
      }
    });
  }

  void _updateRacingData() {
    if (_currentSession == null) return;
    
    final currentPilot = _currentSession!.stints.isNotEmpty 
      ? _currentSession!.pilots.firstWhere(
          (p) => p.id == _currentSession!.stints.last.pilotId,
          orElse: () => _currentSession!.pilots.first,
        )
      : (_currentSession!.pilots.isNotEmpty ? _currentSession!.pilots.first : null);

    final raceDuration = Duration(hours: _currentSession!.configuration.raceDurationHours.round());
    final remainingTime = _raceStartTime != null
      ? KmrsCalculationEngine.calculateRemainingTime(_raceStartTime!, raceDuration)
      : raceDuration;

    final totalLaps = _currentSession!.stints.map((s) => s.lapCount).fold(0, (a, b) => a + b);
    
    final lastLap = _currentSession!.stints.isNotEmpty && _currentSession!.stints.last.lapTimes.isNotEmpty
      ? _currentSession!.stints.last.lapTimes.last
      : Duration.zero;
    
    final bestLap = _currentSession!.stints
      .expand((s) => s.lapTimes)
      .fold<Duration?>(null, (best, current) => best == null || current < best ? current : best) ?? Duration.zero;

    // Calculs KMRS authentiques pour RacingData
    final totalStints = _currentSession!.stints.length;
    final regularStints = totalStints; // TODO: Implémenter calcul exact
    final jokerStints = 0; // TODO: Implémenter calcul exact
    final averageJokerDuration = 0.0; // TODO: Implémenter calcul exact

    _racingData = RacingData(
      timestamp: DateTime.now(),
      currentPilotId: currentPilot?.id ?? '',
      elapsedTime: _elapsedTime,
      remainingTime: remainingTime,
      currentLap: totalLaps,
      lastLapTime: lastLap,
      bestLapTime: bestLap,
      regularStints: regularStints,
      jokerStints: jokerStints,
      averageJokerDuration: averageJokerDuration,
      position: 1,
      gridData: KmrsCalculationEngine.generateRacingGrid(_currentSession!),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}