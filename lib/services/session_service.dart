import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class SessionService {
  static final _sessionRef = FirebaseService.db.collection('sessions').doc('session1');

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

  static Stream<QuerySnapshot<Map<String, dynamic>>> getColumnStream(int columnIndex, {int? limit}) {
    var query = _sessionRef
        .collection('columns')
        .doc('col${columnIndex + 1}')
        .collection('entries')
        .orderBy('timestamp', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    return query.snapshots();
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

  static Future<void> editKart(int columnIndex, String docId, int number, String perf) {
    return _sessionRef
        .collection('columns')
        .doc('col${columnIndex + 1}')
        .collection('entries')
        .doc(docId)
        .update({'number': number, 'perf': perf});
  }
}