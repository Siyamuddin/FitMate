import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fitmate/core/theme/app_colors.dart';
import 'package:fitmate/core/theme/app_radius.dart';
import 'package:fitmate/core/theme/app_spacing.dart';
import 'package:fitmate/core/theme/app_typography.dart';
import 'package:fitmate/core/widgets/states.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.values,
    this.emptyTitle = 'Not enough data',
    this.emptyMessage = 'A chart appears after two entries.',
  });

  final String title;
  final List<double> values;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTypography.headline(AppColors.ink(brightness))),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 180,
          child: values.length < 2
              ? EmptyState(title: emptyTitle, message: emptyMessage)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Material(
                    color: AppColors.surface(brightness),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: <LineChartBarData>[
                          LineChartBarData(
                            isCurved: true,
                            color: AppColors.accent(brightness),
                            spots: <FlSpot>[
                              for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
                            ],
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
