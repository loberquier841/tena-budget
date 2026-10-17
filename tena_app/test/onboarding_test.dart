import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tena_budget/services/user_profile_service.dart';

void main() {
  setUp(() {
    UserProfileService.reset();
  });

  tearDown(() {
    UserProfileService.reset();
  });

  testWidgets('ProfilePage calls onSaved when saved in onboarding mode',
      (WidgetTester tester) async {
    // Create a fake service that returns null for getProfile and does nothing for saveProfile
    class FakeUserProfileService extends UserProfileService {
      @override
      Future<UserProfile?> getProfile() async => null;

      @override
      Future<void> saveProfile(UserProfile profile) async {
        // Do nothing
      }
    }

    // Set the fake instance
    UserProfileService.setInstance(FakeUserProfileService());

    bool onSavedCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: ProfilePage(
        isOnboarding: true,
        onSaved: () {
          onSavedCalled = true;
        },
      ),
    ));

    // Verify that we are on the profile page
    expect(find.text('Comprendre où va mon argent'), findsOneWidget);

    // Fill in the form: we need to select at least one priority
    // For simplicity, we'll tap the first checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    // Tap the save button
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    // Verify that the onSaved callback was called
    expect(onSavedCalled, isTrue);
  });
}