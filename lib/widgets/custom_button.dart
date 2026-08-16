import 'package:flutter/material.dart';

Color _foregroundOnFill(ColorScheme scheme, Color fill, Color? explicit) {
  if (explicit != null) return explicit;
  if (fill == scheme.primary) return scheme.onPrimary;
  if (fill == scheme.error) return scheme.onError;
  if (fill == scheme.secondary) return scheme.onSecondary;
  if (fill == scheme.tertiary) return scheme.onTertiary;
  if (fill == scheme.primaryContainer) return scheme.onPrimaryContainer;
  if (fill == scheme.secondaryContainer) return scheme.onSecondaryContainer;
  if (fill == scheme.tertiaryContainer) return scheme.onTertiaryContainer;
  final brightness = ThemeData.estimateBrightnessForColor(fill);
  return brightness == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
}

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
    this.borderRadius = 12,
    this.icon,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final defaultBackgroundColor = backgroundColor ?? scheme.primary;
    final filledForeground = _foregroundOnFill(
      scheme,
      defaultBackgroundColor,
      textColor,
    );
    final outlinedForeground =
        textColor ?? backgroundColor ?? scheme.primary;

    // Filled buttons use M3 defaults that often fail WCAG when disabled on dark
    // themes. Opaque blend keeps text/icons readable while still reading muted.
    final disabledFill = scheme.surfaceContainerHighest;
    final disabledBlendBase = isOutlined ? scheme.surface : disabledFill;
    final disabledForeground = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: isOutlined ? 0.38 : 0.78),
      disabledBlendBase,
    );
    final disabledOutline = scheme.outline.withValues(alpha: 0.35);

    final showDisabledChrome = isLoading || onPressed == null;

    final labelBase = theme.textTheme.labelLarge;
    final buttonLabelStyle = TextStyle(
      inherit: true,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: labelBase?.fontFamily,
      fontFamilyFallback: labelBase?.fontFamilyFallback,
      letterSpacing: labelBase?.letterSpacing,
      height: labelBase?.height,
    );

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (isOutlined) return Colors.transparent;
            if (states.contains(WidgetState.disabled)) return disabledFill;
            return defaultBackgroundColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return disabledForeground;
            return isOutlined ? outlinedForeground : filledForeground;
          }),
          elevation: WidgetStateProperty.all(isOutlined ? 0.0 : 2.0),
          shadowColor: WidgetStateProperty.all(
            isOutlined ? Colors.transparent : null,
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (!isOutlined) return BorderSide.none;
            final disabled = states.contains(WidgetState.disabled);
            return BorderSide(
              color: disabled ? disabledOutline : defaultBackgroundColor,
              width: 2,
            );
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    showDisabledChrome
                        ? disabledForeground
                        : (isOutlined
                            ? outlinedForeground
                            : filledForeground),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: buttonLabelStyle,
                  ),
                ],
              ),
      ),
    );
  }
}
