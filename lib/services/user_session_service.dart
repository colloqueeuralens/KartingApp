import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service centralisant la gestion des sessions utilisateur multi-utilisateurs
/// Fournit l'isolation des données par utilisateur via Firebase Auth
class UserSessionService {
  static final UserSessionService _instance = UserSessionService._internal();
  factory UserSessionService() => _instance;
  UserSessionService._internal();

  /// Obtient l'ID de l'utilisateur actuellement connecté
  static String getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated - cannot access user-specific data');
    }
    return user.uid;
  }

  /// Vérifie si un utilisateur est connecté
  static bool get isUserAuthenticated {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Obtient l'email de l'utilisateur connecté
  static String? getCurrentUserEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }

  /// Chemin vers les sessions kart de l'utilisateur
  static String getUserSessionPath() {
    final userId = getCurrentUserId();
    return 'users/$userId/sessions';
  }

  /// Chemin vers les sessions KMRS de l'utilisateur
  static String getUserKmrsPath() {
    final userId = getCurrentUserId();
    return 'users/$userId/kmrs_sessions';
  }

  /// Chemin vers les indicateurs de performance de l'utilisateur
  static String getUserPerformancePath() {
    final userId = getCurrentUserId();
    return 'users/$userId/performance_indicator';
  }

  /// Chemin vers une session kart spécifique de l'utilisateur
  static String getUserSessionDoc([String sessionId = 'session1']) {
    return '${getUserSessionPath()}/$sessionId';
  }

  /// Chemin vers une session KMRS spécifique de l'utilisateur
  static String getUserKmrsDoc([String sessionId = 'kmrs_main_session']) {
    return '${getUserKmrsPath()}/$sessionId';
  }

  /// Chemin vers un indicateur de performance spécifique de l'utilisateur
  static String getUserPerformanceDoc([String sessionId = 'kmrs_main_session']) {
    return '${getUserPerformancePath()}/$sessionId';
  }

  /// Chemin vers les colonnes d'une session kart utilisateur
  static String getUserSessionColumnsPath([String sessionId = 'session1']) {
    return '${getUserSessionDoc(sessionId)}/columns';
  }

  /// Chemin vers une colonne spécifique d'une session kart utilisateur
  static String getUserSessionColumnDoc(int columnIndex, [String sessionId = 'session1']) {
    return '${getUserSessionColumnsPath(sessionId)}/col${columnIndex + 1}';
  }

  /// Chemin vers les entrées d'une colonne spécifique
  static String getUserSessionColumnEntriesPath(int columnIndex, [String sessionId = 'session1']) {
    return '${getUserSessionColumnDoc(columnIndex, sessionId)}/entries';
  }

  /// Chemins vers les données partagées (non spécifiques à l'utilisateur)
  static String getSharedCircuitsPath() {
    return 'circuits';
  }

  static String getSharedSecteurChoicesPath() {
    return 'secteur_choices';
  }

  /// Logging pour debugging multi-utilisateurs
  static void logUserSession(String operation) {
    if (kDebugMode) {
      final userId = isUserAuthenticated ? getCurrentUserId() : 'anonymous';
      final email = getCurrentUserEmail() ?? 'no-email';
      print('👤 UserSession[$operation]: User $userId ($email)');
    }
  }

  /// Migration helper - vérifie si l'utilisateur a déjà des données dans l'ancien format
  static Future<bool> hasLegacyData() async {
    // TODO: Implémenter la vérification des données dans l'ancien format
    // Vérifier si des données existent dans /sessions/session1 pour cet utilisateur
    return false;
  }

  /// Migration helper - migrer les données de l'ancien vers le nouveau format
  static Future<void> migrateLegacyData() async {
    if (kDebugMode) {
      print('🔄 UserSession: Starting legacy data migration for user ${getCurrentUserId()}');
    }
    // TODO: Implémenter la migration des données legacy
    // Copier /sessions/session1 -> /users/{userId}/sessions/session1
    // Copier /kmrs_sessions/kmrs_main_session -> /users/{userId}/kmrs_sessions/kmrs_main_session
  }

  /// Nettoyage des chemins utilisateur (pour tests ou reset)
  static Future<void> clearUserData() async {
    if (kDebugMode) {
      print('🗑️ UserSession: Clearing all data for user ${getCurrentUserId()}');
    }
    // TODO: Implémenter le nettoyage complet des données utilisateur
  }

  /// Validation de l'authentication avant opération critique
  static void ensureAuthenticated() {
    if (!isUserAuthenticated) {
      throw Exception('Operation requires user authentication');
    }
  }

  /// Helper pour créer des chemins dynamiques sécurisés
  static String createUserPath(String collection, [String? document]) {
    ensureAuthenticated();
    final userId = getCurrentUserId();
    final basePath = 'users/$userId/$collection';
    return document != null ? '$basePath/$document' : basePath;
  }
}