import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper pour créer des documents Firestore de test
class MockKartDocument {
  final String id;
  final Map<String, dynamic> data;

  MockKartDocument(this.id, this.data);

  QueryDocumentSnapshot<Map<String, dynamic>> toQueryDocumentSnapshot() {
    // Simulation d'un QueryDocumentSnapshot
    return _MockQueryDocumentSnapshot(id, data);
  }
}

class _MockQueryDocumentSnapshot extends QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;

  _MockQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => Map<String, dynamic>.from(_data);

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  dynamic get(Object field) => _data[field];

  // Implémentations minimales pour les autres méthodes requises
  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();

  @override
  bool get exists => true;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
}

class _MockQuerySnapshot extends QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  _MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  int get size => _docs.length;
}

/// Helper pour créer des données de test
class KartTestHelper {
  /// Crée un kart de test
  static MockKartDocument createKart(int number, String performance) {
    return MockKartDocument(
      'kart_$number',
      {
        'number': number,
        'perf': performance,
        'timestamp': Timestamp.now(),
      },
    );
  }

  /// Crée une liste de karts pour une colonne
  static List<MockKartDocument> createColumn(List<Map<String, dynamic>> karts) {
    return karts
        .asMap()
        .entries
        .map((entry) => MockKartDocument(
              'kart_${entry.key}',
              {
                'number': entry.value['number'],
                'perf': entry.value['perf'],
                'timestamp': Timestamp.now(),
              },
            ))
        .toList();
  }

  /// Crée un QuerySnapshot mock
  static QuerySnapshot<Map<String, dynamic>> createQuerySnapshot(
      List<MockKartDocument> karts) {
    final docs = karts.map((k) => k.toQueryDocumentSnapshot()).toList();
    return _MockQuerySnapshot(docs);
  }

  /// Crée des données de test pour plusieurs colonnes
  static List<QuerySnapshot<Map<String, dynamic>>> createColumnsData(
      List<List<Map<String, dynamic>>> columnsKarts) {
    return columnsKarts
        .map((columnKarts) => createQuerySnapshot(createColumn(columnKarts)))
        .toList();
  }
}

/// Helper pour les assertions de performance
class PerformanceAssertions {
  /// Vérifie que le pourcentage calculé est correct
  static void expectPercentage(
    WidgetTester tester,
    int expectedPercentage,
    String description,
  ) {
    // Chercher le texte du pourcentage dans l'indicateur
    final percentageFinder = find.textContaining('$expectedPercentage%');
    expect(
      percentageFinder,
      findsOneWidget,
      reason: 'Expected $expectedPercentage% for: $description',
    );
  }

  /// Vérifie l'état optimal
  static void expectOptimalState(
    WidgetTester tester,
    bool shouldBeOptimal,
    String description,
  ) {
    if (shouldBeOptimal) {
      final optimalFinder = find.textContaining('C\'EST LE MOMENT !');
      expect(
        optimalFinder,
        findsOneWidget,
        reason: 'Expected optimal state for: $description',
      );
    } else {
      final waitingFinder = find.textContaining('ATTENDRE...');
      expect(
        waitingFinder,
        findsOneWidget,
        reason: 'Expected waiting state for: $description',
      );
    }
  }

  /// Vérifie à la fois le pourcentage et l'état optimal
  static void expectState(
    WidgetTester tester,
    int expectedPercentage,
    bool shouldBeOptimal,
    String description,
  ) {
    expectPercentage(tester, expectedPercentage, description);
    expectOptimalState(tester, shouldBeOptimal, description);
  }
}

/// Configurations de test communes
class TestConfigurations {
  /// Configuration 2 colonnes (seuil 100%)
  static const config2Columns = {
    'numColumns': 2,
    'numRows': 3,
    'threshold': 100,
  };

  /// Configuration 3 colonnes (seuil 66%)
  static const config3Columns = {
    'numColumns': 3,
    'numRows': 3,
    'threshold': 66,
  };

  /// Configuration 4 colonnes (seuil 75%)
  static const config4Columns = {
    'numColumns': 4,
    'numRows': 3,
    'threshold': 75,
  };

  /// Couleurs de colonnes de test
  static const columnColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
  ];
}

/// Extension pour faciliter les tests
extension PerformanceTestExtension on WidgetTester {
  /// Attendre que les animations se terminent
  Future<void> pumpAndSettle({Duration? duration}) async {
    await pump();
    await pump(duration ?? const Duration(milliseconds: 100));
  }

  /// Vérifier rapidement un état de performance
  void verifyPerformance(int percentage, bool optimal, String context) {
    PerformanceAssertions.expectState(this, percentage, optimal, context);
  }
}