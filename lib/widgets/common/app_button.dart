import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;
  final List<Color>? gradient;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant  = AppButtonVariant.primary,
    this.loading  = false,
    this.fullWidth= true,
    this.icon,
    this.height,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        opacity:  (loading || onTap == null) ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    final colors = gradient ?? _defaultGradient();
    final h      = height ?? 52.0;

    return Container(
      width:  fullWidth ? double.infinity : null,
      height: h,
      decoration: BoxDecoration(
        gradient:     variant == AppButtonVariant.primary
            ? LinearGradient(colors: colors,
                begin: Alignment.centerLeft, end: Alignment.centerRight)
            : null,
        color: variant == AppButtonVariant.secondary
            ? AppColors.surfaceElevated
            : variant == AppButtonVariant.outline
                ? Colors.transparent
                : variant == AppButtonVariant.ghost
                    ? Colors.transparent
                    : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: (variant == AppButtonVariant.outline)
            ? Border.all(color: AppColors.border)
            : null,
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _labelColor(),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: _labelColor(), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      _labelColor(),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _labelColor() {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.textInverse;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return AppColors.textPrimary;
    }
  }

  List<Color> _defaultGradient() {
    return [AppColors.verdigris, AppColors.chartreuse];
  }
}

/// Gradient text button used in "Approve & Execute" pattern
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final List<Color> colors;
  final double height;
  final Color? textColor;
  final double fontSize;
  final FontWeight fontWeight;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.colors    = const [AppColors.chartreuse, AppColors.chartreuseB],
    this.height    = 48,
    this.textColor,
    this.fontSize  = 14,
    this.fontWeight= FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height:      height,
        decoration: BoxDecoration(
          gradient:     LinearGradient(colors: colors,
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:      textColor ?? AppColors.bgDark,
              fontSize:   fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}
