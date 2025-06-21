import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Service pour communiquer avec le backend FastAPI
class BackendService {
  static const String _baseUrl =
      'http://172.25.147.11:8001'; // IP de votre machine
  static const String _wsBaseUrl = 'ws://172.25.147.11:8001';

  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Vérifier la santé du backend
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Backend health check failed: $e');
      return false;
    }
  }

  /// Obtenir tous les circuits
  static Future<List<Map<String, dynamic>>?> getCircuits() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/circuits'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      print('Error fetching circuits: $e');
      return null;
    }
  }

  /// Obtenir les détails d'un circuit
  static Future<Map<String, dynamic>?> getCircuit(String circuitId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/circuits/$circuitId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching circuit $circuitId: $e');
      return null;
    }
  }

  /// Obtenir le statut d'un circuit
  static Future<Map<String, dynamic>?> getCircuitStatus(
    String circuitId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/circuits/$circuitId/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching circuit status: $e');
      return null;
    }
  }

  /// Démarrer le timing pour un circuit
  static Future<bool> startTiming(String circuitId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/circuits/$circuitId/start-timing'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error starting timing: $e');
      return false;
    }
  }

  /// Arrêter le timing pour un circuit
  static Future<bool> stopTiming(String circuitId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/circuits/$circuitId/stop-timing'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error stopping timing: $e');
      return false;
    }
  }

  /// Obtenir les données de timing récentes
  static Future<List<Map<String, dynamic>>?> getTimingData(
    String circuitId, {
    int limit = 100,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/circuits/$circuitId/data?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      print('Error fetching timing data: $e');
      return null;
    }
  }

  /// Obtenir les statistiques d'un circuit
  static Future<Map<String, dynamic>?> getCircuitStatistics(
    String circuitId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/circuits/$circuitId/statistics'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching statistics: $e');
      return null;
    }
  }
}

