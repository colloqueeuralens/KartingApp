import '../models/lap_statistics_models.dart';
import '../models/live_timing_models.dart';
import 'live_timing_storage_service.dart';
import 'multi_level_cache_service.dart';
import 'lap_statistics_service.dart';

/// Service de statistiques optimisé avec cache multi-niveaux
/// Remplace progressivement LapStatisticsService avec de meilleures performances
class EnhancedLapStatisticsService {
  static final MultiLevelCacheService _multiCache = MultiLevelCacheService();
  static bool _isInitialized = false;
  
  /// Initialiser le service avec cache multi-niveaux
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _multiCache.initialize();
    _isInitialized = true;
  }
  
  /// Obtenir les statistiques avec cache multi-niveaux ultra-optimisé
  static Future<Last10LapsStats> getLast10LapsStats(String kartId) async {
    await _ensureInitialized();
    
    final cacheKey = 'enhanced_stats_$kartId';
    
    // 🚀 CACHE MULTI-NIVEAUX: Essayer L1 → L2 → L3 → Firebase
    final cachedStats = await _multiCache.get<Last10LapsStats>(
      cacheKey,
      (json) => Last10LapsStats.fromJson(json),
    );
    
    if (cachedStats != null) {
      return cachedStats;
    }
    
    // Cache miss: calculer depuis Firebase et stocker dans tous les niveaux
    final stats = await _calculateStatsFromFirebase(kartId);
    
    // Stocker dans cache multi-niveaux avec stratégie intelligente
    await _multiCache.set(
      cacheKey,
      stats,
      (stats) => stats.toJson(),
      maxLevel: CacheLevel.all, // Stocker dans tous les niveaux
    );
    
    return stats;
  }
  
  /// Obtenir les statistiques avec cache adaptatif selon la fréquence d'accès
  static Future<Last10LapsStats> getLast10LapsStatsAdaptive(String kartId) async {
    await _ensureInitialized();
    
    // 🧠 CACHE ADAPTATIF: Détermine le niveau de cache selon la popularité du kart
    final accessFrequency = await _getKartAccessFrequency(kartId);
    final cacheLevel = _determineCacheLevel(accessFrequency);
    
    final cacheKey = 'adaptive_stats_$kartId';
    
    final cachedStats = await _multiCache.get<Last10LapsStats>(
      cacheKey,
      (json) => Last10LapsStats.fromJson(json),
    );
    
    if (cachedStats != null) {
      // Incrémenter la fréquence d'accès
      await _incrementAccessFrequency(kartId);
      return cachedStats;
    }
    
    // Calculer et stocker avec niveau adaptatif
    final stats = await _calculateStatsFromFirebase(kartId);
    await _multiCache.set(
      cacheKey,
      stats,
      (stats) => stats.toJson(),
      maxLevel: cacheLevel,
    );
    
    await _incrementAccessFrequency(kartId);
    return stats;
  }
  
  /// Calculer les statistiques depuis Firebase (logique héritée et optimisée)
  static Future<Last10LapsStats> _calculateStatsFromFirebase(String kartId) async {
    try {
      final allLaps = await LiveTimingStorageService.getKartLaps(kartId, limit: 15);
      
      if (allLaps.isEmpty) {
        return Last10LapsStats.empty();
      }
      
      final validLaps = allLaps.where((lap) {
        return LapStatisticsService.isValidLapTime(lap.lapTime);
      }).toList();
      
      if (validLaps.isEmpty) {
        return Last10LapsStats.empty();
      }
      
      // Exiger au moins 10 tours pour afficher des statistiques
      if (validLaps.length < 10) {
        return Last10LapsStats.insufficientData(validLaps.length);
      }
      
      // Trier par numéro de tour décroissant pour avoir les plus récents en premier
      validLaps.sort((a, b) => b.lapNumber.compareTo(a.lapNumber));
      
      // Prendre les 10 derniers tours
      final last10Laps = validLaps.take(10).toList();
      
      // Calculer les statistiques (utilise les méthodes héritées)
      final average = _calculateAverageTime(last10Laps);
      final best = _findBestTime(last10Laps);
      final worst = _findWorstTime(last10Laps);
      
      return Last10LapsStats.withData(
        averageTime: average,
        bestTime: best,
        worstTime: worst,
        validLapsCount: last10Laps.length,
      );
      
    } catch (e) {
      return Last10LapsStats.empty();
    }
  }
  
  /// Pré-charger les statistiques des karts populaires en arrière-plan
  static Future<void> preloadPopularKarts(List<String> kartIds) async {
    await _ensureInitialized();
    
    // 🚀 PRÉ-CHARGEMENT: Charger en parallèle avec limite de concurrence
    final futures = <Future>[];
    
    for (int i = 0; i < kartIds.length; i += 3) { // Traiter par batch de 3
      final batch = kartIds.skip(i).take(3);
      
      for (final kartId in batch) {
        futures.add(_preloadSingleKart(kartId));
      }
      
      // Attendre le batch avant de continuer
      await Future.wait(futures);
      futures.clear();
      
      // Pause entre les batches pour éviter la surcharge
      if (i + 3 < kartIds.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }
  
  /// Pré-charger un seul kart
  static Future<void> _preloadSingleKart(String kartId) async {
    try {
      await getLast10LapsStats(kartId); // Utilise le cache automatiquement
    } catch (e) {
      // Échec silencieux pour le pré-chargement
    }
  }
  
  /// Invalider le cache pour un kart spécifique
  static Future<void> invalidateKartCache(String kartId) async {
    await _ensureInitialized();
    
    await _multiCache.invalidate('enhanced_stats_$kartId');
    await _multiCache.invalidate('adaptive_stats_$kartId');
    
    // Aussi invalider l'ancien cache pour compatibilité
    LapStatisticsService.invalidateKartCache(kartId);
  }
  
  /// Invalider tout le cache des statistiques
  static Future<void> invalidateAllStats() async {
    await _ensureInitialized();
    
    await _multiCache.invalidatePrefix('enhanced_stats_');
    await _multiCache.invalidatePrefix('adaptive_stats_');
    
    // Aussi invalider l'ancien cache
    LapStatisticsService.invalidateAllStats();
  }
  
  /// Obtenir la fréquence d'accès d'un kart
  static Future<int> _getKartAccessFrequency(String kartId) async {
    final cacheKey = 'access_freq_$kartId';
    
    final frequency = await _multiCache.get<int>(
      cacheKey,
      (json) => json['value'] as int,
    );
    
    return frequency ?? 0;
  }
  
  /// Incrémenter la fréquence d'accès
  static Future<void> _incrementAccessFrequency(String kartId) async {
    final currentFreq = await _getKartAccessFrequency(kartId);
    final newFreq = currentFreq + 1;
    
    await _multiCache.set(
      'access_freq_$kartId',
      newFreq,
      (freq) => {'value': freq},
      maxLevel: CacheLevel.hive, // Stocker la fréquence dans Hive seulement
    );
  }
  
  /// Déterminer le niveau de cache selon la fréquence d'accès
  static CacheLevel _determineCacheLevel(int accessFrequency) {
    if (accessFrequency >= 10) {
      return CacheLevel.all;     // Très populaire: tous les niveaux
    } else if (accessFrequency >= 3) {
      return CacheLevel.hive;    // Moyennement populaire: mémoire + Hive
    } else {
      return CacheLevel.memory;  // Peu populaire: mémoire seulement
    }
  }
  
  /// Obtenir les statistiques de performance complètes
  static Future<Map<String, dynamic>> getPerformanceStats() async {
    await _ensureInitialized();
    
    final multiCacheStats = _multiCache.getPerformanceStats();
    final legacyCacheStats = LapStatisticsService.getCacheStats();
    
    return {
      'multi_level_cache': multiCacheStats,
      'legacy_cache': legacyCacheStats,
      'initialization_status': _isInitialized,
    };
  }
  
  /// S'assurer que le service est initialisé
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
  
  // Méthodes de calcul héritées (optimisées)
  static String _calculateAverageTime(List<LiveLapData> laps) {
    if (laps.isEmpty) return '--:--';
    
    try {
      Duration totalDuration = Duration.zero;
      
      for (final lap in laps) {
        totalDuration += _parseLapTime(lap.lapTime);
      }
      
      final avgDuration = Duration(
        milliseconds: totalDuration.inMilliseconds ~/ laps.length,
      );
      
      return _formatDuration(avgDuration);
    } catch (e) {
      return '--:--';
    }
  }
  
  static String _findBestTime(List<LiveLapData> laps) {
    if (laps.isEmpty) return '--:--';
    
    LiveLapData? bestLap;
    Duration? bestDuration;
    
    try {
      for (final lap in laps) {
        final duration = _parseLapTime(lap.lapTime);
        if (bestDuration == null || duration < bestDuration) {
          bestDuration = duration;
          bestLap = lap;
        }
      }
      
      return bestLap?.lapTime ?? '--:--';
    } catch (e) {
      return '--:--';
    }
  }
  
  static String _findWorstTime(List<LiveLapData> laps) {
    if (laps.isEmpty) return '--:--';
    
    LiveLapData? worstLap;
    Duration? worstDuration;
    
    try {
      for (final lap in laps) {
        final duration = _parseLapTime(lap.lapTime);
        if (worstDuration == null || duration > worstDuration) {
          worstDuration = duration;
          worstLap = lap;
        }
      }
      
      return worstLap?.lapTime ?? '--:--';
    } catch (e) {
      return '--:--';
    }
  }
  
  static Duration _parseLapTime(String lapTime) {
    if (lapTime.isEmpty || lapTime == '--:--' || lapTime == '0:00.000') {
      return Duration.zero;
    }

    try {
      final parts = lapTime.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      } else {
        final secondsParts = lapTime.split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(seconds: seconds, milliseconds: milliseconds);
      }
    } catch (e) {
      return Duration.zero;
    }
  }
  
  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }
}