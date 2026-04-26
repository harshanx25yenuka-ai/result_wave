import 'package:flutter/material.dart';
import 'package:result_wave/utils/constants.dart';

class GaugeChart extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final Color? color;

  const GaugeChart({
    Key? key,
    required this.value,
    this.maxValue = 4.0,
    required this.label,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    final gaugeColor = color ?? _getColor(value);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade200,
                color: gaugeColor,
              ),
            ),
            Column(
              children: [
                Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Color _getColor(double value) {
    if (value >= 3.5) return AppColors.success;
    if (value >= 3.0) return AppColors.primaryBlue;
    if (value >= 2.0) return AppColors.warning;
    return AppColors.error;
  }
}
