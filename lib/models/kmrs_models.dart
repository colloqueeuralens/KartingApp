import 'package:flutter/foundation.dart';

/// Modèles de données pour reproduire KMRS.xlsm
/// Remplace strategy_models.dart avec des structures spécifiques KMRS

/// Session de course complète
class RaceSession {
  final String id;
  final String sessionName;
  final DateTime createdAt;
  final DateTime? startTime;
  final Duration? totalDuration;
  final String circuitName;
  final List<PilotData> pilots;
  final List<StintData> stints;
  final RaceConfiguration configuration;
  final Map<String, dynamic> calculations;
  
  RaceSession({
    required this.id,
    required this.sessionName,
    required this.createdAt,
    this.startTime,
    this.totalDuration,
    required this.circuitName,
    required this.pilots,
    required this.stints,
    required this.configuration,
    required this.calculations,
  });

  factory RaceSession.empty() {
    return RaceSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionName: 'Nouvelle Session',
      createdAt: DateTime.now(),
      circuitName: '',
      pilots: [],
      stints: [],
      configuration: RaceConfiguration.defaultConfig(),
      calculations: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionName': sessionName,
      'createdAt': createdAt.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'totalDuration': totalDuration?.inSeconds,
      'circuitName': circuitName,
      'pilots': pilots.map((p) => p.toMap()).toList(),
      'stints': stints.map((s) => s.toMap()).toList(),
      'configuration': configuration.toMap(),
      'calculations': calculations,
    };
  }

  factory RaceSession.fromMap(Map<String, dynamic> map) {
    return RaceSession(
      id: map['id'] ?? '',
      sessionName: map['sessionName'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      totalDuration: map['totalDuration'] != null ? Duration(seconds: map['totalDuration']) : null,
      circuitName: map['circuitName'] ?? '',
      pilots: (map['pilots'] as List<dynamic>?)?.map((p) => PilotData.fromMap(p)).toList() ?? [],
      stints: (map['stints'] as List<dynamic>?)?.map((s) => StintData.fromMap(s)).toList() ?? [],
      configuration: RaceConfiguration.fromMap(map['configuration'] ?? {}),
      calculations: Map<String, dynamic>.from(map['calculations'] ?? {}),
    );
  }
}

/// Configuration de course KMRS (Start Page - 14 inputs exacts)
class RaceConfiguration {
  // Les 9 vrais inputs KMRS principaux selon le fichier Strategie.txt
  final double raceDurationHours;                    // Race Duration (Hours)
  final int minStintTimeMinutes;                     // Minimum Stint Time (Minutes)
  final int maxStintTimeMinutes;                     // Maximum Stint Time (Minutes)
  final int requiredPitstops;                        // Required Pitstops
  final int pitLaneClosedStartMinutes;               // Pit Lane Closed Start of Race (Minutes)
  final int pitLaneClosedEndMinutes;                 // Pit Lane Closed End of Race (Minutes)
  final Duration pitstopFixDuration;                 // Pitstop Fix (mm:ss)
  final int tempsRoulageMinPilote;                   // Temps Roulage Min/Pilote (minutes)
  final int tempsRoulageMaxPilote;                   // Temps Roulage Max/Pilote (minutes)
  
  // 5 inputs complémentaires pour avoir une interface complète
  final String raceType;                             // Type de course
  final String trackName;                            // Nom du circuit
  final int numberOfPilots;                          // Nombre de pilotes
  final Duration averageLapTime;                     // Temps au tour moyen
  final Map<String, dynamic> customSettings;        // Paramètres personnalisés

  RaceConfiguration({
    required this.raceDurationHours,
    required this.minStintTimeMinutes,
    required this.maxStintTimeMinutes,
    required this.requiredPitstops,
    required this.pitLaneClosedStartMinutes,
    required this.pitLaneClosedEndMinutes,
    required this.pitstopFixDuration,
    required this.tempsRoulageMinPilote,
    required this.tempsRoulageMaxPilote,
    required this.raceType,
    required this.trackName,
    required this.numberOfPilots,
    required this.averageLapTime,
    required this.customSettings,
  });

