import 'package:flutter/material.dart';
import 'package:result_wave/utils/constants.dart';

class GradeCard extends StatelessWidget {
  final String grade;
  final String gradeIcon;
  final double gradePoint;
  final bool isSelected;
  final VoidCallback onTap;

  const GradeCard({
    Key? key,
    required this.grade,
    required this.gradeIcon,
    required this.gradePoint,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor(grade);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 80,
      height: 80,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradeColor, gradeColor.withOpacity(0.8)],
                )
              : null,
          color: isSelected ? null : gradeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? gradeColor : gradeColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(gradeIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    grade,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : gradeColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gradePoint.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white70
                          : gradeColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (['A+', 'A', 'A-'].contains(grade)) return AppColors.success;
    if (['B+', 'B', 'B-'].contains(grade)) return AppColors.primaryBlue;
    if (['C+', 'C', 'C-'].contains(grade)) return AppColors.accentTeal;
    if (['D+', 'D'].contains(grade)) return Colors.orange;
    if (['F', 'F(CA)', 'F(ET)'].contains(grade)) return AppColors.error;
    if (['I', 'I(ET)', 'I(CA)'].contains(grade)) return AppColors.warning;
    return Colors.grey;
  }
}
