import 'package:flutter/material.dart';
import '../../theme/racing_theme.dart';

/// Widget d'indicateur de moment optimal réutilisable
class OptimalMomentIndicator extends StatelessWidget {
  final bool isOptimal;
  final int percentage;
  final int threshold;
  final String? circuitName;

  const OptimalMomentIndicator({
    super.key,
    required this.isOptimal,
    required this.percentage,
    required this.threshold,
    this.circuitName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: isOptimal
            ? RacingTheme.successGradient
            : LinearGradient(
                colors: [RacingTheme.bad, RacingTheme.poor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isOptimal
            ? RacingTheme.racingShadow
            : RacingTheme.darkShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Racing pattern background
              if (isOptimal)
                Positioned.fill(
                  child: CustomPaint(
                    painter: CheckeredPatternPainter(opacity: 0.2),
                  ),
                ),

              // Content avec layout simplifié
              Padding(
                padding: const EdgeInsets.all(12),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Section principale: gauche-centre-droite avec hauteur intrinsèque
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Section gauche: Informations dashboard
                          Flexible(
                            flex: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dashboard header avec icône
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.sports_motorsports,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Titre sur une seule ligne
                                          const Text(
                                            'KMRS RACING DASHBOARD',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // Nom du circuit en dessous, plus gros
                                          if (circuitName != null)
                                            Text(
                                              circuitName!.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Section centrale: Badge LIVE
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Section droite: Indicateur de performance
                          Flexible(
                            flex: 2,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Racing lights row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    final lightOn =
                                        isOptimal ||
                                        index < (percentage / 20).floor();
                                    return Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: lightOn
                                            ? (isOptimal
                                                  ? Colors.white
                                                  : Colors.white.withValues(
                                                      alpha: 0.7,
                                                    ))
                                            : Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                        boxShadow: lightOn
                                            ? [
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 3,
                                                  spreadRadius: 0.5,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  }),
                                ),

                                const SizedBox(height: 8),

                                // Status message
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isOptimal
                                          ? Icons.flag
                                          : Icons.access_time,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        isOptimal
                                            ? 'C\'EST LE MOMENT !'
                                            : 'ATTENDRE...',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // Percentage display
                                Column(
                                  children: [
                                    Text(
                                      '$percentage%',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'SEUIL: $threshold%',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Barre de progression sur toute la largeur
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                // Barre de progression remplie, ancrée à gauche
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width:
                                      constraints.maxWidth *
                                      (percentage / 100).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for checkered pattern (optimal state)
class CheckeredPatternPainter extends CustomPainter {
  final double opacity;

  CheckeredPatternPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const squareSize = 12.0;

    // S'assurer que l'opacity est dans la plage valide
    final validOpacity = opacity.clamp(0.0, 1.0);

    for (double x = 0; x < size.width; x += squareSize * 2) {
      for (double y = 0; y < size.height; y += squareSize * 2) {
        // White squares
        paint.color = Colors.white.withValues(alpha: validOpacity);
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        canvas.drawRect(
          Rect.fromLTWH(x + squareSize, y + squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckeredPatternPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