  factory RaceConfiguration.defaultConfig() {
    return RaceConfiguration(
      raceDurationHours: 4.0,                         // 4 heures par défaut (exemple du fichier)
      minStintTimeMinutes: 15,                        // 15 minutes minimum
      maxStintTimeMinutes: 50,                        // 50 minutes maximum
      requiredPitstops: 7,                            // 7 arrêts obligatoires (8 relais total)
      pitLaneClosedStartMinutes: 15,                  // 15 min fermé début
      pitLaneClosedEndMinutes: 15,                    // 15 min fermé fin
      pitstopFixDuration: const Duration(minutes: 2), // 02:00 fixe
      tempsRoulageMinPilote: 120,                     // 120 min minimum par pilote
      tempsRoulageMaxPilote: 240,                     // 240 min maximum par pilote
      raceType: 'Endurance',
      trackName: 'Circuit par défaut',
      numberOfPilots: 4,
      averageLapTime: const Duration(seconds: 90),
      customSettings: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'raceDurationHours': raceDurationHours,
      'minStintTimeMinutes': minStintTimeMinutes,
      'maxStintTimeMinutes': maxStintTimeMinutes,
      'requiredPitstops': requiredPitstops,
      'pitLaneClosedStartMinutes': pitLaneClosedStartMinutes,
      'pitLaneClosedEndMinutes': pitLaneClosedEndMinutes,
      'pitstopFixDuration': pitstopFixDuration.inSeconds,
      'tempsRoulageMinPilote': tempsRoulageMinPilote,
      'tempsRoulageMaxPilote': tempsRoulageMaxPilote,
      'raceType': raceType,
      'trackName': trackName,
      'numberOfPilots': numberOfPilots,
      'averageLapTime': averageLapTime.inSeconds,
      'customSettings': customSettings,
    };
  }

  factory RaceConfiguration.fromMap(Map<String, dynamic> map) {
    return RaceConfiguration(
      raceDurationHours: (map['raceDurationHours'] ?? 4.0).toDouble(),
      minStintTimeMinutes: map['minStintTimeMinutes'] ?? 15,
      maxStintTimeMinutes: map['maxStintTimeMinutes'] ?? 50,
      requiredPitstops: map['requiredPitstops'] ?? 7,
      pitLaneClosedStartMinutes: map['pitLaneClosedStartMinutes'] ?? 15,
      pitLaneClosedEndMinutes: map['pitLaneClosedEndMinutes'] ?? 15,
      pitstopFixDuration: Duration(seconds: map['pitstopFixDuration'] ?? 120),
      tempsRoulageMinPilote: map['tempsRoulageMinPilote'] ?? 120,
      tempsRoulageMaxPilote: map['tempsRoulageMaxPilote'] ?? 240,
      raceType: map['raceType'] ?? 'Endurance',
      trackName: map['trackName'] ?? 'Circuit par défaut',
      numberOfPilots: map['numberOfPilots'] ?? 4,
      averageLapTime: Duration(seconds: map['averageLapTime'] ?? 90),
      customSettings: Map<String, dynamic>.from(map['customSettings'] ?? {}),
    );
  }
}

/// Données d'un pilote
class PilotData {
  final String id;
  final String name;
  final String nickname;
  final Duration bestLapTime;
  final Duration averageLapTime;
  final List<Duration> lapTimes;
  final int totalLaps;
  final Duration totalDriveTime;
  final double skillLevel; // 0.0 à 1.0
  final Map<String, dynamic> statistics;

  PilotData({
    required this.id,
    required this.name,
    required this.nickname,
    required this.bestLapTime,
    required this.averageLapTime,
    required this.lapTimes,
    required this.totalLaps,
    required this.totalDriveTime,
    required this.skillLevel,
    required this.statistics,
  });

  factory PilotData.create(String name) {
    return PilotData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      nickname: name.split(' ').first,
      bestLapTime: Duration.zero,
      averageLapTime: const Duration(seconds: 90),
      lapTimes: [],
      totalLaps: 0,
      totalDriveTime: Duration.zero,
      skillLevel: 0.5,
      statistics: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'bestLapTime': bestLapTime.inMilliseconds,
      'averageLapTime': averageLapTime.inMilliseconds,
      'lapTimes': lapTimes.map((lt) => lt.inMilliseconds).toList(),
      'totalLaps': totalLaps,
      'totalDriveTime': totalDriveTime.inMilliseconds,
      'skillLevel': skillLevel,
      'statistics': statistics,
    };
  }

  factory PilotData.fromMap(Map<String, dynamic> map) {
    return PilotData(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nickname: map['nickname'] ?? '',
      bestLapTime: Duration(milliseconds: map['bestLapTime'] ?? 0),
      averageLapTime: Duration(milliseconds: map['averageLapTime'] ?? 90000),
      lapTimes: (map['lapTimes'] as List<dynamic>?)
          ?.map((lt) => Duration(milliseconds: lt))
          .toList() ?? [],
      totalLaps: map['totalLaps'] ?? 0,
      totalDriveTime: Duration(milliseconds: map['totalDriveTime'] ?? 0),
      skillLevel: (map['skillLevel'] ?? 0.5).toDouble(),
      statistics: Map<String, dynamic>.from(map['statistics'] ?? {}),
    );
  }
}

