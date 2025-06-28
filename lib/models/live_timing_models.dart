import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour un tour individuel capturé depuis Live Timing WebSocket
class LiveLapData {
  final String id;
  final String kartId;
  final int lapNumber;
  final String lapTime; // Format "1:23.456" tel que reçu du WebSocket
  final DateTime timestamp;
  final Map<String, dynamic> allTimingData; // Toutes les données timing disponibles

  LiveLapData({
    required this.id,
    required this.kartId,
    required this.lapNumber,
    required this.lapTime,
    required this.timestamp,
    required this.allTimingData,
  });

  factory LiveLapData.create({
    required String sessionId,
    required String kartId,
    required int lapNumber,
    required String lapTime,
    required Map<String, dynamic> timingData,
  }) {
    return LiveLapData(
      // ID UNIQUE et STABLE avec session: évite conflits entre sessions
      // Format: sessionId_kartId_lap_001 (padding pour tri correct)
      id: '${sessionId}_${kartId}_lap_${lapNumber.toString().padLeft(3, '0')}',
      kartId: kartId,
      lapNumber: lapNumber,
      lapTime: lapTime,
      timestamp: DateTime.now(),
      allTimingData: Map<String, dynamic>.from(timingData),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kartId': kartId,
      'lapNumber': lapNumber,
      'lapTime': lapTime,
      'timestamp': timestamp.toIso8601String(),
      'allTimingData': allTimingData,
    };
  }

  factory LiveLapData.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;
    try {
      timestamp = DateTime.parse(map['timestamp']);
    } catch (e) {
      timestamp = DateTime.now(); // Fallback en cas d'erreur de parsing
    }
    
    return LiveLapData(
      id: map['id'] ?? '',
      kartId: map['kartId'] ?? '',
      lapNumber: map['lapNumber'] ?? 0,
      lapTime: map['lapTime'] ?? '',
      timestamp: timestamp,
      allTimingData: Map<String, dynamic>.from(map['allTimingData'] ?? {}),
    );
  }

  factory LiveLapData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveLapData.fromMap(data);
  }
}

/// Historique complet des tours pour un kart/équipe
class LiveTimingHistory {
  final String kartId;
  final List<LiveLapData> allLaps;
  final String bestLapTime;
  final int totalLaps;
  final DateTime raceStart;
  final DateTime lastUpdate;

  LiveTimingHistory({
    required this.kartId,
    required this.allLaps,
    required this.bestLapTime,
    required this.totalLaps,
    required this.raceStart,
    required this.lastUpdate,
  });

  factory LiveTimingHistory.create(String kartId) {
    return LiveTimingHistory(
      kartId: kartId,
      allLaps: [],
      bestLapTime: '',
      totalLaps: 0,
      raceStart: DateTime.now(),
      lastUpdate: DateTime.now(),
    );
  }

  /// Ajouter un nouveau tour à l'historique avec déduplication automatique
  LiveTimingHistory addLap(LiveLapData lap) {
    final updatedLaps = List<LiveLapData>.from(allLaps);
    
    // DÉDUPLICATION: Vérifier si un tour avec le même numéro de tour existe déjà
    final existingIndex = updatedLaps.indexWhere((existingLap) => 
      existingLap.lapNumber == lap.lapNumber
    );
    
    if (existingIndex != -1) {
      // Remplacer le tour existant par le nouveau (mise à jour)
      updatedLaps[existingIndex] = lap;
    } else {
      // Ajouter le nouveau tour
      updatedLaps.add(lap);
    }
    
    // Calculer le meilleur tour
    String newBestLap = bestLapTime;
    if (lap.lapTime.isNotEmpty && lap.lapTime != '--:--' && lap.lapTime != '0:00.000') {
      if (bestLapTime.isEmpty || compareLapTimes(lap.lapTime, bestLapTime) < 0) {
        newBestLap = lap.lapTime;
      }
    }

    return LiveTimingHistory(
      kartId: kartId,
      allLaps: updatedLaps,
      bestLapTime: newBestLap,
      totalLaps: updatedLaps.length,
      raceStart: raceStart,
      lastUpdate: DateTime.now(),
    );
  }

