import 'package:flutter/material.dart';
import '../../theme/racing_theme.dart';

/// Sections de debug pliables pour les données techniques
class DebugSections extends StatelessWidget {
  final Map<String, dynamic>? lastTimingData;
  final String? lastRawMessage;

  const DebugSections({
    super.key,
    this.lastTimingData,
    this.lastRawMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (lastTimingData == null && lastRawMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (lastTimingData != null) ...[
            _buildMappedDataSection(),
            const SizedBox(height: 8),
            _buildRawDataSection(),
            const SizedBox(height: 8),
          ],
          if (lastRawMessage != null) _buildWebSocketSection(),
        ],
      ),
    );
  }

  Widget _buildMappedDataSection() {
    final data = lastTimingData!['data'] as Map<String, dynamic>? ?? {};
    final mappedData = data['mapped_data'] as Map<String, dynamic>? ?? {};

    if (mappedData.isEmpty) return const SizedBox.shrink();

    return _ExpandableSection(
      title: 'DONNÉES MAPPÉES (C1-C14)',
      icon: Icons.data_array,
      color: RacingTheme.racingYellow,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: mappedData.entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: RacingTheme.racingBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: RacingTheme.racingBlue,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRawDataSection() {
    final data = lastTimingData!['data'] as Map<String, dynamic>? ?? {};
    final rawData = data['raw_data'] as Map<String, dynamic>? ?? {};

    if (rawData.isEmpty) return const SizedBox.shrink();

    return _ExpandableSection(
      title: 'DONNÉES BRUTES',
      icon: Icons.terminal,
      color: RacingTheme.racingGreen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rawData.toString(),
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: RacingTheme.racingGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildWebSocketSection() {
    return _ExpandableSection(
      title: 'MESSAGE WEBSOCKET BRUT',
      icon: Icons.wifi,
      color: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                lastRawMessage!,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.purple,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade800.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Longueur: ${lastRawMessage!.length} caractères',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Contient "grid||": ${lastRawMessage!.contains("grid||")}',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Contient "init": ${lastRawMessage!.contains("init")}',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _iconRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.color.withValues(alpha: 0.1),
            widget.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header cliquable
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.color,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _iconRotation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _iconRotation.value * 3.14159,
                        child: Icon(
                          Icons.expand_more,
                          color: widget.color,
                          size: 24,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Contenu expandable
          SizeTransition(
            sizeFactor: _heightAnimation,
            child: Container(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}