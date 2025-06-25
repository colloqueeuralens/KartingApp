import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/strategy_service.dart';
import '../../widgets/common/app_bar_actions.dart';
import '../../widgets/strategy/strategy_card.dart';
import '../../widgets/strategy/strategy_data_grid.dart';
import '../../theme/racing_theme.dart';
import '../../models/strategy_models.dart';

/// Écran de stratégie racing reproduisant les fonctionnalités KMRS.xlsm
class StrategyScreen extends StatefulWidget {
  final VoidCallback? onBackToConfig;

  const StrategyScreen({
    super.key,
    this.onBackToConfig,
  });

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final StrategyService _strategyService = StrategyService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _initializeStrategy();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeStrategy() async {
    if (_isInitialized) return;

    try {
      await _strategyService.loadOrCreateDocument();
      
      if (mounted && _strategyService.sheets.isNotEmpty) {
        setState(() {
          _tabController.dispose();
          _tabController = TabController(
            length: _strategyService.sheets.length,
            vsync: this,
          );
          _isInitialized = true;
        });
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.psychology,
                color: RacingTheme.racingGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Stratégie Racing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: RacingTheme.racingBlack,
        elevation: 4,
        shadowColor: RacingTheme.racingGreen.withValues(alpha: 0.3),
        actions: AppBarActions.getResponsiveActions(
          context,
          onBackToConfig: widget.onBackToConfig,
        ),
        bottom: _isInitialized && _strategyService.sheets.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        RacingTheme.racingBlack,
                        RacingTheme.racingBlack.withValues(alpha: 0.8),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: RacingTheme.racingGreen,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                    indicatorColor: RacingTheme.racingGreen,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: _strategyService.sheets
                        .map((sheet) => Tab(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getSheetIcon(sheet.name),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(sheet.name),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RacingTheme.racingBlack,
              Colors.grey[900]!,
            ],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _strategyService,
      builder: (context, _) {
        if (_strategyService.isLoading) {
          return _buildLoadingState();
        }

        if (_strategyService.error != null) {
          return _buildErrorState();
        }

        if (!_isInitialized || _strategyService.sheets.isEmpty) {
          return _buildInitializingState();
        }

        return _buildTabView();
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: StrategyCard(
        title: 'Chargement',
        icon: Icons.sync,
        accentColor: RacingTheme.racingGreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(RacingTheme.racingGreen),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Initialisation de la stratégie...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Préparation des données de performance',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: StrategyCard(
        title: 'Erreur',
        icon: Icons.error_outline,
        accentColor: RacingTheme.bad,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: RacingTheme.bad,
              size: 48,
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                color: RacingTheme.bad,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _strategyService.error ?? 'Erreur inconnue',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _strategyService.refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RacingTheme.racingGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _strategyService.reset(),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Réinitialiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitializingState() {
    return Center(
      child: StrategyCard(
        title: 'Stratégie Racing',
        subtitle: 'Système d\'analyse de performance karting',
        icon: Icons.psychology,
        accentColor: RacingTheme.racingGreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.speed,
                color: RacingTheme.racingGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Système de Stratégie Prêt',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyse de performance et recommandations stratégiques\npour optimiser vos sessions de karting',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await _strategyService.loadOrCreateDocument();
                if (mounted) {
                  await _initializeStrategy();
                }
              },
              icon: const Icon(Icons.analytics),
              label: const Text('Démarrer l\'Analyse'),
              style: ElevatedButton.styleFrom(
                backgroundColor: RacingTheme.racingGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: _strategyService.sheets.map((sheet) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: _buildSheetContent(sheet),
        );
      }).toList(),
    );
  }

  Widget _buildSheetContent(StrategySheet sheet) {
    if (sheet.sections.isEmpty) {
      return _buildEmptySheetState(sheet);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête simple
          _buildSimpleHeader(sheet),
          
          const SizedBox(height: 20),
          
          // Affichage simple des cellules
          ...sheet.sections.map((section) => _buildSimpleSection(section)),
        ],
      ),
    );
  }

  Widget _buildSimpleHeader(StrategySheet sheet) {
    final totalCells = sheet.sections
        .map((s) => s.cells.length)
        .fold(0, (a, b) => a + b);
    
    final formulaCells = sheet.sections
        .map((s) => s.cells.values.where((c) => c.type == StrategyCellType.formula).length)
        .fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getSheetColor(sheet.name).withValues(alpha: 0.2),
            _getSheetColor(sheet.name).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getSheetColor(sheet.name).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSheetIcon(sheet.name),
                color: _getSheetColor(sheet.name),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (sheet.description.isNotEmpty)
                      Text(
                        sheet.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSimpleMetric('Cellules', totalCells.toString(), Icons.grid_on),
              const SizedBox(width: 20),
              _buildSimpleMetric('Formules', formulaCells.toString(), Icons.functions),
              const SizedBox(width: 20),
              _buildSimpleMetric('Sections', sheet.sections.length.toString(), Icons.view_module),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSimpleMetric(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: RacingTheme.racingGreen, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSimpleSection(StrategySection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.grid_on,
                color: RacingTheme.racingGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (section.description.isNotEmpty)
                      Text(
                        section.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSimpleCellList(section),
        ],
      ),
    );
  }
  
  Widget _buildSimpleCellList(StrategySection section) {
    if (section.cells.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Aucune donnée disponible',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final sortedCells = section.cells.entries.toList()
      ..sort((a, b) {
        final aMatch = RegExp(r'([A-Z]+)(\d+)').firstMatch(a.key);
        final bMatch = RegExp(r'([A-Z]+)(\d+)').firstMatch(b.key);
        
        if (aMatch != null && bMatch != null) {
          final aRow = int.parse(aMatch.group(2)!);
          final bRow = int.parse(bMatch.group(2)!);
          if (aRow != bRow) return aRow.compareTo(bRow);
          return aMatch.group(1)!.compareTo(bMatch.group(1)!);
        }
        return a.key.compareTo(b.key);
      });

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedCells.map((entry) {
        return _buildSimpleCell(entry.key, entry.value);
      }).toList(),
    );
  }
  
  Widget _buildSimpleCell(String cellId, StrategyCell cell) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getSimpleCellColor(cell),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cellId,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatSimpleCellValue(cell),
            style: TextStyle(
              color: _getSimpleCellTextColor(cell),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Color _getSimpleCellColor(StrategyCell cell) {
    switch (cell.type) {
      case StrategyCellType.formula:
        return Colors.blue.withValues(alpha: 0.1);
      case StrategyCellType.number:
        return RacingTheme.racingGreen.withValues(alpha: 0.1);
      case StrategyCellType.result:
        return Colors.orange.withValues(alpha: 0.1);
      case StrategyCellType.boolean:
        return cell.value == true 
            ? RacingTheme.good.withValues(alpha: 0.1)
            : RacingTheme.bad.withValues(alpha: 0.1);
      default:
        return Colors.white.withValues(alpha: 0.05);
    }
  }
  
  Color _getSimpleCellTextColor(StrategyCell cell) {
    switch (cell.type) {
      case StrategyCellType.formula:
        return Colors.lightBlue;
      case StrategyCellType.number:
        return RacingTheme.racingGreen;
      case StrategyCellType.result:
        return Colors.orange;
      case StrategyCellType.boolean:
        return cell.value == true ? RacingTheme.good : RacingTheme.bad;
      default:
        return Colors.white;
    }
  }
  
  String _formatSimpleCellValue(StrategyCell cell) {
    if (cell.value == null) return '';

    switch (cell.type) {
      case StrategyCellType.number:
        if (cell.value is num) {
          return cell.value % 1 == 0
              ? cell.value.toInt().toString()
              : cell.value.toStringAsFixed(2);
        }
        break;
      case StrategyCellType.percentage:
        if (cell.value is num) {
          return '${(cell.value * 100).toStringAsFixed(1)}%';
        }
        break;
      case StrategyCellType.boolean:
        return cell.value == true ? 'Oui' : 'Non';
      case StrategyCellType.formula:
        return cell.formula ?? cell.value?.toString() ?? '';
      default:
        return cell.value.toString();
    }

    return cell.value.toString();
  }

  Widget _buildEmptySheetState(StrategySheet sheet) {
    return Center(
      child: StrategyCard(
        title: 'Feuille en Construction',
        subtitle: 'Cette section sera alimentée selon votre analyse KMRS',
        icon: Icons.construction,
        accentColor: Colors.orange,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.engineering,
              color: Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Section "${sheet.name}" en développement',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cette feuille sera configurée après analyse\ndu fichier KMRS.xlsm correspondant',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onCellChanged(String sheetName, String cellId, dynamic value) {
    _strategyService.updateCell(sheetName, cellId, value);
  }

  IconData _getSheetIcon(String sheetName) {
    final name = sheetName.toLowerCase();
    if (name.contains('start') || name.contains('page')) return Icons.settings;
    if (name.contains('main') || name.contains('page')) return Icons.dashboard;
    if (name.contains('calculation') || name.contains('calc')) return Icons.calculate;
    if (name.contains('racing')) return Icons.speed;
    if (name.contains('stint') || name.contains('list')) return Icons.schedule;
    if (name.contains('rapport') || name.contains('pilot')) return Icons.person;
    if (name.contains('simulateur') || name.contains('simul')) return Icons.science;
    return Icons.analytics;
  }

  Color _getSheetColor(String sheetName) {
    final name = sheetName.toLowerCase();
    if (name.contains('start') || name.contains('page')) return Colors.blue;
    if (name.contains('main') || name.contains('page')) return RacingTheme.racingGreen;
    if (name.contains('calculation') || name.contains('calc')) return Colors.orange;
    if (name.contains('racing')) return Colors.red;
    if (name.contains('stint') || name.contains('list')) return Colors.purple;
    if (name.contains('rapport') || name.contains('pilot')) return Colors.teal;
    if (name.contains('simulateur') || name.contains('simul')) return Colors.indigo;
    return RacingTheme.racingGreen;
  }
}