import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/session_service.dart';

/// Grille & gestion des karts
class KartGridView extends StatelessWidget {
  final int numColumns, numRows;
  final List<Color> columnColors;
  final bool readOnly;

  const KartGridView({
    super.key,
    required this.numColumns,
    required this.numRows,
    required this.columnColors,
    required this.readOnly,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _colStream(int c) =>
      SessionService.getColumnStream(c, limit: numRows);

  Stream<List<QuerySnapshot<Map<String, dynamic>>>> get _allCols =>
      CombineLatestStream.list(List.generate(numColumns, (c) => _colStream(c)));

  Future<void> _addKart(int col, int num, String perf) {
    if (readOnly) return Future.value();
    return SessionService.addKart(col, num, perf);
  }

  Future<void> _editKart(int col, String docId, int num, String perf) {
    if (readOnly) return Future.value();
    return SessionService.editKart(col, docId, num, perf);
  }

  void _showKartDialog(
    BuildContext ctx,
    int col, {
    required Set<int> usedNumbers,
    int? initialNumber,
    String? initialPerf,
    required void Function(int, String) onConfirm,
  }) {
    final blocked = Set<int>.from(usedNumbers);
    if (initialNumber != null) blocked.remove(initialNumber);
    final available = List.generate(
      99,
      (i) => i + 1,
    ).where((n) => !blocked.contains(n)).toList();
    int? selNum = initialNumber;
    String? selPerf = initialPerf;
    const opts = ['++', '+', '~', '-', '--', '?'];

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) {
          return AlertDialog(
            title: Text(
              initialNumber == null
                  ? 'Ajouter un kart (col ${col + 1})'
                  : 'Modifier Kart (col ${col + 1})',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text('Numéro de kart'),
                  value: selNum,
                  items: available
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => setDialog(() => selNum = v),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Performance'),
                  value: selPerf,
                  items: opts
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, style: const TextStyle(fontSize: 18)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => selPerf = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: selNum != null && selPerf != null
                    ? () {
                        onConfirm(selNum!, selPerf!);
                        Navigator.pop(dCtx);
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      stream: _allCols,
      builder: (ctx, snapCols) {
        if (snapCols.hasError)
          return Center(child: Text('Erreur karts : ${snapCols.error}'));
        if (!snapCols.hasData)
          return const Center(child: CircularProgressIndicator());
        final colsData = snapCols.data!.map((s) => s.docs).toList();
        final usedNumbers = <int>{
          for (var docs in colsData)
            for (var d in docs) d.data()['number'] as int,
        };

        int good = 0;
        for (var docs in colsData) {
          if (docs.isNotEmpty) {
            final p = docs.first.data()['perf'] as String;
            if (p == '++' || p == '+') good++;
          }
        }
        final pct = (good * 100 / numColumns).round();
        final threshold = numColumns == 2
            ? 100
            : numColumns == 3
            ? 66
            : numColumns == 4
            ? 75
            : 100;
        final isOpt = pct >= threshold;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOpt
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                border: Border.all(
                  color: isOpt ? Colors.green : Colors.red,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    isOpt ? '🟢 C\'EST LE MOMENT !' : '🔴 ATTENDRE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isOpt ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pct% (Seuil: $threshold%)',
                    style: TextStyle(
                      fontSize: 16,
                      color: isOpt ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: List.generate(numColumns, (col) {
                  final docs = colsData[col];
                  final full = docs.length >= numRows;
                  return Expanded(
                    child: Container(
                      color: columnColors[col].withOpacity(0.1),
                      margin: const EdgeInsets.all(2),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final doc = docs[i];
                                final data = doc.data();
                                final number = data['number'] as int;
                                final perf = data['perf'] as String;
                                final bgColor = (perf == '++' || perf == '+')
                                    ? Colors.green.withOpacity(0.3)
                                    : (perf == '--' || perf == '-')
                                    ? Colors.red.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.1);
                                return Card(
                                  color: bgColor,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      'Kart $number',
                                      textAlign: TextAlign.center,
                                    ),
                                    subtitle: Text(
                                      perf,
                                      textAlign: TextAlign.center,
                                    ),
                                    onTap: readOnly
                                        ? null
                                        : () => _showKartDialog(
                                            context,
                                            col,
                                            usedNumbers: usedNumbers,
                                            initialNumber: number,
                                            initialPerf: perf,
                                            onConfirm: (n, p) =>
                                                _editKart(col, doc.id, n, p),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!readOnly)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ElevatedButton.icon(
                                onPressed: () => _showKartDialog(
                                  context,
                                  col,
                                  usedNumbers: usedNumbers,
                                  onConfirm: (n, p) => _addKart(col, n, p),
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(full ? 'Nouveau' : 'Ajouter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: full
                                      ? Colors.orange
                                      : Colors.blue,
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}