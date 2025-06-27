import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/racing_theme.dart';

/// TabBar avec effet glassmorphism pour la Strategy Screen
class GlassmorphismTabBar extends StatefulWidget implements PreferredSizeWidget {
  final List<GlassmorphismTab> tabs;
  final TabController controller;
  final Color? accentColor;
  final Gradient? backgroundGradient;
  final Function(int)? onTap;

  const GlassmorphismTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.accentColor,
    this.backgroundGradient,
    this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(85);

  @override
  State<GlassmorphismTabBar> createState() => _GlassmorphismTabBarState();
}

class _GlassmorphismTabBarState extends State<GlassmorphismTabBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? RacingTheme.racingGreen;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 85,
          decoration: BoxDecoration(
            gradient: widget.backgroundGradient ?? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                RacingTheme.racingBlack,
                RacingTheme.racingBlack.withValues(alpha: 0.9),
                RacingTheme.racingBlack.withValues(alpha: 0.7),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: accent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: widget.tabs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tab = entry.value;
                      final isSelected = widget.controller.index == index;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildTab(
                          tab: tab,
                          index: index,
                          isSelected: isSelected,
                          accent: accent,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab({
    required GlassmorphismTab tab,
    required int index,
    required bool isSelected,
    required Color accent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.controller.animateTo(index);
            widget.onTap?.call(index);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.3),
                        accent.withValues(alpha: 0.15),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tab.icon,
                    color: isSelected ? accent : Colors.white70,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.title,
                      style: TextStyle(
                        color: isSelected ? accent : Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    if (tab.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        tab.subtitle!,
                        style: TextStyle(
                          color: isSelected
                              ? accent.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Data class pour les onglets glassmorphism
class GlassmorphismTab {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;

  const GlassmorphismTab({
    required this.title,
    this.subtitle,
    required this.icon,
    this.accentColor,
  });
}

/// Wrapper pour intégrer GlassmorphismTabBar dans un AppBar
class GlassmorphismAppBarBottom extends StatelessWidget implements PreferredSizeWidget {
  final List<GlassmorphismTab> tabs;
  final TabController controller;
  final Color? accentColor;
  final Function(int)? onTap;

  const GlassmorphismAppBarBottom({
    super.key,
    required this.tabs,
    required this.controller,
    this.accentColor,
    this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(85);

  @override
  Widget build(BuildContext context) {
    return GlassmorphismTabBar(
      tabs: tabs,
      controller: controller,
      accentColor: accentColor,
      onTap: onTap,
    );
  }
}

/// TabBarView avec transitions fluides
class GlassmorphismTabBarView extends StatefulWidget {
  final TabController controller;
  final List<Widget> children;
  final Duration animationDuration;

  const GlassmorphismTabBarView({
    super.key,
    required this.controller,
    required this.children,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<GlassmorphismTabBarView> createState() => _GlassmorphismTabBarViewState();
}

class _GlassmorphismTabBarViewState extends State<GlassmorphismTabBarView>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _currentIndex = widget.controller.index;
    _fadeController.forward();
    
    widget.controller.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTabChange);
    _fadeController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (widget.controller.index != _currentIndex) {
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentIndex = widget.controller.index;
          });
          _fadeController.forward();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _fadeAnimation.value) * 20),
            child: widget.children[_currentIndex],
          ),
        );
      },
    );
  }
}