import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'cache_service.dart';

/// Service de cache à plusieurs niveaux pour optimisation ultime des performances
/// Niveau 1: Cache mémoire (ultra-rapide, TTL court)
/// Niveau 2: Cache local Hive (rapide, TTL moyen, survit aux restarts)
/// Niveau 3: Cache SharedPreferences (persistant, TTL long, backup)
class MultiLevelCacheService {
  static final MultiLevelCacheService _instance = MultiLevelCacheService._internal();
  factory MultiLevelCacheService() => _instance;
  MultiLevelCacheService._internal();

  // Services de cache par niveau
  final CacheService _memoryCache = CacheService();
  Box<String>? _hiveCache;
  SharedPreferences? _prefsCache;
  
  // Configuration TTL par niveau
  static const Duration _memoryTTL = Duration(seconds: 30);     // Niveau 1: 30s
  static const Duration _hiveTTL = Duration(minutes: 5);        // Niveau 2: 5min
  static const Duration _prefsTTL = Duration(hours: 1);         // Niveau 3: 1h
  
  // État d'initialisation
  bool _isInitialized = false;
  
  /// Initialiser tous les niveaux de cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialiser Hive pour cache niveau 2
      await Hive.initFlutter();
      _hiveCache = await Hive.openBox<String>('karting_cache_l2');
      
      // Initialiser SharedPreferences pour cache niveau 3
      _prefsCache = await SharedPreferences.getInstance();
      
      _isInitialized = true;
      
