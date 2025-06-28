import 'dart:async';

/// Service de cache intelligent générique avec TTL et invalidation
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache en mémoire avec metadata
  final Map<String, CacheEntry> _cache = {};
  
  // TTL par défaut : 30 secondes pour données live
  static const Duration _defaultTTL = Duration(seconds: 30);
  
  /// Obtenir une valeur du cache
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    // Vérifier si l'entrée est expirée
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    
    // Mettre à jour le dernier accès
    entry.lastAccessed = DateTime.now();
    return entry.value as T;
  }
  
  /// Stocker une valeur dans le cache
  void set<T>(String key, T value, {Duration? ttl}) {
    final effectiveTTL = ttl ?? _defaultTTL;
    final expiresAt = DateTime.now().add(effectiveTTL);
    
    _cache[key] = CacheEntry(
      value: value,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      lastAccessed: DateTime.now(),
    );
  }
  
  /// Vérifier si une clé existe et est valide
  bool has(String key) {
    return get(key) != null;
  }
  
  /// Invalider une clé spécifique
  void invalidate(String key) {
    _cache.remove(key);
  }
  
  /// Invalider toutes les clés qui commencent par un préfixe
  void invalidatePrefix(String prefix) {
    final keysToRemove = _cache.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }
  
  /// Nettoyer les entrées expirées
  void cleanup() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((entry) => now.isAfter(entry.value.expiresAt))
        .map((entry) => entry.key)
        .toList();
        
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }
  
  /// Vider complètement le cache
  void clear() {
    _cache.clear();
  }
  
  /// Obtenir des statistiques du cache
  CacheStats getStats() {
    final now = DateTime.now();
    final validEntries = _cache.values.where((entry) => now.isBefore(entry.expiresAt));
    
    return CacheStats(
      totalEntries: _cache.length,
      validEntries: validEntries.length,
      expiredEntries: _cache.length - validEntries.length,
    );
  }
  
  /// Méthode get-or-set pour lazy loading
  Future<T> getOrSet<T>(
    String key, 
    Future<T> Function() factory, {
    Duration? ttl,
  }) async {
    // Essayer de récupérer du cache d'abord
    final cached = get<T>(key);
    if (cached != null) {
      return cached;
    }
    
    // Si pas en cache, calculer et stocker
    final value = await factory();
    set(key, value, ttl: ttl);
    return value;
  }
}

/// Entrée de cache avec métadonnées
class CacheEntry {
  final dynamic value;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime lastAccessed;
  
  CacheEntry({
    required this.value,
    required this.createdAt,
    required this.expiresAt,
    required this.lastAccessed,
  });
}

/// Statistiques du cache
class CacheStats {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  
  const CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });
  
  double get hitRatio => totalEntries > 0 ? validEntries / totalEntries : 0.0;
}