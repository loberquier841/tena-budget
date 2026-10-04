import 'package:flutter/material.dart';

import '../theme/tena_theme.dart';
import 'tena_card.dart';

/// Section dont le contenu est chargé de façon asynchrone.
///
/// Centralise les trois états que toute section de données doit traiter
/// correctement : chargement, erreur et contenu. Les sections du tableau de
/// bord montaient des `FutureBuilder` imbriqués avec des traitements différents
/// selon la page, ce qui donnait des rendus disparates.
class TenaFutureSection<T> extends StatelessWidget {
  final Future<T> future;

  /// Construit le contenu une fois la donnée disponible.
  final Widget Function(BuildContext context, T data) builder;

  final String title;
  final IconData icon;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  const TenaFutureSection({
    super.key,
    required this.future,
    required this.builder,
    required this.title,
    required this.icon,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Rien à afficher',
    this.emptyMessage = '',
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingCard(title: title, icon: icon);
        }

        if (snapshot.hasError) {
          return _ErrorCard(
            title: title,
            icon: icon,
            message: 'Impossible de charger $title.',
          );
        }

        return TenaCard(child: builder(context, snapshot.data as T));
      },
    );
  }
}

/// Squelette de chargement.
///
/// Un indicateur circulaire nu donne l'impression d'une application figée ;
/// des lignes fantômes annoncent la forme du contenu à venir.
class TenaSkeleton extends StatelessWidget {
  final double height;
  final double width;

  const TenaSkeleton({
    super.key,
    this.height = 14,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: TenaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const _LoadingCard({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: TenaColors.textTertiary),
              const SizedBox(width: TenaSpacing.sm),
              Text(title.toUpperCase(), style: TenaLabels.overline),
            ],
          ),
          const SizedBox(height: TenaSpacing.lg),
          const TenaSkeleton(width: 160, height: 20),
          const SizedBox(height: TenaSpacing.md),
          const TenaSkeleton(width: 240),
          const SizedBox(height: TenaSpacing.sm),
          const TenaSkeleton(width: 200),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _ErrorCard({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return TenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: TenaColors.danger,
              ),
              const SizedBox(width: TenaSpacing.sm),
              Text(title.toUpperCase(), style: TenaLabels.overline),
            ],
          ),
          const SizedBox(height: TenaSpacing.md),
          Text(message, style: TenaLabels.subtitle),
        ],
      ),
    );
  }
}

/// Ligne de transaction pour le tableau de bord.
///
/// Aligne montant, libellé et date sur une grille stricte : les montants
/// d'une même colonne sont ainsi comparables d'un coup d'œil, ce qu'un
/// `ListTile` ne garantit pas.
class TenaTransactionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final bool isIncome;

  /// Date affichée sous le montant.
  final String? trailingDate;

  const TenaTransactionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    this.trailingDate,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? TenaColors.success : TenaColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: TenaSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TenaColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: TenaRadius.sm,
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: TenaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: TenaColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TenaSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isIncome ? '+' : '-'}$amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailingDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  trailingDate!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: TenaColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
