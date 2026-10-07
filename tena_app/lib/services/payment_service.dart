import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// État du paiement Premium de l'application.
///
/// Aucun de ces états n'est obtenu par une simple action locale de
/// l'utilisateur : seul [PaymentStatus.verified] donne un accès Premium en
/// production, et il ne peut être atteint que par la vérification serveur
/// (voir [PaymentVerifier]), qui sera branchée sur le backend Iyzico.
enum PaymentStatus {
  /// Aucun paiement connu : l'accès est bloqué.
  unverified,

  /// L'utilisateur déclare avoir payé et a demandé une vérification, mais le
  /// serveur ne l'a pas encore confirmé. L'accès reste bloqué.
  pendingVerification,

  /// Paiement confirmé par le serveur (backend Iyzico à venir).
  verified,

  /// État de démonstration, **uniquement en développement**.
  ///
  /// Il ne débloque jamais l'application en release : voir
  /// [PaymentService.isPremiumUnlocked]. L'interface l'affiche avec un
  /// bandeau explicite pour qu'il ne puisse pas être confondu avec un vrai
  /// paiement.
  demo,
}

/// Résultat d'une tentative de vérification du paiement côté serveur.
enum PaymentVerificationResult {
  /// Le serveur a confirmé le paiement.
  confirmed,

  /// Le serveur répond mais le paiement n'est pas trouvé ou pas payé.
  rejected,

  /// La vérification serveur n'est pas encore branchée (backend absent).
  notConfigured,

  /// Le serveur est injoignable : on ne conclut rien, l'accès reste bloqué.
  unavailable,
}

/// Point d'extension prévu pour le backend de vérification Iyzico.
///
/// Aucune implémentation réelle n'existe aujourd'hui : [NullPaymentVerifier]
/// est la valeur par défaut et répond systématiquement
/// [PaymentVerificationResult.notConfigured]. Quand le backend sera en place,
/// une implémentation réelle (appel HTTP signé, validation de la référence de
/// transaction Iyzico) devra être injectée via
/// [PaymentService.instance.verifier] sans modifier le paywall.
abstract class PaymentVerifier {
  Future<PaymentVerificationResult> verify();
}

/// Implémentation provisoire : aucun backend, donc aucune vérification.
class NullPaymentVerifier implements PaymentVerifier {
  const NullPaymentVerifier();

  @override
  Future<PaymentVerificationResult> verify() async {
    return PaymentVerificationResult.notConfigured;
  }
}

/// Gère l'état de paiement de l'application.
///
/// Conception volontairement prête pour Iyzico + backend :
/// - le lien de checkout n'est jamais codé en dur : il est fourni au build
///   via `--dart-define=TENA_IYZICO_CHECKOUT_URL=...` (vide par défaut) ;
/// - le déblocage Premium passe par [PaymentVerifier], injectable, dont
///   l'implémentation actuelle ([NullPaymentVerifier]) ne débloque rien ;
/// - un état de démonstration existe pour le développement, refusé en
///   release, et signalé à l'écran par un bandeau dédié.
///
/// [ChangeNotifier] permet au paywall et à l'écran hôte de réagir à un
/// changement d'état (par exemple l'arrivée d'une confirmation serveur)
/// sans reconstruire l'arbre manuellement.
class PaymentService extends ChangeNotifier {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  static const String _statusKey = 'tena_payment_status';

  /// Identifiant du build qui reçoit le lien de checkout (vide = aucun).
  ///
  /// Renseigné à la compilation :
  /// `flutter run --dart-define=TENA_IYZICO_CHECKOUT_URL=https://...`
  static const String _checkoutUrlFromBuild = String.fromEnvironment(
    'TENA_IYZICO_CHECKOUT_URL',
  );

  /// Vérificateur serveur, remplacé par le futur backend Iyzico.
  PaymentVerifier verifier = const NullPaymentVerifier();

  PaymentStatus _status = PaymentStatus.unverified;

  PaymentStatus get status => _status;

