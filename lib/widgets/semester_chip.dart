import 'package:flutter/material.dart';
import 'package:result_wave/utils/constants.dart';

class SemesterChip extends StatelessWidget {
  final int semester;
  final bool isActive;
  final VoidCallback onTap;
  final double? width;
  final double? marginHorizontal;

  const SemesterChip({
    Key? key,
    required this.semester,
    required this.isActive,
    required this.onTap,
    this.width,
    this.marginHorizontal = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: marginHorizontal ?? 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width ?? 100,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ), // Reduced from 16,10 to 12,7 (30% reduction)
          decoration: BoxDecoration(
            gradient: isActive ? AppGradients.primary : null,
            color: isActive
                ? null
                : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(20), // Reduced from 25 to 20
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              width: 0.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              'Semester $semester',
              style: TextStyle(
                fontSize: 12, // Reduced from 13 to 12
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
