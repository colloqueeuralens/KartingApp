import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/kmrs_models.dart';
import '../../theme/racing_theme.dart';

/// Card pilote avec effet glassmorphism et animations
class GlassmorphismPilotCard extends StatefulWidget {
  final PilotData pilot;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color? accentColor;

  const GlassmorphismPilotCard({
    super.key,
    required this.pilot,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.accentColor,
  });

  @override
  State<GlassmorphismPilotCard> createState() => _GlassmorphismPilotCardState();
}

class _GlassmorphismPilotCardState extends State<GlassmorphismPilotCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
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
    
    _fadeAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? RacingTheme.racingGreen;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: MouseRegion(
              onEnter: (_) => _onHover(true),
              onExit: (_) => _onHover(false),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isHovered
                        ? accent.withValues(alpha: 0.5)
                        : accent.withValues(alpha: 0.3),
                    width: _isHovered ? 2 : 1,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isHovered
                              ? [
                                  Colors.white.withValues(alpha: 0.2),
                                  accent.withValues(alpha: 0.1),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Avatar pilote
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accent.withValues(alpha: 0.3),
                                  accent.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                widget.pilot.nickname.isNotEmpty
                                    ? widget.pilot.nickname[0].toUpperCase()
                                    : widget.pilot.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Informations pilote
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.pilot.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDuration(widget.pilot.totalDriveTime),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.flag,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.pilot.totalLaps} tours',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Actions
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionButton(
                                icon: Icons.edit,
                                color: accent,
                                onPressed: widget.onEdit,
                                tooltip: 'Modifier',
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                icon: Icons.delete,
                                color: RacingTheme.bad,
                                onPressed: widget.onDelete,
                                tooltip: 'Supprimer',
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}min';
    }
  }
}

/// Bouton d'ajout de pilote avec glassmorphism
class GlassmorphismAddPilotButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color? accentColor;

  const GlassmorphismAddPilotButton({
    super.key,
    required this.onPressed,
    this.accentColor,
  });

  @override
  State<GlassmorphismAddPilotButton> createState() => _GlassmorphismAddPilotButtonState();
}

class _GlassmorphismAddPilotButtonState extends State<GlassmorphismAddPilotButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

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
    final accent = widget.accentColor ?? RacingTheme.racingGreen;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              setState(() {
                _isPressed = true;
              });
              _animationController.forward();
            },
            onTapUp: (_) {
              setState(() {
                _isPressed = false;
              });
              _animationController.reverse();
              widget.onPressed();
            },
            onTapCancel: () {
              setState(() {
                _isPressed = false;
              });
              _animationController.reverse();
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.5),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.2),
                          accent.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add,
                            color: accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Ajouter un pilote',
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
}