import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_session_service.dart';

/// Service pour la persistance de l'indicateur de performance KMRS
/// Maintient l'état optimal/percentage/threshold entre les navigations
class PerformanceIndicatorService extends ChangeNotifier {
  static final PerformanceIndicatorService _instance = PerformanceIndicatorService._internal();
  factory PerformanceIndicatorService() => _instance;
  PerformanceIndicatorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // État de l'indicateur de performance
  bool _isOptimal = false;
  int _percentage = 0;
  int _threshold = 100;
  bool _isInitialized = false;
  
  // Getters
  bool get isOptimal => _isOptimal;
  int get percentage => _percentage;
  int get threshold => _threshold;
  bool get isInitialized => _isInitialized;

  /// Met à jour l'état de performance et le synchronise avec Firebase (user-specific)
  Future<void> updatePerformance(bool isOptimal, int percentage, int threshold) async {
    UserSessionService.ensureAuthenticated(); // Vérification sécurité
    
    // Éviter les mises à jour inutiles
    if (_isOptimal == isOptimal && 
        _percentage == percentage && 
        _threshold == threshold) {
      return;
    }

    _isOptimal = isOptimal;
    _percentage = percentage;
    _threshold = threshold;
    _isInitialized = true;

    if (kDebugMode) {
      print('📊 PerformanceIndicator: Updated - $percentage% (threshold: $threshold%, optimal: $isOptimal)');
    }

    // Déclencher rebuild immédiat
    notifyListeners();

    // Sauvegarder dans Firebase pour sync multi-plateformes (user-specific)
    try {
      final userPerformancePath = UserSessionService.getUserPerformanceDoc();
      await _firestore.doc(userPerformancePath).set({
        'isOptimal': isOptimal,
        'percentage': percentage,
        'threshold': threshold,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
      
      UserSessionService.logUserSession('updatePerformance');
    } catch (e) {
      if (kDebugMode) {
        print('📊 PerformanceIndicator: Firebase save error: $e');
      }
    }
  }

  /// Stream Firebase pour synchronisation temps réel multi-plateformes (user-specific)
  Stream<Map<String, dynamic>?> getPerformanceStream() {
    UserSessionService.ensureAuthenticated(); // Vérification sécurité
    final userPerformancePath = UserSessionService.getUserPerformanceDoc();
    
    if (kDebugMode) {
      print('📊 PerformanceIndicator: Listening to Firebase stream: $userPerformancePath');
    }
    
    return _firestore.doc(userPerformancePath).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        // Mettre à jour le cache local sans déclencher une boucle
        final newIsOptimal = data['isOptimal'] ?? false;
        final newPercentage = data['percentage'] ?? 0;
        final newThreshold = data['threshold'] ?? 100;
        
        // Éviter les notifications circulaires
        if (_isOptimal != newIsOptimal || 
            _percentage != newPercentage || 
            _threshold != newThreshold) {
          
          _isOptimal = newIsOptimal;
          _percentage = newPercentage;
          _threshold = newThreshold;
          _isInitialized = true;
          
          if (kDebugMode) {
            print('📊 PerformanceIndicator: Firebase sync - $newPercentage% (optimal: $newIsOptimal)');
          }
          
          notifyListeners();
        }
        
        return data;
      }
      return null;
    });
  }

  /// Charge l'état initial depuis Firebase ou utilise le cache (user-specific)
  Future<void> loadInitialState() async {
    UserSessionService.ensureAuthenticated(); // Vérification sécurité
    
    // Éviter les recharges multiples
    if (_isInitialized) return;

    try {
      final userPerformancePath = UserSessionService.getUserPerformanceDoc();
      final doc = await _firestore.doc(userPerformancePath).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _isOptimal = data['isOptimal'] ?? false;
        _percentage = data['percentage'] ?? 0;
        _threshold = data['threshold'] ?? 100;
        _isInitialized = true;
        
        if (kDebugMode) {
          print('📊 PerformanceIndicator: Loaded from Firebase - $_percentage% (optimal: $_isOptimal)');
        }
        
        notifyListeners();
      } else {
        // Initialiser avec valeurs par défaut
        _isOptimal = false;
        _percentage = 0;
        _threshold = 100;
        _isInitialized = true;
        
        if (kDebugMode) {
          print('📊 PerformanceIndicator: Initialized with defaults');
        }
        
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 PerformanceIndicator: Load error: $e');
      }
      
      // Fallback aux valeurs par défaut
      _isOptimal = false;
      _percentage = 0;
      _threshold = 100;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Reset de l'état (pour debug ou nettoyage, user-specific)
  Future<void> reset() async {
    UserSessionService.ensureAuthenticated(); // Vérification sécurité
    
    _isOptimal = false;
    _percentage = 0;
    _threshold = 100;
    _isInitialized = false;
    notifyListeners();

    try {
      final userPerformancePath = UserSessionService.getUserPerformanceDoc();
      await _firestore.doc(userPerformancePath).delete();
      
      UserSessionService.logUserSession('resetPerformance');
      if (kDebugMode) {
        print('📊 PerformanceIndicator: Reset completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 PerformanceIndicator: Reset error: $e');
      }
    }
  }
}