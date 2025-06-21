import 'package:flutter/material.dart';

/// Barre de progression avec style racing pour le moment optimal
class RacingProgressBar extends StatefulWidget {
  final double progress; // 0.0 à 1.0
  final int totalKarts;
  final int goodPerformanceKarts;
  final String thresholdText;
  final bool isOptimalMoment;

  const RacingProgressBar({
    super.key,
    required this.progress,
    required this.totalKarts,
    required this.goodPerformanceKarts,
    required this.thresholdText,
    this.isOptimalMoment = false,
  });

  @override
  State<RacingProgressBar> createState() => _RacingProgressBarState();
}

class _RacingProgressBarState extends State<RacingProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: widget.progress)
        .animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
        );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController.forward();

    if (widget.isOptimalMoment) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RacingProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animer vers la nouvelle valeur
    _progressAnimation =
        Tween<double>(
          begin: _progressAnimation.value,
          end: widget.progress,
        ).animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
        );

    _progressController.reset();
    _progressController.forward();

    // Gérer l'animation pulse
    if (widget.isOptimalMoment && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isOptimalMoment && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_progressAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isOptimalMoment
                    ? [Colors.green[50]!, Colors.green[100]!]
                    : [Colors.grey[50]!, Colors.grey[100]!],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isOptimalMoment
                    ? Colors.green[300]!
                    : Colors.grey[300]!,
                width: widget.isOptimalMoment ? 2 : 1,
              ),
              boxShadow: widget.isOptimalMoment
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec statistiques
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Performance Globale',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isOptimalMoment
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isOptimalMoment
                            ? Colors.green[600]
                            : Colors.grey[600],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.goodPerformanceKarts}/${widget.totalKarts}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Barre de progression principale
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      // Barre de fond avec pattern racing
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: RacingPatternPainter(),
                        ),
                      ),

                      // Barre de progression
                      FractionallySizedBox(
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.isOptimalMoment
                                  ? [Colors.green[400]!, Colors.green[600]!]
                                  : [Colors.blue[400]!, Colors.blue[600]!],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (widget.isOptimalMoment
                                            ? Colors.green
                                            : Colors.blue)
                                        .withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Informations détaillées
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.thresholdText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${(_progressAnimation.value * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: widget.isOptimalMoment
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),

                // Message moment optimal
                if (widget.isOptimalMoment)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "C'EST LE MOMENT!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Painter pour créer un pattern racing sur la barre de progression
class RacingPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    // Dessiner des lignes diagonales pour effet racing
    for (double i = -size.height; i < size.width; i += 8) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget indicateur de seuil
class ThresholdIndicator extends StatelessWidget {
  final double threshold;
  final String label;

  const ThresholdIndicator({
    super.key,
    required this.threshold,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 4),
          Text(
            '$label: ${(threshold * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}