  /// Lien de checkout Iyzico fourni par la configuration de build.
  ///
  /// `null` tant qu'aucun lien n'a été injecté : dans ce cas le paywall
  /// affiche un bouton de paiement inactif plutôt qu'une fausse URL.
  Uri? get checkoutUrl {
    final raw = _checkoutUrlFromBuild.trim();

    if (raw.isEmpty) return null;

    return Uri.tryParse(raw);
  }

  /// Vrai uniquement si l'application doit être débloquée.
  ///
  /// En release, l'état [PaymentStatus.demo] n'autorise jamais l'accès : un
  /// APK de production construit avec une préférence de démo resterait bloqué
  /// derrière le paywall.
  bool get isPremiumUnlocked {
    switch (_status) {
      case PaymentStatus.verified:
        return true;
      case PaymentStatus.demo:
        return kDebugMode;
      case PaymentStatus.unverified:
      case PaymentStatus.pendingVerification:
        return false;
    }
  }

  /// Bandeau à afficher quand l'accès repose sur un état de démonstration.
  bool get isDemoMode => _status == PaymentStatus.demo && kDebugMode;

  /// Recharge l'état persisté (appelé au démarrage de l'application).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statusKey);

    _status = _parse(raw);

    notifyListeners();
  }

  PaymentStatus _parse(String? raw) {
    switch (raw) {
      case 'verified':
        // Seul le serveur peut produire cet état ; il est relu depuis les
        // préférences pour ne pas re-demander le paiement à chaque
        // lancement.
        return PaymentStatus.verified;
      case 'pending':
        return PaymentStatus.pendingVerification;
      case 'demo':
        // En release, une trace de démo ne débloque rien : on revient à
        // l'état par défaut plutôt que de conserver un faux accès.
        return kDebugMode ? PaymentStatus.demo : PaymentStatus.unverified;
      default:
        return PaymentStatus.unverified;
    }
  }

  /// Demande au serveur de vérifier le paiement déclaré par l'utilisateur.
  ///
  /// Ne débloque **jamais** par elle-même : seul un retour
  /// [PaymentVerificationResult.confirmed] du [verifier] passe en
  /// [PaymentStatus.verified]. Tant que le backend n'existe pas, le résultat
  /// est [PaymentVerificationResult.notConfigured] et l'accès reste bloqué.
  Future<PaymentVerificationResult> requestVerification() async {
    // Marque la demande : l'utilisateur ayant payé n'est pas renvoyé à zéro
    // entre deux tentatives de vérification.
    if (_status == PaymentStatus.unverified) {
      await _persist(PaymentStatus.pendingVerification);
    }

    final result = await verifier.verify();

    switch (result) {
      case PaymentVerificationResult.confirmed:
        await _persist(PaymentStatus.verified);
      case PaymentVerificationResult.rejected:
        await _persist(PaymentStatus.unverified);
      case PaymentVerificationResult.notConfigured:
      case PaymentVerificationResult.unavailable:
      // L'accès reste bloqué : rien à changer au-delà de la demande déjà
      // enregistrée.
        break;
    }

    return result;
  }

  /// Passe en état de démonstration (développement uniquement).
  ///
  /// Refusé en release : la méthode lève [StateError] plutôt que de créer un
  /// faux état Premium.
  Future<void> enableDemoMode() async {
    if (!kDebugMode) {
      throw StateError(
        'Le mode démonstration est interdit dans un build de production.',
      );
    }

    await _persist(PaymentStatus.demo);
  }

  /// Quitte la démonstration pour revenir à l'état réel (bloqué sauf si un
  /// paiement a été vérifié).
  Future<void> disableDemoMode() async {
    if (_status == PaymentStatus.demo) {
      await _persist(PaymentStatus.unverified);
    }
  }

  /// Forçage d'état réservé aux tests.
  @visibleForTesting
  void debugOverrideStatus(PaymentStatus status) {
    _status = status;

    notifyListeners();
  }

  Future<void> _persist(PaymentStatus status) async {
    _status = status;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_statusKey, _encode(status));

    notifyListeners();
  }

  String _encode(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.verified:
        return 'verified';
      case PaymentStatus.pendingVerification:
        return 'pending';
      case PaymentStatus.demo:
        return 'demo';
      case PaymentStatus.unverified:
        return 'unverified';
    }
  }
}
