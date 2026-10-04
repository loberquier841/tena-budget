import 'package:flutter/material.dart';

import '../theme/tena_theme.dart';

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
