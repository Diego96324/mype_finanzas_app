import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget de campo de texto animado con estados de validación visuales
class AnimatedFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Color? primaryColor;
  final Color? cardColor;
  final Color? textColor;
  final bool showSuccessIcon;
  final bool autoValidate;

  const AnimatedFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onTap,
    this.onChanged,
    this.primaryColor,
    this.cardColor,
    this.textColor,
    this.showSuccessIcon = true,
    this.autoValidate = true,
  });

  @override
  State<AnimatedFormField> createState() => _AnimatedFormFieldState();
}

class _AnimatedFormFieldState extends State<AnimatedFormField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  bool _isFocused = false;
  bool _hasError = false;
  bool _isValid = false;
  String? _currentError;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticIn,
      ),
    );

    _focusNode.addListener(_onFocusChange);

    if (widget.autoValidate) {
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChanged() {
    if (!widget.autoValidate) return;

    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() {
        _hasError = false;
        _isValid = false;
        _currentError = null;
      });
      return;
    }

    final error = widget.validator?.call(text);
    setState(() {
      _hasError = error != null;
      _isValid = error == null;
      _currentError = error;
    });

    if (_hasError) {
      _animationController.forward(from: 0);
    }
  }

  Color _getBorderColor() {
    final primaryColor = widget.primaryColor ?? const Color(0xFF13BB67);

    if (_hasError) {
      return Colors.red.shade400;
    }
    if (_isValid && widget.showSuccessIcon) {
      return Colors.green.shade400;
    }
    if (_isFocused) {
      return primaryColor;
    }
    return (widget.textColor ?? Colors.white).withValues(alpha: 0.1);
  }

  Widget? _getSuffixIcon() {
    if (widget.suffixIcon != null) {
      return widget.suffixIcon;
    }

    if (!widget.autoValidate || widget.controller.text.isEmpty) {
      return null;
    }

    if (_hasError) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
            ),
          );
        },
      );
    }

    if (_isValid && widget.showSuccessIcon) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade400,
            ),
          );
        },
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.cardColor ?? const Color(0xFF2D2D2D);
    final textColor = widget.textColor ?? Colors.white;
    final primaryColor = widget.primaryColor ?? const Color(0xFF13BB67);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: _hasError
              ? Offset(_shakeAnimation.value * (1 - _animationController.value), 0)
              : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _hasError
                      ? Colors.red.withValues(alpha: 0.2)
                      : _isValid && widget.showSuccessIcon
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.05),
                  blurRadius: _isFocused ? 15 : 10,
                  offset: const Offset(0, 4),
                  spreadRadius: _isFocused ? 1 : 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  validator: widget.validator,
                  enabled: widget.enabled,
                  onTap: widget.onTap,
                  onChanged: widget.onChanged,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hint,
                    prefixIcon: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.icon,
                        color: _isFocused
                            ? primaryColor
                            : _hasError
                                ? Colors.red.shade400
                                : primaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                    suffixIcon: _getSuffixIcon(),
                    labelStyle: TextStyle(
                      color: _hasError
                          ? Colors.red.shade400
                          : textColor.withValues(alpha: 0.7),
                    ),
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.4),
                    ),
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _getBorderColor(),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _getBorderColor(),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.red.shade400,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.red.shade400,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                // Mensaje de error animado
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: _hasError && _currentError != null
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 8,
                            bottom: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _currentError!,
                                  style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

