import 'dart:async';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';
import 'live_timing_storage_service.dart';
import 'live_timing_simulator.dart';
import 'lap_statistics_service.dart';
import 'enhanced_lap_statistics_service.dart';

/// Service global pour maintenir Live Timing actif en arrière-plan
/// et partager les données entre toutes les pages de l'application
class GlobalLiveTimingService extends ChangeNotifier {
  static final GlobalLiveTimingService _instance = GlobalLiveTimingService._internal();
  static GlobalLiveTimingService get instance => _instance;
  
  GlobalLiveTimingService._internal();

  // État du service
  bool _isActive = false;
  bool _isConnected = false;
  bool _isSimulating = false;
  String? _currentCircuitId;
  String? _errorMessage;

  // Données Live Timing
  Map<String, Map<String, dynamic>> _driversData = {};
  List<String> _columnOrder = [];
  int _connectionAttempts = 0;
  final LiveTimingWebSocketService _wsService = LiveTimingWebSocketService();
  final LiveTimingSimulator _simulator = LiveTimingSimulator();

  // Getters publics
  bool get isActive => _isActive;
  bool get isConnected => _isConnected;
  bool get isSimulating => _isSimulating;
  String? get currentCircuitId => _currentCircuitId;
  String? get errorMessage => _errorMessage;
  Map<String, Map<String, dynamic>> get driversData => Map.from(_driversData);
  List<String> get columnOrder => List.from(_columnOrder);

  /// Récupérer la liste des karts disponibles avec leurs noms d'équipes
  List<KartInfo> get availableKarts {
    final karts = <KartInfo>[];
    
    _driversData.forEach((kartId, driverData) {
      final teamName = _extractTeamName(driverData);
      final kartNumber = _extractKartNumber(kartId, driverData);
      
      if (kartNumber != null) {
        karts.add(KartInfo(
          id: kartId,
          number: kartNumber,
          teamName: teamName,
        ));
      }
    });
    
    // Trier par numéro de kart
    karts.sort((a, b) => a.number.compareTo(b.number));
    return karts;
  }

