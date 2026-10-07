import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/payment_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

/// Écran de blocage affiché tant que le paiement n'est pas vérifié.
///
/// Aucun déblocage n'est possible depuis cet écran aujourd'hui : le lien
/// Iyzico n'est injecté qu'au build (`--dart-define`), et la vérification
/// attend le futur backend (voir [PaymentVerifier]). Un état de
/// démonstration est proposé en développement uniquement, avec un bandeau qui
/// l'empêche de passer pour un vrai paiement.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final PaymentService _payment = PaymentService.instance;

  bool _checking = false;

  Future<void> _openCheckout() async {
    final url = _payment.checkoutUrl;

    if (url == null) return;

    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      tenaShowSnack(
        context,
        'Impossible d’ouvrir le lien de paiement.',
        error: true,
      );
    }
  }

  Future<void> _verify() async {
    setState(() => _checking = true);

    final result = await _payment.requestVerification();

    if (!mounted) return;

    setState(() => _checking = false);

    switch (result) {
      case PaymentVerificationResult.confirmed:
        tenaShowSnack(context, 'Paiement confirmé. Bienvenue dans Premium.');
      case PaymentVerificationResult.rejected:
        tenaShowSnack(
          context,
          'Aucun paiement correspondant n’a été trouvé.',
          error: true,
        );
      case PaymentVerificationResult.notConfigured:
        tenaShowSnack(
          context,
          'Vérification serveur non disponible : l’accès reste bloqué.',
          error: true,
        );
      case PaymentVerificationResult.unavailable:
        tenaShowSnack(
          context,
          'Serveur de vérification injoignable. Réessaie plus tard.',
          error: true,
        );
    }
  }

  Future<void> _toggleDemo(bool enable) async {
    if (enable) {
      await _payment.enableDemoMode();
    } else {
      await _payment.disableDemoMode();
    }

    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasCheckout = _payment.checkoutUrl != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TenaSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: TenaCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PaywallHeader(),
                    const SizedBox(height: TenaSpacing.lg),
                    const _BenefitList(),
                    const SizedBox(height: TenaSpacing.lg),
                    _StatusBlock(payment: _payment),
                    const SizedBox(height: TenaSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        // Sans lien injecté au build, il n'y a rien à ouvrir :
                        // le bouton reste visible mais inactif plutôt que de
                        // diriger vers une fausse URL.
                        onPressed: hasCheckout ? _openCheckout : null,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Payer avec Iyzico'),
                      ),
                    ),
                    if (!hasCheckout) ...[
                      const SizedBox(height: TenaSpacing.sm),
                      Text(
                        'Le lien de paiement sécurisé sera activé par le '
                        'serveur TENΛ.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TenaColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: TenaSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _checking ? null : _verify,
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: const Text('J’ai payé — vérifier l’accès'),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: TenaSpacing.lg),
                      _DemoSection(payment: _payment, onToggle: _toggleDemo),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Identité du paywall : logo, accroche, positionnement Premium.
class _PaywallHeader extends StatelessWidget {
  const _PaywallHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: TenaColors.goldSheen,
                borderRadius: TenaRadius.md,
              ),
              alignment: Alignment.center,
              child: const Text(
                'Λ',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: TenaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TENΛ BUDGET', style: TenaLabels.overline),
                  const SizedBox(height: 2),
                  const Text(
                    'Espace Premium',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: TenaSpacing.lg),
        const Text(
          'Ton espace est verrouillé : le paiement doit être confirmé par '
          'le serveur TENΛ avant l’accès aux modules.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}

/// Liste des bénéfices (fonctionnalités réellement présentes dans l'app).
class _BenefitList extends StatelessWidget {
  const _BenefitList();

  static const _benefits = [
    (Icons.wallet_outlined, 'Budget global et budgets par catégorie'),
    (Icons.swap_vert_rounded, 'Transactions chiffrées, stockées localement'),
    (Icons.track_changes_outlined, 'Objectifs d’épargne et suivi'),
    (Icons.insights_outlined, 'Prévisions et bilans mensuels'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, label) in _benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: TenaSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 17, color: TenaColors.gold),
                const SizedBox(width: TenaSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: TenaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Reprise d'état affichée au-dessus des boutons : ce que le serveur sait (ou
/// non) du paiement, formulée sans ambiguïté.
class _StatusBlock extends StatelessWidget {
  final PaymentService payment;

  const _StatusBlock({required this.payment});

  String get _message {
    switch (payment.status) {
      case PaymentStatus.unverified:
        return 'Aucun paiement confirmé pour l’instant.';
      case PaymentStatus.pendingVerification:
        return 'Déclaration de paiement enregistrée, en attente de la '
            'vérification serveur. L’accès reste bloqué tant que le serveur '
            'ne confirme pas.';
      case PaymentStatus.verified:
        return 'Paiement vérifié.';
      case PaymentStatus.demo:
        return 'Mode démonstration actif : ce n’est pas un paiement réel.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = payment.status == PaymentStatus.pendingVerification;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TenaSpacing.md),
      decoration: BoxDecoration(
        color: TenaColors.surfaceRaised,
        borderRadius: TenaRadius.sm,
        border: Border.all(
          color: pending
              ? TenaColors.gold.withValues(alpha: 0.4)
              : TenaColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded,
            size: 16,
            color: pending ? TenaColors.gold : TenaColors.textTertiary,
          ),
          const SizedBox(width: TenaSpacing.sm),
          Expanded(
            child: Text(
              _message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: TenaColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc réservé aux builds de développement : active ou désactive l'état de
/// démonstration. Il n'est jamais compilé en release ([kDebugMode]) et le
/// libellé explicite interdit de le confondre avec un paiement.
class _DemoSection extends StatelessWidget {
  final PaymentService payment;
  final ValueChanged<bool> onToggle;

  const _DemoSection({required this.payment, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = payment.status == PaymentStatus.demo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TenaSpacing.md),
      decoration: BoxDecoration(
        borderRadius: TenaRadius.sm,
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, size: 15, color: Color(0xFFFBBF24)),
              SizedBox(width: TenaSpacing.sm),
              Text('DÉVELOPPEMENT — DÉMONSTRATION', style: TenaLabels.overline),
            ],
          ),
          const SizedBox(height: TenaSpacing.sm),
          const Text(
            'Accès de test pour l’interface uniquement. Aucun paiement n’est '
            'effectué, cet état n’existe pas en production.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: TenaColors.textSecondary,
            ),
          ),
          const SizedBox(height: TenaSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onToggle(!active),
              child: Text(
                active
                    ? 'Quitter la démonstration'
                    : 'Activer la démonstration',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
