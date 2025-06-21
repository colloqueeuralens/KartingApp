import 'package:flutter/material.dart';

/// Widget d'affichage des temps avec format racing professionnel
class LiveTimingDisplay extends StatefulWidget {
  final String? lapTime;
  final String? bestTime;
  final int? position;
  final String? gap;
  final bool isLiveUpdate;

  const LiveTimingDisplay({
    super.key,
    this.lapTime,
    this.bestTime,
    this.position,
    this.gap,
    this.isLiveUpdate = false,
  });

  @override
  State<LiveTimingDisplay> createState() => _LiveTimingDisplayState();
}

class _LiveTimingDisplayState extends State<LiveTimingDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _updateController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _updateController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _colorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.amber[300],
    ).animate(_updateController);
  }

  @override
  void didUpdateWidget(LiveTimingDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animation lors d'une mise à jour en direct
    if (widget.isLiveUpdate &&
        (widget.lapTime != oldWidget.lapTime ||
            widget.position != oldWidget.position)) {
      _updateController.forward().then((_) {
        _updateController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _updateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                _colorAnimation.value?.withValues(alpha: 0.1) ??
                Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Position et temps principal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.position != null)
                    PositionBadge(position: widget.position!),
                  if (widget.lapTime != null)
                    RacingTimeDisplay(
                      time: widget.lapTime!,
                      label: 'Dernier T.',
                      isPrimary: true,
                    ),
                ],
              ),

              if (widget.bestTime != null || widget.gap != null)
                const SizedBox(height: 12),

              // Temps secondaires
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.bestTime != null)
                    RacingTimeDisplay(
                      time: widget.bestTime!,
                      label: 'Meilleur T.',
                      isPrimary: false,
                    ),
                  if (widget.gap != null) GapDisplay(gap: widget.gap!),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Badge de position avec style racing
class PositionBadge extends StatelessWidget {
  final int position;

  const PositionBadge({super.key, required this.position});

  Color _getPositionColor() {
    switch (position) {
      case 1:
        return Colors.amber[600]!; // Or
      case 2:
        return Colors.grey[400]!; // Argent
      case 3:
        return Colors.brown[400]!; // Bronze
      default:
        return Colors.blue[600]!; // Autre
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getPositionColor(),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: _getPositionColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          position.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Affichage de temps au format racing
class RacingTimeDisplay extends StatelessWidget {
  final String time;
  final String label;
  final bool isPrimary;

  const RacingTimeDisplay({
    super.key,
    required this.time,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPrimary ? Colors.green[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPrimary ? Colors.green[300]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Text(
            _formatRacingTime(time),
            style: TextStyle(
              fontSize: isPrimary ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.green[700] : Colors.grey[700],
              fontFamily: 'monospace', // Police monospace pour l'alignement
            ),
          ),
        ),
      ],
    );
  }

  String _formatRacingTime(String time) {
    // Si le temps est déjà au bon format, le retourner tel quel
    if (time.contains(':') && time.contains('.')) {
      return time;
    }

    // Sinon, essayer de le formatter
    try {
      final double seconds = double.parse(time);
      final int minutes = (seconds / 60).floor();
      final double remainingSeconds = seconds % 60;

      return '${minutes}:${remainingSeconds.toStringAsFixed(3).padLeft(6, '0')}';
    } catch (e) {
      return time; // Retourner tel quel si parsing échoue
    }
  }
}

/// Affichage de l'écart
class GapDisplay extends StatelessWidget {
  final String gap;

  const GapDisplay({super.key, required this.gap});

  @override
  Widget build(BuildContext context) {
    final bool isPositive = !gap.startsWith('-');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Écart',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPositive ? Colors.red[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPositive ? Colors.red[300]! : Colors.green[300]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.add : Icons.remove,
                size: 12,
                color: isPositive ? Colors.red[700] : Colors.green[700],
              ),
              Text(
                gap.replaceFirst('-', ''),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.red[700] : Colors.green[700],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