  /// Démarrer le Live Timing réel avec logique de connexion robuste
  Future<bool> startRealTiming(String circuitId) async {
    if (_isActive) {
      await stopTiming();
    }

    try {
      _currentCircuitId = circuitId;
      _errorMessage = null;
      _driversData.clear();
      notifyListeners();

      // WebSocket-first approach - Connect to WebSocket first
      final connected = await _connectToTiming(circuitId);
      if (!connected) {
        _errorMessage = 'Impossible de se connecter au WebSocket avant le timing';
        _isActive = false;
        notifyListeners();
        return false;
      }

      // Stabilization delay before starting backend (délai critique !)
      await Future.delayed(const Duration(seconds: 2));

      // Démarrer timing backend
      final timingSuccess = await BackendService.startTiming(circuitId);
      if (!timingSuccess) {
        _errorMessage = 'Impossible de démarrer le timing backend';
        await _wsService.disconnect();
        _isActive = false;
        notifyListeners();
        return false;
      }

      // Démarrer session de stockage
      try {
        await LiveTimingStorageService.startSession(circuitId);
      } catch (e) {
        // Log l'erreur mais ne bloque pas le timing
        print('Erreur lors du démarrage de la session de stockage: $e');
      }

      // Activer détection des tours
      _wsService.enableLapDetection(true);

      _isActive = true;
      _isConnected = true;
      _isSimulating = false;
      _errorMessage = null;

      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Erreur lors du démarrage: $e';
      _isActive = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Démarrer la simulation Live Timing
  Future<bool> startSimulation(String circuitId) async {
    if (_isActive) {
      await stopTiming();
    }

    try {
      _currentCircuitId = circuitId;
      _errorMessage = null;
      notifyListeners();

      // Démarrer session de stockage
      await LiveTimingStorageService.startSession(circuitId);

      // Configurer le simulateur avec ordre des colonnes
      _simulator.onDataUpdate = (data) {
        _driversData = Map<String, Map<String, dynamic>>.from(data);
        _wsService.processSimulatedData(data);
        _columnOrder = _wsService.columnOrder; // ⭐ Maintenir l'ordre pour simulation aussi
        
        // 🚀 OPTIMISATION: Invalider le cache lors de nouvelles données
        _invalidateStatsCache();
        
        notifyListeners();
      };

      // Démarrer simulation
      _simulator.startSimulation();
      _wsService.enableLapDetection(true);

      _isActive = true;
      _isConnected = true;
      _isSimulating = true;

      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = 'Erreur lors du démarrage de la simulation: $e';
      _isActive = false;
      _isConnected = false;
      _isSimulating = false;
      notifyListeners();
      return false;
    }
  }

  /// Connexion au timing avec retry logic (transfert de l'ancien code)
  Future<bool> _connectToTiming(String circuitId) async {
    // Vérifier la santé du backend d'abord
    final healthy = await BackendService.checkHealth();
    if (!healthy) {
      _errorMessage = 'Backend non disponible';
      notifyListeners();
      return false;
    }

    _connectionAttempts = 0;
    return await _attemptWebSocketConnection(circuitId);
  }

  /// Tentative de connexion WebSocket avec retry (logique exacte de l'ancien code)
  Future<bool> _attemptWebSocketConnection(String circuitId) async {
    const maxAttempts = 3;
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      _connectionAttempts = attempt;
      
      try {
        // Se connecter au WebSocket avec timeout
        final connected = await _wsService.connect(circuitId).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            return false;
          },
        );

        if (connected) {
          _isConnected = true;
          _errorMessage = null;
          
          // Écouter les données en temps réel + maintenir columnOrder
          _wsService.stream?.listen((data) {
            _driversData = _wsService.allKartsData;
            _columnOrder = _wsService.columnOrder; // ⭐ Maintenir l'ordre des colonnes
            _isConnected = _wsService.isConnected;
            
            // 🚀 OPTIMISATION: Invalider le cache lors de nouvelles données temps réel
            _invalidateStatsCache();
            
            notifyListeners();
          }, onError: (error) {
            _errorMessage = 'Connexion WebSocket perdue: $error';
            _isConnected = false;
            notifyListeners();
          });
          
          return true; // Succès, sortir de la boucle
        }

        // Échec de connexion, attendre avant retry
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
        }
        
      } catch (e) {
        if (attempt == maxAttempts) {
          _errorMessage = 'Impossible de se connecter au WebSocket après $maxAttempts tentatives';
          _isConnected = false;
          notifyListeners();
          return false;
        }
      }
    }
    
    return false;
  }

  /// Arrêter le Live Timing
  Future<void> stopTiming() async {
    try {
      if (_isSimulating) {
        _simulator.stopSimulation();
      } else {
        if (_currentCircuitId != null) {
          await BackendService.stopTiming(_currentCircuitId!);
        }
      }

      _wsService.enableLapDetection(false);
      await _wsService.disconnect();
      await LiveTimingStorageService.stopSession();

      _isActive = false;
      _isConnected = false;
      _isSimulating = false;
      _currentCircuitId = null;
      _driversData.clear();
      _columnOrder.clear();
      _errorMessage = null;

      notifyListeners();

    } catch (e) {
      _errorMessage = 'Erreur lors de l\'arrêt: $e';
      notifyListeners();
    }
  }

  /// Extraire le nom d'équipe depuis les données du pilote
  String? _extractTeamName(Map<String, dynamic> driverData) {
    const possibleKeys = [
      'Equipe', 'Team', 'Équipe', 'Club', 'Sponsor', 'Organisation', 
      'Team Name', 'Nom Équipe', 'Nom Team', 'TeamName', 'EquipeName',
      'Squad', 'Crew', 'Écurie'
    ];

    for (final key in possibleKeys) {
      final value = driverData[key]?.toString()?.trim();
      if (value != null && value.isNotEmpty && value != '--') {
        return value;
      }
    }
    return null;
  }

  /// Extraire le numéro de kart depuis l'ID ou les données
  int? _extractKartNumber(String kartId, Map<String, dynamic> driverData) {
    // Essayer depuis les données d'abord
    const possibleKeys = ['Kart', 'Number', 'Numéro', 'Num', 'Car'];
    for (final key in possibleKeys) {
      final value = driverData[key]?.toString();
      if (value != null) {
        final number = int.tryParse(value);
        if (number != null && number > 0) {
          return number;
        }
      }
    }

    // Fallback: essayer de parser l'ID
    final number = int.tryParse(kartId);
    if (number != null && number > 0) {
      return number;
    }

    return null;
  }

  /// 🔍 DEBUG: Simuler des karts disponibles pour les tests de statistiques
  void updateKartsData(List<KartInfo> karts) {
    print('🎯 DEBUG - Updating karts data: ${karts.length} karts');
    
    // Simuler les données des karts comme si elles venaient du Live Timing
    _driversData.clear();
    for (final kart in karts) {
      _driversData[kart.id] = {
        'number': kart.number.toString(),
        'team': kart.teamName ?? 'ÉQUIPE ${kart.number}',
        'position': '1',
        // Ajouter d'autres champs pour simuler Live Timing complet
      };
    }
    
    _isActive = true;
    _isConnected = true;
    print('  ├─ _isActive: $_isActive');
    print('  ├─ _isConnected: $_isConnected');
    print('  └─ Available karts: ${_driversData.keys.join(', ')}');
    
    // 🔄 INVALIDER LE CACHE pour forcer la mise à jour des statistiques
    _invalidateStatsCache();
    
    // Notifier tous les listeners que les données ont changé
    notifyListeners();
  }

  /// Invalider le cache des statistiques lors de nouvelles données Live Timing
  void _invalidateStatsCache() {
    try {
      // 🚀 OPTIMISATION MULTI-NIVEAUX: Invalider intelligemment tous les caches
      if (_driversData.isNotEmpty) {
        // Invalider cache original (niveau 1)
        LapStatisticsService.invalidateAllStats();
        
        // Invalider cache multi-niveaux (L1, L2, L3)
        EnhancedLapStatisticsService.invalidateAllStats();
        
        // 🎯 PRÉ-CHARGEMENT INTELLIGENT: Recharger les karts populaires
        final popularKartIds = _driversData.keys.take(5).toList(); // Top 5 karts
        if (popularKartIds.isNotEmpty) {
          // Pré-charger en arrière-plan sans bloquer
          Future.microtask(() => EnhancedLapStatisticsService.preloadPopularKarts(popularKartIds));
        }
      }
    } catch (e) {
      // En cas d'erreur, ne pas planter le Live Timing
      debugPrint('Erreur invalidation cache multi-niveaux: $e');
    }
  }

  @override
  void dispose() {
    stopTiming();
    super.dispose();
  }
}

/// Modèle pour les informations d'un kart
class KartInfo {
  final String id;
  final int number;
  final String? teamName;

  const KartInfo({
    required this.id,
    required this.number,
    this.teamName,
  });

  /// Affichage formaté pour dropdown
  String get displayName {
    if (teamName != null && teamName!.isNotEmpty) {
      return '$number - $teamName';
    }
    return number.toString();
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KartInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          number == other.number;

  @override
  int get hashCode => id.hashCode ^ number.hashCode;
}