import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_service.dart';

class CircuitService {
  static final _collection = FirebaseService.db.collection('circuits');
  static final _secteurChoicesCollection = FirebaseService.db.collection(
    'secteur_choices',
  );

  static Stream<QuerySnapshot<Map<String, dynamic>>> getCircuitsStream() {
    return _collection.orderBy('nom').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getSecteurChoicesStream() {
    return _secteurChoicesCollection.orderBy('nom').snapshots();
  }

  static Future<void> createCircuit({
    required String nom,
    required String liveTimingUrl,
    required String wssUrl,
    required List<String?> cValues,
  }) async {
    final circuitData = {
      'nom': nom,
      'liveTimingUrl': liveTimingUrl,
      'wssUrl': wssUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Ajouter C1-C14
    for (int i = 0; i < 14; i++) {
      circuitData['c${i + 1}'] = cValues[i] ?? 'Non utilisé';
    }

    await _collection.add(circuitData);
  }

  static Future<void> addSecteurChoice(String nom) async {
    await _secteurChoicesCollection.add({
      'nom': nom,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Récupère le nom du circuit par son ID
  static Future<String?> getCircuitName(String circuitId) async {
    try {
      final doc = await _collection.doc(circuitId).get();
      if (doc.exists) {
        return doc.data()?['nom'] as String?;
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération du nom du circuit: $e');
      return null;
    }
  }

  /// Vérifie si un circuit existe déjà avec le même nom ET URL
  static Future<bool> circuitExists(String nom, String liveTimingUrl) async {
    final query = await _collection
        .where('nom', isEqualTo: nom)
        .where('liveTimingUrl', isEqualTo: liveTimingUrl)
        .get();
    
    return query.docs.isNotEmpty;
  }

  /// Vérifie si un circuit a des mappings null/vides (nécessite une configuration manuelle)
  static bool hasNullMappings(Map<String, dynamic> circuitData) {
    int nullCount = 0;
    for (int i = 1; i <= 14; i++) {
      final value = circuitData['c$i'];
      if (value == null || value == 'Non utilisé' || value.toString().trim().isEmpty) {
        nullCount++;
      }
    }
    // Si moins de 3 colonnes sont configurées, considérer comme nécessitant une configuration
    final configuredCount = 14 - nullCount;
    return configuredCount < 3;
  }

  /// Met à jour les mappings d'un circuit existant
  static Future<void> updateCircuitMappings(String circuitId, Map<String, String> mappings) async {
    final updateData = <String, dynamic>{};
    
    // Mettre à jour C1-C14 avec les nouveaux mappings
    for (int i = 1; i <= 14; i++) {
      final key = 'c$i';
      updateData[key] = mappings[key] ?? 'Non utilisé';
    }
    
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    await _collection.doc(circuitId).update(updateData);
  }

  /// Importe des circuits depuis un fichier JSON
  static Future<Map<String, int>> importCircuitsFromJson(String jsonContent) async {
    try {
      // Vérifier que Firebase est initialisé
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase n\'est pas initialisé');
      }

      final Map<String, dynamic> data = json.decode(jsonContent);

      int importedCount = 0;
      int skippedCount = 0;
      List<String> skippedCircuits = [];

      for (final entry in data.entries) {
        final circuitName = entry.key;
        final circuitData = entry.value as Map<String, dynamic>;

        // Extraire les données
        final url = circuitData['url'] as String? ?? '';
        final websocketUrl = circuitData['wssUrl'] as String? ?? '';
        final mapping = circuitData['mapping'] as Map<String, dynamic>? ?? {};

        // Vérifier si le circuit existe déjà
        final exists = await circuitExists(circuitName, url);
        if (exists) {
          skippedCount++;
          skippedCircuits.add(circuitName);
          print('Circuit "$circuitName" ignoré (doublon détecté)');
          continue;
        }

        // Convertir le mapping en Map<String, String> et créer les cValues
        final List<String?> cValues = List.filled(14, null);
        for (int i = 1; i <= 14; i++) {
          final key = 'C$i';
          final value = mapping[key] as String?;
          if (value != null && value.isNotEmpty) {
            cValues[i - 1] = value;
          }
        }

        // Créer le circuit
        await createCircuit(
          nom: circuitName,
          liveTimingUrl: url,
          wssUrl: websocketUrl,
          cValues: cValues,
        );

        importedCount++;
        print('Circuit "$circuitName" importé avec succès');
      }

      print('Import terminé: $importedCount circuits importés, $skippedCount ignorés');
      
      return {
        'imported': importedCount,
        'skipped': skippedCount,
      };
    } catch (e, stackTrace) {
      print('Erreur lors de l\'import dans CircuitService: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
