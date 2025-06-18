import 'package:flutter/material.dart';

/// Design system racing pour KMRS Racing
class RacingTheme {
  // Couleurs principales racing
  static const Color racingRed = Color(0xFFDC143C);
  static const Color racingBlack = Color(0xFF1C1C1C);
  static const Color racingWhite = Color(0xFFFFFFFF);
  static const Color racingGreen = Color(0xFF228B22);
  static const Color racingYellow = Color(0xFFFFD700);
  static const Color racingBlue = Color(0xFF4169E1);

  // Couleurs de performance
  static const Color excellent = Color(0xFF00C851);
  static const Color good = Color(0xFF66BB6A);
  static const Color neutral = Color(0xFFFF8F00);
  static const Color poor = Color(0xFFFF5722);
  static const Color bad = Color(0xFFD32F2F);
  static const Color unknown = Color(0xFF9E9E9E);

  // Gradients racing
  static const LinearGradient racingGradient = LinearGradient(
    colors: [racingRed, Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient checkeredGradient = LinearGradient(
    colors: [racingBlack, Color(0xFF424242)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [racingGreen, Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Espacement racing
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // Rayons racing
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  // Ombres racing
  static List<BoxShadow> racingShadow = [
    BoxShadow(
      color: racingRed.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> darkShadow = [
    BoxShadow(
      color: racingBlack.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  /// Couleur basée sur la performance
  static Color getPerformanceColor(String perf) {
    switch (perf) {
      case '++':
        return excellent;
      case '+':
        return good;
      case '~':
        return neutral;
      case '-':
        return poor;
      case '--':
        return bad;
      case '?':
        return unknown;
      default:
        return unknown;
    }
  }

  /// Icône basée sur la performance
  static IconData getPerformanceIcon(String perf) {
    switch (perf) {
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

  /// Thème principal de l'application
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.grey.withValues(alpha: 0.2),
        brightness: Brightness.light,
        primary: Colors.grey.shade700,
        secondary: Colors.grey.shade600,
        surface: racingWhite,
        error: bad,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: racingBlack,
        foregroundColor: racingWhite,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: racingWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: racingBlack.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        margin: const EdgeInsets.all(paddingS),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: racingGreen,
          foregroundColor: racingWhite,
          elevation: 4,
          padding: const EdgeInsets.symmetric(
            horizontal: paddingL,
            vertical: paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: racingBlack),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: bad, width: 2),
        ),
        contentPadding: const EdgeInsets.all(paddingM),
      ),

      // Typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: racingBlack,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        headlineMedium: TextStyle(
          color: racingBlack,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        titleLarge: TextStyle(
          color: racingBlack,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
        bodyLarge: TextStyle(
          color: racingBlack,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: racingBlack,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Composants UI racing réutilisables
class RacingWidgets {
  /// Container racing avec gradient
  static Widget racingContainer({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(RacingTheme.paddingM),
      decoration: BoxDecoration(
        gradient: gradient ?? RacingTheme.racingGradient,
        borderRadius:
            borderRadius ?? BorderRadius.circular(RacingTheme.radiusM),
        boxShadow: boxShadow ?? RacingTheme.racingShadow,
      ),
      child: child,
    );
  }

  /// Badge de performance racing
  static Widget performanceBadge(String perf) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RacingTheme.paddingS,
        vertical: RacingTheme.paddingXS,
      ),
      decoration: BoxDecoration(
        color: RacingTheme.getPerformanceColor(perf),
        borderRadius: BorderRadius.circular(RacingTheme.radiusS),
        boxShadow: [
          BoxShadow(
            color: RacingTheme.getPerformanceColor(perf).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            RacingTheme.getPerformanceIcon(perf),
            color: RacingTheme.racingWhite,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            perf,
            style: const TextStyle(
              color: RacingTheme.racingWhite,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Pattern damier pour les victoires
  static Widget checkeredPattern({
    required double width,
    required double height,
    double opacity = 0.1,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: RacingTheme.checkeredGradient.scale(opacity),
      ),
      child: CustomPaint(painter: CheckeredPatternPainter(opacity: opacity)),
    );
  }
}

/// Painter pour motif damier
class CheckeredPatternPainter extends CustomPainter {
  final double opacity;

  CheckeredPatternPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RacingTheme.racingWhite.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    const squareSize = 20.0;

    for (double x = 0; x < size.width; x += squareSize * 2) {
      for (double y = 0; y < size.height; y += squareSize * 2) {
        // Carré en alternance
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        canvas.drawRect(
          Rect.fromLTWH(x + squareSize, y + squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
