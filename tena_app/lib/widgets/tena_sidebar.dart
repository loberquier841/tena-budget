import 'package:flutter/material.dart';

import '../pages/app_module_page.dart' show TenaModuleStatus;
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
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;

  const TenaSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.searchQuery = '',
    this.onSearchChanged,
  });

  static const double drawerWidth = 272;
  static const double railWidth = 248;
  static const double collapsedWidth = 72;

  static int _groupLength(List<TenaNavItem> items) {
    return items.length >= 6 ? 6 : items.length;
  }

  @override
  Widget build(BuildContext context) {
    final showLabels = !collapsed;
    final q = searchQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? null
        : [
            for (var i = 0; i < items.length; i++)
              if (items[i].title.toLowerCase().contains(q)) (i, items[i])
          ];
    return Container(
      width: collapsed ? collapsedWidth : null,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D10),
        border: Border(right: BorderSide(color: TenaColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(compact: collapsed, onToggle: onToggleCollapsed),
            if (showLabels && onSearchChanged != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(TenaSpacing.md, 0, TenaSpacing.md, TenaSpacing.xs),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Rechercher…',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: TenaRadius.md,
                          borderSide: const BorderSide(color: TenaColors.border)),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (filtered != null) ...[
                    for (final e in filtered)
                      _SidebarItem(item: e.$2, selected: selectedIndex == e.$1,
                          onTap: () => onSelected(e.$1), compact: collapsed),
                    if (filtered.isEmpty && showLabels)
                      const Padding(padding: EdgeInsets.all(16),
                          child: Text('Aucun module',
                              style: TextStyle(color: TenaColors.textTertiary, fontSize: 12))),
                  ] else ...[
                    if (showLabels) const _Section('Principal'),
                    for (var i = 0; i < _groupLength(items); i++)
                      _SidebarItem(item: items[i], selected: selectedIndex == i,
                          onTap: () => onSelected(i), compact: collapsed),
                    if (showLabels) const _Section('Modules'),
                    for (var i = _groupLength(items); i < items.length; i++)
                      _SidebarItem(item: items[i], selected: selectedIndex == i,
                          onTap: () => onSelected(i), compact: collapsed),
                  ],
                ],
              ),
            ),
            if (showLabels) const _SidebarFooter(),
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
  final TenaModuleStatus status;

  const TenaNavItem({
    required this.title,
    required this.icon,
    this.activeIcon,
    this.status = TenaModuleStatus.available,
  });
}

class _Brand extends StatelessWidget {
  final bool compact;
  final VoidCallback? onToggle;
  const _Brand({this.compact = false, this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : TenaSpacing.lg, TenaSpacing.md,
          compact ? 6 : TenaSpacing.md, TenaSpacing.sm),
      child: Row(
        mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Image.asset('assets/tena_icon.png', width: 28, height: 28),
          if (!compact) ...[
            const SizedBox(width: TenaSpacing.sm),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('TENΛ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: TenaColors.textPrimary)),
                Text('BUDGET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.2, color: TenaColors.gold)),
              ]),
            ),
            if (onToggle != null)
              IconButton(tooltip: 'Replier', icon: const Icon(Icons.chevron_left, size: 18),
                  onPressed: onToggle, visualDensity: VisualDensity.compact),
          ] else if (onToggle != null)
            IconButton(tooltip: 'Déplier', icon: const Icon(Icons.chevron_right, size: 16),
                onPressed: onToggle, visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 24, height: 24)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(TenaSpacing.lg, TenaSpacing.sm, TenaSpacing.lg, 2),
        child: Text(text.toUpperCase(), style: TenaLabels.overline.copyWith(fontSize: 10)),
      );
}

class _SidebarItem extends StatelessWidget {
  final TenaNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _SidebarItem({required this.item, required this.selected, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = selected ? TenaColors.gold : TenaColors.textSecondary;
    final tile = Material(
      color: selected ? TenaColors.gold.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: TenaRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: TenaRadius.md,
        hoverColor: TenaColors.gold.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : TenaSpacing.md, vertical: compact ? 10 : 10),
          child: compact
              ? Center(child: Icon(selected ? (item.activeIcon ?? item.icon) : item.icon, size: 20, color: color))
              : Row(children: [
                  Icon(selected ? (item.activeIcon ?? item.icon) : item.icon, size: 19, color: color),
                  const SizedBox(width: TenaSpacing.md),
                  Expanded(
                    child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? TenaColors.textPrimary : TenaColors.textSecondary)),
                  ),
                  if (item.status == TenaModuleStatus.planned)
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(color: TenaColors.textTertiary, shape: BoxShape.circle)),
                ]),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TenaSpacing.sm, vertical: 1),
      child: compact ? Tooltip(message: item.title, child: tile) : tile,
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
