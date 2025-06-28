import 'dart:async';
import 'dart:math';

/// Simulateur de données Live Timing pour les tests
class LiveTimingSimulator {
  static const List<String> _kartIds = ['1', '2', '3', '4', '5', '6', '7', '8'];
  static const List<String> _pilotNames = [
    'MARTIN', 'DUBOIS', 'BERNARD', 'THOMAS', 'ROBERT', 'PETIT', 'DURAND', 'LEROY'
  ];
  
  final Random _random = Random();
  final Map<String, Map<String, dynamic>> _kartsData = {};
  final Map<String, int> _lapNumbers = {};
  final Map<String, Duration> _baseLapTimes = {};
  Timer? _simulationTimer;
  bool _isRunning = false;
  
  // Callback pour envoyer les données simulées
  Function(Map<String, dynamic>)? onDataUpdate;
  
  /// Initialiser le simulateur avec des données de base
  void initialize() {
    _kartsData.clear();
    _lapNumbers.clear();
    _baseLapTimes.clear();
    
    for (int i = 0; i < _kartIds.length; i++) {
      final kartId = _kartIds[i];
      final pilotName = _pilotNames[i];
      
      // Temps de base entre 1:15 et 1:35
      final baseSeconds = 75 + _random.nextInt(20);
      final baseMillis = _random.nextInt(1000);
      _baseLapTimes[kartId] = Duration(seconds: baseSeconds, milliseconds: baseMillis);
      
      _lapNumbers[kartId] = 0;
      
      _kartsData[kartId] = {
        'Pos.': '${i + 1}',
        'Nom': pilotName,
        'Tours': '0',
        'Dernier T.': '--:--:---',
        'Meilleur': '--:--:---',
        'Écart': i == 0 ? '00:00:000' : '+${i * 2}.${_random.nextInt(10)}${_random.nextInt(10)}${_random.nextInt(10)}',
        'V.Moy': '${45 + _random.nextInt(15)}.${_random.nextInt(10)} km/h',
        'Statut': 'En course',
      };
    }
  }
  
  /// Démarrer la simulation
  void startSimulation() {
    if (_isRunning) return;
    
    initialize();
    _isRunning = true;
    
    // Envoyer des mises à jour toutes les 3-8 secondes (simulation de nouveaux tours)
    _simulationTimer = Timer.periodic(
      Duration(seconds: 3 + _random.nextInt(5)),
      (_) => _generateLapUpdate(),
    );
    
    // Envoyer la configuration initiale
    _sendUpdate();
  }
  
  /// Arrêter la simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isRunning = false;
  }
  
  /// Générer une mise à jour de tour pour un kart aléatoire
  void _generateLapUpdate() {
    if (!_isRunning || _kartsData.isEmpty) return;
    
    // Choisir un kart aléatoire
    final kartId = _kartIds[_random.nextInt(_kartIds.length)];
    final kartData = _kartsData[kartId]!;
    
    // Incrémenter le numéro de tour
    _lapNumbers[kartId] = (_lapNumbers[kartId] ?? 0) + 1;
    final newLapNumber = _lapNumbers[kartId]!;
    
    // Générer un nouveau temps de tour (variation de ±3 secondes)
    final baseTime = _baseLapTimes[kartId]!;
    final variation = Duration(
      milliseconds: -3000 + _random.nextInt(6000), // ±3 secondes
    );
    final newLapTime = baseTime + variation;
    
    // Formater le temps (format: M:SS.mmm)
    final minutes = newLapTime.inMinutes;
    final seconds = newLapTime.inSeconds % 60;
    final milliseconds = newLapTime.inMilliseconds % 1000;
    final formattedTime = '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
    
    // Mettre à jour les données du kart
    kartData['Tours'] = newLapNumber.toString();
    kartData['Dernier T.'] = formattedTime;
    
    // Mettre à jour le meilleur temps si nécessaire
    final currentBest = kartData['Meilleur'] as String;
    if (currentBest == '--:--:---' || _isTimeBetter(formattedTime, currentBest)) {
      kartData['Meilleur'] = formattedTime;
    }
    
    // Mettre à jour la vitesse moyenne
    kartData['V.Moy'] = '${45 + _random.nextInt(15)}.${_random.nextInt(10)} km/h';
    
    // Recalculer les positions si nécessaire (simple simulation)
    _updatePositions();
    
    // Envoyer la mise à jour
    _sendUpdate();
  }
  
  /// Comparer deux temps pour déterminer lequel est meilleur
  bool _isTimeBetter(String time1, String time2) {
    try {
      final duration1 = _parseTime(time1);
      final duration2 = _parseTime(time2);
      return duration1 < duration2;
    } catch (e) {
      return false;
    }
  }
  
  /// Parser un temps au format M:SS.mmm vers Duration
  Duration _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final minutes = int.parse(parts[0]);
    final secondsParts = parts[1].split('.');
    final seconds = int.parse(secondsParts[0]);
    final milliseconds = int.parse(secondsParts[1]);
    
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }
  
  /// Mettre à jour les positions (simulation simple)
  void _updatePositions() {
    // Trier les karts par meilleur temps
    final sortedKarts = _kartsData.entries.toList();
    sortedKarts.sort((a, b) {
      final timeA = a.value['Meilleur'] as String;
      final timeB = b.value['Meilleur'] as String;
      
      if (timeA == '--:--:---' && timeB == '--:--:---') return 0;
      if (timeA == '--:--:---') return 1;
      if (timeB == '--:--:---') return -1;
      
      try {
        final durationA = _parseTime(timeA);
        final durationB = _parseTime(timeB);
        return durationA.compareTo(durationB);
      } catch (e) {
        return 0;
      }
    });
    
    // Mettre à jour les positions
    for (int i = 0; i < sortedKarts.length; i++) {
      sortedKarts[i].value['Pos.'] = '${i + 1}';
    }
  }
  
  /// Envoyer une mise à jour des données
  void _sendUpdate() {
    if (onDataUpdate != null) {
      onDataUpdate!(_kartsData);
    }
  }
  
  /// Générer une mise à jour manuelle pour un kart spécifique
  void generateManualLap(String kartId) {
    if (!_isRunning || !_kartsData.containsKey(kartId)) return;
    
    final kartData = _kartsData[kartId]!;
    
    // Forcer un nouveau tour pour ce kart
    _lapNumbers[kartId] = (_lapNumbers[kartId] ?? 0) + 1;
    final newLapNumber = _lapNumbers[kartId]!;
    
    final baseTime = _baseLapTimes[kartId]!;
    final variation = Duration(milliseconds: -1000 + _random.nextInt(2000));
    final newLapTime = baseTime + variation;
    
    final minutes = newLapTime.inMinutes;
    final seconds = newLapTime.inSeconds % 60;
    final milliseconds = newLapTime.inMilliseconds % 1000;
    final formattedTime = '$minutes:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
    
    kartData['Tours'] = newLapNumber.toString();
    kartData['Dernier T.'] = formattedTime;
    
    final currentBest = kartData['Meilleur'] as String;
    if (currentBest == '--:--:---' || _isTimeBetter(formattedTime, currentBest)) {
      kartData['Meilleur'] = formattedTime;
    }
    
    _updatePositions();
    _sendUpdate();
  }
  
  /// Obtenir l'état actuel de la simulation
  bool get isRunning => _isRunning;
  
  /// Obtenir les données actuelles
  Map<String, dynamic> get currentData => Map.from(_kartsData);
  
  /// Réinitialiser la simulation
  void reset() {
    stopSimulation();
    _kartsData.clear();
    _lapNumbers.clear();
    _baseLapTimes.clear();
  }
}