import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/forecast_service.dart';

class ForecastPage extends StatefulWidget {
  const ForecastPage({super.key});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> {
  final DatabaseService _database = DatabaseService.instance;

  ForecastResult? _forecast;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final transactions = await _database.getTransactions();
    final forecast = ForecastService.calculate(transactions);

    if (!mounted) return;

    setState(() {
      _forecast = forecast;
      _loading = false;
    });
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _forecast == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final forecast = _forecast!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Prévisions',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Estimation basée sur tes données locales.'),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dépenses prévues',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _money(forecast.estimatedNextMonthExpenses),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Estimation des dépenses du prochain mois.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenus prévus',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _money(forecast.estimatedNextMonthIncome),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Estimation des revenus du prochain mois.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solde prévu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _money(forecast.estimatedBalance),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: forecast.estimatedBalance >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      forecast.estimatedBalance >= 0
                          ? 'Les revenus estimés couvrent les dépenses estimées.'
                          : 'Les dépenses estimées dépassent les revenus estimés.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Moyennes utilisées',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.trending_down),
                    title: const Text('Dépenses mensuelles moyennes'),
                    trailing: Text(_money(forecast.averageMonthlyExpenses)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: const Text('Revenus mensuels moyens'),
                    trailing: Text(_money(forecast.averageMonthlyIncome)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cette prévision est calculée uniquement à partir des transactions enregistrées sur cet appareil. Elle pourra ensuite être améliorée avec les fonctionnalités avancées de TENΛ.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
