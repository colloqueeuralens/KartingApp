import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service de debouncing pour optimiser les performances et réduire les appels API
class DebouncingService {
  static final Map<String, Timer> _timers = {};
  static final Map<String, dynamic> _lastResults = {};
  
  /// Debounce une fonction avec une clé unique
  static void debounce(
    String key,
    Duration delay,
    VoidCallback callback,
  ) {
    // Annuler le timer précédent s'il existe
    _timers[key]?.cancel();
    
    // Créer un nouveau timer
    _timers[key] = Timer(delay, () {
      callback();
      _timers.remove(key);
    });
  }
  
  /// Debounce une fonction Future avec cache du résultat
  static void debounceAsync<T>(
    String key,
    Duration delay,
    Future<T> Function() asyncCallback,
    Function(T) onResult, {
    Function(dynamic)? onError,
  }) {
    // Annuler le timer précédent s'il existe
    _timers[key]?.cancel();
    
    // Créer un nouveau timer
    _timers[key] = Timer(delay, () async {
      try {
        final result = await asyncCallback();
        _lastResults[key] = result;
        onResult(result);
      } catch (e) {
        onError?.call(e);
      } finally {
        _timers.remove(key);
      }
    });
  }
  
  /// Obtenir le dernier résultat en cache pour une clé
  static T? getLastResult<T>(String key) {
    return _lastResults[key] as T?;
  }
  
  /// Annuler un debounce en cours
  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }
  
  /// Annuler tous les debounces
  static void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
  
  /// Vérifier si un debounce est en cours
  static bool isActive(String key) {
    return _timers.containsKey(key);
  }
  
  /// Nettoyer les résultats en cache
  static void clearResults() {
    _lastResults.clear();
  }
  
  /// Obtenir les statistiques du debouncing
  static Map<String, dynamic> getStats() {
    return {
      'active_timers': _timers.length,
      'cached_results': _lastResults.length,
      'active_keys': _timers.keys.toList(),
    };
  }
}

/// Classe pour gérer le debouncing des requêtes Firebase
class FirebaseDebouncer {
  static const Duration _defaultDelay = Duration(milliseconds: 300);
  
  /// Debounce les appels getKartLaps
  static void debounceGetKartLaps(
    String kartId,
    Future<List<dynamic>> Function() fetchFunction,
    Function(List<dynamic>) onResult, {
    Duration? delay,
  }) {
    final key = 'get_kart_laps_$kartId';
    
    DebouncingService.debounceAsync<List<dynamic>>(
      key,
      delay ?? _defaultDelay,
      fetchFunction,
      onResult,
    );
  }
  
  /// Debounce les appels de statistiques
  static void debounceGetStats(
    String kartId,
    Future<dynamic> Function() fetchFunction,
    Function(dynamic) onResult, {
    Duration? delay,
  }) {
    final key = 'get_stats_$kartId';
    
    DebouncingService.debounceAsync<dynamic>(
      key,
      delay ?? _defaultDelay,
      fetchFunction,
      onResult,
    );
  }
  
  /// Debounce les mises à jour UI
  static void debounceUIUpdate(
    String componentId,
    VoidCallback updateCallback, {
    Duration? delay,
  }) {
    final key = 'ui_update_$componentId';
    
    DebouncingService.debounce(
      key,
      delay ?? const Duration(milliseconds: 50),
      updateCallback,
    );
  }
}

/// Mixin pour ajouter facilement le debouncing à un widget
mixin DebouncingMixin {
  /// Debounce une fonction avec une clé basée sur le widget
  void debounce(
    String action,
    Duration delay,
    VoidCallback callback,
  ) {
    final key = '${runtimeType}_$action';
    DebouncingService.debounce(key, delay, callback);
  }
  
  /// Debounce une fonction async
  void debounceAsync<T>(
    String action,
    Duration delay,
    Future<T> Function() asyncCallback,
    Function(T) onResult, {
    Function(dynamic)? onError,
  }) {
    final key = '${runtimeType}_$action';
    DebouncingService.debounceAsync<T>(
      key,
      delay,
      asyncCallback,
      onResult,
      onError: onError,
    );
  }
  
  /// Annuler tous les debounces de ce widget
  void cancelAllDebounces() {
    final prefix = runtimeType.toString();
    final activeKeys = DebouncingService.getStats()['active_keys'] as List<String>;
    
    for (final key in activeKeys) {
      if (key.startsWith(prefix)) {
        DebouncingService.cancel(key);
      }
    }
  }
}