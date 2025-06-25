import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/racing_theme.dart';
import '../../models/strategy_models.dart';

/// Grid de données racing pour afficher et éditer les cellules de stratégie
class StrategyDataGrid extends StatefulWidget {
  final StrategySection section;
  final Function(String cellId, dynamic value)? onCellChanged;
  final bool isEditable;
  final double cellWidth;
  final double cellHeight;

  const StrategyDataGrid({
    super.key,
    required this.section,
    this.onCellChanged,
    this.isEditable = true,
    this.cellWidth = 180,
    this.cellHeight = 60,
  });

  @override
  State<StrategyDataGrid> createState() => _StrategyDataGridState();
}

class _StrategyDataGridState extends State<StrategyDataGrid> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _selectedCellId;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  void _initializeControllers() {
    widget.section.cells.forEach((cellId, cell) {
      _controllers[cellId] = TextEditingController(
        text: cell.value?.toString() ?? '',
      );
      _focusNodes[cellId] = FocusNode();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.cells.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Container(
              height: 400, // Hauteur fixe pour éviter les problèmes de contraintes
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: _buildGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            RacingTheme.racingGreen.withValues(alpha: 0.2),
            RacingTheme.racingGreen.withValues(alpha: 0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: RacingTheme.racingGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
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
                  widget.section.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.section.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.section.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.isEditable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: RacingTheme.racingGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Éditable',
                style: TextStyle(
                  color: RacingTheme.racingGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (widget.section.cells.isEmpty) {
      return Container(
        height: 200,
        child: const Center(
          child: Text(
            'Aucune donnée disponible',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Approche simplifiée : afficher les cellules existantes dans une liste verticale
    final sortedCells = widget.section.cells.entries.toList()
      ..sort((a, b) {
        // Trier par position (A1, A2, A3, B1, B2, etc.)
        final aMatch = RegExp(r'([A-Z]+)(\d+)').firstMatch(a.key);
        final bMatch = RegExp(r'([A-Z]+)(\d+)').firstMatch(b.key);
        
        if (aMatch != null && bMatch != null) {
          final aRow = int.parse(aMatch.group(2)!);
          final bRow = int.parse(bMatch.group(2)!);
          final aCol = aMatch.group(1)!;
          final bCol = bMatch.group(1)!;
          
          if (aRow != bRow) return aRow.compareTo(bRow);
          return aCol.compareTo(bCol);
        }
        return a.key.compareTo(b.key);
      });

    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        direction: Axis.horizontal,
        spacing: 4,
        runSpacing: 4,
        children: sortedCells.map((entry) {
          return Container(
            width: widget.cellWidth,
            height: widget.cellHeight,
            child: _buildCellSimple(entry.key, entry.value),
          );
        }).toList(),
      ),
    );
  }

  String _getCellId(int row, int col) {
    // Convertir en référence Excel (A1, B2, etc.)
    final colLetter = String.fromCharCode(65 + col);
    return '$colLetter${row + 1}';
  }

  Widget _buildCellSimple(String cellId, StrategyCell cell) {
    final isSelected = _selectedCellId == cellId;
    final isEditable = widget.isEditable && cell.isEditable;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCellId = cellId;
        });
        if (isEditable && _focusNodes.containsKey(cellId)) {
          _focusNodes[cellId]!.requestFocus();
        }
        HapticFeedback.lightImpact();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _getCellColor(cell, isSelected, false),
          border: Border.all(
            color: isSelected
                ? RacingTheme.racingGreen
                : RacingTheme.racingGreen.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec l'ID de la cellule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Text(
                cellId,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Contenu de la cellule
            Container(
              padding: const EdgeInsets.all(4),
              width: double.infinity,
              height: 35, // Hauteur fixe pour le contenu
              child: _buildCellContent(cellId, cell, isEditable),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String cellId, StrategyCell? cell, int row, int col) {
    final isSelected = _selectedCellId == cellId;
    final isEmpty = cell == null;
    final isEditable = widget.isEditable && (cell?.isEditable ?? true);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCellId = cellId;
        });
        if (isEditable && _focusNodes.containsKey(cellId)) {
          _focusNodes[cellId]!.requestFocus();
        }
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: widget.cellWidth,
        height: widget.cellHeight,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _getCellColor(cell, isSelected, isEmpty),
          border: Border.all(
            color: isSelected
                ? RacingTheme.racingGreen
                : RacingTheme.racingGreen.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _buildCellContent(cellId, cell, isEditable),
      ),
    );
  }

  Color _getCellColor(StrategyCell? cell, bool isSelected, bool isEmpty) {
    if (isEmpty) {
      return Colors.grey.withValues(alpha: 0.1);
    }

    if (isSelected) {
      return RacingTheme.racingGreen.withValues(alpha: 0.2);
    }

    switch (cell!.type) {
      case StrategyCellType.formula:
        return Colors.blue.withValues(alpha: 0.1);
      case StrategyCellType.number:
        return RacingTheme.racingGreen.withValues(alpha: 0.1);
      case StrategyCellType.result:
        return Colors.orange.withValues(alpha: 0.1);
      default:
        return Colors.white.withValues(alpha: 0.05);
    }
  }

  Widget _buildCellContent(String cellId, StrategyCell? cell, bool isEditable) {
    if (cell == null) {
      return const SizedBox.shrink();
    }

    if (isEditable && cell.isEditable) {
      return _buildEditableCell(cellId, cell);
    } else {
      return _buildReadOnlyCell(cell);
    }
  }

  Widget _buildEditableCell(String cellId, StrategyCell cell) {
    return TextFormField(
      controller: _controllers[cellId],
      focusNode: _focusNodes[cellId],
      style: TextStyle(
        color: _getTextColor(cell),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(6),
        isDense: true,
      ),
      onChanged: (value) {
        widget.onCellChanged?.call(cellId, value);
      },
      onEditingComplete: () {
        setState(() {
          _selectedCellId = null;
        });
      },
      keyboardType: _getKeyboardType(cell.type),
    );
  }

  Widget _buildReadOnlyCell(StrategyCell cell) {
    return Container(
      padding: const EdgeInsets.all(6),
      child: Align(
        alignment: _getAlignment(cell.type),
        child: Text(
          _formatCellValue(cell),
          style: TextStyle(
            color: _getTextColor(cell),
            fontSize: 12,
            fontWeight: cell.type == StrategyCellType.formula
                ? FontWeight.w600
                : FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  String _formatCellValue(StrategyCell cell) {
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
      case StrategyCellType.time:
        // Format temps en mm:ss.ms
        if (cell.value is num) {
          final seconds = cell.value.toDouble();
          final minutes = (seconds / 60).floor();
          final remainingSeconds = seconds % 60;
          return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toStringAsFixed(3).padLeft(6, '0')}';
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

  Color _getTextColor(StrategyCell cell) {
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

  Alignment _getAlignment(StrategyCellType type) {
    switch (type) {
      case StrategyCellType.number:
      case StrategyCellType.percentage:
      case StrategyCellType.time:
        return Alignment.centerRight;
      case StrategyCellType.boolean:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  TextInputType _getKeyboardType(StrategyCellType type) {
    switch (type) {
      case StrategyCellType.number:
      case StrategyCellType.percentage:
      case StrategyCellType.time:
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RacingTheme.racingGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_off,
              color: Colors.white.withValues(alpha: 0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune donnée dans cette section',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les données apparaîtront ici après configuration',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}