/// Données d'un relais (stint) - version KMRS sans carburant
class StintData {
  final String id;
  final String pilotId;
  final int stintNumber;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? stintDuration;
  final Duration pitStopDuration;
  final Duration? pitInTime;          // Temps d'entrée aux stands (Pit In)
  final Duration? pitOutTime;         // Temps de sortie des stands (Pit Out)
  final List<Duration> lapTimes;
  final String notes;
  final StintStatus status;
  final bool isJokerStint;            // Relais joker ou régulier
  final Map<String, dynamic> telemetry;

  StintData({
    required this.id,
    required this.pilotId,
    required this.stintNumber,
    required this.startTime,
    this.endTime,
    this.stintDuration,
    required this.pitStopDuration,
    this.pitInTime,
    this.pitOutTime,
    required this.lapTimes,
    required this.notes,
    required this.status,
    this.isJokerStint = false,
    required this.telemetry,
  });

  factory StintData.create(String pilotId, int stintNumber) {
    return StintData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pilotId: pilotId,
      stintNumber: stintNumber,
      startTime: DateTime.now(),
      pitStopDuration: Duration.zero,
      lapTimes: [],
      notes: '',
      status: StintStatus.planned,
      isJokerStint: false,
      telemetry: {},
    );
  }

  Duration get actualDuration => endTime?.difference(startTime) ?? Duration.zero;
  
  int get lapCount => lapTimes.length;
  
  Duration get bestLapTime => lapTimes.isEmpty 
    ? Duration.zero 
    : lapTimes.reduce((a, b) => a < b ? a : b);
  
  Duration get averageLapTime => lapTimes.isEmpty 
    ? Duration.zero 
    : Duration(milliseconds: lapTimes.map((lt) => lt.inMilliseconds).reduce((a, b) => a + b) ~/ lapTimes.length);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pilotId': pilotId,
      'stintNumber': stintNumber,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'stintDuration': stintDuration?.inMilliseconds,
      'pitStopDuration': pitStopDuration.inMilliseconds,
      'pitInTime': pitInTime?.inMilliseconds,
      'pitOutTime': pitOutTime?.inMilliseconds,
      'lapTimes': lapTimes.map((lt) => lt.inMilliseconds).toList(),
      'notes': notes,
      'status': status.toString(),
      'isJokerStint': isJokerStint,
      'telemetry': telemetry,
    };
  }

  factory StintData.fromMap(Map<String, dynamic> map) {
    return StintData(
      id: map['id'] ?? '',
      pilotId: map['pilotId'] ?? '',
      stintNumber: map['stintNumber'] ?? 0,
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      stintDuration: map['stintDuration'] != null ? Duration(milliseconds: map['stintDuration']) : null,
      pitStopDuration: Duration(milliseconds: map['pitStopDuration'] ?? 0),
      pitInTime: map['pitInTime'] != null ? Duration(milliseconds: map['pitInTime']) : null,
      pitOutTime: map['pitOutTime'] != null ? Duration(milliseconds: map['pitOutTime']) : null,
      lapTimes: (map['lapTimes'] as List<dynamic>?)
          ?.map((lt) => Duration(milliseconds: lt))
          .toList() ?? [],
      notes: map['notes'] ?? '',
      status: StintStatus.values.firstWhere(
        (s) => s.toString() == map['status'],
        orElse: () => StintStatus.planned,
      ),
      isJokerStint: map['isJokerStint'] ?? false,
      telemetry: Map<String, dynamic>.from(map['telemetry'] ?? {}),
    );
  }
}

/// Statut d'un relais
enum StintStatus {
  planned,
  active,
  completed,
  cancelled,
}

