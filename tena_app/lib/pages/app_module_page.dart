import 'package:flutter/material.dart';

import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

/// Statut honnête d'un module (jamais de fausse donnée).
enum TenaModuleStatus { available, inProgress, planned }

/// Écran générique pour modules non encore branchés sur données réelles.
/// N'affiche aucune donnée fictive : explique ce qui est disponible localement
/// et propose des actions réelles vers les modules opérationnels.
class AppModulePage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String summary;
  final TenaModuleStatus status;
  final List<({String label, int pageIndex, IconData icon})> actions;
  final void Function(int index)? onNavigate;

  const AppModulePage({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.status,
    this.actions = const [],
    this.onNavigate,
  });

  String get _statusLabel => switch (status) {
        TenaModuleStatus.available => 'Opérationnel (local)',
        TenaModuleStatus.inProgress => 'En cours d’intégration',
        TenaModuleStatus.planned => 'Prévu — non branché',
      };

  Color get _statusColor => switch (status) {
        TenaModuleStatus.available => TenaColors.success,
        TenaModuleStatus.inProgress => TenaColors.gold,
        TenaModuleStatus.planned => TenaColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TenaSpacing.xl),
          child: TenaCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: TenaColors.gold.withValues(alpha: 0.12),
                        borderRadius: TenaRadius.md,
                      ),
                      child: Icon(icon, color: TenaColors.gold, size: 28),
                    ),
                    const SizedBox(width: TenaSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 8, color: _statusColor),
                              const SizedBox(width: 6),
                              Text(_statusLabel,
                                  style: TextStyle(
                                      color: _statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TenaSpacing.xl),
                Text(summary,
                    style: const TextStyle(
                        color: TenaColors.textSecondary, height: 1.5)),
                const SizedBox(height: TenaSpacing.lg),
                const Text(
                  'Aucune donnée fictive. Données financières 100% locales (aucun serveur). '
                  'Les sauvegardes chiffrées et l’import CSV sont accessibles via Transactions/Profil selon disponibilité.',
                  style: TextStyle(
                      color: TenaColors.textTertiary, fontSize: 12, height: 1.4),
                ),
                if (actions.isNotEmpty && onNavigate != null) ...[
                  const SizedBox(height: TenaSpacing.xl),
                  Wrap(
                    spacing: TenaSpacing.sm,
                    runSpacing: TenaSpacing.sm,
                    children: [
                      for (final a in actions)
                        OutlinedButton.icon(
                          onPressed: () => onNavigate!(a.pageIndex),
                          icon: Icon(a.icon, size: 18),
                          label: Text(a.label),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
