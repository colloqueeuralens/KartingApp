import '../models/lap_statistics_models.dart';
import '../models/live_timing_models.dart';
import 'live_timing_storage_service.dart';
import 'cache_service.dart';

/// Service pour calculer les statistiques des 10 derniers tours avec cache intelligent
class LapStatisticsService {
  static final CacheService _cache = CacheService();
  
  // TTL plus court pour données live timing (30s)
  static const Duration _liveTTL = Duration(seconds: 30);
  
  /// Obtenir les statistiques des 10 derniers tours pour un kart (avec cache intelligent)
  static Future<Last10LapsStats> getLast10LapsStats(String kartId) async {
    final cacheKey = 'stats_$kartId';
    
    // 🚀 OPTIMISATION: Essayer le cache en premier (cache-aside pattern)
    return await _cache.getOrSet(
      cacheKey,
      () => _calculateStatsFromFirebase(kartId),
      ttl: _liveTTL,
    );
  }
  
  /// Calculer les statistiques depuis Firebase (logique originale préservée)
  static Future<Last10LapsStats> _calculateStatsFromFirebase(String kartId) async {
    try {
      // 📊 LOGIQUE ORIGINALE: Récupérer tous les tours du kart depuis le service de stockage
      final allLaps = await LiveTimingStorageService.getKartLaps(kartId);
      
      if (allLaps.isEmpty) {
        return Last10LapsStats.empty();
      }
      
      // Filtrer les tours valides (temps de tour non vide et non placeholder)
      final validLaps = allLaps.where((lap) => isValidLapTime(lap.lapTime)).toList();
      
      if (validLaps.isEmpty) {
        // Pas de tours valides
        return Last10LapsStats.empty();
      }
      
      // Trier par numéro de tour décroissant pour avoir les plus récents en premier
      validLaps.sort((a, b) => b.lapNumber.compareTo(a.lapNumber));
      
      // Prendre les 10 derniers tours (ou moins si pas assez)
      final last10Laps = validLaps.take(10).toList();
      
      // Calculer les statistiques
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
      // En cas d'erreur, retourner des statistiques vides
      return Last10LapsStats.empty();
    }
  }
  
  /// Invalider le cache pour un kart spécifique (lors de nouveaux tours)
  static void invalidateKartCache(String kartId) {
    _cache.invalidate('stats_$kartId');
  }
  
  /// Invalider tout le cache des statistiques
  static void invalidateAllStats() {
    _cache.invalidatePrefix('stats_');
  }
  
  /// Obtenir des statistiques du cache pour monitoring
  static Map<String, dynamic> getCacheStats() {
    final stats = _cache.getStats();
    return {
      'total_entries': stats.totalEntries,
      'valid_entries': stats.validEntries,
      'hit_ratio': (stats.hitRatio * 100).toStringAsFixed(1) + '%',
      'expired_entries': stats.expiredEntries,
    };
  }
  
  /// Vérifier si un temps de tour est valide (rendu public pour enhanced service)
  static bool isValidLapTime(String lapTime) {
    if (lapTime.isEmpty) return false;
    if (lapTime == '--:--' || lapTime == '0:00.000' || lapTime == 'null') return false;
    if (lapTime.contains('--')) return false;
    
    // Vérifier le format basique (doit contenir des chiffres)
    return RegExp(r'\d').hasMatch(lapTime);
  }
  
  /// Calculer le temps moyen des tours
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
  
  /// Trouver le meilleur temps
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
  
  /// Trouver le pire temps
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
  
  /// Parser un temps de tour vers Duration
  static Duration _parseLapTime(String lapTime) {
    if (lapTime.isEmpty || lapTime == '--:--' || lapTime == '0:00.000') {
      return Duration.zero;
    }

    try {
      final parts = lapTime.split(':');
      if (parts.length == 2) {
        // Format "1:23.456"
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      } else {
        // Format "23.456" (secondes seulement)
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
  
  /// Formater une Duration vers String
  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }
}