/// Données pour l'interface Racing KMRS (16x22 grid)
class RacingData {
  final DateTime timestamp;
  final String currentPilotId;
  final Duration elapsedTime;
  final Duration remainingTime;
  final int currentLap;
  final Duration lastLapTime;
  final Duration bestLapTime;
  final int regularStints;              // Relais réguliers
  final int jokerStints;                // Relais joker
  final double averageJokerDuration;    // Durée moyenne des jokers
  final int position;
  final List<List<dynamic>> gridData;   // 16x22 matrix

  RacingData({
    required this.timestamp,
    required this.currentPilotId,
    required this.elapsedTime,
    required this.remainingTime,
    required this.currentLap,
    required this.lastLapTime,
    required this.bestLapTime,
    required this.regularStints,
    required this.jokerStints,
    required this.averageJokerDuration,
    required this.position,
    required this.gridData,
  });

  factory RacingData.empty() {
    return RacingData(
      timestamp: DateTime.now(),
      currentPilotId: '',
      elapsedTime: Duration.zero,
      remainingTime: Duration.zero,
      currentLap: 0,
      lastLapTime: Duration.zero,
      bestLapTime: Duration.zero,
      regularStints: 0,
      jokerStints: 0,
      averageJokerDuration: 0.0,
      position: 0,
      gridData: List.generate(22, (_) => List.generate(16, (_) => '')),
    );
  }
}

/// Service de calcul KMRS authentique (remplace le VBA Excel)
class KmrsCalculationEngine {
  /// Formule principale KMRS: Calcul des relais longs restants
  /// =ENT((B7 - B12 * 'Start Page'!B2 - 'Main Page'!B11 * 'Main Page'!B10) / ('Start Page'!B3- 'Start Page'!B2))
  static int calculateRemainingLongStints(
    Duration remainingTime,
    int requiredStintsRemaining,
    int minStintTime,
    int requiredStopsRemaining,
    Duration remainingTimeUntilPitlaneCloses,
    int maxStintTime,
  ) {
    final numerator = remainingTime.inMinutes - 
                     (requiredStintsRemaining * minStintTime) - 
                     (requiredStopsRemaining * remainingTimeUntilPitlaneCloses.inMinutes);
    final denominator = maxStintTime - minStintTime;
    
    if (denominator == 0) return 0;
    return (numerator / denominator).floor();
  }

  /// Formule Joker: Calcul des relais joker
  /// =B12-B16 (Total relais - Relais longs)
  static int calculateJokerStints(int totalStints, int longStints) {
    return totalStints - longStints;
  }

  /// Formule Joker Moyen: Durée moyenne des relais joker
  /// =SI(B17>0;( B8 - B16 * 'Start Page'!$B$3- (B9-1) * 'Start Page'!$B$10)/ B17; 0)
  static double calculateAverageJokerStintDuration(
    int jokerStints,
    Duration totalTime,
    int longStints,
    int maxStintTime,
    int requiredStops,
    Duration pitstopFixTime,
  ) {
    if (jokerStints <= 0) return 0.0;
    
    final numerator = totalTime.inMinutes - 
                     (longStints * maxStintTime) - 
                     ((requiredStops - 1) * pitstopFixTime.inMinutes);
    
    return numerator / jokerStints;
  }

  /// Calcul de Marge: Optimisation stratégique
  /// Marge = Nb_arrêts × (Max_stint - (Durée_totale_minutes / Nb_arrêts))
  static double calculateMargin(
    int numberOfStops,
    int maxStintTime,
    Duration totalRaceTime,
  ) {
    if (numberOfStops == 0) return 0.0;
    
    final averageStintTime = totalRaceTime.inMinutes / numberOfStops;
    return numberOfStops * (maxStintTime - averageStintTime);
  }

