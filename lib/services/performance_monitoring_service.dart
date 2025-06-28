import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'cache_service.dart';
import 'multi_level_cache_service.dart';
import 'debouncing_service.dart';
import 'enhanced_lap_statistics_service.dart';
import 'lap_statistics_service.dart';

/// Service de monitoring des performances pour toutes les optimisations
class PerformanceMonitoringService extends ChangeNotifier {
  static final PerformanceMonitoringService _instance = PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  // Métriques de performance
  final Map<String, List<double>> _responseTimesMs = {};
  final Map<String, int> _operationCounts = {};
  final Map<String, DateTime> _lastOperationTimes = {};
  
  // Monitoring Firebase
  int _firebaseReads = 0;
  int _firebaseWrites = 0;
  int _cacheMisses = 0;
  int _cacheHits = 0;
  
  // Monitoring UI
  int _uiRebuilds = 0;
  int _debouncedCalls = 0;
  double _averageFrameTime = 16.0; // 60 FPS baseline
  
  // Configuration
  final int _maxSampleSize = 100;
  Timer? _periodicReportTimer;
  

  
  /// Enregistrer une opération avec temps de réponse
  void recordOperation(String operationType, double responseTimeMs) {
    // Ajouter le temps de réponse
    _responseTimesMs.putIfAbsent(operationType, () => []);
    _responseTimesMs[operationType]!.add(responseTimeMs);
    
    // Limiter la taille des échantillons
    if (_responseTimesMs[operationType]!.length > _maxSampleSize) {
      _responseTimesMs[operationType]!.removeAt(0);
    }
    
    // Incrémenter le compteur
    _operationCounts[operationType] = (_operationCounts[operationType] ?? 0) + 1;
    _lastOperationTimes[operationType] = DateTime.now();
    
    notifyListeners();
  }
  
  /// Enregistrer une lecture Firebase
  void recordFirebaseRead() {
    _firebaseReads++;
    recordOperation('firebase_read', 0); // Le temps sera mesuré par l'appelant
  }
  
  /// Enregistrer une écriture Firebase
  void recordFirebaseWrite() {
    _firebaseWrites++;
    recordOperation('firebase_write', 0);
  }
  
  /// Enregistrer un cache hit
  void recordCacheHit(String cacheLevel) {
    _cacheHits++;
    recordOperation('cache_hit_$cacheLevel', 0);
  }
  
  /// Enregistrer un cache miss
  void recordCacheMiss() {
    _cacheMisses++;
    recordOperation('cache_miss', 0);
  }
  
  /// Enregistrer un rebuild UI
  void recordUIRebuild(String componentName) {
    _uiRebuilds++;
    recordOperation('ui_rebuild_$componentName', 0);
  }
  
  /// Enregistrer un appel debounced
  void recordDebouncedCall(String operationType) {
    _debouncedCalls++;
    recordOperation('debounced_$operationType', 0);
  }
  
