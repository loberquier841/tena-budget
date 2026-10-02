import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FinanceChart extends StatelessWidget {
  final List<FlSpot> income;
  final List<FlSpot> expenses;
  final List<String> labels;

  const FinanceChart({
    super.key,
    required this.income,
    required this.expenses,
    required this.labels,
  });

  double _maxValue() {
    double max = 0;

    for (final spot in income) {
      if (spot.y > max) max = spot.y;
    }

    for (final spot in expenses) {
      if (spot.y > max) max = spot.y;
    }

    if (max == 0) return 100;

    return (max * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _maxValue();

    final gold = const Color(0xFFD4AF37);
    final expenseColor = const Color(0xFFC86B6B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.show_chart, size: 22),
            SizedBox(width: 8),
            Text(
              'Revenus et dépenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            _Legend(color: gold, label: 'Revenus'),
            const SizedBox(width: 20),
            _Legend(color: expenseColor, label: 'Dépenses'),
          ],
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 195,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,

              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  );
                },
              ),

              borderData: FlBorderData(show: false),

              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),

                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: maxY / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()} €',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),

                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: labels.length > 8 ? 2 : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();

                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }

                      return Text(
                        labels[index],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),

              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final index = spot.x.toInt();

                      final label = index >= 0 && index < labels.length
                          ? labels[index]
                          : '';

                      return LineTooltipItem(
                        '$label\n${spot.y.toStringAsFixed(2).replaceAll('.', ',')} €',
                        const TextStyle(fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),

              lineBarsData: [
                LineChartBarData(
                  spots: income,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  barWidth: 3,
                  color: gold,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: gold.withValues(alpha: 0.08),
                  ),
                ),

                LineChartBarData(
                  spots: expenses,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  barWidth: 3,
                  color: expenseColor,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: expenseColor.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
