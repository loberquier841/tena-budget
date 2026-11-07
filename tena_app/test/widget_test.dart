import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tena_budget/main.dart';
import 'package:tena_budget/services/crypto_service.dart';
import 'package:tena_budget/services/payment_service.dart';
import 'package:tena_budget/services/secure_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TENΛ Budget démarre (smoke, état local déterministe)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'tena_payment_state': '{"isPremium":false}',
    });
    CryptoService.useKeyStore(
      SecureStorageKeyStore(fallback: PreferencesKeyStore(SharedPreferences.getInstance)),
    );
    CryptoService.debugSetKey('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=');
    await PaymentService.instance.load();

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TenaBudgetApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800));

    // Démarrage sans crash ; écran onboarding ou chargement affiché.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
