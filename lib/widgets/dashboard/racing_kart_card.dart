import 'package:flutter/material.dart';

/// Card kart avec style racing amélioré et animations
class RacingKartCard extends StatefulWidget {
  final String kartNumber;
  final String? performance;
  final Color color;
  final VoidCallback? onTap;
  final bool isOptimalMoment;
  final bool showPulse;

  const RacingKartCard({
    super.key,
    required this.kartNumber,
    this.performance,
    required this.color,
    this.onTap,
    this.isOptimalMoment = false,
    this.showPulse = false,
  });

  @override
  State<RacingKartCard> createState() => _RacingKartCardState();
}

class _RacingKartCardState extends State<RacingKartCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _hoverController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Animation pulse pour moment optimal
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation hover
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    // Démarrer pulse si moment optimal
    if (widget.isOptimalMoment && widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RacingKartCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gérer l'animation pulse
    if (widget.isOptimalMoment &&
        widget.showPulse &&
        !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if ((!widget.isOptimalMoment || !widget.showPulse) &&
        _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _pulseAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 120,
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color.withValues(alpha: 0.9),
                      widget.color.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isOptimalMoment
                        ? Colors.amber
                        : widget.color.withValues(alpha: 0.3),
                    width: widget.isOptimalMoment ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: _isHovered ? 12 : 6,
                      offset: Offset(0, _isHovered ? 6 : 3),
                    ),
                    if (widget.isOptimalMoment)
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern racing
                    if (widget.isOptimalMoment)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.amber.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                    // Contenu principal
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Numéro de kart avec style racing
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: widget.color, width: 2),
                              ),
                              child: Text(
                                '#${widget.kartNumber}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.color,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Performance indicator
                          if (widget.performance != null)
                            Align(
                              alignment: Alignment.center,
                              child: PerformanceIndicator(
                                performance: widget.performance!,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Icône racing en arrière-plan
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.speed,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget d'indication de performance avec style racing
class PerformanceIndicator extends StatelessWidget {
  final String performance;

  const PerformanceIndicator({super.key, required this.performance});

  Color _getPerformanceColor() {
    switch (performance) {
      case '++':
        return Colors.green[600]!;
      case '+':
        return Colors.lightGreen[600]!;
      case '~':
        return Colors.orange[600]!;
      case '-':
        return Colors.deepOrange[600]!;
      case '--':
        return Colors.red[600]!;
      case '?':
        return Colors.grey[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getPerformanceIcon() {
    switch (performance) {
      case '++':
        return Icons.keyboard_double_arrow_up;
      case '+':
        return Icons.keyboard_arrow_up;
      case '~':
        return Icons.remove;
      case '-':
        return Icons.keyboard_arrow_down;
      case '--':
        return Icons.keyboard_double_arrow_down;
      case '?':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getPerformanceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPerformanceIcon(), color: Colors.white, size: 14),
          const SizedBox(width: 2),
          Text(
            performance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
