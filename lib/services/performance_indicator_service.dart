import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  /// Met à jour l'état de performance et le synchronise avec Firebase
  Future<void> updatePerformance(bool isOptimal, int percentage, int threshold) async {
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

    // Sauvegarder dans Firebase pour sync multi-plateformes
    try {
      await _firestore.collection('performance_indicator').doc('kmrs_main_session').set({
        'isOptimal': isOptimal,
        'percentage': percentage,
        'threshold': threshold,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('📊 PerformanceIndicator: Firebase save error: $e');
      }
    }
  }

  /// Stream Firebase pour synchronisation temps réel multi-plateformes
  Stream<Map<String, dynamic>?> getPerformanceStream() {
    if (kDebugMode) {
      print('📊 PerformanceIndicator: Listening to Firebase stream');
    }
    
    return _firestore.collection('performance_indicator').doc('kmrs_main_session').snapshots().map((doc) {
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

  /// Charge l'état initial depuis Firebase ou utilise le cache
  Future<void> loadInitialState() async {
    // Éviter les recharges multiples
    if (_isInitialized) return;

    try {
      final doc = await _firestore.collection('performance_indicator').doc('kmrs_main_session').get();
      
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

  /// Reset de l'état (pour debug ou nettoyage)
  Future<void> reset() async {
    _isOptimal = false;
    _percentage = 0;
    _threshold = 100;
    _isInitialized = false;
    notifyListeners();

    try {
      await _firestore.collection('performance_indicator').doc('kmrs_main_session').delete();
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