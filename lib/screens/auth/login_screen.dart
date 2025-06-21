import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/racing_theme.dart';

/// Écran de connexion / inscription avec thème racing
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
  bool _isRegister = false, _loading = false;

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
      if (_isRegister) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtl.text.trim(),
          password: _passCtl.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtl.text.trim(),
          password: _passCtl.text,
        );
      }
      // AuthGate détectera le changement et naviguera automatiquement
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.message ?? 'Erreur Firebase')),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade100, Colors.grey.shade50, Colors.white],
        ),
      ),
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
    return Column(
      children: [
        Text(
          'KMRS Racing',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kart Management & Racing System',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isRegister ? 'Créer un compte' : 'Connexion',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: RacingTheme.racingBlack,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Email Field
                        TextFormField(
                          controller: _emailCtl,
                          decoration: const InputDecoration(
                            labelText: 'Adresse email',
                            prefixIcon: Icon(Icons.email_outlined),
                            hintText: 'exemple@email.com',
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
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outline),
                            hintText: 'Minimum 6 caractères',
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
                              borderRadius: BorderRadius.circular(8),
                              color: RacingTheme.racingGreen,
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _submit,
                              icon: Icon(
                                _isRegister ? Icons.person_add : Icons.login,
                              ),
                              label: Text(
                                _isRegister ? 'S\'inscrire' : 'Se connecter',
                              ),
                              style: ElevatedButton.styleFrom(
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Toggle Button
                        TextButton(
                          onPressed: () =>
                              setState(() => _isRegister = !_isRegister),
                          child: Text(
                            _isRegister
                                ? 'J\'ai déjà un compte'
                                : 'Pas encore inscrit ?',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
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

/// Custom painter for checkered flag pattern
class CheckeredFlagPainter extends CustomPainter {
  final double animation;

  CheckeredFlagPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const squareSize = 20.0;
    final offset = animation * squareSize;

    for (
      double x = -squareSize + offset;
      x < size.width + squareSize;
      x += squareSize * 2
    ) {
      for (
        double y = -squareSize;
        y < size.height + squareSize;
        y += squareSize * 2
      ) {
        // White squares
        paint.color = Colors.white.withValues(alpha: 0.05);
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
        canvas.drawRect(
          Rect.fromLTWH(x + squareSize, y + squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckeredFlagPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
