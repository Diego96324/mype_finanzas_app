import 'package:flutter/material.dart';

/// Botón reutilizable con variantes (filled, outlined, tonal) y estado de carga.
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final IconData? icon;
  final ButtonVariant variant;
  final Color? color;
  final Color? textColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.icon,
    this.variant = ButtonVariant.filled,
    this.color,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveText = textColor ??
        (variant == ButtonVariant.filled ? theme.colorScheme.onPrimary : theme.colorScheme.primary);

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                variant == ButtonVariant.filled ? theme.colorScheme.onPrimary : effectiveColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: effectiveText),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: effectiveText,
            ),
          ),
        ),
      ],
    );

    final button = switch (variant) {
      ButtonVariant.filled => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveColor,
            foregroundColor: effectiveText,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      ButtonVariant.outlined => OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: effectiveColor, width: 2),
            foregroundColor: effectiveColor,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      ButtonVariant.tonal => FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: effectiveColor.withValues(alpha: 0.15),
            foregroundColor: effectiveColor,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        ),
    };

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

enum ButtonVariant { filled, outlined, tonal }

