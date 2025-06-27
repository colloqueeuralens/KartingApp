import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../theme/racing_theme.dart';

/// Input field avec effet glassmorphism pour KMRS
class GlassmorphismInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType inputType;
  final String? Function(String?)? validator;
  final bool isRequired;
  final Color? accentColor;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final bool obscureText;
  final VoidCallback? onTap;
  final bool readOnly;

  const GlassmorphismInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.inputType = TextInputType.text,
    this.validator,
    this.isRequired = true,
    this.accentColor,
    this.inputFormatters,
    this.maxLines = 1,
    this.obscureText = false,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<GlassmorphismInputField> createState() => _GlassmorphismInputFieldState();
}

class _GlassmorphismInputFieldState extends State<GlassmorphismInputField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    setState(() {
      _isFocused = hasFocus;
    });
    
    if (hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? RacingTheme.racingGreen;
    
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label avec icône
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: _isFocused ? accent : Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: _isFocused ? accent : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isRequired)
                    Text(
                      ' *',
                      style: TextStyle(
                        color: RacingTheme.bad,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            
            // Input field container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasError
                      ? RacingTheme.bad
                      : _isFocused
                          ? accent
                          : Colors.white.withValues(alpha: 0.3),
                  width: _isFocused ? 2 : 1,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isFocused ? 10 : 5,
                    sigmaY: _isFocused ? 10 : 5,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isFocused
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: widget.controller,
                      keyboardType: widget.inputType,
                      inputFormatters: widget.inputFormatters,
                      maxLines: widget.maxLines,
                      obscureText: widget.obscureText,
                      readOnly: widget.readOnly,
                      onTap: widget.onTap,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: widget.readOnly
                            ? Icon(
                                Icons.lock_outline,
                                color: Colors.white.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                      validator: widget.validator ??
                          (widget.isRequired
                              ? (value) {
                                  if (value == null || value.isEmpty) {
                                    setState(() {
                                      _hasError = true;
                                    });
                                    return 'Ce champ est requis';
                                  }
                                  setState(() {
                                    _hasError = false;
                                  });
                                  return null;
                                }
                              : null),
                      onChanged: (value) {
                        if (_hasError) {
                          setState(() {
                            _hasError = false;
                          });
                        }
                      },
                      onTapOutside: (event) {
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dropdown field avec effet glassmorphism
class GlassmorphismDropdownField<T> extends StatefulWidget {
  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool isRequired;
  final Color? accentColor;
  final String hint;

  const GlassmorphismDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.isRequired = true,
    this.accentColor,
    required this.hint,
  });

  @override
  State<GlassmorphismDropdownField<T>> createState() => _GlassmorphismDropdownFieldState<T>();
}

class _GlassmorphismDropdownFieldState<T> extends State<GlassmorphismDropdownField<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
      animation: _focusAnimation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label avec icône
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: _isFocused ? accent : Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: _isFocused ? accent : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isRequired)
                    Text(
                      ' *',
                      style: TextStyle(
                        color: RacingTheme.bad,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            
            // Dropdown container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasError
                      ? RacingTheme.bad
                      : _isFocused
                          ? accent
                          : Colors.white.withValues(alpha: 0.3),
                  width: _isFocused ? 2 : 1,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isFocused ? 10 : 5,
                    sigmaY: _isFocused ? 10 : 5,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isFocused
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<T>(
                      value: widget.value,
                      items: widget.items,
                      onChanged: widget.onChanged,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      dropdownColor: RacingTheme.racingBlack,
                      validator: widget.validator ??
                          (widget.isRequired
                              ? (value) {
                                  if (value == null) {
                                    setState(() {
                                      _hasError = true;
                                    });
                                    return 'Sélectionnez une option';
                                  }
                                  setState(() {
                                    _hasError = false;
                                  });
                                  return null;
                                }
                              : null),
                      onTap: () {
                        setState(() {
                          _isFocused = true;
                        });
                        _animationController.forward();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}