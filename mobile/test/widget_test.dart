import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_mvp/account_settings.dart';
import 'package:taxi_mvp/api.dart';
import 'package:taxi_mvp/app_language.dart';
import 'package:taxi_mvp/home_screen.dart';
import 'package:taxi_mvp/main.dart';
import 'package:taxi_mvp/map_picker.dart';

void main() {
  testWidgets('opening the app asks for passenger or driver', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TaxiApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Good Day Kilo Taxi logo'), findsOneWidget);
    expect(find.text('I am a passenger'), findsOneWidget);
    expect(find.text('I am a driver'), findsOneWidget);
    await tester.tap(find.text('I am a passenger'));
    await tester.pump();
    expect(find.text('Sign in as a passenger.'), findsOneWidget);
    await tester.tap(find.text('Change role'));
    await tester.pump();
    expect(find.text('I am a driver'), findsOneWidget);
  });

  testWidgets('driver registration asks for a vehicle plate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(role: 'driver', onBack: () {}, onSuccess: _done),
      ),
    );
    final registerButton = find.text('New here? Create an account');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump();
    expect(find.text('Create your driver account.'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Vehicle plate'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));
  });

  testWidgets('saved Myanmar choice changes the opening and place search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'my'});
    await tester.pumpWidget(const TaxiApp());
    await tester.pumpAndSettle();
    expect(find.text('ဒီအက်ပ်ကို ဘယ်လို အသုံးပြုမလဲ။'), findsOneWidget);
    await tester.tap(find.byTooltip('ဘာသာစကား ပြောင်းရန်'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('How will you use the app today?'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en');

    await tester.pumpWidget(
      AppLanguage(
        code: 'my',
        onChange: (_) {},
        child: MaterialApp(
          home: Scaffold(
            body: PlacePicker(
              city: 'Yangon',
              places: [
                {'id': 'sule', 'name': 'Sule Pagoda', 'area': 'Downtown'},
                {
                  'id': 'airport',
                  'name': 'Yangon International Airport',
                  'area': 'Mingaladon',
                },
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('ဆူးလေဘုရား'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'လေဆိပ်');
    await tester.pump();
    expect(find.text('ဆူးလေဘုရား'), findsNothing);
    expect(find.text('ရန်ကုန်အပြည်ပြည်ဆိုင်ရာလေဆိပ်'), findsOneWidget);
  });

  test('map selections stay inside the configured service area', () {
    final bounds = {
      'south': 16.55,
      'north': 17.20,
      'west': 95.85,
      'east': 96.50,
    };
    expect(insideServiceArea(16.7745, 96.1582, bounds), isTrue);
    expect(insideServiceArea(17.9757, 102.6331, bounds), isFalse);
  });

  testWidgets('account screen shows profile and password controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsPage(
          api: Api('test-token'),
          user: {
            'name': 'Passenger Test',
            'email': 'passenger@example.com',
            'phone': '09111111111',
            'role': 'passenger',
          },
          onSignOut: () async {},
        ),
      ),
    );

    expect(find.text('My account'), findsOneWidget);
    expect(find.text('passenger@example.com'), findsOneWidget);
    expect(find.text('Passenger account'), findsOneWidget);
    expect(find.text('Save account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));
  });
}

Future<void> _done(String token, Map<String, dynamic> user) async {}