  /// Comparer deux temps de tour (format "1:23.456")
  /// Retourne < 0 si time1 < time2, > 0 si time1 > time2, 0 si égaux
  static int compareLapTimes(String time1, String time2) {
    try {
      final duration1 = _parseLapTime(time1);
      final duration2 = _parseLapTime(time2);
      return duration1.compareTo(duration2);
    } catch (e) {
      return 0; // En cas d'erreur, considérer comme égaux
    }
  }

  /// Parser un temps de tour format "1:23.456" vers Duration
  static Duration _parseLapTime(String lapTime) {
    if (lapTime.isEmpty || lapTime == '--:--' || lapTime == '0:00.000') {
      return Duration.zero;
    }

    try {
      // Format attendu : "1:23.456" ou "23.456"
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

  Map<String, dynamic> toMap() {
    return {
      'kartId': kartId,
      'allLaps': allLaps.map((lap) => lap.toMap()).toList(),
      'bestLapTime': bestLapTime,
      'totalLaps': totalLaps,
      'raceStart': raceStart.toIso8601String(),
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  factory LiveTimingHistory.fromMap(Map<String, dynamic> map) {
    return LiveTimingHistory(
      kartId: map['kartId'] ?? '',
      allLaps: (map['allLaps'] as List<dynamic>?)
          ?.map((lap) => LiveLapData.fromMap(lap))
          .toList() ?? [],
      bestLapTime: map['bestLapTime'] ?? '',
      totalLaps: map['totalLaps'] ?? 0,
      raceStart: DateTime.parse(map['raceStart']),
      lastUpdate: DateTime.parse(map['lastUpdate']),
    );
  }
}

/// Session de timing live pour regrouper tous les karts
class LiveTimingSession {
  final String sessionId;
  final String circuitId;
  final DateTime raceStart;
  final Map<String, LiveTimingHistory> kartsHistory;
  final bool isActive;

  LiveTimingSession({
    required this.sessionId,
    required this.circuitId,
    required this.raceStart,
    required this.kartsHistory,
    required this.isActive,
  });

  factory LiveTimingSession.create({
    required String circuitId,
  }) {
    final sessionId = 'live_timing_${DateTime.now().millisecondsSinceEpoch}';
    return LiveTimingSession(
      sessionId: sessionId,
      circuitId: circuitId,
      raceStart: DateTime.now(),
      kartsHistory: {},
      isActive: true,
    );
  }

  /// Ajouter un tour pour un kart
  LiveTimingSession addLapForKart(String kartId, LiveLapData lap) {
    final updatedHistory = Map<String, LiveTimingHistory>.from(kartsHistory);
    
    if (updatedHistory.containsKey(kartId)) {
      updatedHistory[kartId] = updatedHistory[kartId]!.addLap(lap);
    } else {
      updatedHistory[kartId] = LiveTimingHistory.create(kartId).addLap(lap);
    }

    return LiveTimingSession(
      sessionId: sessionId,
      circuitId: circuitId,
      raceStart: raceStart,
      kartsHistory: updatedHistory,
      isActive: isActive,
    );
  }

  /// Créer une copie avec modifications
  LiveTimingSession copyWith({
    String? sessionId,
    String? circuitId,
    DateTime? raceStart,
    Map<String, LiveTimingHistory>? kartsHistory,
    bool? isActive,
  }) {
    return LiveTimingSession(
      sessionId: sessionId ?? this.sessionId,
      circuitId: circuitId ?? this.circuitId,
      raceStart: raceStart ?? this.raceStart,
      kartsHistory: kartsHistory ?? this.kartsHistory,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'circuitId': circuitId,
      'raceStart': raceStart.toIso8601String(),
      'kartsHistory': kartsHistory.map((key, value) => MapEntry(key, value.toMap())),
      'isActive': isActive,
    };
  }

  factory LiveTimingSession.fromMap(Map<String, dynamic> map) {
    return LiveTimingSession(
      sessionId: map['sessionId'] ?? '',
      circuitId: map['circuitId'] ?? '',
      raceStart: DateTime.parse(map['raceStart']),
      kartsHistory: (map['kartsHistory'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(key, LiveTimingHistory.fromMap(value)))
          ?? {},
      isActive: map['isActive'] ?? false,
    );
  }
}
