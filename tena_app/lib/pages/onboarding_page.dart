import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../theme/tena_theme.dart';
import '../widgets/tena_card.dart';

/// Écran d'accueil et questionnaire guidé de premier démarrage.
/// Assure que chaque nouvel utilisateur configure son profil local chiffré
/// avant d'accéder au tableau de bord.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 6;

  // Réponses du questionnaire
  String _householdMode = 'personal';
  String _incomePattern = 'regular';
  String _budgetExperience = 'starting';
  String _notificationPreference = 'balanced';
  final Set<String> _selectedPriorities = {'understand-money', 'control-spending'};
  final Set<String> _wantedFeatures = {'transactions', 'budgets', 'savings-goals'};
  final Set<String> _visibleCards = {'spending', 'goals', 'recent-transactions', 'alerts', 'forecast'};
  bool _compact = false;
  bool _isSaving = false;
  String? _errorMessage;

  static const _prioritiesMap = {
    'understand-money': 'Comprendre où va mon argent',
    'control-spending': 'Mieux contrôler mes dépenses au quotidien',
    'save': 'Épargner pour concrétiser mes projets',
    'prepare-expenses': 'Anticiper les dépenses à venir et imprévus',
    'manage-debt': 'Mieux gérer mes crédits et dettes',
    'family-visibility': 'Organiser les finances du foyer',
  };

  static const _featuresMap = {
    'transactions': 'Suivi des dépenses et revenus',
    'budgets': 'Enveloppes et plafonds par catégorie',
    'savings-goals': 'Objectifs d’épargne avec date cible',
    'forecast': 'Prévisions et solde prévisionnel',
    'import-csv': 'Importation de relevés bancaires (CSV)',
    'encrypted-backups': 'Sauvegardes chiffrées & export',
  };

  static const _cardsMap = {
    'spending': 'Graphique des dépenses par jour',
    'goals': 'Progression des objectifs d’épargne',
    'recent-transactions': 'Dernières transactions',
    'alerts': 'Alertes et dépassements de budget',
    'forecast': 'Prévisions de fin de mois',
  };

  void _nextStep() {
    if (_currentStep == 3 && _selectedPriorities.isEmpty) {
      setState(() => _errorMessage = 'Veuillez sélectionner au moins une priorité.');
      return;
    }
    setState(() => _errorMessage = null);

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (_selectedPriorities.isEmpty) {
      setState(() => _errorMessage = 'Veuillez sélectionner au moins une priorité.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final profile = UserProfile(
        id: 'primary',
        schemaVersion: 1,
        createdAt: now,
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
      );

      await UserProfileService.saveProfile(profile);
      widget.onComplete();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la création du profil : $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: SafeArea(
        child: Column(
          children: [
            // Header TENΛ avec progression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC5A059).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFC5A059).withOpacity(0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Color(0xFFC5A059),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'TENΛ BUDGET',
                            style: TextStyle(
                              color: Color(0xFFE5C07B),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Étape ${_currentStep + 1} / $_totalSteps',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC5A059)),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenu des étapes
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (step) => setState(() => _currentStep = step),
                children: [
                  _buildWelcomeStep(),
                  _buildHouseholdStep(),
                  _buildIncomeAndExperienceStep(),
                  _buildPrioritiesStep(),
                  _buildFeaturesStep(),
                  _buildDashboardConfigStep(),
                ],
              ),
            ),

            // Barre de navigation inférieure
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Précédent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _nextStep,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Icon(
                            _currentStep == _totalSteps - 1
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _isSaving
                          ? 'Chiffrement du coffre…'
                          : (_currentStep == _totalSteps - 1
                              ? 'Accéder à mon tableau de bord'
                              : 'Continuer'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

  // ÉTAPE 1 : Bienvenue & Confidentialité
  Widget _buildWelcomeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Bienvenue dans\nTENΛ Budget',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'L’application de gestion financière pensée pour votre clarté, votre liberté et votre confidentialité absolue.',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          _buildPillarCard(
            Icons.lock_rounded,
            '100% Local & Hors ligne',
            'Vos finances restent sur cet appareil. Aucun compte cloud obligatoire, aucune dépendance serveur.',
          ),
          const SizedBox(height: 16),
          _buildPillarCard(
            Icons.security_rounded,
            'Chiffrement AES-256',
            'Toutes vos données sensibles (montants, libellés, catégories) sont chiffrées au repos dans SQLite.',
          ),
          const SizedBox(height: 16),
          _buildPillarCard(
            Icons.visibility_off_rounded,
            'Zéro suivi, Zéro publicité',
            'Aucune revente de données personnelles, aucun traceur tiers. Vos finances vous appartiennent.',
          ),
        ],
      ),
    );
  }

  // ÉTAPE 2 : Situation du foyer
  Widget _buildHouseholdStep() {
    final options = [
      {'key': 'personal', 'title': 'Gestion personnelle', 'desc': 'Je gère mes propres finances en solo'},
      {'key': 'couple', 'title': 'En couple', 'desc': 'Dépenses et budget partagés à deux'},
      {'key': 'family', 'title': 'Famille', 'desc': 'Foyer avec enfants et dépenses communes'},
      {'key': 'business-later', 'title': 'Activité professionnelle', 'desc': 'Indépendant ou micro-entreprise'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quel est votre cadre de gestion ?',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Cela nous permet d’adapter les catégories et les seuils d’alerte.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 24),
          ...options.map((opt) {
            final isSelected = _householdMode == opt['key'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _householdMode = opt['key']!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFC5A059).withOpacity(0.12)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFC5A059) : Colors.white.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: opt['key']!,
                        groupValue: _householdMode,
                        activeColor: const Color(0xFFC5A059),
                        onChanged: (val) {
                          if (val != null) setState(() => _householdMode = val);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt['desc']!,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ÉTAPE 3 : Revenus et Expérience
  Widget _buildIncomeAndExperienceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenus & habitudes',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun montant exact n’est demandé. Ces indications personnalisent votre calendrier.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 24),
          const Text(
            'Régularité de vos revenus :',
            style: TextStyle(color: Color(0xFFE5C07B), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSelectionChipGroup(
            options: {
              'regular': 'Plutôt fixes (salaire, pension)',
              'variable': 'Variables (commissions, freelance)',
              'mixed': 'Mixtes (fixe + variable)',
              'prefer-not-to-say': 'Je préfère ne pas préciser',
            },
            current: _incomePattern,
            onSelect: (val) => setState(() => _incomePattern = val),
          ),
          const SizedBox(height: 28),
          const Text(
            'Votre expérience avec le budget :',
            style: TextStyle(color: Color(0xFFE5C07B), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSelectionChipGroup(
            options: {
              'starting': 'Je débute complètement',
              'some-habits': 'J’ai quelques habitudes',
              'experienced': 'J’optimise au centime près',
            },
            current: _budgetExperience,
            onSelect: (val) => setState(() => _budgetExperience = val),
          ),
        ],
      ),
    );
  }

  // ÉTAPE 4 : Priorités financières
  Widget _buildPrioritiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quels sont vos objectifs ?',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez une ou plusieurs priorités clés :',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ..._prioritiesMap.entries.map((entry) {
            final isChecked = _selectedPriorities.contains(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CheckboxListTile(
                value: isChecked,
                activeColor: const Color(0xFFC5A059),
                checkColor: Colors.black,
                tileColor: isChecked
                    ? const Color(0xFFC5A059).withOpacity(0.08)
                    : Colors.white.withOpacity(0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isChecked
                        ? const Color(0xFFC5A059).withOpacity(0.6)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedPriorities.add(entry.key);
                    } else {
                      _selectedPriorities.remove(entry.key);
                    }
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ÉTAPE 5 : Fonctionnalités souhaitées
  Widget _buildFeaturesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modules à activer',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tous ces modules fonctionnent 100% hors ligne et peuvent être modifiés plus tard.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ..._featuresMap.entries.map((entry) {
            final isChecked = _wantedFeatures.contains(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CheckboxListTile(
                value: isChecked,
                activeColor: const Color(0xFFC5A059),
                checkColor: Colors.black,
                tileColor: isChecked
                    ? const Color(0xFFC5A059).withOpacity(0.08)
                    : Colors.white.withOpacity(0.03),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isChecked
                        ? const Color(0xFFC5A059).withOpacity(0.6)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _wantedFeatures.add(entry.key);
                    } else {
                      _wantedFeatures.remove(entry.key);
                    }
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ÉTAPE 6 : Personnalisation du Dashboard & Finalisation
  Widget _buildDashboardConfigStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personnalisez votre accueil',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez les cartes à afficher directement sur votre tableau de bord.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ..._cardsMap.entries.map((entry) {
            final isChecked = _visibleCards.contains(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: isChecked,
                activeColor: const Color(0xFFC5A059),
                checkColor: Colors.black,
                dense: true,
                tileColor: Colors.white.withOpacity(0.03),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: Text(entry.value, style: const TextStyle(color: Colors.white, fontSize: 14)),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _visibleCards.add(entry.key);
                    } else {
                      _visibleCards.remove(entry.key);
                    }
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _compact,
            activeColor: const Color(0xFFC5A059),
            title: const Text('Mode d’affichage compact', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: Text(
              'Optimise l’espace pour afficher plus de détails sans défilement',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            onChanged: (val) => setState(() => _compact = val),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A059).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFFC5A059), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coffre-fort local prêt',
                        style: TextStyle(color: Color(0xFFE5C07B), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'En cliquant ci-dessous, votre profil sera chiffré dans SQLite via AES-256.',
                        style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A059).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFC5A059), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChipGroup({
    required Map<String, String> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      children: options.entries.map((entry) {
        final isSelected = current == entry.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onSelect(entry.key),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC5A059).withOpacity(0.15)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFFC5A059) : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE5C07B) : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
