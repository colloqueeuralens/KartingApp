/// Modèle pour les statistiques des 10 derniers tours d'un kart
class Last10LapsStats {
  final String averageTime;    // "1:23.456" ou "--:--"
  final String bestTime;       // "1:20.123" ou "--:--"
  final String worstTime;      // "1:25.789" ou "--:--"
  final bool hasValidData;     // true si au moins 1 tour valide
  final int validLapsCount;    // Nombre de tours valides utilisés (sur 10 max)

  const Last10LapsStats({
    required this.averageTime,
    required this.bestTime,
    required this.worstTime,
    required this.hasValidData,
    required this.validLapsCount,
  });

  /// Statistiques vides quand pas de données
  factory Last10LapsStats.empty() {
    return const Last10LapsStats(
      averageTime: '--:--',
      bestTime: '--:--',
      worstTime: '--:--',
      hasValidData: false,
      validLapsCount: 0,
    );
  }

  /// Constructeur pour données insuffisantes (moins de 10 tours)
  factory Last10LapsStats.insufficientData(int actualCount) {
    return Last10LapsStats(
      averageTime: 'Manque de données',
      bestTime: 'Manque de données',
      worstTime: 'Manque de données',
      hasValidData: false,
      validLapsCount: actualCount,
    );
  }

  /// Statistiques avec données valides
  factory Last10LapsStats.withData({
    required String averageTime,
    required String bestTime,
    required String worstTime,
    required int validLapsCount,
  }) {
    return Last10LapsStats(
      averageTime: averageTime,
      bestTime: bestTime,
      worstTime: worstTime,
      hasValidData: validLapsCount >= 1, // Au moins 1 tour pour être significatif
      validLapsCount: validLapsCount,
    );
  }

  /// Sérialisation pour cache multi-niveaux
  Map<String, dynamic> toJson() {
    return {
      'averageTime': averageTime,
      'bestTime': bestTime,
      'worstTime': worstTime,
      'hasValidData': hasValidData,
      'validLapsCount': validLapsCount,
    };
  }

  /// Désérialisation depuis cache multi-niveaux
  factory Last10LapsStats.fromJson(Map<String, dynamic> json) {
    return Last10LapsStats(
      averageTime: json['averageTime'] as String,
      bestTime: json['bestTime'] as String,
      worstTime: json['worstTime'] as String,
      hasValidData: json['hasValidData'] as bool,
      validLapsCount: json['validLapsCount'] as int,
    );
  }
}