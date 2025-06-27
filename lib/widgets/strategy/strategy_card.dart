import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/racing_theme.dart';

/// Card de stratégie avec design racing glassmorphe
class StrategyCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final Color? accentColor;
  final bool showBorder;
  final EdgeInsets? padding;
  final double? height;

  const StrategyCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.icon,
    this.onTap,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.accentColor,
    this.showBorder = true,
    this.padding,
    this.height,
  });

  @override
  State<StrategyCard> createState() => _StrategyCardState();
}

class _StrategyCardState extends State<StrategyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
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
    final accentColor = widget.accentColor ?? RacingTheme.racingGreen;
    
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap?.call();
              },
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: widget.showBorder
                      ? Border.all(
                          color: _isHovered
                              ? accentColor
                              : accentColor.withValues(alpha: 0.3),
                          width: _isHovered ? 2 : 1,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: _isHovered ? 0.3 : 0.1),
                      blurRadius: _isHovered ? 20 : 10,
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(accentColor),
                      if (!widget.isCollapsed) _buildContent(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.2),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
        border: widget.isCollapsed
            ? null
            : Border(
                bottom: BorderSide(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.onToggleCollapse != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onToggleCollapse?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: widget.isCollapsed ? 0 : _rotationAnimation.value * 3.14159,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 16,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: widget.child,
    );
  }
}

/// Card de métrique racing avec valeur et label
class StrategyMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? accentColor;
  final bool isLoading;
  final VoidCallback? onTap;

  const StrategyMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accentColor,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? RacingTheme.racingGreen;
    
    return StrategyCard(
      title: label,
      icon: icon,
      accentColor: color,
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 2,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      unit!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Card d'état avec indicateur coloré
class StrategyStatusCard extends StatelessWidget {
  final String title;
  final String status;
  final IconData statusIcon;
  final Color statusColor;
  final String? description;
  final VoidCallback? onTap;

  const StrategyStatusCard({
    super.key,
    required this.title,
    required this.status,
    required this.statusIcon,
    required this.statusColor,
    this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StrategyCard(
      title: title,
      accentColor: statusColor,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card d'action avec bouton stylisé
class StrategyActionCard extends StatelessWidget {
  final String title;
  final String buttonText;
  final IconData? buttonIcon;
  final VoidCallback onPressed;
  final Color? accentColor;
  final bool isLoading;
  final String? description;

  const StrategyActionCard({
    super.key,
    required this.title,
    required this.buttonText,
    this.buttonIcon,
    required this.onPressed,
    this.accentColor,
    this.isLoading = false,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? RacingTheme.racingGreen;
    
    return StrategyCard(
      title: title,
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (description != null) ...[
            Text(
              description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onPressed,
                  icon: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        )
                      : Icon(buttonIcon ?? Icons.play_arrow),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
            ),
        ],
      ),
    );
  }
}