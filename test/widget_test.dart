import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:car_luxe_cleaning_flutter/app/app.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Car Luxe Cleaning app starts on basket composer', (
    WidgetTester tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: CarLuxeCleaningApp()));
    await tester.pumpAndSettle();

    expect(find.text('Connexion CRM'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'CLC');
    await tester.tap(find.text('SE CONNECTER'));
    await tester.pumpAndSettle();

    expect(find.text('PANIER'), findsOneWidget);
    expect(find.text('CHOISIR LA PRESTATION'), findsOneWidget);
    expect(find.text('LAVAGE'), findsOneWidget);
  });
}
