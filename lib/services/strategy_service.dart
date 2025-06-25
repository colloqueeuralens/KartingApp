import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/strategy_models.dart';

/// Service pour gérer les données de stratégie native (remplace le parsing KMRS)
class StrategyService extends ChangeNotifier {
  static final StrategyService _instance = StrategyService._internal();
  factory StrategyService() => _instance;
  StrategyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  StrategyDocument? _currentDocument;
  bool _isLoading = false;
  String? _error;

  /// Document de stratégie actuel
  StrategyDocument? get currentDocument => _currentDocument;
  
  /// État de chargement
  bool get isLoading => _isLoading;
  
  /// Message d'erreur
  String? get error => _error;
  
  /// Feuilles disponibles
  List<StrategySheet> get sheets => _currentDocument?.sheets ?? [];

  /// Charge ou crée le document de stratégie
  Future<void> loadOrCreateDocument() async {
    try {
      _setLoading(true);
      _setError(null);

      // Essayer de charger depuis Firebase
      final doc = await _firestore.collection('strategy').doc('main').get();
      
      if (doc.exists && doc.data() != null) {
        _currentDocument = StrategyDocument.fromMap(doc.data()!);
      } else {
        // Créer un document exemple basé sur KMRS
        _currentDocument = await _createKmrsDocument();
        await saveDocument();
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Erreur de chargement: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Sauvegarde le document dans Firebase
  Future<bool> saveDocument() async {
    if (_currentDocument == null) return false;

    try {
      await _firestore.collection('strategy').doc('main').set(_currentDocument!.toMap());
      return true;
    } catch (e) {
      _setError('Erreur de sauvegarde: $e');
      return false;
    }
  }

  /// Met à jour une cellule et recalcule
  Future<void> updateCell(String sheetName, String cellReference, dynamic value) async {
    if (_currentDocument == null) return;

    try {
      _setLoading(true);
      
      final sheet = _currentDocument!.getSheet(sheetName);
      if (sheet != null) {
        final updatedSheet = sheet.updateCell(cellReference, value);
        _currentDocument = _currentDocument!.updateSheet(sheetName, updatedSheet);
        
        // Auto-sauvegarde
        await saveDocument();
        notifyListeners();
      }
    } catch (e) {
      _setError('Erreur de mise à jour: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Recalcule toutes les formules
  Future<void> recalculateAll() async {
    if (_currentDocument == null) return;

    try {
      _setLoading(true);
      _currentDocument = _currentDocument!.recalculateAll();
      await saveDocument();
      notifyListeners();
    } catch (e) {
      _setError('Erreur de recalcul: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Obtient une feuille par nom
  StrategySheet? getSheet(String name) {
    return _currentDocument?.getSheet(name);
  }

  /// Obtient une feuille par index
  StrategySheet? getSheetByIndex(int index) {
    return _currentDocument?.getSheetByIndex(index);
  }

  /// Créé un document KMRS basé sur une structure typique de stratégie karting
  /// Créé un document KMRS basé sur l'analyse automatique du fichier KMRS.xlsm
  /// Structure analysée: 7 feuilles principales avec 473 formules complexes
  Future<StrategyDocument> _createKmrsDocument() async {
    final now = DateTime.now();
    
    return StrategyDocument(
      id: 'kmrs_strategy_main',
      name: 'Stratégie KMRS',
      description: 'Document de stratégie karting reproduisant les fonctionnalités KMRS.xlsm',
      sheets: [
        _createStartPageSheet(),
        _createMainPageSheet(),
        _createCalculationsSheet(),
        _createRacingSheet(),
        _createStintsListSheet(),
        _createRapportPilotesSheet(),
        _createSimulateurSheet(),
      ],
      version: '1.0',
      createdAt: now,
      lastModified: now,
      settings: {
        'autoCalculate': true,
        'precision': 3,
        'theme': 'racing',
        'units': 'metric',
      },
    );
  }

  /// Feuille 1: Start Page - Configuration et paramètres principaux
  StrategySheet _createStartPageSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête principal
    cells['A1'] = StrategyCell(
      id: 'A1',
      value: 'CONFIGURATION KMRS - SESSION KARTING',
      type: StrategyCellType.text,
      isEditable: false,
      lastModified: DateTime.now(),
    );
    
    // Paramètres de course
    cells['A3'] = StrategyCell(id: 'A3', value: 'Durée de course (min):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B3'] = StrategyCell(id: 'B3', value: 60, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A4'] = StrategyCell(id: 'A4', value: 'Nombre de pilotes:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B4'] = StrategyCell(id: 'B4', value: 2, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A5'] = StrategyCell(id: 'A5', value: 'Temps minimum par stint (min):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B5'] = StrategyCell(id: 'B5', value: 15, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A6'] = StrategyCell(id: 'A6', value: 'Circuit:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B6'] = StrategyCell(id: 'B6', value: 'Circuit de Lens', type: StrategyCellType.text, isEditable: true, lastModified: DateTime.now());
    
    cells['A7'] = StrategyCell(id: 'A7', value: 'Date:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B7'] = StrategyCell(id: 'B7', value: DateTime.now().toString().split(' ')[0], type: StrategyCellType.text, isEditable: true, lastModified: DateTime.now());
    
    // Paramètres carburant
    cells['A9'] = StrategyCell(id: 'A9', value: 'PARAMÈTRES CARBURANT', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['A10'] = StrategyCell(id: 'A10', value: 'Capacité réservoir (L):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B10'] = StrategyCell(id: 'B10', value: 8.5, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A11'] = StrategyCell(id: 'A11', value: 'Consommation (L/h):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B11'] = StrategyCell(id: 'B11', value: 4.2, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A12'] = StrategyCell(id: 'A12', value: 'Marge sécurité (L):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B12'] = StrategyCell(id: 'B12', value: 0.5, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    // Paramètres stratégiques
    cells['A14'] = StrategyCell(id: 'A14', value: 'STRATÉGIE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['A15'] = StrategyCell(id: 'A15', value: 'Temps arrêt pit (sec):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B15'] = StrategyCell(id: 'B15', value: 45, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A16'] = StrategyCell(id: 'A16', value: 'Objectif temps au tour:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B16'] = StrategyCell(id: 'B16', value: '1:25.500', type: StrategyCellType.time, isEditable: true, lastModified: DateTime.now());

    return StrategySheet(
      id: 'start_page',
      name: 'Start Page',
      description: 'Configuration générale et paramètres de session',
      order: 0,
      sections: [
        StrategySection(
          id: 'config',
          name: 'Configuration Course',
          description: 'Paramètres principaux de la session karting',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 20,
          colEnd: 4,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Feuille 2: Main Page - Interface principale de course
  StrategySheet _createMainPageSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête principal
    cells['A1'] = StrategyCell(id: 'A1', value: 'INTERFACE PRINCIPALE - TEMPS EN DIRECT', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Headers du tableau
    final headers = ['Tour', 'Temps', 'Delta', 'S1', 'S2', 'S3', 'Pilote', 'Position'];
    for (int i = 0; i < headers.length; i++) {
      cells['${String.fromCharCode(65 + i)}3'] = StrategyCell(
        id: '${String.fromCharCode(65 + i)}3',
        value: headers[i],
        type: StrategyCellType.text,
        isEditable: false,
        lastModified: DateTime.now(),
      );
    }
    
    // Données d'exemple des tours
    final exampleLaps = [
      [1, '1:26.543', '+0.000', '28.234', '31.125', '27.184', 'Pilote 1', 1],
      [2, '1:25.892', '-0.651', '28.156', '30.987', '26.749', 'Pilote 1', 1],
      [3, '1:25.234', '-1.309', '27.987', '30.876', '26.371', 'Pilote 1', 1],
      [4, '1:26.187', '-0.356', '28.123', '31.234', '26.830', 'Pilote 1', 1],
      [5, '1:24.987', '-1.556', '27.834', '30.654', '26.499', 'Pilote 1', 1],
      [6, '1:25.456', '-1.087', '28.001', '30.923', '26.532', 'Pilote 1', 1],
      [7, '1:25.123', '-1.420', '27.912', '30.789', '26.422', 'Pilote 1', 1],
      [8, '1:26.789', '+0.246', '28.345', '31.456', '26.988', 'Pilote 1', 1],
      [9, '1:25.678', '-0.865', '28.089', '31.012', '26.577', 'Pilote 1', 1],
      [10, '1:24.823', '-1.720', '27.756', '30.567', '26.500', 'Pilote 1', 1],
    ];
    
    for (int row = 0; row < exampleLaps.length; row++) {
      for (int col = 0; col < exampleLaps[row].length; col++) {
        final cellRef = '${String.fromCharCode(65 + col)}${row + 4}';
        final value = exampleLaps[row][col];
        
        cells[cellRef] = StrategyCell(
          id: cellRef,
          value: value,
          type: col == 0 || col == 7 ? StrategyCellType.number : 
                col == 1 || col == 3 || col == 4 || col == 5 ? StrategyCellType.time :
                col == 2 ? StrategyCellType.result : StrategyCellType.text,
          isEditable: col >= 6, // Pilote et position éditables
          lastModified: DateTime.now(),
        );
      }
    }

    return StrategySheet(
      id: 'main_page',
      name: 'Main Page',
      description: 'Interface principale de course et chronométrage',
      order: 1,
      sections: [
        StrategySection(
          id: 'live_timing',
          name: 'Temps en Direct',
          description: 'Chronométrage live et analyse par secteurs',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 20,
          colEnd: 8,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Feuille 3: Calculations v2 - Moteur de calcul principal
  StrategySheet _createCalculationsSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête
    cells['A1'] = StrategyCell(id: 'A1', value: 'MOTEUR DE CALCUL - ANALYSES PERFORMANCE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Section Statistiques Temps
    cells['A3'] = StrategyCell(id: 'A3', value: 'STATISTIQUES CHRONOMÉTRAGE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A4'] = StrategyCell(id: 'A4', value: 'Meilleur temps:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B4'] = StrategyCell(id: 'B4', value: '1:24.823', type: StrategyCellType.time, formula: 'MIN(MainPage!B4:B14)', isEditable: false, lastModified: DateTime.now());
    
    cells['A5'] = StrategyCell(id: 'A5', value: 'Temps moyen:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B5'] = StrategyCell(id: 'B5', value: '1:25.671', type: StrategyCellType.time, formula: 'AVERAGE(MainPage!B4:B14)', isEditable: false, lastModified: DateTime.now());
    
    cells['A6'] = StrategyCell(id: 'A6', value: 'Temps le plus lent:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B6'] = StrategyCell(id: 'B6', value: '1:26.789', type: StrategyCellType.time, formula: 'MAX(MainPage!B4:B14)', isEditable: false, lastModified: DateTime.now());
    
    cells['A7'] = StrategyCell(id: 'A7', value: 'Écart type:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B7'] = StrategyCell(id: 'B7', value: 0.672, type: StrategyCellType.number, formula: 'STDEV(MainPage!B4:B14)', isEditable: false, lastModified: DateTime.now());
    
    // Section Carburant
    cells['A9'] = StrategyCell(id: 'A9', value: 'CALCULS CARBURANT', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A10'] = StrategyCell(id: 'A10', value: 'Consommation tours:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B10'] = StrategyCell(id: 'B10', value: 2.45, type: StrategyCellType.number, formula: '(StartPage!B11/60)*(B5/60)', isEditable: false, lastModified: DateTime.now());
    
    cells['A11'] = StrategyCell(id: 'A11', value: 'Autonomie théorique:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B11'] = StrategyCell(id: 'B11', value: 34.7, type: StrategyCellType.number, formula: '(StartPage!B10-StartPage!B12)/B10', isEditable: false, lastModified: DateTime.now());
    
    cells['A12'] = StrategyCell(id: 'A12', value: 'Tours avant ravitaillement:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B12'] = StrategyCell(id: 'B12', value: 30, type: StrategyCellType.number, formula: 'FLOOR(B11*0.9)', isEditable: false, lastModified: DateTime.now());
    
    // Section Performance
    cells['A14'] = StrategyCell(id: 'A14', value: 'ANALYSE PERFORMANCE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A15'] = StrategyCell(id: 'A15', value: 'Consistency:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B15'] = StrategyCell(id: 'B15', value: 92.3, type: StrategyCellType.percentage, formula: '(1-(B7/B5))*100', isEditable: false, lastModified: DateTime.now());
    
    cells['A16'] = StrategyCell(id: 'A16', value: 'Potentiel gain:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B16'] = StrategyCell(id: 'B16', value: 0.848, type: StrategyCellType.time, formula: 'B5-B4', isEditable: false, lastModified: DateTime.now());
    
    cells['A17'] = StrategyCell(id: 'A17', value: 'Tours optimal/h:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B17'] = StrategyCell(id: 'B17', value: 42.1, type: StrategyCellType.number, formula: '3600/(B4*60)', isEditable: false, lastModified: DateTime.now());
    
    // Secteurs analyse
    cells['D3'] = StrategyCell(id: 'D3', value: 'ANALYSE SECTEURS', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['D4'] = StrategyCell(id: 'D4', value: 'Meilleur S1:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E4'] = StrategyCell(id: 'E4', value: '27.756', type: StrategyCellType.time, formula: 'MIN(MainPage!D4:D14)', isEditable: false, lastModified: DateTime.now());
    
    cells['D5'] = StrategyCell(id: 'D5', value: 'Meilleur S2:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E5'] = StrategyCell(id: 'E5', value: '30.567', type: StrategyCellType.time, formula: 'MIN(MainPage!E4:E14)', isEditable: false, lastModified: DateTime.now());
    
    cells['D6'] = StrategyCell(id: 'D6', value: 'Meilleur S3:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E6'] = StrategyCell(id: 'E6', value: '26.371', type: StrategyCellType.time, formula: 'MIN(MainPage!F4:F14)', isEditable: false, lastModified: DateTime.now());

    return StrategySheet(
      id: 'calculations',
      name: 'Calculations v2',
      description: 'Moteur de calcul et analyses approfondies',
      order: 2,
      sections: [
        StrategySection(
          id: 'calculations',
          name: 'Calculs Automatiques',
          description: 'Formules de performance et analyses statistiques',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 25,
          colEnd: 6,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Feuille 4: RACING - Interface de course en direct
  StrategySheet _createRacingSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête
    cells['A1'] = StrategyCell(id: 'A1', value: 'INTERFACE RACING - COURSE EN DIRECT', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Statut course
    cells['A3'] = StrategyCell(id: 'A3', value: 'STATUT COURSE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A4'] = StrategyCell(id: 'A4', value: 'Temps écoulé:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B4'] = StrategyCell(id: 'B4', value: '23:45', type: StrategyCellType.time, isEditable: true, lastModified: DateTime.now());
    
    cells['A5'] = StrategyCell(id: 'A5', value: 'Temps restant:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B5'] = StrategyCell(id: 'B5', value: '36:15', type: StrategyCellType.time, formula: 'StartPage!B3*60-B4', isEditable: false, lastModified: DateTime.now());
    
    cells['A6'] = StrategyCell(id: 'A6', value: 'Tours effectués:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B6'] = StrategyCell(id: 'B6', value: 10, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A7'] = StrategyCell(id: 'A7', value: 'Position actuelle:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B7'] = StrategyCell(id: 'B7', value: 3, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    // Informations stratégiques
    cells['A9'] = StrategyCell(id: 'A9', value: 'STRATÉGIE TEMPS RÉEL', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A10'] = StrategyCell(id: 'A10', value: 'Carburant restant:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B10'] = StrategyCell(id: 'B10', value: 5.2, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A11'] = StrategyCell(id: 'A11', value: 'Tours avant pit:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B11'] = StrategyCell(id: 'B11', value: 18, type: StrategyCellType.number, formula: 'B10/Calculations!B10', isEditable: false, lastModified: DateTime.now());
    
    cells['A12'] = StrategyCell(id: 'A12', value: 'Prochain arrêt:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B12'] = StrategyCell(id: 'B12', value: 'Tour 28', type: StrategyCellType.result, formula: 'B6+B11', isEditable: false, lastModified: DateTime.now());
    
    cells['A13'] = StrategyCell(id: 'A13', value: 'Type d\'arrêt:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B13'] = StrategyCell(id: 'B13', value: 'Changement pilote + Carburant', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Alertes
    cells['D3'] = StrategyCell(id: 'D3', value: 'ALERTES', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['D4'] = StrategyCell(id: 'D4', value: '⚠️ Carburant critique:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E4'] = StrategyCell(id: 'E4', value: false, type: StrategyCellType.boolean, formula: 'B10<1.0', isEditable: false, lastModified: DateTime.now());
    
    cells['D5'] = StrategyCell(id: 'D5', value: '🔥 Dernier tour rapide:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E5'] = StrategyCell(id: 'E5', value: true, type: StrategyCellType.boolean, isEditable: false, lastModified: DateTime.now());
    
    cells['D6'] = StrategyCell(id: 'D6', value: '🎯 Dans la fenêtre:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E6'] = StrategyCell(id: 'E6', value: true, type: StrategyCellType.boolean, isEditable: false, lastModified: DateTime.now());

    return StrategySheet(
      id: 'racing',
      name: 'RACING',
      description: 'Interface de course en direct et alertes stratégiques',
      order: 3,
      sections: [
        StrategySection(
          id: 'live_race',
          name: 'Course Live',
          description: 'Données temps réel et décisions stratégiques',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 20,
          colEnd: 6,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Feuille 5: Stints List - Gestion des relais et planification
  StrategySheet _createStintsListSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête
    cells['A1'] = StrategyCell(id: 'A1', value: 'GESTION DES RELAIS - PLANIFICATION STINTS', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Headers du tableau
    final headers = ['Stint', 'Pilote', 'Début', 'Fin', 'Durée', 'Tours', 'Carburant', 'Statut'];
    for (int i = 0; i < headers.length; i++) {
      cells['${String.fromCharCode(65 + i)}3'] = StrategyCell(
        id: '${String.fromCharCode(65 + i)}3',
        value: headers[i],
        type: StrategyCellType.text,
        isEditable: false,
        lastModified: DateTime.now(),
      );
    }
    
    // Stints planifiés
    final stints = [
      [1, 'Pilote 1', '14:00:00', '14:28:00', 28, 10, 6.5, 'Terminé'],
      [2, 'Pilote 2', '14:28:45', '14:56:30', 27.75, 10, 5.8, 'En cours'],
      [3, 'Pilote 1', '14:57:15', '15:25:00', 27.75, 10, 6.0, 'Planifié'],
      [4, 'Pilote 2', '15:25:45', '15:53:30', 27.75, 10, 5.5, 'Planifié'],
      [5, 'Pilote 1', '15:54:15', '16:00:00', 5.75, 2, 2.0, 'Final'],
    ];
    
    for (int row = 0; row < stints.length; row++) {
      for (int col = 0; col < stints[row].length; col++) {
        final cellRef = '${String.fromCharCode(65 + col)}${row + 4}';
        final value = stints[row][col];
        
        cells[cellRef] = StrategyCell(
          id: cellRef,
          value: value,
          type: col == 0 || col == 4 || col == 5 ? StrategyCellType.number :
                col == 2 || col == 3 ? StrategyCellType.time :
                col == 6 ? StrategyCellType.number : StrategyCellType.text,
          isEditable: col >= 1 && col <= 6, // Tout sauf stint # et statut
          lastModified: DateTime.now(),
        );
      }
    }
    
    // Résumé stratégique
    cells['A10'] = StrategyCell(id: 'A10', value: 'RÉSUMÉ STRATÉGIQUE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A11'] = StrategyCell(id: 'A11', value: 'Total tours prévus:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B11'] = StrategyCell(id: 'B11', value: 42, type: StrategyCellType.number, formula: 'SUM(F4:F8)', isEditable: false, lastModified: DateTime.now());
    
    cells['A12'] = StrategyCell(id: 'A12', value: 'Temps Pilote 1:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B12'] = StrategyCell(id: 'B12', value: 61.5, type: StrategyCellType.number, isEditable: false, lastModified: DateTime.now());
    
    cells['A13'] = StrategyCell(id: 'A13', value: 'Temps Pilote 2:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B13'] = StrategyCell(id: 'B13', value: 55.5, type: StrategyCellType.number, isEditable: false, lastModified: DateTime.now());
    
    cells['A14'] = StrategyCell(id: 'A14', value: 'Carburant total:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B14'] = StrategyCell(id: 'B14', value: 25.8, type: StrategyCellType.number, formula: 'SUM(G4:G8)', isEditable: false, lastModified: DateTime.now());
    
    cells['A15'] = StrategyCell(id: 'A15', value: 'Arrêts prévus:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B15'] = StrategyCell(id: 'B15', value: 4, type: StrategyCellType.number, isEditable: false, lastModified: DateTime.now());

    return StrategySheet(
      id: 'stints_list',
      name: 'Stints List',
      description: 'Planification et gestion des relais pilotes',
      order: 4,
      sections: [
        StrategySection(
          id: 'stints_planning',
          name: 'Planification Relais',
          description: 'Gestion des changements de pilotes et stratégie',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 20,
          colEnd: 8,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Feuille 6: Rapport Pilotes - Synthèse des résultats
  StrategySheet _createRapportPilotesSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête
    cells['A1'] = StrategyCell(id: 'A1', value: 'RAPPORT PILOTES - STATISTIQUES DÉTAILLÉES', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Headers statistiques
    final headers = ['Pilote', 'Tours', 'Meilleur', 'Moyen', 'Écart', 'Consistency', 'Temps Total'];
    for (int i = 0; i < headers.length; i++) {
      cells['${String.fromCharCode(65 + i)}3'] = StrategyCell(
        id: '${String.fromCharCode(65 + i)}3',
        value: headers[i],
        type: StrategyCellType.text,
        isEditable: false,
        lastModified: DateTime.now(),
      );
    }
    
    // Données pilotes
    final pilotsData = [
      ['Pilote 1', 21, '1:24.823', '1:25.456', '+0.633', '94.2%', '29:52.58'],
      ['Pilote 2', 21, '1:25.234', '1:25.987', '+1.164', '91.8%', '30:15.42'],
    ];
    
    for (int row = 0; row < pilotsData.length; row++) {
      for (int col = 0; col < pilotsData[row].length; col++) {
        final cellRef = '${String.fromCharCode(65 + col)}${row + 4}';
        final value = pilotsData[row][col];
        
        cells[cellRef] = StrategyCell(
          id: cellRef,
          value: value,
          type: col == 1 ? StrategyCellType.number :
                col == 2 || col == 3 || col == 6 ? StrategyCellType.time :
                col == 5 ? StrategyCellType.percentage : StrategyCellType.text,
          isEditable: false,
          lastModified: DateTime.now(),
        );
      }
    }
    
    // Analyses comparatives
    cells['A7'] = StrategyCell(id: 'A7', value: 'ANALYSE COMPARATIVE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A8'] = StrategyCell(id: 'A8', value: 'Pilote le plus rapide:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B8'] = StrategyCell(id: 'B8', value: 'Pilote 1', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    cells['A9'] = StrategyCell(id: 'A9', value: 'Écart moyen:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B9'] = StrategyCell(id: 'B9', value: 0.531, type: StrategyCellType.time, formula: 'B5-B4', isEditable: false, lastModified: DateTime.now());
    
    cells['A10'] = StrategyCell(id: 'A10', value: 'Plus consistent:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B10'] = StrategyCell(id: 'B10', value: 'Pilote 1', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    cells['A11'] = StrategyCell(id: 'A11', value: 'Total tours équipe:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B11'] = StrategyCell(id: 'B11', value: 42, type: StrategyCellType.number, formula: 'B4+B5', isEditable: false, lastModified: DateTime.now());
    
    cells['A12'] = StrategyCell(id: 'A12', value: 'Temps total course:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B12'] = StrategyCell(id: 'B12', value: '60:08.00', type: StrategyCellType.time, formula: 'G4+G5', isEditable: false, lastModified: DateTime.now());
    
    // Recommandations
    cells['D7'] = StrategyCell(id: 'D7', value: 'RECOMMANDATIONS', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['D8'] = StrategyCell(id: 'D8', value: '✓ Privilégier Pilote 1 en fin de course', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['D9'] = StrategyCell(id: 'D9', value: '⚠ Améliorer consistency Pilote 2', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['D10'] = StrategyCell(id: 'D10', value: '🎯 Objectif écart < 0.3s', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());

    return StrategySheet(
      id: 'rapport_pilotes',
      name: 'Rapport Pilotes',
      description: 'Analyse comparative et statistiques détaillées des pilotes',
      order: 5,
      sections: [
        StrategySection(
          id: 'pilot_analysis',
          name: 'Analyse Pilotes',
          description: 'Comparaison performance et recommandations stratégiques',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 15,
          colEnd: 7,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Feuille 7: Simulateur - Prédictions et optimisations stratégiques
  StrategySheet _createSimulateurSheet() {
    final cells = <String, StrategyCell>{};
    
    // En-tête
    cells['A1'] = StrategyCell(id: 'A1', value: 'SIMULATEUR STRATÉGIQUE - OPTIMISATION COURSE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    // Paramètres de simulation
    cells['A3'] = StrategyCell(id: 'A3', value: 'PARAMÈTRES SIMULATION', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A4'] = StrategyCell(id: 'A4', value: 'Objectif temps au tour:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B4'] = StrategyCell(id: 'B4', value: '1:25.000', type: StrategyCellType.time, isEditable: true, lastModified: DateTime.now());
    
    cells['A5'] = StrategyCell(id: 'A5', value: 'Marge dégradation (/tour):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B5'] = StrategyCell(id: 'B5', value: 0.025, type: StrategyCellType.number, isEditable: true, lastModified: DateTime.now());
    
    cells['A6'] = StrategyCell(id: 'A6', value: 'Risque météo (%):', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B6'] = StrategyCell(id: 'B6', value: 15, type: StrategyCellType.percentage, isEditable: true, lastModified: DateTime.now());
    
    cells['A7'] = StrategyCell(id: 'A7', value: 'Stratégie agressive:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B7'] = StrategyCell(id: 'B7', value: true, type: StrategyCellType.boolean, isEditable: true, lastModified: DateTime.now());
    
    // Prédictions
    cells['A9'] = StrategyCell(id: 'A9', value: 'PRÉDICTIONS COURSE', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A10'] = StrategyCell(id: 'A10', value: 'Tours prévus:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B10'] = StrategyCell(id: 'B10', value: 42, type: StrategyCellType.number, formula: '(StartPage!B3*60)/B4', isEditable: false, lastModified: DateTime.now());
    
    cells['A11'] = StrategyCell(id: 'A11', value: 'Temps final estimé:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B11'] = StrategyCell(id: 'B11', value: '59:30.00', type: StrategyCellType.time, formula: 'B10*B4', isEditable: false, lastModified: DateTime.now());
    
    cells['A12'] = StrategyCell(id: 'A12', value: 'Position prévue:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B12'] = StrategyCell(id: 'B12', value: 2, type: StrategyCellType.number, isEditable: false, lastModified: DateTime.now());
    
    cells['A13'] = StrategyCell(id: 'A13', value: 'Écart avec leader:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B13'] = StrategyCell(id: 'B13', value: '+12.5s', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    // Scénarios alternatifs
    cells['D9'] = StrategyCell(id: 'D9', value: 'SCÉNARIOS ALTERNATIFS', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['D10'] = StrategyCell(id: 'D10', value: 'Scénario conservateur:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E10'] = StrategyCell(id: 'E10', value: 'P3 (+18s)', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    cells['D11'] = StrategyCell(id: 'D11', value: 'Scénario optimal:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E11'] = StrategyCell(id: 'E11', value: 'P1 (-3s)', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    cells['D12'] = StrategyCell(id: 'D12', value: 'Risque Safety Car:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['E12'] = StrategyCell(id: 'E12', value: 'P4 (+25s)', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    // Recommandations stratégiques
    cells['A15'] = StrategyCell(id: 'A15', value: 'RECOMMANDATIONS', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    
    cells['A16'] = StrategyCell(id: 'A16', value: '🎯 Fenetre optimale arrêt:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B16'] = StrategyCell(id: 'B16', value: 'Tours 28-30', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    cells['A17'] = StrategyCell(id: 'A17', value: '⚡ Mode push recommandé:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B17'] = StrategyCell(id: 'B17', value: 'Tours 35-40', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());
    
    cells['A18'] = StrategyCell(id: 'A18', value: '🏁 Stratégie victoire:', type: StrategyCellType.text, isEditable: false, lastModified: DateTime.now());
    cells['B18'] = StrategyCell(id: 'B18', value: 'Undercut Tour 26', type: StrategyCellType.result, isEditable: false, lastModified: DateTime.now());

    return StrategySheet(
      id: 'simulateur',
      name: 'Simulateur',
      description: 'Simulation avoncée et scénarios stratégiques optimaux',
      order: 6,
      sections: [
        StrategySection(
          id: 'strategic_simulation',
          name: 'Simulation Stratégique',
          description: 'Modélisation et prédictions de course avancées',
          cells: cells,
          rowStart: 1,
          colStart: 1,
          rowEnd: 25,
          colEnd: 6,
        ),
      ],
      lastModified: DateTime.now(),
    );
  }

  /// Exporte le document vers un format compatible Excel (si nécessaire)
  Future<Map<String, dynamic>> exportToExcel() async {
    if (_currentDocument == null) return {};

    // Structure d'export compatible avec les outils Excel
    final exportData = <String, dynamic>{
      'metadata': {
        'name': _currentDocument!.name,
        'version': _currentDocument!.version,
        'exported_at': DateTime.now().toIso8601String(),
      },
      'sheets': <Map<String, dynamic>>[],
    };

    for (final sheet in _currentDocument!.sheets) {
      final sheetData = <String, dynamic>{
        'name': sheet.name,
        'description': sheet.description,
        'cells': <Map<String, dynamic>>[],
      };

      for (final section in sheet.sections) {
        section.cells.forEach((cellRef, cell) {
          sheetData['cells'].add({
            'reference': cellRef,
            'value': cell.value,
            'type': cell.type.name,
            'formula': cell.formula,
            'editable': cell.isEditable,
          });
        });
      }

      exportData['sheets'].add(sheetData);
    }

    return exportData;
  }

  /// Définir l'état de chargement
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Définir une erreur
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Vider le cache et recharger
  Future<void> refresh() async {
    _currentDocument = null;
    _error = null;
    await loadOrCreateDocument();
  }

  /// Réinitialiser avec un document vide
  Future<void> reset() async {
    _currentDocument = await _createKmrsDocument();
    await saveDocument();
    notifyListeners();
  }
}