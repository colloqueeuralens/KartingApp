import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class SessionService {
  static final _sessionRef = FirebaseService.db
      .collection('sessions')
      .doc('session1');

  static Stream<DocumentSnapshot<Map<String, dynamic>>> getSessionStream() {
    return _sessionRef.snapshots();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getSession() {
    return _sessionRef.get();
  }

  static Future<void> updateConfiguration({
    required int numColumns,
    required int numRows,
    required List<String> columnColors,
    String? selectedCircuitId,
  }) async {
    await _sessionRef.set({
      'numColumns': numColumns,
      'numRows': numRows,
      'columnColors': columnColors,
      'selectedCircuitId': selectedCircuitId,
    }, SetOptions(merge: true));
  }

  static Future<void> clearKartEntries(int numColumns) async {
    for (int i = 1; i <= numColumns; i++) {
      final entriesRef = _sessionRef
          .collection('columns')
          .doc('col$i')
          .collection('entries');
      final snap = await entriesRef.get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getColumnStream(
    int columnIndex, {
    int? limit = 10,
  }) {
    final finalLimit = limit ?? 10;

    return _sessionRef
        .collection('columns')
        .doc('col${columnIndex + 1}')
        .collection('entries')
        .orderBy('timestamp', descending: true)
        .limit(finalLimit)
        .snapshots()
        .map((snapshot) {
          // Diagnostic de performance simple
          return snapshot;
        });
  }

  static Future<void> addKart(int columnIndex, int number, String perf) {
    return _sessionRef
        .collection('columns')
        .doc('col${columnIndex + 1}')
        .collection('entries')
        .add({
          'number': number,
          'perf': perf,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> editKart(
    int columnIndex,
    String docId,
    int number,
    String perf,
  ) {
    return _sessionRef
        .collection('columns')
        .doc('col${columnIndex + 1}')
        .collection('entries')
        .doc(docId)
        .update({'number': number, 'perf': perf});
  }

  static Future<void> deleteKart(int columnIndex, String docId) {
    return _sessionRef
        .collection('columns')
        .doc('col${columnIndex + 1}')
        .collection('entries')
        .doc(docId)
        .delete();
  }

  static Future<void> moveKart(
    int fromColumnIndex,
    int toColumnIndex,
    String docId,
    int number,
    String perf,
  ) async {
    // Transaction optimisée pour réduire les événements de stream multiples
    await FirebaseService.db.runTransaction((transaction) async {
      // Références des documents
      final fromDocRef = _sessionRef
          .collection('columns')
          .doc('col${fromColumnIndex + 1}')
          .collection('entries')
          .doc(docId);

      final toColRef = _sessionRef
          .collection('columns')
          .doc('col${toColumnIndex + 1}')
          .collection('entries');

      // Créer d'abord dans la nouvelle colonne
      final newDocRef = toColRef.doc();
      transaction.set(newDocRef, {
        'number': number,
        'perf': perf,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Supprimer de la colonne source après création
      transaction.delete(fromDocRef);
    });
  }
}