      // Nettoyage périodique des caches
      _startPeriodicCleanup();
      
    } catch (e) {
      // En cas d'erreur, continuer avec cache mémoire seulement
      _isInitialized = true;
    }
  }
  
  /// Obtenir une valeur en cascade (L1 → L2 → L3 → null)
  Future<T?> get<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    await _ensureInitialized();
    
    // 🚀 NIVEAU 1: Cache mémoire (ultra-rapide)
    final memoryValue = _memoryCache.get<T>(key);
    if (memoryValue != null) {
      _recordHit('L1');
      return memoryValue;
    }
    
    // 🔥 NIVEAU 2: Cache Hive (rapide, persistant)
    final hiveValue = await _getFromHive<T>(key, fromJson);
    if (hiveValue != null) {
      // Remonter vers cache mémoire pour accès futurs
      _memoryCache.set(key, hiveValue, ttl: _memoryTTL);
      _recordHit('L2');
      return hiveValue;
    }
    
    // 💾 NIVEAU 3: Cache SharedPreferences (backup persistant)
    final prefsValue = await _getFromPrefs<T>(key, fromJson);
    if (prefsValue != null) {
      // Remonter vers cache Hive et mémoire
      _memoryCache.set(key, prefsValue, ttl: _memoryTTL);
      await _setToHive(key, prefsValue);
      _recordHit('L3');
      return prefsValue;
    }
    
    _recordMiss();
    return null;
  }
  
  /// Stocker une valeur dans tous les niveaux appropriés
  Future<void> set<T>(
    String key, 
    T value, 
    Map<String, dynamic> Function(T) toJson, {
    CacheLevel? maxLevel,
  }) async {
    await _ensureInitialized();
    final effectiveMaxLevel = maxLevel ?? CacheLevel.all;
    
    // Niveau 1: Toujours stocker en mémoire
    _memoryCache.set(key, value, ttl: _memoryTTL);
    
    // Niveau 2: Stocker dans Hive si autorisé
    if (effectiveMaxLevel.index >= CacheLevel.hive.index) {
      await _setToHive(key, value, toJson: toJson);
    }
    
    // Niveau 3: Stocker dans SharedPreferences si autorisé
    if (effectiveMaxLevel.index >= CacheLevel.all.index) {
      await _setToPrefs(key, value, toJson: toJson);
    }
  }
  
  /// Invalider une clé dans tous les niveaux
  Future<void> invalidate(String key) async {
    await _ensureInitialized();
    
    // Invalider dans tous les niveaux
    _memoryCache.invalidate(key);
    await _hiveCache?.delete(key);
    await _prefsCache?.remove(key);
  }
  
  /// Invalider par préfixe dans tous les niveaux
  Future<void> invalidatePrefix(String prefix) async {
    await _ensureInitialized();
    
    // Niveau 1: Cache mémoire
    _memoryCache.invalidatePrefix(prefix);
    
    // Niveau 2: Cache Hive
    if (_hiveCache != null) {
      final keysToDelete = _hiveCache!.keys
          .where((key) => key.toString().startsWith(prefix))
          .toList();
      for (final key in keysToDelete) {
        await _hiveCache!.delete(key);
      }
    }
    
    // Niveau 3: SharedPreferences
    if (_prefsCache != null) {
      final keys = _prefsCache!.getKeys();
      final keysToRemove = keys.where((key) => key.startsWith(prefix)).toList();
      for (final key in keysToRemove) {
        await _prefsCache!.remove(key);
      }
    }
  }
  
  /// Obtenir depuis cache Hive avec vérification TTL
  Future<T?> _getFromHive<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    if (_hiveCache == null) return null;
    
    try {
      final jsonString = _hiveCache!.get(key);
      if (jsonString == null) return null;
      
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(data['expiresAt']);
      
      // Vérifier expiration
      if (DateTime.now().isAfter(expiresAt)) {
        await _hiveCache!.delete(key);
        return null;
      }
      
      return fromJson(data['value']);
    } catch (e) {
      // En cas d'erreur, supprimer l'entrée corrompue
      await _hiveCache!.delete(key);
      return null;
    }
  }
  
  /// Stocker dans cache Hive avec TTL
  Future<void> _setToHive<T>(String key, T value, {Map<String, dynamic> Function(T)? toJson}) async {
    if (_hiveCache == null) return;
    
    try {
      final expiresAt = DateTime.now().add(_hiveTTL);
      final data = {
        'value': toJson?.call(value) ?? value,
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      await _hiveCache!.put(key, json.encode(data));
    } catch (e) {
      // Échec silencieux pour ne pas planter l'app
    }
  }
  
  /// Obtenir depuis SharedPreferences avec vérification TTL
  Future<T?> _getFromPrefs<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    if (_prefsCache == null) return null;
    
    try {
      final jsonString = _prefsCache!.getString(key);
      if (jsonString == null) return null;
      
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(data['expiresAt']);
      
      // Vérifier expiration
      if (DateTime.now().isAfter(expiresAt)) {
        await _prefsCache!.remove(key);
        return null;
      }
      
      return fromJson(data['value']);
    } catch (e) {
      // En cas d'erreur, supprimer l'entrée corrompue
      await _prefsCache!.remove(key);
      return null;
    }
  }
  
  /// Stocker dans SharedPreferences avec TTL
  Future<void> _setToPrefs<T>(String key, T value, {Map<String, dynamic> Function(T)? toJson}) async {
    if (_prefsCache == null) return;
    
    try {
      final expiresAt = DateTime.now().add(_prefsTTL);
      final data = {
        'value': toJson?.call(value) ?? value,
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      await _prefsCache!.setString(key, json.encode(data));
    } catch (e) {
      // Échec silencieux pour ne pas planter l'app
    }
  }
  
  /// Nettoyage périodique des caches expirés
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 10), (timer) {
      _cleanupExpiredEntries();
    });
  }
  
  /// Nettoyer les entrées expirées de tous les niveaux
  Future<void> _cleanupExpiredEntries() async {
    try {
      // Niveau 1: Cache mémoire
      _memoryCache.cleanup();
      
      // Niveau 2: Cache Hive
      if (_hiveCache != null) {
        final now = DateTime.now();
        final keysToDelete = <dynamic>[];
        
        for (final key in _hiveCache!.keys) {
          try {
            final jsonString = _hiveCache!.get(key);
            if (jsonString != null) {
              final data = json.decode(jsonString) as Map<String, dynamic>;
              final expiresAt = DateTime.parse(data['expiresAt']);
              if (now.isAfter(expiresAt)) {
                keysToDelete.add(key);
              }
            }
          } catch (e) {
            keysToDelete.add(key);
          }
        }
        
        for (final key in keysToDelete) {
          await _hiveCache!.delete(key);
        }
      }
      
      // Niveau 3: SharedPreferences (nettoyage similaire si nécessaire)
      // Note: Pas de nettoyage automatique pour éviter la surcharge
      
    } catch (e) {
      // Échec silencieux du nettoyage
    }
  }
  
  /// S'assurer que le service est initialisé
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  // Statistiques de performance (optionnel)
  int _l1Hits = 0, _l2Hits = 0, _l3Hits = 0, _misses = 0;
  
  void _recordHit(String level) {
    switch (level) {
      case 'L1': _l1Hits++; break;
      case 'L2': _l2Hits++; break;
      case 'L3': _l3Hits++; break;
    }
  }
  
  void _recordMiss() => _misses++;
  
  /// Obtenir les statistiques de performance du cache
  Map<String, dynamic> getPerformanceStats() {
    final total = _l1Hits + _l2Hits + _l3Hits + _misses;
    return {
      'l1_hits': _l1Hits,
      'l2_hits': _l2Hits,
      'l3_hits': _l3Hits,
      'misses': _misses,
      'total_requests': total,
      'hit_ratio': total > 0 ? ((_l1Hits + _l2Hits + _l3Hits) / total * 100).toStringAsFixed(1) + '%' : '0%',
      'l1_ratio': total > 0 ? (_l1Hits / total * 100).toStringAsFixed(1) + '%' : '0%',
    };
  }
  
  /// Nettoyer tous les caches
  Future<void> clearAll() async {
    await _ensureInitialized();
    
    _memoryCache.clear();
    await _hiveCache?.clear();
    
    if (_prefsCache != null) {
      final keys = _prefsCache!.getKeys().where((key) => key.startsWith('karting_')).toList();
      for (final key in keys) {
        await _prefsCache!.remove(key);
      }
    }
  }
}

/// Énumération des niveaux de cache
enum CacheLevel {
  memory,  // Niveau 1: Mémoire seulement
  hive,    // Niveau 2: Mémoire + Hive
  all,     // Niveau 3: Tous les niveaux
}