/// Service pour gérer la connexion WebSocket en temps réel
class LiveTimingWebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  String? _currentCircuitId;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _pingInterval = Duration(seconds: 30);

  // NOUVEAU: Cache pour accumuler toutes les données des karts
  final Map<String, Map<String, dynamic>> _kartDataCache = {};
  int _messageCounter = 0;

  /// Stream des données de timing en temps réel
  Stream<Map<String, dynamic>>? get stream => _controller?.stream;

  /// Statut de la connexion
  bool get isConnected => _isConnected;

  /// Circuit ID actuellement connecté
  String? get currentCircuitId => _currentCircuitId;

  /// Se connecter à un circuit pour le timing en temps réel
  Future<bool> connect(String circuitId) async {
    if (_isConnected && _currentCircuitId == circuitId) {
      return true; // Déjà connecté au bon circuit
    }

    await disconnect(); // Déconnecter de l'ancien circuit si nécessaire

    try {
      final wsUrl = '${BackendService._wsBaseUrl}/circuits/$circuitId/live';
      print('Connecting to WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _controller = StreamController<Map<String, dynamic>>.broadcast();
      _currentCircuitId = circuitId;
      _reconnectAttempts = 0;

      // Écouter les messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      // Démarrer le ping pour maintenir la connexion
      _startPing();

      _isConnected = true;
      print('WebSocket connected to circuit $circuitId');
      return true;
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _handleError(e);
      return false;
    }
  }

  /// Se déconnecter du WebSocket
  Future<void> disconnect() async {
    _isConnected = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }

    if (_controller != null && !_controller!.isClosed) {
      await _controller!.close();
      _controller = null;
    }

    _currentCircuitId = null;
    _reconnectAttempts = 0;

    // NOUVEAU: Vider le cache lors de la déconnexion
    _kartDataCache.clear();
    _messageCounter = 0;
    print('WebSocket disconnected - Cache des karts vidé');
  }

  /// Gérer les messages reçus
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> parsed = json.decode(message);

      // Accès robuste aux drivers selon la structure reçue
      Map<String, dynamic>? drivers;

      // Tenter d'accéder aux drivers selon différentes structures possibles
      if (parsed.containsKey('drivers')) {
        drivers = parsed['drivers'] as Map<String, dynamic>?;
      } else if (parsed.containsKey('data') && parsed['data'] != null) {
        final Map<String, dynamic> dataSection =
            parsed['data'] as Map<String, dynamic>;
        drivers = dataSection['drivers'] as Map<String, dynamic>?;
      } else if (parsed.containsKey('karting_data') &&
          parsed['karting_data'] != null) {
        final Map<String, dynamic> kartingSection =
            parsed['karting_data'] as Map<String, dynamic>;
        drivers = kartingSection['drivers'] as Map<String, dynamic>?;
      }

      if (drivers == null) {
        print(json.encode(parsed));
        return;
      }

      // NOUVEAU: Mettre à jour le cache avec les nouvelles données (FUSION INTELLIGENTE)
      _messageCounter++;
      drivers.forEach((kartId, stats) {
        if (stats is Map<String, dynamic>) {
          // Fusion intelligente : conserver les données existantes + mettre à jour les nouvelles
          if (_kartDataCache.containsKey(kartId)) {
            // Le kart existe déjà : fusionner les nouvelles données avec les existantes
            _kartDataCache[kartId]!.addAll(Map<String, dynamic>.from(stats));
          } else {
            // Nouveau kart : créer l'entrée complète
            _kartDataCache[kartId] = Map<String, dynamic>.from(stats);
          }
        }
      });

      // NOUVEAU: Afficher la totalité du cache à chaque message
      print('');
      print(
        '🏁 ====== MESSAGE #$_messageCounter - ÉTAT COMPLET DE TOUS LES KARTS ======',
      );
      print('📊 Total karts suivis: ${_kartDataCache.length}');
      print('');

      // Trier les karts par numéro pour un affichage ordonné
      final sortedKarts = _kartDataCache.entries.toList();
      sortedKarts.sort((a, b) {
        // Essayer de trier par position/classement si disponible
        final classementA = a.value['Classement']?.toString() ?? '999';
        final classementB = b.value['Classement']?.toString() ?? '999';
        try {
          return int.parse(classementA).compareTo(int.parse(classementB));
        } catch (e) {
          // Si pas numérique, trier par ID de kart
          return a.key.compareTo(b.key);
        }
      });

      sortedKarts.forEach((entry) {
        final kartId = entry.key;
        final stats = entry.value;

        print('🏎️  KART #$kartId:');
        stats.forEach((field, value) {
          print('    • $field → $value');
        });
        print('');
      });

      print('🏁 ====== FIN ÉTAT COMPLET ======');
      print('');

      // Ignorer les pongs
      if (parsed['type'] == 'pong') {
        print('Received pong from server');
        return;
      }

      // Transmettre les données de timing
      if (parsed['type'] == 'karting_data' &&
          _controller != null &&
          !_controller!.isClosed) {
        _controller!.add(parsed);
      }

      // Gérer les mises à jour de statut
      if (parsed['type'] == 'status_update') {
        print('Status update: ${parsed['status']}');
      }

      // Gérer les erreurs
      if (parsed['type'] == 'error') {
        print('Backend error: ${parsed['error']}');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  /// Gérer les erreurs de connexion
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _isConnected = false;

    if (_reconnectAttempts < _maxReconnectAttempts &&
        _currentCircuitId != null) {
      _attemptReconnect();
    } else {
      print('Max reconnection attempts reached');
      disconnect();
    }
  }

  /// Gérer la déconnexion
  void _handleDisconnection() {
    print('WebSocket disconnected');
    _isConnected = false;

    if (_reconnectAttempts < _maxReconnectAttempts &&
        _currentCircuitId != null) {
      _attemptReconnect();
    }
  }

  /// Tenter une reconnexion
  void _attemptReconnect() {
    _reconnectAttempts++;
    print('Attempting reconnection $_reconnectAttempts/$_maxReconnectAttempts');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_currentCircuitId != null) {
        connect(_currentCircuitId!);
      }
    });
  }

  /// Démarrer le ping pour maintenir la connexion
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(json.encode({'type': 'ping'}));
        } catch (e) {
          print('Error sending ping: $e');
        }
      }
    });
  }

  /// Fermer le service
  void dispose() {
    disconnect();
  }
}
