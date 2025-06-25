import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèles de données pour la stratégie karting reproduisant KMRS.xlsm

/// Type de données dans une cellule de stratégie
enum StrategyCellType {
  text,
  number,
  time,
  percentage,
  boolean,
  formula,
  result
}

/// Une cellule de données dans une feuille de stratégie
class StrategyCell {
  final String id;
  final dynamic value;
  final StrategyCellType type;
  final String? formula;
  final bool isEditable;
  final Map<String, dynamic>? validation;
  final DateTime lastModified;

  const StrategyCell({
    required this.id,
    required this.value,
    required this.type,
    this.formula,
    this.isEditable = true,
    this.validation,
    required this.lastModified,
  });

  factory StrategyCell.fromMap(Map<String, dynamic> map) {
    return StrategyCell(
      id: map['id'] ?? '',
      value: map['value'],
      type: StrategyCellType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => StrategyCellType.text,
      ),
      formula: map['formula'],
      isEditable: map['isEditable'] ?? true,
      validation: map['validation'],
      lastModified: (map['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'value': value,
      'type': type.name,
      'formula': formula,
      'isEditable': isEditable,
      'validation': validation,
      'lastModified': Timestamp.fromDate(lastModified),
    };
  }

  StrategyCell copyWith({
    String? id,
    dynamic value,
    StrategyCellType? type,
    String? formula,
    bool? isEditable,
    Map<String, dynamic>? validation,
    DateTime? lastModified,
  }) {
    return StrategyCell(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      formula: formula ?? this.formula,
      isEditable: isEditable ?? this.isEditable,
      validation: validation ?? this.validation,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  /// Calcule la valeur si c'est une formule
  dynamic calculateValue(Map<String, dynamic> context) {
    if (type == StrategyCellType.formula && formula != null) {
      return _evaluateFormula(formula!, context);
    }
    return value;
  }

  /// Évalue une formule simple (à étendre selon les besoins KMRS)
  dynamic _evaluateFormula(String formula, Map<String, dynamic> context) {
    try {
      // Formules de base pour commencer
      if (formula.startsWith('SUM(')) {
        return _evaluateSum(formula, context);
      }
      if (formula.startsWith('AVERAGE(')) {
        return _evaluateAverage(formula, context);
      }
      if (formula.startsWith('IF(')) {
        return _evaluateIf(formula, context);
      }
      if (formula.startsWith('MAX(')) {
        return _evaluateMax(formula, context);
      }
      if (formula.startsWith('MIN(')) {
        return _evaluateMin(formula, context);
      }
      
      // TODO: Ajouter plus de formules selon les besoins KMRS
      return value;
    } catch (e) {
      return '#ERROR';
    }
  }

  double _evaluateSum(String formula, Map<String, dynamic> context) {
    final refs = _extractCellReferences(formula);
    double sum = 0;
    for (final ref in refs) {
      final val = context[ref];
      if (val is num) sum += val.toDouble();
    }
    return sum;
  }

  double _evaluateAverage(String formula, Map<String, dynamic> context) {
    final refs = _extractCellReferences(formula);
    double sum = 0;
    int count = 0;
    for (final ref in refs) {
      final val = context[ref];
      if (val is num) {
        sum += val.toDouble();
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }

  dynamic _evaluateIf(String formula, Map<String, dynamic> context) {
    // Implémentation simplifiée d'IF
    // TODO: Parser plus sophistiqué selon besoins KMRS
    return value;
  }

  double _evaluateMax(String formula, Map<String, dynamic> context) {
    final refs = _extractCellReferences(formula);
    double max = double.negativeInfinity;
    for (final ref in refs) {
      final val = context[ref];
      if (val is num && val.toDouble() > max) {
        max = val.toDouble();
      }
    }
    return max == double.negativeInfinity ? 0 : max;
  }

  double _evaluateMin(String formula, Map<String, dynamic> context) {
    final refs = _extractCellReferences(formula);
    double min = double.infinity;
    for (final ref in refs) {
      final val = context[ref];
      if (val is num && val.toDouble() < min) {
        min = val.toDouble();
      }
    }
    return min == double.infinity ? 0 : min;
  }

  List<String> _extractCellReferences(String formula) {
    // Extraction basique des références de cellules (A1, B2, etc.)
    final regex = RegExp(r'[A-Z]+\d+');
    return regex.allMatches(formula).map((m) => m.group(0)!).toList();
  }
}

/// Section de données dans une feuille de stratégie
class StrategySection {
  final String id;
  final String name;
  final String description;
  final Map<String, StrategyCell> cells;
  final int rowStart;
  final int colStart;
  final int rowEnd;
  final int colEnd;
  final bool isCollapsed;

  const StrategySection({
    required this.id,
    required this.name,
    this.description = '',
    required this.cells,
    required this.rowStart,
    required this.colStart,
    required this.rowEnd,
    required this.colEnd,
    this.isCollapsed = false,
  });

  factory StrategySection.fromMap(Map<String, dynamic> map) {
    final cellsMap = <String, StrategyCell>{};
    if (map['cells'] != null) {
      (map['cells'] as Map<String, dynamic>).forEach((key, value) {
        cellsMap[key] = StrategyCell.fromMap(value);
      });
    }

    return StrategySection(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      cells: cellsMap,
      rowStart: map['rowStart'] ?? 0,
      colStart: map['colStart'] ?? 0,
      rowEnd: map['rowEnd'] ?? 0,
      colEnd: map['colEnd'] ?? 0,
      isCollapsed: map['isCollapsed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final cellsMap = <String, dynamic>{};
    cells.forEach((key, value) {
      cellsMap[key] = value.toMap();
    });

    return {
      'id': id,
      'name': name,
      'description': description,
      'cells': cellsMap,
      'rowStart': rowStart,
      'colStart': colStart,
      'rowEnd': rowEnd,
      'colEnd': colEnd,
      'isCollapsed': isCollapsed,
    };
  }

  /// Recalcule toutes les formules de la section
  StrategySection recalculate() {
    final context = <String, dynamic>{};
    
    // Créer le contexte avec toutes les valeurs
    cells.forEach((key, cell) {
      if (cell.type != StrategyCellType.formula) {
        context[key] = cell.value;
      }
    });

    // Calculer les formules
    final updatedCells = <String, StrategyCell>{};
    cells.forEach((key, cell) {
      if (cell.type == StrategyCellType.formula) {
        final calculatedValue = cell.calculateValue(context);
        updatedCells[key] = cell.copyWith(value: calculatedValue);
        context[key] = calculatedValue;
      } else {
        updatedCells[key] = cell;
      }
    });

    return StrategySection(
      id: id,
      name: name,
      description: description,
      cells: updatedCells,
      rowStart: rowStart,
      colStart: colStart,
      rowEnd: rowEnd,
      colEnd: colEnd,
      isCollapsed: isCollapsed,
    );
  }
}

/// Feuille de stratégie reproduisant une feuille Excel
class StrategySheet {
  final String id;
  final String name;
  final String description;
  final int order;
  final List<StrategySection> sections;
  final Map<String, dynamic> metadata;
  final DateTime lastModified;

  const StrategySheet({
    required this.id,
    required this.name,
    this.description = '',
    required this.order,
    required this.sections,
    this.metadata = const {},
    required this.lastModified,
  });

  factory StrategySheet.fromMap(Map<String, dynamic> map) {
    final sectionsList = <StrategySection>[];
    if (map['sections'] != null) {
      for (final sectionData in map['sections']) {
        sectionsList.add(StrategySection.fromMap(sectionData));
      }
    }

    return StrategySheet(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      order: map['order'] ?? 0,
      sections: sectionsList,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      lastModified: (map['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'order': order,
      'sections': sections.map((s) => s.toMap()).toList(),
      'metadata': metadata,
      'lastModified': Timestamp.fromDate(lastModified),
    };
  }

  /// Recalcule toutes les formules de la feuille
  StrategySheet recalculate() {
    final recalculatedSections = sections.map((section) => section.recalculate()).toList();
    
    return StrategySheet(
      id: id,
      name: name,
      description: description,
      order: order,
      sections: recalculatedSections,
      metadata: metadata,
      lastModified: DateTime.now(),
    );
  }

  /// Obtient une cellule par référence (ex: "A1")
  StrategyCell? getCell(String reference) {
    for (final section in sections) {
      if (section.cells.containsKey(reference)) {
        return section.cells[reference];
      }
    }
    return null;
  }

  /// Met à jour une cellule
  StrategySheet updateCell(String reference, dynamic value) {
    final updatedSections = <StrategySection>[];
    
    for (final section in sections) {
      if (section.cells.containsKey(reference)) {
        final updatedCells = Map<String, StrategyCell>.from(section.cells);
        final oldCell = updatedCells[reference]!;
        updatedCells[reference] = oldCell.copyWith(
          value: value,
          lastModified: DateTime.now(),
        );
        
        updatedSections.add(StrategySection(
          id: section.id,
          name: section.name,
          description: section.description,
          cells: updatedCells,
          rowStart: section.rowStart,
          colStart: section.colStart,
          rowEnd: section.rowEnd,
          colEnd: section.colEnd,
          isCollapsed: section.isCollapsed,
        ));
      } else {
        updatedSections.add(section);
      }
    }
    
    final updatedSheet = StrategySheet(
      id: id,
      name: name,
      description: description,
      order: order,
      sections: updatedSections,
      metadata: metadata,
      lastModified: DateTime.now(),
    );
    
    // Recalculer après mise à jour
    return updatedSheet.recalculate();
  }
}

/// Document de stratégie complet reproduisant KMRS.xlsm
class StrategyDocument {
  final String id;
  final String name;
  final String description;
  final List<StrategySheet> sheets;
  final String version;
  final DateTime createdAt;
  final DateTime lastModified;
  final Map<String, dynamic> settings;

  const StrategyDocument({
    required this.id,
    required this.name,
    this.description = '',
    required this.sheets,
    this.version = '1.0',
    required this.createdAt,
    required this.lastModified,
    this.settings = const {},
  });

  factory StrategyDocument.fromMap(Map<String, dynamic> map) {
    final sheetsList = <StrategySheet>[];
    if (map['sheets'] != null) {
      for (final sheetData in map['sheets']) {
        sheetsList.add(StrategySheet.fromMap(sheetData));
      }
    }

    return StrategyDocument(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      sheets: sheetsList,
      version: map['version'] ?? '1.0',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (map['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sheets': sheets.map((s) => s.toMap()).toList(),
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModified': Timestamp.fromDate(lastModified),
      'settings': settings,
    };
  }

  /// Obtient une feuille par nom
  StrategySheet? getSheet(String name) {
    try {
      return sheets.firstWhere((sheet) => sheet.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Obtient une feuille par index
  StrategySheet? getSheetByIndex(int index) {
    if (index >= 0 && index < sheets.length) {
      return sheets[index];
    }
    return null;
  }

  /// Met à jour une feuille
  StrategyDocument updateSheet(String sheetName, StrategySheet updatedSheet) {
    final updatedSheets = sheets.map((sheet) {
      return sheet.name == sheetName ? updatedSheet : sheet;
    }).toList();

    return StrategyDocument(
      id: id,
      name: name,
      description: description,
      sheets: updatedSheets,
      version: version,
      createdAt: createdAt,
      lastModified: DateTime.now(),
      settings: settings,
    );
  }

  /// Recalcule toutes les formules du document
  StrategyDocument recalculateAll() {
    final recalculatedSheets = sheets.map((sheet) => sheet.recalculate()).toList();
    
    return StrategyDocument(
      id: id,
      name: name,
      description: description,
      sheets: recalculatedSheets,
      version: version,
      createdAt: createdAt,
      lastModified: DateTime.now(),
      settings: settings,
    );
  }

  /// Crée un document de stratégie exemple pour les tests
  static StrategyDocument createExample() {
    final now = DateTime.now();
    
    // Exemple de structure que nous ajusterons selon votre analyse KMRS
    return StrategyDocument(
      id: 'kmrs_strategy_${now.millisecondsSinceEpoch}',
      name: 'Stratégie KMRS',
      description: 'Document de stratégie karting reproduisant KMRS.xlsm',
      sheets: [
        StrategySheet(
          id: 'overview',
          name: 'Vue d\'ensemble',
          description: 'Vue d\'ensemble et paramètres généraux',
          order: 0,
          sections: [],
          lastModified: now,
        ),
        StrategySheet(
          id: 'times',
          name: 'Temps',
          description: 'Analyse des temps de tour',
          order: 1,
          sections: [],
          lastModified: now,
        ),
        StrategySheet(
          id: 'performance',
          name: 'Performance',
          description: 'Calculs de performance',
          order: 2,
          sections: [],
          lastModified: now,
        ),
        StrategySheet(
          id: 'strategy',
          name: 'Stratégie',
          description: 'Recommandations stratégiques',
          order: 3,
          sections: [],
          lastModified: now,
        ),
        StrategySheet(
          id: 'results',
          name: 'Résultats',
          description: 'Résultats et conclusions',
          order: 4,
          sections: [],
          lastModified: now,
        ),
      ],
      version: '1.0',
      createdAt: now,
      lastModified: now,
      settings: {
        'autoCalculate': true,
        'precision': 2,
        'theme': 'racing',
      },
    );
  }
}