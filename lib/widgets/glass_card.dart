import 'package:flutter/material.dart';
import 'package:result_wave/utils/constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const GlassCard({
    Key? key,
    required this.child,
    this.onTap,
    this.elevation = 4,
    this.padding,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppConstants.borderRadiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.surfaceDark.withOpacity(0.8),
                  AppColors.backgroundDark.withOpacity(0.9),
                ]
              : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.95)],
        ),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: elevation,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppConstants.borderRadiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              borderRadius ??
              BorderRadius.circular(AppConstants.borderRadiusLg),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientCard extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;
  final VoidCallback? onTap;

  const GradientCard({Key? key, required this.child, this.gradient, this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.primary,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }
}
