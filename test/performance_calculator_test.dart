import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'test_helpers.dart';

/// Tests purs pour la logique de calcul de performance (sans widget)
void main() {
  group('Performance Calculator Logic Tests', () {
    
    /// Extrait et teste la logique de calcul directement
    int calculatePerformance({
      required List<List<Map<String, dynamic>>> columnsData,
      required int numColumns,
    }) {
      // Reproduction de la logique exacte du widget
      final allKarts = <Map<String, dynamic>>[];
      final kartNumbers = <int>[];

      for (var columnKarts in columnsData) {
        for (var kartData in columnKarts) {
          allKarts.add(kartData);
          kartNumbers.add(kartData['number'] as int);
        }
      }

      // Calculer les bonnes performances (logique exacte du widget)
      int good = 0;
      for (int colIndex = 0; colIndex < columnsData.length; colIndex++) {
        final docs = columnsData[colIndex];
        if (docs.isNotEmpty) {
          final firstKart = docs.first;
          final number = firstKart['number'] as int;
          final p = firstKart['perf'] as String;
          final appearances = kartNumbers.where((n) => n == number).length;

          print('Col$colIndex: Kart$number ($p) - appearances: $appearances');
          
          if (appearances == 1 && (p == '++' || p == '+')) {
            good++;
            print('  → COUNTED as GOOD (total good: $good)');
          } else {
            print('  → NOT counted (appearances: $appearances, perf: $p)');
          }
        } else {
          print('Col$colIndex: EMPTY');
        }
      }

      final currentKartCount = kartNumbers.length;
      final calculatedPct = currentKartCount > 0
          ? (good * 100 / numColumns).round()
          : 0;

      print('CALCULATION RESULT: $good good karts / $numColumns columns = $calculatedPct%');
      return calculatedPct;
    }

    group('Basic Calculation Tests', () {
      
      test('Empty columns return 0%', () {
        final result = calculatePerformance(
          columnsData: [[], [], []],
          numColumns: 3,
        );
        expect(result, equals(0));
      });

      test('1 good kart out of 3 columns = 33%', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [],
            [],
          ],
          numColumns: 3,
        );
        expect(result, equals(33));
      });

      test('2 good karts out of 3 columns = 66%', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '+'}],
            [],
          ],
          numColumns: 3,
        );
        expect(result, equals(67)); // (2*100/3).round() = 67
      });

      test('3 good karts out of 3 columns = 100%', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '+'}],
            [{'number': 3, 'perf': '++'}],
          ],
          numColumns: 3,
        );
        expect(result, equals(100));
      });
    });

    group('Performance Types Tests', () {
      
      test('++ and + count as good performances', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '+'}],
            [{'number': 3, 'perf': '~'}], // Should not count
          ],
          numColumns: 3,
        );
        expect(result, equals(67)); // 2 good out of 3
      });

      test('~, -, --, ? do not count as good performances', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '~'}],
            [{'number': 2, 'perf': '-'}],
            [{'number': 3, 'perf': '--'}],
          ],
          numColumns: 3,
        );
        expect(result, equals(0));
      });

      test('? performance does not count', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '?'}],
            [{'number': 2, 'perf': '++'}],
            [{'number': 3, 'perf': '+'}],
          ],
          numColumns: 3,
        );
        expect(result, equals(67)); // 2 good out of 3
      });
    });

    group('First Kart Only Logic Tests', () {
      
      test('Only first kart per column counts', () {
        final result = calculatePerformance(
          columnsData: [
            [
              {'number': 1, 'perf': '++'}, // First: should count
              {'number': 4, 'perf': '--'}, // Second: should not count
            ],
            [
              {'number': 2, 'perf': '-'},  // First: should not count (bad perf)
              {'number': 5, 'perf': '++'}, // Second: should not count
            ],
            [
              {'number': 3, 'perf': '+'},  // First: should count
            ],
          ],
          numColumns: 3,
        );
        expect(result, equals(67)); // 2 good firsts out of 3
      });
    });

    group('BUG DETECTION: Duplicate Kart Numbers', () {
      
      test('CRITICAL BUG: Duplicate kart numbers cause wrong calculation', () {
        // This test simulates what happens during drag & drop when the same kart
        // number appears temporarily in multiple columns
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}], // kart1 in col0
            [{'number': 1, 'perf': '++'}], // SAME kart1 in col1 (during drag)
            [],
          ],
          numColumns: 3,
        );
        
        // EXPECTED BUG: appearances will be 2, so "appearances == 1" condition fails
        // This means NO karts will be counted as good, resulting in 0%
        // CORRECT BEHAVIOR should be: each column's first kart counts independently
        
        print('\n🔍 CRITICAL TEST: Duplicate kart numbers');
        print('Expected if working correctly: 67% (2 good karts in 2 columns)');
        print('Expected if buggy: 0% (appearances == 1 condition fails)');
        print('Actual result: $result%');
        
        if (result == 0) {
          print('❌ BUG CONFIRMED: appearances == 1 condition causes problems with duplicates');
          print('💡 SOLUTION: Remove appearances == 1 condition or handle duplicates differently');
        } else if (result == 67) {
          print('✅ WORKING CORRECTLY: Duplicates handled properly');
        } else {
          print('❓ UNEXPECTED RESULT: Neither 0% nor 67% - needs investigation');
        }
        
        // For now, we expect the bug to manifest as 0%
        // When fixed, this should be 67%
        expect(result, equals(0), reason: 'Bug: appearances == 1 fails with duplicates');
      });

      test('Multiple duplicate scenarios', () {
        // Scenario: All columns have the same kart number
        final result1 = calculatePerformance(
          columnsData: [
            [{'number': 5, 'perf': '++'}],
            [{'number': 5, 'perf': '+'}],
            [{'number': 5, 'perf': '++'}],
          ],
          numColumns: 3,
        );
        
        print('\n🔍 TEST: All columns same kart number');
        print('Actual result: $result1%');
        expect(result1, equals(0), reason: 'Bug: appearances == 1 fails when kart appears 3 times');

        // Scenario: Two columns with same number, one different
        final result2 = calculatePerformance(
          columnsData: [
            [{'number': 7, 'perf': '++'}],
            [{'number': 7, 'perf': '+'}],
            [{'number': 8, 'perf': '++'}],
          ],
          numColumns: 3,
        );
        
        print('\n🔍 TEST: Two same, one different');
        print('Actual result: $result2%');
        // Expected: kart7 appears twice (appearances=2), kart8 appears once (appearances=1)
        // Only kart8 should count, so 1 good out of 3 = 33%
        expect(result2, equals(33), reason: 'Only unique karts should count');
      });
    });

    group('Different Column Configurations', () {
      
      test('2 columns configuration (100% threshold)', () {
        // 1 good out of 2 = 50%
        final result1 = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [],
          ],
          numColumns: 2,
        );
        expect(result1, equals(50));

        // 2 good out of 2 = 100%
        final result2 = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '+'}],
          ],
          numColumns: 2,
        );
        expect(result2, equals(100));
      });

      test('4 columns configuration (75% threshold)', () {
        // 3 good out of 4 = 75%
        final result1 = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '+'}],
            [{'number': 3, 'perf': '+'}],
            [],
          ],
          numColumns: 4,
        );
        expect(result1, equals(75));

        // 2 good out of 4 = 50%
        final result2 = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '+'}],
            [],
            [],
          ],
          numColumns: 4,
        );
        expect(result2, equals(50));
      });
    });

    group('Edge Cases', () {
      
      test('All excellent performances', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '++'}],
            [{'number': 2, 'perf': '++'}],
            [{'number': 3, 'perf': '++'}],
          ],
          numColumns: 3,
        );
        expect(result, equals(100));
      });

      test('All bad performances', () {
        final result = calculatePerformance(
          columnsData: [
            [{'number': 1, 'perf': '--'}],
            [{'number': 2, 'perf': '--'}],
            [{'number': 3, 'perf': '--'}],
          ],
          numColumns: 3,
        );
        expect(result, equals(0));
      });

      test('Mixed performances with multiple karts per column', () {
        final result = calculatePerformance(
          columnsData: [
            [
              {'number': 1, 'perf': '++'}, // First: good
              {'number': 4, 'perf': '--'}, // Second: ignored
              {'number': 7, 'perf': '++'}, // Third: ignored
            ],
            [
              {'number': 2, 'perf': '~'},  // First: not good
              {'number': 5, 'perf': '++'}, // Second: ignored
            ],
            [
              {'number': 3, 'perf': '+'},  // First: good
              {'number': 6, 'perf': '~'},  // Second: ignored
            ],
          ],
          numColumns: 3,
        );
        expect(result, equals(67)); // 2 good firsts out of 3
      });
    });
  });
}