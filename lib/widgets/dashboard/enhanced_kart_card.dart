import 'package:flutter/material.dart';

/// Carte de kart améliorée avec animations et interactions
class EnhancedKartCard extends StatefulWidget {
  final int number;
  final String perf;
  final bool isOptimal;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isAnimating;
  final bool disablePulseAnimation;

  const EnhancedKartCard({
    super.key,
    required this.number,
    required this.perf,
    required this.isOptimal,
    required this.backgroundColor,
    this.onTap,
    this.onLongPress,
    this.isAnimating = false,
    this.disablePulseAnimation = false,
  });

  @override
  State<EnhancedKartCard> createState() => _EnhancedKartCardState();
}

class _EnhancedKartCardState extends State<EnhancedKartCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Animation de scale pour l'interaction
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Animation de pulse pour les performances optimales
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation shimmer pour les nouvelles données
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Démarrer les animations appropriées
    if (widget.isOptimal && !widget.disablePulseAnimation) {
      _pulseController.repeat(reverse: true);
    }

    if (widget.isAnimating) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(EnhancedKartCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gérer les changements d'état d'animation
    if (widget.isOptimal != oldWidget.isOptimal ||
        widget.disablePulseAnimation != oldWidget.disablePulseAnimation) {
      if (widget.isOptimal && !widget.disablePulseAnimation) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _shimmerController.repeat();
      } else {
        _shimmerController.stop();
        _shimmerController.reset();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Color get _performanceColor {
    switch (widget.perf) {
      case '++':
        return Colors.green;
      case '+':
        return Colors.lightGreen;
      case '~':
        return Colors.orange;
      case '-':
        return Colors.red;
      case '--':
        return Colors.red.shade800;
      case '?':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData get _performanceIcon {
    switch (widget.perf) {
      case '++':
        return Icons.trending_up;
      case '+':
        return Icons.arrow_upward;
      case '~':
        return Icons.remove;
      case '-':
        return Icons.arrow_downward;
      case '--':
        return Icons.trending_down;
      case '?':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _scaleController.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _scaleController.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _scaleController.reverse();
        },
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _pulseAnimation,
            _shimmerAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale:
                  _scaleAnimation.value *
                  (widget.isOptimal && !widget.disablePulseAnimation
                      ? _pulseAnimation.value
                      : 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isOptimal
                        ? Colors.green.withValues(alpha: 0.8)
                        : _isHovered
                        ? Colors.blue.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: widget.isOptimal ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isHovered || widget.isOptimal)
                          ? (_performanceColor.withValues(alpha: 0.3))
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: _isHovered ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Shimmer effect pour les nouvelles données
                      if (widget.isAnimating)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [
                                  _shimmerAnimation.value - 0.3,
                                  _shimmerAnimation.value,
                                  _shimmerAnimation.value + 0.3,
                                ],
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Contenu principal
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Numéro du kart
                            Text(
                              widget.number.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _isHovered || widget.isOptimal
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Indicateur de performance
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _performanceIcon,
                                  color: _performanceColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.perf,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _performanceColor,
                                  ),
                                ),
                              ],
                            ),

                            // Indicateur optimal
                            if (widget.isOptimal) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'OPTIMAL',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Overlay pour hover effect
                      if (_isHovered)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _performanceColor.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Widget d'emplacement vide pour drag & drop
class EmptyKartSlot extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isHighlighted;
  final String hintText;

  const EmptyKartSlot({
    super.key,
    this.onTap,
    this.isHighlighted = false,
    this.hintText = 'Vide',
  });

  @override
  State<EmptyKartSlot> createState() => _EmptyKartSlotState();
}

class _EmptyKartSlotState extends State<EmptyKartSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EmptyKartSlot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isHighlighted != oldWidget.isHighlighted) {
      if (widget.isHighlighted) {
        _breathingController.repeat(reverse: true);
      } else {
        _breathingController.stop();
        _breathingController.reset();
      }
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isHighlighted
                      ? Colors.blue.withValues(alpha: _breathingAnimation.value)
                      : _isHovered
                      ? Colors.grey.withValues(alpha: 0.4)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: widget.isHighlighted ? 2 : 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: widget.isHighlighted
                          ? Colors.blue.withValues(
                              alpha: _breathingAnimation.value,
                            )
                          : Colors.grey.withValues(alpha: 0.5),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.hintText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
