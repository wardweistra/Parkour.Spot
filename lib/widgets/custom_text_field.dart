import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Widget? suffixIconWidget;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final void Function()? onTap;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final List<String>? autofillHints;
  final bool enabled;
  final bool autofocus;
  final String? helperText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixIconWidget,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.enabled = true,
    this.autofocus = false,
    this.helperText,
  });

  static InputDecoration decoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    String? helperText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline.withValues(alpha: 0.5)),
      focusedBorder: border(scheme.primary, width: 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, width: 2),
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textInputAction: textInputAction,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      decoration: decoration(
        context,
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon:
            suffixIconWidget ?? (suffixIcon != null ? Icon(suffixIcon) : null),
      ),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
      ),
    );
  }
}
