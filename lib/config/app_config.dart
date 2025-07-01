/// Configuration globale de l'application KMRS Racing
class AppConfig {
  // URL du backend - À modifier selon l'environnement
  static const String _devBackendUrl = 'http://172.25.147.11:8001';
  static const String _devWsUrl = 'ws://172.25.147.11:8001';
  
  static const String _prodBackendUrl = 'https://api.kmrs-racing.eu';
  static const String _prodWsUrl = 'wss://api.kmrs-racing.eu';
  
  /// Détermine automatiquement l'environnement
  static bool get isProduction {
    // Détection de production basée sur l'URL ou le build
    const String currentUrl = String.fromEnvironment('FLUTTER_WEB_BASE_URL', 
        defaultValue: 'http://localhost');
    
    // Production si on est sur le domaine kmrs-racing.eu ou build release
    return currentUrl.contains('kmrs-racing.eu') || 
           currentUrl.contains('web.app') ||
           const bool.fromEnvironment('dart.vm.product');
  }
  
  /// URL du backend selon l'environnement
      static String get backendUrl {
        return isProduction
            ? 'https://api.kmrs-racing.eu' // ← HTTPS au lieu de HTTP
            : 'http://172.25.147.11:8001';
      }
  
  /// URL WebSocket selon l'environnement
  static String get wsUrl {
    return isProduction
        ? 'wss://api.kmrs-racing.eu'      // ✅ WebSocket sécurisé via NGINX
        : 'ws://172.25.147.11:8001';      // Dev local
  }
  
  /// Configuration Firebase
  static const String firebaseProjectId = 'kartingapp-fef5c';
  
  /// Configuration de l'app
  static const String appName = 'KMRS Racing';
  static const String appVersion = '1.0.0';
  
  /// Timeouts de connexion
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 30);
  
  /// Configuration live timing
  static const Duration liveTimingReconnectDelay = Duration(seconds: 5);
  static const int maxReconnectAttempts = 5;
  
  /// URLs utiles
  static String get healthCheckUrl => '$backendUrl/health';
  static String get websocketUrl => '$wsUrl/circuits';
  
  /// Debug info
  static Map<String, dynamic> get debugInfo => {
    'environment': isProduction ? 'production' : 'development',
    'backendUrl': backendUrl,
    'wsUrl': wsUrl,
    'version': appVersion,
  };
}