  /// Mesurer et enregistrer une opération async
  Future<T> measureOperation<T>(
    String operationType,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      recordOperation(operationType, stopwatch.elapsedMilliseconds.toDouble());
      return result;
    } catch (e) {
      stopwatch.stop();
      recordOperation('${operationType}_error', stopwatch.elapsedMilliseconds.toDouble());
      rethrow;
    }
  }
  
  /// Mesurer et enregistrer une opération synchrone
  T measureSync<T>(
    String operationType,
    T Function() operation,
  ) {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = operation();
      stopwatch.stop();
      recordOperation(operationType, stopwatch.elapsedMicroseconds / 1000.0);
      return result;
    } catch (e) {
      stopwatch.stop();
      recordOperation('${operationType}_error', stopwatch.elapsedMicroseconds / 1000.0);
      rethrow;
    }
  }
  
  /// Calculer les statistiques pour un type d'opération
  Map<String, double> _calculateStats(List<double> values) {
    if (values.isEmpty) {
      return {
        'min': 0.0,
        'max': 0.0,
        'avg': 0.0,
        'p50': 0.0,
        'p95': 0.0,
        'p99': 0.0,
      };
    }
    
    final sorted = List<double>.from(values)..sort();
    final length = sorted.length;
    
    return {
      'min': sorted.first,
      'max': sorted.last,
      'avg': sorted.reduce((a, b) => a + b) / length,
      'p50': sorted[(length * 0.5).floor()],
      'p95': sorted[(length * 0.95).floor()],
      'p99': sorted[(length * 0.99).floor()],
    };
  }
  
  /// Obtenir le rapport de performance complet
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    // Statistiques par opération
    final operationStats = <String, dynamic>{};
    _responseTimesMs.forEach((operation, times) {
      operationStats[operation] = {
        'stats': _calculateStats(times),
        'count': _operationCounts[operation] ?? 0,
        'last_operation': _lastOperationTimes[operation]?.toIso8601String(),
      };
    });
    
    // Statistiques Firebase
    final firebaseStats = {
      'reads': _firebaseReads,
      'writes': _firebaseWrites,
      'total_operations': _firebaseReads + _firebaseWrites,
    };
    
    // Statistiques Cache
    final totalCacheOps = _cacheHits + _cacheMisses;
    final cacheStats = {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hit_ratio': totalCacheOps > 0 ? (_cacheHits / totalCacheOps * 100).toStringAsFixed(1) + '%' : '0%',
      'total_operations': totalCacheOps,
    };
    
    // Statistiques UI
    final uiStats = {
      'rebuilds': _uiRebuilds,
      'debounced_calls': _debouncedCalls,
      'average_frame_time_ms': _averageFrameTime,
      'estimated_fps': (1000 / _averageFrameTime).round(),
    };
    
    // Statistiques des services
    final serviceStats = {
      'multi_level_cache': MultiLevelCacheService().getPerformanceStats(),
      'legacy_cache': LapStatisticsService.getCacheStats(),
      'debouncing': DebouncingService.getStats(),
    };
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'operations': operationStats,
      'firebase': firebaseStats,
      'cache': cacheStats,
      'ui': uiStats,
      'services': serviceStats,
      'summary': _generateSummary(),
    };
  }
  
  /// Générer un résumé des performances
  Map<String, dynamic> _generateSummary() {
    final totalOps = _operationCounts.values.fold(0, (sum, count) => sum + count);
    final avgResponseTime = _responseTimesMs.values
        .expand((times) => times)
        .fold(0.0, (sum, time) => sum + time) / 
        max(1, _responseTimesMs.values.expand((times) => times).length);
    
    final cacheHitRatio = _cacheHits + _cacheMisses > 0 
        ? _cacheHits / (_cacheHits + _cacheMisses) * 100
        : 0.0;
    
    return {
      'total_operations': totalOps,
      'average_response_time_ms': avgResponseTime.toStringAsFixed(2),
      'cache_hit_ratio': '${cacheHitRatio.toStringAsFixed(1)}%',
      'firebase_operations': _firebaseReads + _firebaseWrites,
      'ui_rebuilds': _uiRebuilds,
      'performance_grade': _calculatePerformanceGrade(),
    };
  }
  
  /// Calculer une note de performance
  String _calculatePerformanceGrade() {
    double score = 100.0;
    
    // Pénaliser les temps de réponse élevés
    final avgResponseTime = _responseTimesMs.values
        .expand((times) => times)
        .fold(0.0, (sum, time) => sum + time) / 
        max(1, _responseTimesMs.values.expand((times) => times).length);
    
    if (avgResponseTime > 500) score -= 30; // Très lent
    else if (avgResponseTime > 200) score -= 20; // Lent
    else if (avgResponseTime > 100) score -= 10; // Moyen
    
    // Récompenser un bon cache hit ratio
    final cacheHitRatio = _cacheHits + _cacheMisses > 0 
        ? _cacheHits / (_cacheHits + _cacheMisses) * 100
        : 0.0;
    
    if (cacheHitRatio > 80) score += 10; // Excellent cache
    else if (cacheHitRatio < 50) score -= 15; // Cache inefficace
    
    // Pénaliser trop de rebuilds UI
    if (_uiRebuilds > 1000) score -= 20;
    else if (_uiRebuilds > 500) score -= 10;
    
    if (score >= 90) return 'A+ (Excellent)';
    if (score >= 80) return 'A (Très bon)';
    if (score >= 70) return 'B (Bon)';
    if (score >= 60) return 'C (Moyen)';
    return 'D (À améliorer)';
  }
  
  
  /// Réinitialiser toutes les métriques
  void resetMetrics() {
    _responseTimesMs.clear();
    _operationCounts.clear();
    _lastOperationTimes.clear();
    _firebaseReads = 0;
    _firebaseWrites = 0;
    _cacheMisses = 0;
    _cacheHits = 0;
    _uiRebuilds = 0;
    _debouncedCalls = 0;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _periodicReportTimer?.cancel();
    super.dispose();
  }
}
