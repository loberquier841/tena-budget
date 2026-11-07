/// Entrées déclaratives Finance 360 (LOT 12) — comptes/actifs/passifs manuels.
/// Montants en centimes entiers (int) pour éviter les flottants monétaires.
/// Données locales ; libellés/notes sensibles chiffrés en base via service.
enum FinanceEntryKind { account, asset, liability }

class FinanceEntry {
  final String id;
  final FinanceEntryKind kind;
  final String subtype; // ex: current, savings, cash, real_estate, loan...
  final String name;
  final String? institution;
  final String currency; // ex: EUR
  final int amountCents; // solde/valeur (actif) ou restant dû (passif)
  final int? initialAmountCents;
  final String? notes;
  final bool archived;
  final String createdAt; // ISO8601 UTC
  final String updatedAt;

  const FinanceEntry({
    required this.id,
    required this.kind,
    required this.subtype,
    required this.name,
    this.institution,
    this.currency = 'EUR',
    required this.amountCents,
    this.initialAmountCents,
    this.notes,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FinanceEntry copyWith({
    String? name,
    String? subtype,
    String? institution,
    String? currency,
    int? amountCents,
    int? initialAmountCents,
    String? notes,
    bool? archived,
    String? updatedAt,
  }) => FinanceEntry(
        id: id,
        kind: kind,
        subtype: subtype ?? this.subtype,
        name: name ?? this.name,
        institution: institution ?? this.institution,
        currency: currency ?? this.currency,
        amountCents: amountCents ?? this.amountCents,
        initialAmountCents: initialAmountCents ?? this.initialAmountCents,
        notes: notes ?? this.notes,
        archived: archived ?? this.archived,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
