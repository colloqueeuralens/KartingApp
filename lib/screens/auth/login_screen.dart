import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/racing_theme.dart';
import '../../widgets/common/glassmorphism_container.dart';
import 'dart:math' as math;

/// Écran de connexion avec thème racing et glassmorphism
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;

  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _backgroundController;

  late Animation<double> _logoRotation;
  late Animation<double> _formSlide;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _logoRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Form animation controller
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _formSlide = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _formController,
        curve: Curves.easeOut, // ← plus d’overshoot
      ),
    );

    // Background animation controller
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoController.forward();
    _formController.forward();
    _backgroundController.repeat();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _backgroundController.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtl.text.trim(),
        password: _passCtl.text,
      );
      // AuthGate détectera le changement et naviguera automatiquement
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.message ?? 'Erreur de connexion')),
              ],
            ),
            backgroundColor: RacingTheme.bad,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A1628), // Bleu marine très foncé
                const Color(0xFF1E3A8A), // Bleu marine moyen
                const Color(0xFF1E40AF), // Bleu légèrement plus clair
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Effet de texture satiné subtile
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    painter: SilkTexturePainter(_backgroundAnimation.value),
                  ),
                ),
              ),
              // Effet de vagues subtiles
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(
                    painter: WavesPainter(_backgroundAnimation.value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/KMRS.jpg',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback en cas d'erreur de chargement
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade700,
              ),
              child: const Icon(
                Icons.sports_motorsports,
                color: Colors.white,
                size: 60,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'KMRS Analyzer',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 2,
        shadows: [
          Shadow(
            offset: const Offset(0, 2),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return AnimatedBuilder(
      animation: _formSlide,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * _formSlide.value),
          child: Opacity(
            opacity: 1 - _formSlide.value,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(24),
              child: GlassmorphismContainer(
                blur: 20,
                opacity: 0.15,
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Email Field
                      TextFormField(
                        controller: _emailCtl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Adresse email',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          hintText: 'exemple@email.com',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: RacingTheme.bad,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: RacingTheme.bad,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'Email invalide',
                      ),

                      const SizedBox(height: 24),

                      // Password Field
                      TextFormField(
                        controller: _passCtl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          hintText: 'Minimum 6 caractères',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: RacingTheme.bad,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: RacingTheme.bad,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        obscureText: true,
                        validator: (v) => v != null && v.length >= 6
                            ? null
                            : '6 caractères minimum',
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      if (_loading)
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                RacingTheme.racingGreen.withValues(alpha: 0.8),
                                RacingTheme.racingGreen,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: RacingTheme.racingGreen.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Connexion...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.login, color: Colors.white),
                            label: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style:
                                ElevatedButton.styleFrom(
                                  backgroundColor: RacingTheme.racingGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  shadowColor: RacingTheme.racingGreen
                                      .withValues(alpha: 0.3),
                                ).copyWith(
                                  elevation:
                                      WidgetStateProperty.resolveWith<double>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.pressed,
                                        ))
                                          return 2;
                                        return 8;
                                      }),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background
            Positioned.fill(child: _buildBackground()),

            // Main Content
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    // Titres en haut
                    Padding(
                      padding: const EdgeInsets.only(top: 60, bottom: 40),
                      child: _buildTitle(),
                    ),

                    // Logo au centre
                    _buildLogo(),

                    const SizedBox(height: 60),

                    // Form en bas
                    Expanded(
                      child: SingleChildScrollView(child: _buildLoginForm()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter pour effet de texture satiné
class SilkTexturePainter extends CustomPainter {
  final double animation;

  SilkTexturePainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Lignes diagonales pour effet satiné
    for (double i = -size.width; i < size.width + size.height; i += 8) {
      final offset = (animation * 20) % 16;
      paint.color = Colors.white.withValues(alpha: 0.02);
      canvas.drawLine(
        Offset(i + offset, 0),
        Offset(i + size.height + offset, size.height),
        paint,
      );
    }

    // Lignes croisées pour plus de profondeur
    for (double i = 0; i < size.height + size.width; i += 12) {
      final offset = (animation * -15) % 18;
      paint.color = Colors.white.withValues(alpha: 0.01);
      canvas.drawLine(
        Offset(0, i + offset),
        Offset(size.width, i - size.width + offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SilkTexturePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

/// Custom painter pour effet de vagues subtiles
class WavesPainter extends CustomPainter {
  final double animation;

  WavesPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();

    // Première vague
    paint.color = Colors.white.withValues(alpha: 0.03);
    path.reset();
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          size.height * 0.3 +
          30 * math.sin((x / 80) + (animation * 2 * math.pi));
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Deuxième vague
    paint.color = Colors.white.withValues(alpha: 0.02);
    path.reset();
    for (double x = 0; x <= size.width; x += 1) {
      final y =
          size.height * 0.7 +
          20 * math.sin((x / 60) - (animation * 1.5 * math.pi));
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
