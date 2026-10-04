import 'package:flutter/material.dart';

import '../theme/tena_theme.dart';

/// Barre de navigation latérale de TENΛ Budget.
///
/// Sur grand écran, la navigation est affichée en permanence : une application
/// financière doit permettre d'atteindre n'importe quel module en un regard.
/// Sur téléphone, la même barre est servie par le tiroir, ce qui garantit un
/// rendu identique sur les deux formats.
///
/// Le module actif est identifié par trois signaux simultanés — liseré doré,
/// fond légèrement éclairci et icône pleine — afin de rester lisible sans
/// dépendre uniquement de la couleur.
class TenaSidebar extends StatelessWidget {
  final List<TenaNavItem> items;

  final int selectedIndex;

  final ValueChanged<int> onSelected;

  const TenaSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Largeur du tiroir sur téléphone.
  static const double drawerWidth = 272;

  /// Largeur de la colonne fixe sur grand écran.
  static const double railWidth = 248;

  /// Les six premiers modules forment le groupe principal ; le reste est
  /// présenté à part. Cette séparation évite une liste de quatorze entrées
  /// indistinctes, illisible sans défilement.
  static int _groupLength(List<TenaNavItem> items) {
    return items.length >= 6 ? 6 : items.length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D10),
        border: Border(right: BorderSide(color: TenaColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Brand(),
            const SizedBox(height: TenaSpacing.xs),
            const _SidebarSectionLabel('Principal'),
            const SizedBox(height: TenaSpacing.sm),
            for (var i = 0; i < _groupLength(items); i++)
              _SidebarItem(
                item: items[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            const SizedBox(height: TenaSpacing.lg),
            const _SidebarSectionLabel('Modules'),
            const SizedBox(height: TenaSpacing.sm),
            for (var i = _groupLength(items); i < items.length; i++)
              _SidebarItem(
                item: items[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            const Spacer(),
            const _SidebarFooter(),
          ],
        ),
      ),
    );
  }
}

/// Entrée de navigation.
class TenaNavItem {
  final String title;
  final IconData icon;
  final IconData? activeIcon;

  const TenaNavItem({
    required this.title,
    required this.icon,
    this.activeIcon,
  });
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TenaSpacing.lg,
        TenaSpacing.xl,
        TenaSpacing.lg,
        TenaSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: TenaColors.gold.withValues(alpha: 0.1),
              borderRadius: TenaRadius.md,
              border: Border.all(
                color: TenaColors.gold.withValues(alpha: 0.28),
              ),
            ),
            child: Image.asset('assets/tena_icon.png'),
          ),
          const SizedBox(width: TenaSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TENΛ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: TenaColors.textPrimary,
                  ),
                ),
                Text(
                  'BUDGET',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: TenaColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String text;

  const _SidebarSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TenaSpacing.lg,
        TenaSpacing.sm,
        TenaSpacing.lg,
        0,
      ),
      child: Text(
        text.toUpperCase(),
        style: TenaLabels.overline.copyWith(fontSize: 10),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final TenaNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? TenaColors.gold : TenaColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TenaSpacing.md,
        vertical: 2,
      ),
      child: Material(
        color: selected
            ? TenaColors.gold.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: TenaRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: TenaRadius.md,
          hoverColor: TenaColors.gold.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: TenaRadius.md,
              border: const Border(
                // Liseré gauche : signal de position le plus lisible, il
                // reste perceptible même avec un daltonisme rouge-vert.
                left: BorderSide(color: Colors.transparent, width: 3),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: TenaSpacing.md,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? (item.activeIcon ?? item.icon) : item.icon,
                  size: 19,
                  color: color,
                ),
                const SizedBox(width: TenaSpacing.md),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? TenaColors.textPrimary
                          : TenaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TenaSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(TenaSpacing.md),
        decoration: BoxDecoration(
          color: TenaColors.surface,
          borderRadius: TenaRadius.md,
          border: Border.all(color: TenaColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: TenaColors.goldSheen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: TenaColors.gold,
              ),
            ),
            const SizedBox(width: TenaSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Donnees chiffrees',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: TenaColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'AES-256-GCM',
                    style: TextStyle(
                      fontSize: 10,
                      color: TenaColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
