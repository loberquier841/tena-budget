import 'package:flutter/material.dart';

import '../theme/tena_theme.dart';

/// Barre de progression de budget, avec code couleur sémantique.
///
/// Remplace les `LinearProgressIndicator` bruts qui restaient dans la couleur
/// par défaut du thème. Points résolus ici :
/// - la couleur suit le niveau de consommation (normal, vigilance, dépassé) ;
/// - le dépassement est visible sans calcul mental, la barre étant saturée à
///   100 % mais accompagnée d'un pourcentage explicite au-delà ;
/// - la valeur est annoncée aux lecteurs d'écran, la barre seule n'étant pas
///   une information exploitable ;
/// - l'épaisseur et l'arrondi sont identiques sur toutes les pages.
class TenaProgressBar extends StatelessWidget {
  /// Valeur atteinte, dans n'importe quelle unité.
  final double value;

  /// Valeur maximale de référence (budget, objectif...).
  final double total;

  final double height;

  const TenaProgressBar({
    super.key,
    required this.value,
    required this.total,
    this.height = 10,
  });

  /// Consommation en pourcentage. Vaut zéro quand aucune limite n'est définie.
  double get _ratio {
    if (total <= 0) return 0;
    return value / total;
  }

  Color get _color {
    if (total <= 0) return TenaColors.textTertiary;

    if (_ratio >= 1) return TenaColors.danger;

    if (_ratio >= 0.9) return const Color(0xFFFBBF24);

    return TenaColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    // Sans budget, une barre vide ne transmet aucune information : on
    // n'affiche la piste que lorsqu'il existe une référence.
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    final ratio = _ratio;
    final percent = (ratio * 100).round();

    final overflow = ratio > 1;

    return Semantics(
      label: 'Consommation',
      value: '$percent pour cent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: height,
              backgroundColor: TenaColors.surfaceRaised,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
          // Le pourcentage n'apparaît que lorsqu'il y a dépassement : sinon
          // il ferait doublon avec le montant affiché à côté et alourdirait
          // chaque ligne.
          if (overflow) ...[
            const SizedBox(height: TenaSpacing.xs),
            Text(
              'Budget dépassé de ${(ratio * 100 - 100).round()} %',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TenaColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne de couple « dépensé / budget ».
///
/// Centralisée pour que le libellé reste identique partout : la version
/// précédente répétait la mise en forme dans chaque page.
class TenaAmountRow extends StatelessWidget {
  final String label;
  final String value;

  /// Suffixe affiché après la valeur (`/ 1 500,00 €`).
  final String? suffix;

  final Color? valueColor;
  final bool emphasize;

  const TenaAmountRow({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.valueColor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: emphasize ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: TenaColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: TenaSpacing.sm),
        // `FittedBox` évite le débordement quand le budget est élevé.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: emphasize ? 24 : 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: valueColor ?? TenaColors.textPrimary,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: TenaSpacing.xs),
                  Text(
                    suffix!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: TenaColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte de base de l'application.
///
/// Remplace les `Card(elevation: 0)` dispersés : bordure, fond, arrondi et
/// ombre sont désormais identiques partout, ce qui donne l'impression d'un
/// produit unique plutôt que d'un assemblage d'écrans.
class TenaCard extends StatelessWidget {
  final Widget child;

  /// Padding interne. `EdgeInsets.zero` pour les cartes qui gèrent elles-mêmes
  /// leurs marges (listes pleine largeur).
  final EdgeInsetsGeometry padding;

  final VoidCallback? onTap;

  /// Met la carte en avant avec un liseré doré et une ombre dorée.
  final bool highlighted;

  const TenaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TenaSpacing.lg),
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF1A1710) : TenaColors.surface,
        borderRadius: TenaRadius.lg,
        border: Border.all(
          color: highlighted ? TenaColors.goldMuted : TenaColors.border,
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: highlighted ? TenaShadows.gold : TenaShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return content;

    // Léger enfoncement tactile, sans animation lourde.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TenaRadius.lg,
        splashColor: TenaColors.gold.withValues(alpha: 0.06),
        highlightColor: TenaColors.gold.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }
}

/// Indicateur chiffré (carte de statistique).
///
/// Prend toute la largeur disponible par défaut : les appelants qui connaissent
/// une largeur fixe (grille) la fournissent explicitement.
class TenaStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Couleur du chiffre. Le doré reste réservé au solde et aux actions
  /// principales : l'utiliser partout effacerait la hiérarchie.
  final Color? valueColor;

  /// Texte d'aide sous le chiffre (variation, contexte).
  final String? hint;

  /// Texte d'aide en couleur d'alerte.
  final bool hintIsWarning;

  final double? width;

  const TenaStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.hint,
    this.hintIsWarning = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final accent = valueColor ?? TenaColors.textPrimary;

    final card = TenaCard(
      padding: const EdgeInsets.all(TenaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: TenaRadius.sm,
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: TenaSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TenaColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TenaSpacing.md),
          // `FittedBox` évite qu'un montant à six chiffres ne déborde sur
          // petit écran au lieu de rétrécir.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: TenaSpacing.xs),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: hintIsWarning
                    ? TenaColors.danger
                    : TenaColors.textTertiary,
                fontWeight: hintIsWarning ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );

    if (width == null) return card;

    return SizedBox(width: width, child: card);
  }
}

/// Titre de section : surtitre doré + titre + sous-titre optionnel.
class TenaSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const TenaSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Row(
            children: [
              Icon(icon, size: 15, color: TenaColors.gold),
              const SizedBox(width: TenaSpacing.sm),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TenaLabels.overline,
                ),
              ),
            ],
          )
        else
          Text(title.toUpperCase(), style: TenaLabels.overline),
        const SizedBox(height: TenaSpacing.sm),
        Text(title, style: TenaLabels.title),
        if (subtitle != null) ...[
          const SizedBox(height: TenaSpacing.xs),
          Text(subtitle!, style: TenaLabels.subtitle),
        ],
      ],
    );
  }
}

/// Message temporaire affiché après une action (ajout, restauration...).
///
/// Remplace les `SnackBar` bruts, dont le style par défaut tranche avec le
/// thème doré.
void tenaShowSnack(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final scheme = Theme.of(context).colorScheme;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: error ? scheme.error : TenaColors.gold,
            ),
            const SizedBox(width: TenaSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: TenaColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: TenaRadius.md),
        margin: const EdgeInsets.all(TenaSpacing.lg),
        duration: const Duration(seconds: 3),
      ),
    );
}

/// État vide : explication + action optionnelle.
///
/// Aucun module ne doit afficher une zone entièrement vide : c'est la
/// principale cause de l'impression « prototype ».
class TenaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;

  const TenaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TenaSpacing.xl,
          vertical: TenaSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: TenaColors.gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: TenaColors.gold.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(icon, size: 28, color: TenaColors.gold),
            ),
            const SizedBox(height: TenaSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: TenaColors.textPrimary,
              ),
            ),
            const SizedBox(height: TenaSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: TenaColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: TenaSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: TenaColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TenaSpacing.xl,
                    vertical: TenaSpacing.md,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: TenaRadius.md,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
