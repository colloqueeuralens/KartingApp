import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  /// Initialise Firebase avec optimisations de performance
  static Future<void> enableOfflinePersistence() async {
    try {
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true)
      );
    } catch (e) {
    }
  }

  static FirebaseFirestore get db => _db;

  static Future<void> ensureConfigExists() async {
    final ref = _db.collection('sessions').doc('session1');
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'numColumns': 3,
        'numRows': 3,
        'columnColors': ['Bleu', 'Blanc', 'Rouge'],
      });
    }
  }

  static Future<void> ensureSecteurChoicesExist() async {
    final ref = _db.collection('secteur_choices');
    final snap = await ref.get();

    if (snap.docs.isEmpty) {
      // Initialiser les choix par défaut
      final defaultChoices = [
        "Classement",
        "Kart",
        "Equipe/Pilote",
        "S1",
        "S2",
        "S3",
        "Dernier T.",
        "Ecart",
        "Meilleur T.",
        "En Piste",
        "Stands",
        "Lap",
        "",
        "Intervalles",
        "Penalites",
        "Categorie",
      ];

      for (final choice in defaultChoices) {
        await ref.add({
          'nom': choice,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