  /// Calcule le temps restant de course
  static Duration calculateRemainingTime(
    DateTime raceStart,
    Duration raceDuration,
  ) {
    final elapsed = DateTime.now().difference(raceStart);
    final remaining = raceDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Calcule les statistiques d'un pilote
  static Map<String, dynamic> calculatePilotStatistics(PilotData pilot, List<StintData> stints) {
    final pilotStints = stints.where((s) => s.pilotId == pilot.id).toList();
    
    if (pilotStints.isEmpty) {
      return {
        'totalStints': 0,
        'totalDriveTime': Duration.zero,
        'averageStintDuration': Duration.zero,
        'bestLapTime': Duration.zero,
        'averageLapTime': Duration.zero,
        'totalLaps': 0,
        'consistency': 0.0,
      };
    }

    final totalDriveTime = pilotStints
        .map((s) => s.actualDuration)
        .fold(Duration.zero, (a, b) => a + b);

    final allLaps = pilotStints
        .expand((s) => s.lapTimes)
        .toList();

    final bestLap = allLaps.isEmpty 
        ? Duration.zero 
        : allLaps.reduce((a, b) => a < b ? a : b);

    final averageLap = allLaps.isEmpty 
        ? Duration.zero 
        : Duration(milliseconds: allLaps.map((lt) => lt.inMilliseconds).reduce((a, b) => a + b) ~/ allLaps.length);

    // Calcul de consistance (écart-type inversé)
    double consistency = 0.0;
    if (allLaps.length > 1) {
      final mean = averageLap.inMilliseconds.toDouble();
      final variance = allLaps
          .map((lt) => (lt.inMilliseconds - mean) * (lt.inMilliseconds - mean))
          .reduce((a, b) => a + b) / allLaps.length;
      final stdDev = variance.isNaN ? 0.0 : (variance / mean) * 100; // CV en %
      consistency = stdDev == 0 ? 100.0 : (100.0 - stdDev).clamp(0.0, 100.0);
    }

    return {
      'totalStints': pilotStints.length,
      'totalDriveTime': totalDriveTime,
      'averageStintDuration': Duration(milliseconds: totalDriveTime.inMilliseconds ~/ pilotStints.length),
      'bestLapTime': bestLap,
      'averageLapTime': averageLap,
      'totalLaps': allLaps.length,
      'consistency': consistency,
    };
  }

  /// Génère les données pour la grille Racing KMRS 16x22
  static List<List<dynamic>> generateRacingGrid(RaceSession session) {
    final grid = List.generate(22, (_) => List.generate(16, (_) => ''));
    
    // Headers KMRS (ligne 0)
    grid[0] = [
      'Stint #', 'Time Remaining', 'Pilote', 'Stint Duration', 'Type',
      'Pit In', 'Pit Out', 'Pit Time', 'Dernier Tour', 'Meilleur Tour',
      'Tours', 'Statut', 'Temps Roulage', 'Notes',
      'Joker', 'Régulier'
    ];

    // Données KMRS en temps réel (lignes 1-21)
    for (int i = 1; i < 22; i++) {
      if (i <= session.stints.length) {
        final stint = session.stints[i - 1];
        final pilot = session.pilots.firstWhere(
          (p) => p.id == stint.pilotId,
          orElse: () => PilotData.create('Unknown'),
        );
        
        // Calcul du temps restant (diminue avec chaque relais)
        final raceDurationMinutes = (session.configuration.raceDurationHours * 60).round();
        final elapsedMinutes = session.stints.take(i).map((s) => s.actualDuration.inMinutes).fold(0, (a, b) => a + b);
        final remainingMinutes = raceDurationMinutes - elapsedMinutes;
        
        grid[i] = [
          stint.stintNumber.toString(),                           // Stint #
          '$remainingMinutes min',                                // Time Remaining
          pilot.name,                                             // Pilote
          _formatDuration(stint.actualDuration),                  // Stint Duration
          stint.isJokerStint ? 'Joker' : 'Régulier',             // Type
          stint.pitInTime != null ? _formatDuration(stint.pitInTime!) : '', // Pit In
          stint.pitOutTime != null ? _formatDuration(stint.pitOutTime!) : '', // Pit Out
          _formatDuration(stint.pitStopDuration),                 // Pit Time
          stint.lapTimes.isNotEmpty ? _formatDuration(stint.lapTimes.last) : '', // Dernier Tour
          stint.bestLapTime != Duration.zero ? _formatDuration(stint.bestLapTime) : '', // Meilleur Tour
          stint.lapCount.toString(),                              // Tours
          stint.status.toString().split('.').last,               // Statut
          _formatDuration(stint.actualDuration),                  // Temps Roulage
          stint.notes,                                            // Notes
          stint.isJokerStint ? 'X' : '',                         // Joker
          !stint.isJokerStint ? 'X' : '',                        // Régulier
        ];
      }
    }

    return grid;
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${(milliseconds ~/ 10).toString().padLeft(2, '0')}';
  }
}