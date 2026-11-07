import '../models/transaction.dart';

/// Règle automatique prioritaire.
class TransactionRule {
  final List<String> keywords;
  final String category;
  final TransactionType? type;
  final int priority; // plus élevé = prioritaire
  final bool userDefined;

  const TransactionRule({
    required this.keywords,
    required this.category,
    this.type,
    this.priority = 0,
    this.userDefined = false,
  });

  bool matches(Transaction t) {
    if (type != null && t.type != type) return false;
    final label = _normalize(t.description);
    return keywords.any((k) => label.contains(_normalize(k)));
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Résultat de catégorisation avec explication.
class CategorizationResult {
  final String? category;
  final String? matchedKeyword;
  final String? ruleDescription;
  final bool preservedManual;
  final bool isRecurring;

  const CategorizationResult({
    this.category,
    this.matchedKeyword,
    this.ruleDescription,
    this.preservedManual = false,
    this.isRecurring = false,
  });
}

class TransactionRuleService {
  final List<TransactionRule> rules;
  final Set<String> manualCategories; // catégories considérées manuelles/protégées

  TransactionRuleService({
    List<TransactionRule>? rules,
    Set<String>? manualCategories,
  })  : rules = (rules ?? List<TransactionRule>.from(defaultRules))..sort((a, b) => b.priority.compareTo(a.priority)),
        manualCategories = manualCategories ?? {'Manuel', 'Custom'};

  static const List<TransactionRule> defaultRules = [
    TransactionRule(keywords: ['carrefour', 'monoprix', 'lidl', 'courses', 'supermarche'], category: 'Alimentation', priority: 10),
    TransactionRule(keywords: ['sncf', 'ratp', 'uber', 'taxi', 'essence', 'carburant'], category: 'Transport', priority: 10),
    TransactionRule(keywords: ['loyer', 'edf', 'eau', 'internet'], category: 'Logement', priority: 10),
    TransactionRule(keywords: ['netflix', 'spotify', 'prime'], category: 'Abonnements', priority: 10),
    TransactionRule(keywords: ['salaire', 'paie', 'remuneration'], category: 'Salaire', type: TransactionType.income, priority: 10),
  ];

  /// Reconnaissance commerçant : normalise le libellé bancaire.
  static String normalizeMerchant(String label) {
    var s = label.toLowerCase();
    s = s.replaceAll(RegExp(r'\d{2}/\d{2}'), '');
    s = s.replaceAll(RegExp(r'cb\s*\*?\s*'), '');
    s = s.replaceAll(RegExp(r'[^a-zà-ÿ0-9 ]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String? suggestCategory(Transaction t) {
    for (final r in rules) {
      if (r.matches(t)) return r.category;
    }
    return null;
  }

  CategorizationResult explain(Transaction t) {
    for (final r in rules) {
      if (r.matches(t)) {
        final kw = r.keywords.firstWhere((k) => _norm(t.description).contains(_norm(k)), orElse: () => r.keywords.first);
        return CategorizationResult(
          category: r.category,
          matchedKeyword: kw,
          ruleDescription: 'Règle priorité ${r.priority}: "$kw" -> ${r.category}',
        );
      }
    }
    return const CategorizationResult();
  }

  bool isManualCategory(String category) => manualCategories.contains(category);

  Transaction apply(Transaction t, {bool preserveManual = true}) {
    if (preserveManual && isManualCategory(t.category)) {
      return t;
    }
    // catégorie non vide et non "Autres" => considérée manuelle par défaut
    if (preserveManual && t.category.isNotEmpty && t.category != 'Autres') {
      return t;
    }
    final suggested = suggestCategory(t);
    if (suggested == null) return t;
    return t.copyWith(category: suggested);
  }

  List<Transaction> applyAll(Iterable<Transaction> transactions) =>
      transactions.map((t) => apply(t)).toList();

  /// Détection de dépenses récurrentes : même commerçant + montant proche sur >=2 mois.
  static List<List<Transaction>> detectRecurring(Iterable<Transaction> transactions) {
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key = '${normalizeMerchant(t.description)}|${(t.amount * 100).round()}';
      groups.putIfAbsent(key, () => []).add(t);
    }
    final result = <List<Transaction>>[];
    for (final g in groups.values) {
      if (g.length >= 2) {
        // vérifier étalement sur au moins 2 mois distincts
        final months = g.map((t) => '${t.date.year}-${t.date.month}').toSet();
        if (months.length >= 2) result.add(g);
      }
    }
    return result;
  }

  /// Apprentissage : crée une règle utilisateur à partir d'une correction manuelle.
  static TransactionRule learnFromCorrection(Transaction original, String correctedCategory) {
    final merchant = normalizeMerchant(original.description);
    final tokens = merchant.split(' ').where((w) => w.length >= 3).toList();
    final keywords = tokens.isEmpty ? [merchant] : tokens;
    return TransactionRule(
      keywords: keywords,
      category: correctedCategory,
      priority: 100,
      userDefined: true,
    );
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
