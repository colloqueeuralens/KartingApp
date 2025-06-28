import 'package:flutter/material.dart';
import 'dart:ui';

/// Container avec effet glassmorphism pour overlays et notifications
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final Border? border;

  const GlassmorphismContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border:
            border ??
            Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Notification glassmorphism pour moment optimal
class OptimalMomentNotification extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onDismiss;

  const OptimalMomentNotification({
    super.key,
    required this.isVisible,
    this.onDismiss,
  });

  @override
  State<OptimalMomentNotification> createState() =>
      _OptimalMomentNotificationState();
}

class _OptimalMomentNotificationState extends State<OptimalMomentNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isVisible) {
      _slideController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(OptimalMomentNotification oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !oldWidget.isVisible) {
      _slideController.forward();
      _pulseController.repeat(reverse: true);
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _slideController.reverse();
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _pulseAnimation]),
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: GlassmorphismContainer(
                blur: 15,
                opacity: 0.25,
                color: Colors.green,
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                  width: 2,
                ),
                child: Row(
                  children: [
                    // Icône
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Contenu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "C'EST LE MOMENT!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Performance optimale atteinte",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bouton fermer
                    if (widget.onDismiss != null)
                      IconButton(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.close, color: Colors.white),
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

/// Modal dialog avec effet glassmorphism
class GlassmorphismDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const GlassmorphismDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // 🖥️ Détecter si web pour contraindre la largeur
    final isWeb = MediaQuery.of(context).size.width > 600;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWeb ? 700 : double.infinity, // 🎨 Web: proportionné aux dropdowns (650px + marge)
        ),
        child: GlassmorphismContainer(
          blur: 20,
          opacity: 0.15,
          color: Colors.white,
          padding: const EdgeInsets.all(8), // 🎨 Padding encore plus compact pour harmonie
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titre
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 16, // 🎨 Taille proportionnelle aux nouveaux dropdowns
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8), // 🎨 Espacement plus compact
              ],

              // Contenu
              child,

              // Actions
              if (actions != null) ...[
                const SizedBox(height: 8), // 🎨 Espacement plus compact
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay glassmorphism pour live timing
class LiveTimingOverlay extends StatelessWidget {
  final Widget child;
  final bool isVisible;
  final VoidCallback? onClose;

  const LiveTimingOverlay({
    super.key,
    required this.child,
    required this.isVisible,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        child: GlassmorphismContainer(
          blur: 15,
          opacity: 0.2,
          color: Colors.black,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          child: Stack(
            children: [
              child,

              // Bouton fermer
              if (onClose != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Button avec effet glassmorphism
class GlassmorphismButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;

  const GlassmorphismButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassmorphismContainer(
        blur: 10,
        opacity: 0.2,
        color: color ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: child,
      ),
    );
  }
}
