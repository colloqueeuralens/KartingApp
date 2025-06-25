import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/live_timing/live_timing_screen.dart';
import '../../screens/strategy/strategy_screen.dart';
import '../../navigation/auth_gate.dart';
import '../../navigation/main_navigator.dart';
import '../../theme/racing_theme.dart';

/// Classe commune pour les actions de l'AppBar avec thème racing
class AppBarActions {
  /// Actions responsive qui s'adaptent à la taille d'écran
  static List<Widget> getResponsiveActions(
    BuildContext context, {
    VoidCallback? onBackToConfig,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Sur mobile (< 600px), utiliser le menu hamburger
    if (screenWidth < 600) {
      return [_buildMobileMenu(context, onBackToConfig: onBackToConfig)];
    }
    
    // Sur desktop, utiliser les boutons horizontaux
    return getActions(context, onBackToConfig: onBackToConfig);
  }

  /// Menu hamburger pour mobile
  static Widget _buildMobileMenu(
    BuildContext context, {
    VoidCallback? onBackToConfig,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.menu,
        color: Colors.white,
        size: 24,
      ),
      color: RacingTheme.racingBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: RacingTheme.racingGreen, width: 1),
      ),
      onSelected: (value) => _handleMenuSelection(context, value, onBackToConfig),
      itemBuilder: (BuildContext context) => [
        _buildMenuItem(
          value: 'dashboard',
          icon: Icons.dashboard,
          label: 'Dashboard',
        ),
        _buildMenuItem(
          value: 'live_timing',
          icon: Icons.timer,
          label: 'Live Timing',
        ),
        _buildMenuItem(
          value: 'strategy',
          icon: Icons.psychology,
          label: 'Stratégie',
        ),
        _buildMenuItem(
          value: 'config',
          icon: Icons.settings,
          label: 'Configuration',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'logout',
          icon: Icons.logout,
          label: 'Déconnexion',
          isDestructive: true,
        ),
      ],
    );
  }

  /// Construire un item de menu avec style racing
  static PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? RacingTheme.bad : RacingTheme.racingGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? RacingTheme.bad : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gérer la sélection du menu mobile
  static void _handleMenuSelection(
    BuildContext context,
    String value,
    VoidCallback? onBackToConfig,
  ) {
    switch (value) {
      case 'dashboard':
        _navigateToDashboard(context, onBackToConfig);
        break;
      case 'live_timing':
        _navigateToLiveTiming(context, onBackToConfig);
        break;
      case 'strategy':
        _navigateToStrategy(context, onBackToConfig);
        break;
      case 'config':
        _navigateToConfig(context);
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  /// Navigation vers Dashboard
  static void _navigateToDashboard(BuildContext context, VoidCallback? onBackToConfig) {
    VoidCallback? configCallback = onBackToConfig;
    if (configCallback == null) {
      final mainNavigator = context.findAncestorStateOfType<MainNavigatorState>();
      if (mainNavigator != null) {
        configCallback = mainNavigator.goToConfig;
      }
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => DashboardScreen(onBackToConfig: configCallback),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigation vers Live Timing
  static void _navigateToLiveTiming(BuildContext context, VoidCallback? onBackToConfig) {
    VoidCallback? configCallback = onBackToConfig;
    if (configCallback == null) {
      final mainNavigator = context.findAncestorStateOfType<MainNavigatorState>();
      if (mainNavigator != null) {
        configCallback = mainNavigator.goToConfig;
      }
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LiveTimingScreen(onBackToConfig: configCallback),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigation vers Stratégie
  static void _navigateToStrategy(BuildContext context, VoidCallback? onBackToConfig) {
    VoidCallback? configCallback = onBackToConfig;
    if (configCallback == null) {
      final mainNavigator = context.findAncestorStateOfType<MainNavigatorState>();
      if (mainNavigator != null) {
        configCallback = mainNavigator.goToConfig;
      }
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => StrategyScreen(onBackToConfig: configCallback),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigation vers Configuration
  static void _navigateToConfig(BuildContext context) {
    final mainNavigator = context.findAncestorStateOfType<MainNavigatorState>();
    if (mainNavigator != null) {
      mainNavigator.goToConfig();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigator()),
        (route) => route.isFirst,
      );
    }
  }

  /// Actions horizontales pour desktop (méthode existante)
  static List<Widget> getActions(
    BuildContext context, {
    VoidCallback? onBackToConfig,
  }) {
    return [
      // Bouton Dashboard avec design racing
      _RacingActionButton(
        icon: Icons.dashboard,
        label: 'Dashboard',
        onPressed: () => _navigateToDashboard(context, onBackToConfig),
      ),

      const SizedBox(width: 8),

      // Bouton Live Timing avec design racing
      _RacingActionButton(
        icon: Icons.timer,
        label: 'Live Timing',
        onPressed: () => _navigateToLiveTiming(context, onBackToConfig),
      ),

      const SizedBox(width: 8),

      // Bouton Stratégie avec design racing
      _RacingActionButton(
        icon: Icons.psychology,
        label: 'Stratégie',
        onPressed: () => _navigateToStrategy(context, onBackToConfig),
      ),

      const SizedBox(width: 8),

      // Bouton Configuration avec design racing
      _RacingActionButton(
        icon: Icons.settings,
        label: 'Config',
        onPressed: () => _navigateToConfig(context),
      ),

      const SizedBox(width: 8),

      // Bouton Déconnexion avec design racing
      _RacingActionButton(
        icon: Icons.logout,
        label: 'Déconnexion',
        isDestructive: true,
        onPressed: () => _showLogoutDialog(context),
      ),

      const SizedBox(width: 8),
    ];
  }

  static void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: RacingTheme.racingRed),
              SizedBox(width: 12),
              Text('Déconnexion'),
            ],
          ),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthGate()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Erreur: $e')),
                          ],
                        ),
                        backgroundColor: RacingTheme.bad,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: RacingTheme.bad,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Widget de bouton d'action racing personnalisé
class _RacingActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _RacingActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  State<_RacingActionButton> createState() => _RacingActionButtonState();
}

class _RacingActionButtonState extends State<_RacingActionButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) {
          _animationController.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _animationController.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: _isHovered
                      ? (widget.isDestructive
                            ? RacingTheme.bad.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.2))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _isHovered
                      ? Border.all(
                          color: widget.isDestructive
                              ? RacingTheme.bad
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1,
                        )
                      : null,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.isDestructive && _isHovered
                          ? RacingTheme.bad
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.isDestructive && _isHovered
                            ? RacingTheme.bad
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
