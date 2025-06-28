/// Configuration globale de l'application KMRS Racing
class AppConfig {
  // URL du backend - À modifier selon l'environnement
  static const String _devBackendUrl = 'http://172.25.147.11:8001';
  static const String _devWsUrl = 'ws://172.25.147.11:8001';
  
  static const String _prodBackendUrl = 'https://api.kmrs-racing.com';
  static const String _prodWsUrl = 'wss://api.kmrs-racing.com';
  
  /// Détermine automatiquement l'environnement
  static bool get isProduction {
    // En production, l'URL contiendra votre domaine
    const String currentUrl = String.fromEnvironment('FLUTTER_WEB_BASE_URL', 
        defaultValue: 'http://localhost');
    
    return currentUrl.contains('kmrs-racing.com') || 
           currentUrl.contains('firebase') ||
           const bool.fromEnvironment('dart.vm.product');
  }
  
  /// URL du backend selon l'environnement
  static String get backendUrl {
    return isProduction ? _prodBackendUrl : _devBackendUrl;
  }
  
  /// URL WebSocket selon l'environnement
  static String get wsUrl {
    return isProduction ? _prodWsUrl : _devWsUrl;
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