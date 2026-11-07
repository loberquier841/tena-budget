import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/app_scope.dart';
import '../services/appearance_service.dart';
import '../services/user_profile_service.dart';
import '../theme/tena_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _priorities = {
    'understand-money': 'Comprendre où va mon argent',
    'control-spending': 'Mieux contrôler mes dépenses',
    'save': 'Épargner pour mes projets',
    'prepare-expenses': 'Préparer les dépenses à venir',
    'manage-debt': 'Mieux gérer mes crédits et dettes',
    'family-visibility': 'Organiser les finances du foyer',
  };
  static const _features = {
    'transactions': 'Transactions locales',
    'budgets': 'Budgets',
    'savings-goals': 'Objectifs d’épargne',
    'forecast': 'Prévisions',
    'simulations': 'Simulations',
    'import-csv': 'Import CSV',
    'import-excel': 'Import Excel',
    'export-reports': 'Exports et rapports',
    'bank-sync': 'Banque (mock uniquement)',
    'ai-assistant': 'TENΛ AI',
    'family-space': 'Espace famille',
    'business-space': 'Entreprise future',
    'encrypted-backups': 'Sauvegardes chiffrées',
  };
  static const _cards = {
    'spending': 'Dépenses',
    'goals': 'Objectifs',
    'recent-transactions': 'Transactions récentes',
    'alerts': 'Alertes locales',
    'forecast': 'Prévisions',
  };

  String _householdMode = 'personal';
  String _incomePattern = 'regular';
  String _budgetExperience = 'starting';
  String _notificationPreference = 'balanced';
  Set<String> _selectedPriorities = {'understand-money'};
  Set<String> _wantedFeatures = {'transactions', 'budgets', 'savings-goals'};
  Set<String> _visibleCards = {
    'spending',
    'goals',
    'recent-transactions',
    'alerts',
    'forecast',
  };
  bool _compact = false;
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String? _existingCreatedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserProfileService.getProfile(
          userId: AppScope.activeUserId);
      if (profile != null) {
        _existingCreatedAt = profile.createdAt;
        _householdMode =
            profile.answers['householdMode'] as String? ?? _householdMode;
        _incomePattern =
            profile.answers['incomePattern'] as String? ?? _incomePattern;
        _budgetExperience =
            profile.answers['budgetExperience'] as String? ?? _budgetExperience;
        _notificationPreference =
            profile.answers['notificationPreference'] as String? ??
            _notificationPreference;
        _selectedPriorities = Set<String>.from(
          profile.answers['priorities'] as List? ?? _selectedPriorities,
        );
        _wantedFeatures = Set<String>.from(
          profile.answers['wantedFeatures'] as List? ?? _wantedFeatures,
        );
        _visibleCards = Set<String>.from(
          profile.dashboard['visibleCards'] as List? ?? _visibleCards,
        );
        _compact = profile.dashboard['compact'] as bool? ?? false;
      }
    } catch (error) {
      _message = 'Profil local illisible : $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedPriorities.isEmpty) {
      setState(() => _message = 'Choisis au moins une priorité.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await UserProfileService.saveProfile(
        UserProfile(
          createdAt: _existingCreatedAt ?? now,
          updatedAt: now,
          completedAt: now,
          answers: {
            'householdMode': _householdMode,
            'incomePattern': _incomePattern,
            'budgetExperience': _budgetExperience,
            'priorities': _selectedPriorities.toList(),
            'wantedFeatures': _wantedFeatures.toList(),
            'notificationPreference': _notificationPreference,
          },
          dashboard: {
            'visibleCards': _visibleCards.toList(),
            'compact': _compact,
          },
        ),
        userId: AppScope.activeUserId,
      );
      _existingCreatedAt ??= now;
      setState(
        () => _message = 'Profil enregistré et chiffré sur cet appareil.',
      );
    } catch (error) {
      setState(() => _message = 'Enregistrement impossible : $error');
    } finally {
      setState(() => _saving = false);
    }
  }

  String get _offerProjection {
    if (_householdMode == 'family') {
      return 'Famille — formule future, non disponible';
    }
    if (_householdMode == 'business-later') {
      return 'Entreprise — offre future';
    }
    if (_wantedFeatures.contains('simulations') &&
        _wantedFeatures.contains('ai-assistant')) {
      return 'Premium+ — projection future, non disponible';
    }
    if (_wantedFeatures.contains('ai-assistant') ||
        _wantedFeatures.contains('bank-sync')) {
      return 'Premium — projection future, non disponible';
    }
    if (_wantedFeatures.contains('forecast') ||
        _wantedFeatures.contains('import-excel')) {
      return 'Plus/Pro — projection future, non disponible';
    }
    return 'Free — espace local personnel';
  }

  Widget _multiSelect(
    String title,
    Map<String, String> options,
    Set<String> selected,
    void Function(String) toggle,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...options.entries.map(
              (entry) => CheckboxListTile(
                value: selected.contains(entry.key),
                title: Text(entry.value),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (_) => setState(() => toggle(entry.key)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String title,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: title),
      items: options.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => onChanged(value));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _appearanceCard(),
        const SizedBox(height: 16),
        Text(
          'Mon profil financier',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Tes réponses restent locales et sont chiffrées dans SQLite. Aucun montant ni identifiant bancaire n’est demandé.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _dropdown('Type de foyer', _householdMode, const {
                  'personal': 'Personnel',
                  'couple': 'En couple',
                  'family': 'Famille',
                  'business-later': 'Professionnel plus tard',
                }, (v) => _householdMode = v),
                const SizedBox(height: 12),
                _dropdown('Revenus', _incomePattern, const {
                  'regular': 'Plutôt réguliers',
                  'variable': 'Variables',
                  'mixed': 'Mélange des deux',
                  'prefer-not-to-say': 'Je préfère ne pas préciser',
                }, (v) => _incomePattern = v),
                const SizedBox(height: 12),
                _dropdown('Expérience du budget', _budgetExperience, const {
                  'starting': 'Je commence',
                  'some-habits': 'Quelques habitudes',
                  'experienced': 'Expérimenté(e)',
                }, (v) => _budgetExperience = v),
              ],
            ),
          ),
        ),
        _multiSelect(
          'Mes priorités',
          _priorities,
          _selectedPriorities,
          (id) => _selectedPriorities.contains(id)
              ? _selectedPriorities.remove(id)
              : _selectedPriorities.add(id),
        ),
        _multiSelect(
          'Fonctions qui m’intéressent',
          _features,
          _wantedFeatures,
          (id) => _wantedFeatures.contains(id)
              ? _wantedFeatures.remove(id)
              : _wantedFeatures.add(id),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personnalisation du tableau de bord',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ..._cards.entries.map(
                  (entry) => CheckboxListTile(
                    value: _visibleCards.contains(entry.key),
                    title: Text(entry.value),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (_) => setState(
                      () => _visibleCards.contains(entry.key)
                          ? _visibleCards.remove(entry.key)
                          : _visibleCards.add(entry.key),
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _compact,
                  title: const Text('Affichage compact'),
                  onChanged: (value) => setState(() => _compact = value),
                ),
                _dropdown('Notifications', _notificationPreference, const {
                  'essential': 'Essentielles seulement',
                  'balanced': 'Équilibrées',
                  'none': 'Aucune',
                }, (v) => _notificationPreference = v),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Formule correspondant à tes besoins'),
            subtitle: Text(
              '$_offerProjection\nAucun paiement ni déverrouillage. Les tarifs ne sont pas configurés.',
            ),
            isThreeLine: true,
          ),
        ),
        if (_message != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_message!)),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.lock_outline),
          label: Text(
            _saving ? 'Enregistrement…' : 'Enregistrer mon profil chiffré',
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _appearanceCard() {
    return AnimatedBuilder(
      animation: AppearanceService.instance,
      builder: (context, _) {
        final a = AppearanceService.instance;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Apparence & accessibilité', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Préférences locales (appareil). Thème premium noir/blanc/or.', style: TextStyle(color: TenaColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThemeMode>(
                initialValue: a.themeMode,
                decoration: const InputDecoration(labelText: 'Thème', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Automatique (système)')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                ],
                onChanged: (v){ if(v!=null) a.setThemeMode(v); },
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: Text('Taille du texte')),
                Text('${(a.textScale*100).round()}%', style: const TextStyle(color: TenaColors.textSecondary)),
              ]),
              Slider(min: 0.85, max: 1.35, divisions: 10, value: a.textScale, onChanged: a.setTextScale),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Réduire les animations'),
                subtitle: const Text('Accessibilité / confort visuel', style: TextStyle(fontSize: 12)),
                value: a.reduceMotion,
                onChanged: a.setReduceMotion,
              ),
              const Divider(height: 18),
              DropdownButtonFormField<String>(
                initialValue: a.dateFormat,
                decoration: const InputDecoration(labelText: 'Format de date', border: OutlineInputBorder(), isDense: true),
                items: const [DropdownMenuItem(value: 'fr', child: Text('Français (JJ/MM/AAAA)')), DropdownMenuItem(value: 'iso', child: Text('ISO (AAAA-MM-JJ)'))],
                onChanged: (v){ if(v!=null) a.setDateFormat(v); },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: a.currency,
                decoration: const InputDecoration(labelText: 'Devise d’affichage (préférence locale)', border: OutlineInputBorder(), isDense: true),
                items: const [DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')), DropdownMenuItem(value: 'CHF', child: Text('CHF')), DropdownMenuItem(value: 'USD', child: Text('USD'))],
                onChanged: (v){ if(v!=null) a.setCurrency(v); },
              ),
            ]),
          ),
        );
      },
    );
  }

}
