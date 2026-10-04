import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tena_budget/main.dart';

void main() {
  testWidgets('TENΛ Budget démarre correctement', (WidgetTester tester) async {
    // Le rendu par défaut du test est un écran étroit : la barre
    // latérale fixe n'apparaît qu'au-delà de 1080 px de large.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TenaBudgetApp());

    // Marqueurs de la barre latérale, désormais porteuse de l'identité.
    expect(find.text('TENΛ'), findsOneWidget);
    expect(find.text('BUDGET'), findsOneWidget);

    // Modules reellement presents et cliquables dans la navigation.
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
  });
}
