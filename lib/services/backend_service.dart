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
    print('WebSocket disconnected');
  }

  /// Gérer les messages reçus
  void _handleMessage(dynamic message) {
    try {
      print('=== MESSAGE WEBSOCKET BRUT COMPLET ===');
      print(message.toString());
      print('=======================================');

      final Map<String, dynamic> data = json.decode(message);
      print('=== DONNÉES JSON PARSÉES ===');
      print(json.encode(data));
      print('============================');
      print('Parsed WebSocket message type: ${data['type']}');

      // Ignorer les pongs
      if (data['type'] == 'pong') {
        print('Received pong from server');
        return;
      }

      // Transmettre les données de timing
      if (data['type'] == 'timing_data' &&
          _controller != null &&
          !_controller!.isClosed) {
        print('=== DONNÉES TIMING TRANSMISES AU STREAM ===');
        print(json.encode(data));
        print('=========================================');
        print('Forwarding timing data to stream');
        _controller!.add(data);
      }

      // Gérer les mises à jour de statut
      if (data['type'] == 'status_update') {
        print('Status update: ${data['status']}');
      }

      // Gérer les erreurs
      if (data['type'] == 'error') {
        print('Backend error: ${data['error']}');
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
