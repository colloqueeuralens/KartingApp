import 'package:flutter/material.dart';
import '../../theme/racing_theme.dart';

/// Tableau de timing live avec style F1/MotoGP
class LiveTimingTable extends StatefulWidget {
  final Map<String, Map<String, dynamic>> driversData;
  final bool isConnected;

  const LiveTimingTable({
    super.key,
    required this.driversData,
    required this.isConnected,
  });

  @override
  State<LiveTimingTable> createState() => _LiveTimingTableState();
}

class _LiveTimingTableState extends State<LiveTimingTable>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Extraire les headers dynamiquement depuis les données
  List<String> get headers {
    if (widget.driversData.isEmpty) return [];

    // Collecter tous les headers de tous les karts
    final allHeaders = <String>{};
    for (final driver in widget.driversData.values) {
      allHeaders.addAll(driver.keys);
    }
    return allHeaders.toList();
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RacingTheme.racingBlack,
            RacingTheme.racingBlack.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: RacingTheme.racingShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isConnected
                ? RacingTheme.racingGreen.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(children: [_buildHeader(), _buildTableContent()]),
      ),
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
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
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
            color: Colors.black.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: RacingTheme.racingGreen.withValues(alpha: 0.3),
                width: 1,
              ),
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
        fontSize: isMobile ? 10 : 12,
        fontWeight: FontWeight.bold,
        color: RacingTheme.racingGreen,
        letterSpacing: isMobile ? 0.5 : 1.0,
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

  const _DynamicTimingRow({
    required this.driver,
    required this.headers,
    required this.isEven,
    required this.isLast,
    required this.getRowBackgroundColor,
    required this.getResponsiveFlex,
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
    // Animer si les données ont changé
    if (oldWidget.driver.toString() != widget.driver.toString()) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Obtenir la position pour la couleur du podium
    final position =
        int.tryParse(widget.driver['Classement']?.toString() ?? '999') ?? 999;
    final podiumColor = widget.getRowBackgroundColor(position);

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        // Couleur de fond : animation highlight > podium > alternance normale
        Color? backgroundColor = _highlightAnimation.value;
        if (backgroundColor == null || backgroundColor == Colors.transparent) {
          backgroundColor =
              podiumColor ??
              (widget.isEven
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.transparent);
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
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
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

  Widget _buildDynamicCell(String header, bool isMobile) {
    final value = widget.driver[header]?.toString() ?? '';

    // Styling spécial selon le type de colonne
    Color textColor = Colors.white;
    FontWeight fontWeight = FontWeight.normal;

    if (header == 'Classement') {
      fontWeight = FontWeight.bold;
      // Plus de couleur sur le numéro, maintenant c'est le background de la ligne
      textColor = Colors.white;
    }

    if (header.contains('T.')) {
      // Temps
      textColor = Colors.white;
      fontWeight = FontWeight.w600;
    }

    return Center(
      child: Text(
        value,
        style: TextStyle(
          fontSize: isMobile ? 11 : 13,
          fontWeight: fontWeight,
          color: textColor,
          fontFamily: header.contains('T.') ? 'monospace' : null,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: isMobile ? 1 : 2,
      ),
    );
  }
}
