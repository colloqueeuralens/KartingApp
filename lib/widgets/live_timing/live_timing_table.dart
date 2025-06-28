import 'package:flutter/material.dart';
import '../../theme/racing_theme.dart';

/// Tableau de timing live avec style F1/MotoGP
class LiveTimingTable extends StatefulWidget {
  final Map<String, Map<String, dynamic>> driversData;
  final bool isConnected;
  final List<String> columnOrder; // NOUVEAU: Ordre des colonnes du backend

  const LiveTimingTable({
    super.key,
    required this.driversData,
    required this.isConnected,
    this.columnOrder = const [], // Par défaut: liste vide
  });

  @override
  State<LiveTimingTable> createState() => _LiveTimingTableState();
}

class _LiveTimingTableState extends State<LiveTimingTable>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Système de tracking des meilleurs temps
  Map<String, String> _personalBestTimes = {}; // Meilleurs temps personnels par pilote
  String? _globalBestTime; // Meilleur temps global actuel
  String? _globalBestPilot; // Pilote détenteur du record global
  Map<String, String> _recentImprovements = {}; // Améliorations récentes (temporaires)

  /// Ordre des colonnes fixe et logique pour éviter le mélange aléatoire
  static const List<String> _fixedColumnOrder = [
    'Classement',
    'Kart',
    'Pilote',
    'Meilleur T.',
    'Dernier T.',
    'Ecart',
    'Tours',
    'Position',
    'Pos.',
    'Clt',
    'Numéro',
    'Nom',
    'Best Lap',
    'Last Lap',
    'Gap',
    'Laps',
    'S1',
    'S2',
    'S3',
    'Vitesse',
    'Speed',
  ];

  /// Extraire les headers dans l'ordre du backend ou ordre fixe
  List<String> get headers {
    if (widget.driversData.isEmpty) return [];

    // Collecter tous les headers de tous les karts
    final allHeaders = <String>{};
    for (final driver in widget.driversData.values) {
      allHeaders.addAll(driver.keys);
    }
    
    // Use backend column order if available
    if (widget.columnOrder.isNotEmpty) {
      final orderedHeaders = <String>[];
      
      // First add columns in backend order (C1→C2→C3...)
      for (final column in widget.columnOrder) {
        if (allHeaders.contains(column)) {
          orderedHeaders.add(column);
          allHeaders.remove(column);
        }
      }
      
      // Then add remaining columns alphabetically
      final remainingHeaders = allHeaders.toList()..sort();
      orderedHeaders.addAll(remainingHeaders);
      
      return orderedHeaders;
    }
    
    // Fallback: Use fixed order if no backend order
    final orderedHeaders = <String>[];
    
    // First add columns in fixed order
    for (final column in _fixedColumnOrder) {
      if (allHeaders.contains(column)) {
        orderedHeaders.add(column);
        allHeaders.remove(column);
      }
    }
    
    // Then add remaining columns alphabetically
    final remainingHeaders = allHeaders.toList()..sort();
    orderedHeaders.addAll(remainingHeaders);
    
    return orderedHeaders;
  }

  /// Filtrer les headers pour ne garder que les colonnes utiles (non vides)
  List<String> get usefulHeaders {
    final allHeaders = headers;
    return allHeaders.where((header) {
      // Vérifier si au moins un kart a une valeur non-vide pour cette colonne
      return sortedDrivers.any(
        (driver) => driver[header]?.toString().trim().isNotEmpty == true,
      );
    }).toList();
  }

  /// Headers adaptés selon la taille d'écran
  List<String> getResponsiveHeaders(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useful = usefulHeaders;

    if (screenWidth < 600) {
      // Mobile : colonnes principales uniquement
      final priority = [
        'Classement',
        'Kart',
        'Pilote',
        'Meilleur T.',
        'Dernier T.',
      ];
      return useful.where((header) => priority.contains(header)).toList();
    } else if (screenWidth < 900) {
      // Tablet : colonnes importantes
      final priority = [
        'Classement',
        'Kart',
        'Pilote',
        'Meilleur T.',
        'Dernier T.',
        'Ecart',
        'Tours',
      ];
      return useful.where((header) => priority.contains(header)).toList();
    } else {
      // Desktop : toutes les colonnes utiles
      return useful;
    }
  }

  /// Obtenir le flex adaptatif selon la colonne et la taille d'écran
  int getResponsiveFlex(String header, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile : flex optimisé
      if (header == 'Classement') return 1;
      if (header == 'Kart') return 1;
      if (header == 'Pilote') return 2;
      if (header.contains('T.')) return 2;
      return 1;
    } else {
      // Desktop/Tablet : flex normal
      if (header == 'Pilote' || header == 'Kart') return 2;
      if (header.contains('T.') || header == 'Ecart') return 2;
      return 1;
    }
  }

  /// Extraire les rows dynamiquement depuis les données
  List<Map<String, dynamic>> get sortedDrivers {
    if (widget.driversData.isEmpty) return [];

    final drivers = <Map<String, dynamic>>[];

    widget.driversData.forEach((driverId, driverData) {
      final driver = Map<String, dynamic>.from(driverData);
      driver['_driverId'] = driverId; // Garder l'ID pour référence
      drivers.add(driver);
    });

    // Trier par classement si disponible
    drivers.sort((a, b) {
      final classementA = a['Classement']?.toString() ?? '999';
      final classementB = b['Classement']?.toString() ?? '999';
      try {
        return int.parse(classementA).compareTo(int.parse(classementB));
      } catch (e) {
        return classementA.compareTo(classementB);
      }
    });

    return drivers;
  }

  /// Couleur de background pour les positions du podium
  Color? getRowBackgroundColor(int position) {
    switch (position) {
      case 1:
        return RacingTheme.racingGold.withValues(alpha: 0.3);
      case 2:
        return Colors.grey.shade300.withValues(alpha: 0.3);
      case 3:
        return Colors.orange.shade300.withValues(alpha: 0.3);
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isConnected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiveTimingTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !oldWidget.isConnected) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isConnected && oldWidget.isConnected) {
      _pulseController.stop();
    }
    
    // Mettre à jour le système de tracking des meilleurs temps
    _updateBestTimesTracking();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Mettre à jour le système de tracking des meilleurs temps
  void _updateBestTimesTracking() {
    _recentImprovements.clear();
    String? newGlobalBest;
    String? newGlobalPilot;
    
    for (final driver in sortedDrivers) {
      final pilotId = driver['_driverId'] as String;
      final currentBest = _getBestTimeFromDriver(driver);
      
      if (currentBest != null && _isValidTime(currentBest)) {
        // Vérifier amélioration personnelle
        final previousBest = _personalBestTimes[pilotId];
        if (previousBest == null || _isTimeBetter(currentBest, previousBest)) {
          _personalBestTimes[pilotId] = currentBest;
          
          // Si c'était une amélioration, la marquer temporairement
          if (previousBest != null) {
            _recentImprovements[pilotId] = currentBest;
            
            // Supprimer l'amélioration après 5 secondes
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _recentImprovements.remove(pilotId);
                });
              }
            });
          }
        }
        
        // Vérifier meilleur temps global
        if (newGlobalBest == null || _isTimeBetter(currentBest, newGlobalBest)) {
          newGlobalBest = currentBest;
          newGlobalPilot = pilotId;
        }
      }
    }
    
    // Mettre à jour le record global
    if (newGlobalBest != null && newGlobalBest != _globalBestTime) {
      _globalBestTime = newGlobalBest;
      _globalBestPilot = newGlobalPilot;
    }
  }

  /// Extraire le meilleur temps d'un pilote depuis ses données
  String? _getBestTimeFromDriver(Map<String, dynamic> driver) {
    final possibleKeys = ['Meilleur T.', 'Meilleur', 'Best Lap', 'Best', 'Meilleur Temps'];
    
    for (final key in possibleKeys) {
      final value = driver[key]?.toString();
      if (value != null && _isValidTime(value)) {
        return value;
      }
    }
    return null;
  }

  /// Vérifier si un temps est valide
  bool _isValidTime(String time) {
    return time.isNotEmpty && 
           time != '--:--:---' && 
           time != '--:--' && 
           time != '0:00.000' &&
           time != '00:00:000';
  }

  /// Comparer deux temps pour déterminer lequel est meilleur
  bool _isTimeBetter(String time1, String time2) {
    try {
      final duration1 = _parseTime(time1);
      final duration2 = _parseTime(time2);
      return duration1 < duration2;
    } catch (e) {
      return false;
    }
  }

  /// Parser un temps vers Duration
  Duration _parseTime(String timeStr) {
    if (!_isValidTime(timeStr)) return Duration.zero;

    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isConnected
              ? RacingTheme.racingGreen.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(children: [_buildHeader(), _buildTableContent()]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RacingTheme.racingGreen.withValues(alpha: 0.2),
            RacingTheme.racingGreen.withValues(alpha: 0.1),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RacingTheme.racingGreen.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.timer, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'LIVE TIMING BOARD',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: RacingTheme.racingGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.isConnected
                      ? RacingTheme.racingGreen.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isConnected
                        ? RacingTheme.racingGreen
                        : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: widget.isConnected ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.isConnected
                              ? RacingTheme.racingGreen
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isConnected ? 'LIVE' : 'OFFLINE',
                      style: TextStyle(
                        color: widget.isConnected
                            ? RacingTheme.racingGreen
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableContent() {
    final drivers = sortedDrivers;

    if (drivers.isEmpty) {
      return Container(
        height: 300,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_off, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text(
                'EN ATTENTE DES DONNÉES',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connectez-vous au timing pour voir les données en temps réel',
                style: TextStyle(fontSize: 14, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [_buildDynamicTableHeaders(), _buildDynamicTableRows()],
    );
  }

  Widget _buildDynamicTableHeaders() {
    return Builder(
      builder: (context) {
        final headersList = getResponsiveHeaders(context);
        final screenWidth = MediaQuery.of(context).size.width;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 600 ? 8 : 16,
            vertical: screenWidth < 600 ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withValues(alpha: 0.3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
          child: Row(
            children: headersList.map((header) {
              final flex = getResponsiveFlex(header, context);

              return Expanded(
                flex: flex,
                child: _HeaderCell(
                  header.toUpperCase(),
                  isMobile: screenWidth < 600,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDynamicTableRows() {
    return Builder(
      builder: (context) {
        final drivers = sortedDrivers;
        final headersList = getResponsiveHeaders(context);

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            final isEven = index % 2 == 0;

            return _DynamicTimingRow(
              driver: driver,
              headers: headersList,
              isEven: isEven,
              isLast: index == drivers.length - 1,
              getRowBackgroundColor: getRowBackgroundColor,
              getResponsiveFlex: (header) => getResponsiveFlex(header, context),
              globalBestTime: _globalBestTime,
              globalBestPilot: _globalBestPilot,
              recentImprovements: _recentImprovements,
            );
          },
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool isMobile;

  const _HeaderCell(this.text, {this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF9CA3AF),
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DynamicTimingRow extends StatefulWidget {
  final Map<String, dynamic> driver;
  final List<String> headers;
  final bool isEven;
  final bool isLast;
  final Color? Function(int position) getRowBackgroundColor;
  final int Function(String header) getResponsiveFlex;
  final String? globalBestTime;
  final String? globalBestPilot;
  final Map<String, String> recentImprovements;

  const _DynamicTimingRow({
    required this.driver,
    required this.headers,
    required this.isEven,
    required this.isLast,
    required this.getRowBackgroundColor,
    required this.getResponsiveFlex,
    required this.globalBestTime,
    required this.globalBestPilot,
    required this.recentImprovements,
  });

  @override
  State<_DynamicTimingRow> createState() => _DynamicTimingRowState();
}

class _DynamicTimingRowState extends State<_DynamicTimingRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _highlightAnimation =
        ColorTween(
          begin: Colors.transparent,
          end: RacingTheme.racingGreen.withValues(alpha: 0.3),
        ).animate(
          CurvedAnimation(
            parent: _highlightController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void didUpdateWidget(_DynamicTimingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Obtenir la position pour vérifier si c'est le podium
    final position = int.tryParse(widget.driver['Classement']?.toString() ?? '999') ?? 999;
    final isPodium = position >= 1 && position <= 3;
    
    // NE PAS animer les 3 premières places pour préserver leur background podium
    if (!isPodium && oldWidget.driver.toString() != widget.driver.toString()) {
      _highlightController.forward().then((_) {
        _highlightController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }


  /// Obtenir la position du pilote de manière flexible (simulation et données réelles)
  int _getDriverPosition() {
    // Essayer plusieurs clés possibles pour la position
    final possibleKeys = ['Classement', 'Position', 'Pos.', 'Clt', 'Pos'];
    
    for (final key in possibleKeys) {
      final value = widget.driver[key]?.toString();
      if (value != null && value.isNotEmpty && value != '--') {
        final position = int.tryParse(value);
        if (position != null && position > 0) {
          return position;
        }
      }
    }
    
    return 999; // Position par défaut si aucune trouvée
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Obtenir la position pour la couleur du podium (flexible pour simulation et données réelles)
    final position = _getDriverPosition();
    final podiumColor = widget.getRowBackgroundColor(position);

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        // Logique de couleur de fond améliorée
        Color? backgroundColor;
        
        // Vérifier si c'est le podium (1-2-3)
        final isPodium = position >= 1 && position <= 3;
        
        if (isPodium) {
          // PODIUM: toujours utiliser la couleur podium, jamais d'animation
          backgroundColor = podiumColor;
        } else {
          // AUTRES POSITIONS: animation highlight si active, sinon alternance normale
          backgroundColor = _highlightAnimation.value;
          if (backgroundColor == null || backgroundColor == Colors.transparent) {
            backgroundColor = widget.isEven
                ? const Color(0xFF374151).withValues(alpha: 0.2)
                : const Color(0xFF1F2937).withValues(alpha: 0.1);
          }
        }

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 16,
            vertical: isMobile ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: widget.isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  )
                : null,
          ),
          child: Row(
            children: widget.headers.map((header) {
              final flex = widget.getResponsiveFlex(header);

              return Expanded(
                flex: flex,
                child: _buildDynamicCell(header, isMobile),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Vérifier si un temps est valide
  bool _isValidTime(String time) {
    return time.isNotEmpty && 
           time != '--:--:---' && 
           time != '--:--' && 
           time != '0:00.000' &&
           time != '00:00:000';
  }

  /// Vérifier si une colonne contient des temps de tour
  bool _isTimeColumn(String header) {
    final timeHeaders = [
      'Meilleur T.', 'Dernier T.', 'Meilleur', 'Dernier',
      'Best Lap', 'Last Lap', 'Meilleur Temps', 'Dernier Temps'
    ];
    return timeHeaders.any((timeHeader) => header.contains(timeHeader)) ||
           header.toLowerCase().contains('time') ||
           header.toLowerCase().contains('temps');
  }

  Widget _buildDynamicCell(String header, bool isMobile) {
    final value = widget.driver[header]?.toString() ?? '';
    final pilotId = widget.driver['_driverId'] as String;

    // Styling spécial selon le type de colonne et les systèmes de couleurs
    Color textColor = Colors.white;
    FontWeight fontWeight = FontWeight.normal;
    Color? backgroundColor;

    // Vérifier si c'est une colonne de temps pour appliquer les couleurs spéciales
    if (_isTimeColumn(header) && _isValidTime(value)) {
      // PRIORITÉ 1: Meilleur tour global (violet/rose)
      if (widget.globalBestTime != null && value == widget.globalBestTime && pilotId == widget.globalBestPilot) {
        textColor = Colors.purple[300]!;
        fontWeight = FontWeight.bold;
        backgroundColor = Colors.purple.withValues(alpha: 0.2);
      }
      // PRIORITÉ 2: Amélioration personnelle récente (vert)
      else if (widget.recentImprovements.containsKey(pilotId) && 
               widget.recentImprovements[pilotId] == value) {
        textColor = Colors.green[400]!;
        fontWeight = FontWeight.bold;
        backgroundColor = Colors.green.withValues(alpha: 0.2);
      }
      // Style normal pour les temps
      else {
        textColor = Colors.white;
        fontWeight = FontWeight.w600;
      }
    }
    // Style pour les autres colonnes
    else {
      if (header == 'Classement' || header == 'Position' || header == 'Pos.' || header == 'Clt') {
        fontWeight = FontWeight.bold;
      }
      textColor = Colors.white;
    }

    return Center(
      child: Container(
        padding: backgroundColor != null ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2) : null,
        decoration: backgroundColor != null
            ? BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: fontWeight,
            color: textColor,
            fontFamily: _isTimeColumn(header) ? 'monospace' : null,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: isMobile ? 1 : 2,
        ),
      ),
    );
  }
}
