import 'package:flutter/material.dart';

/// Slot vide pour kart avec style racing et animations
class EmptyKartSlot extends StatefulWidget {
  final VoidCallback? onTap;
  final Color color;
  final bool showPulse;

  const EmptyKartSlot({
    super.key,
    this.onTap,
    required this.color,
    this.showPulse = false,
  });

  @override
  State<EmptyKartSlot> createState() => _EmptyKartSlotState();
}

class _EmptyKartSlotState extends State<EmptyKartSlot>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _hoverController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Animation breathing subtile
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Animation hover
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.8).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    // Démarrer l'animation breathing si activée
    if (widget.showPulse) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EmptyKartSlot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showPulse && !_breathingController.isAnimating) {
      _breathingController.repeat(reverse: true);
    } else if (!widget.showPulse && _breathingController.isAnimating) {
      _breathingController.stop();
      _breathingController.reset();
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
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
      animation: Listenable.merge([
        _breathingAnimation,
        _scaleAnimation,
        _opacityAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _breathingAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 120,
                height: 110,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: _opacityAnimation.value * 0.1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.color.withValues(
                      alpha: _opacityAnimation.value,
                    ),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Pattern en arrière-plan
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: DashedPatternPainter(
                          color: widget.color.withValues(
                            alpha: _opacityAnimation.value * 0.3,
                          ),
                        ),
                      ),
                    ),

                    // Contenu central
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icône racing
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(
                                alpha: _opacityAnimation.value * 0.1,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.color.withValues(
                                  alpha: _opacityAnimation.value,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: widget.color.withValues(
                                alpha: _opacityAnimation.value,
                              ),
                              size: 24,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Texte
                          Text(
                            'Ajouter\nKart',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.color.withValues(
                                alpha: _opacityAnimation.value,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Animation de highlight sur hover
                    if (_isHovered)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            colors: [
                              widget.color.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
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

/// Painter pour créer un pattern en pointillés
class DashedPatternPainter extends CustomPainter {
  final Color color;

  DashedPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Créer des lignes diagonales en pointillés
    for (double y = 0; y < size.height; y += 16) {
      for (double x = 0; x < size.width; x += 8) {
        if ((x + y) % 16 < 4) {
          path.moveTo(x, y);
          path.lineTo(x + 4, y);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Version compacte pour espaces réduits
class CompactEmptyKartSlot extends StatelessWidget {
  final VoidCallback? onTap;
  final Color color;

  const CompactEmptyKartSlot({super.key, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add, color: color.withValues(alpha: 0.7), size: 20),
      ),
    );
  }
}
