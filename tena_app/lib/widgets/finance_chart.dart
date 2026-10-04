import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/tena_theme.dart';

/// Graphique des revenus et dépenses par jour.
///
/// Améliorations apportées sur la version d'origine :
/// - axe des ordonnées en format compact (`1,2k €` au lieu de `1200 €`) ;
/// - grille horizontale plus discrète, divisions arrondies pour un majorant
///   lisible ;
/// - pastilles masquées quand les points sont trop nombreux pour ne pas
///   surcharger le tracé ;
/// - infobulle présentant les deux séries du même jour, pas seulement la série
///   survolée.
///
/// Aucune donnée n'est inventée : le widget ne dessine que les points fournis.
class FinanceChart extends StatelessWidget {
  final List<FlSpot> income;
  final List<FlSpot> expenses;
  final List<String> labels;

  /// Hauteur du graphique, ajustable selon le contexte.
  final double height;

  const FinanceChart({
    super.key,
    required this.income,
    required this.expenses,
    required this.labels,
    this.height = 240,
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

  /// Au-delà de ce nombre de points, les pastilles sont masquées : sinon le
  /// tracé se transforme en bande illisible.
  bool get _shouldShowDots => labels.length <= 20;

  @override
  Widget build(BuildContext context) {
    final maxY = _maxValue();

    // Intervalle arrondi à un multiple de 50 pour obtenir des étiquettes
    // propres : sans cela, l'axe affiche `137,5 €` et paraît inachevé.
    final rawStep = maxY / 4;
    final step = (rawStep / 50).round() * 50.0;
    final effectiveStep = step <= 0 ? rawStep : step;
    final top = effectiveStep * 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.show_chart_rounded, size: 16, color: TenaColors.gold),
            SizedBox(width: TenaSpacing.sm),
            Text(
              'Revenus et dépenses',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: TenaColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: TenaSpacing.md),
        const Row(
          children: [
            _Legend(color: TenaColors.gold, label: 'Revenus'),
            SizedBox(width: TenaSpacing.xl),
            _Legend(color: TenaColors.danger, label: 'Dépenses'),
          ],
        ),
        const SizedBox(height: TenaSpacing.xl),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: top,

              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: effectiveStep,
                getDrawingHorizontalLine: (_) {
                  return FlLine(
                    color: TenaColors.border.withValues(alpha: 0.7),
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
                    reservedSize: 54,
                    interval: effectiveStep,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          tenaMoneyCompact(value),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: TenaColors.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();

                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }

                      // Un libellé sur trois au-delà de 10 points, un sur
                      // quatre au-delà de 20 : sinon les dates se chevauchent.
                      final every = labels.length > 20
                          ? 4
                          : labels.length > 10
                          ? 3
                          : 1;

                      if (index % every != 0) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          labels[index],
                          style: const TextStyle(
                            color: TenaColors.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => TenaColors.surfaceRaised,
                  tooltipBorder: const BorderSide(color: TenaColors.border),
                  // L'infobulle affiche les deux séries du jour survolé :
                  // comparer revenus et dépenses du même jour est l'usage
                  // principal du graphique.
                  getTooltipItems: (spots) {
                    if (spots.isEmpty) return const [];

                    final day = spots.first.spotIndex;

                    final incomeValue = day < income.length
                        ? income[day].y
                        : 0.0;
                    final expensesValue = day < expenses.length
                        ? expenses[day].y
                        : 0.0;

                    final label = day >= 0 && day < labels.length
                        ? labels[day]
                        : '';

                    return [
                      LineTooltipItem(
                        label,
                        const TextStyle(
                          color: TenaColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '\nRevenus  ${tenaMoney(incomeValue)}',
                            style: const TextStyle(
                              color: TenaColors.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          TextSpan(
                            text: '\nDépenses  ${tenaMoney(expensesValue)}',
                            style: const TextStyle(
                              color: TenaColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ];
                  },
                ),
              ),

              lineBarsData: [
                LineChartBarData(
                  spots: income,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  barWidth: 2.5,
                  color: TenaColors.gold,
                  dotData: FlDotData(
                    show: _shouldShowDots,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: TenaColors.gold,
                        // Contour de la couleur du fond : le point reste net
                        // même quand il chevauche le tracé.
                        strokeWidth: 2,
                        strokeColor: TenaColors.surface,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        TenaColors.gold.withValues(alpha: 0.18),
                        TenaColors.gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),

                LineChartBarData(
                  spots: expenses,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  barWidth: 2.5,
                  color: TenaColors.danger,
                  dotData: FlDotData(
                    show: _shouldShowDots,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: TenaColors.danger,
                        strokeWidth: 2,
                        strokeColor: TenaColors.surface,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        TenaColors.danger.withValues(alpha: 0.16),
                        TenaColors.danger.withValues(alpha: 0.0),
                      ],
                    ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: TenaSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: TenaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
