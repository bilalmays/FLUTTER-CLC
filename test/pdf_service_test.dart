import 'dart:convert';

import 'package:car_luxe_cleaning_flutter/features/pdf/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildQuotePdf generates a valid PDF with the TypeScript-style quote',
    () async {
      const service = FlutterPdfService();

      final bytes = await service.buildQuotePdf(
        QuotePdfInput(
          reference: 'DEV-TEST-001',
          date: DateTime(2026, 7, 4),
          language: 'FR',
          client: const DocumentParty(
            name: 'Bilal de Boeck',
            email: 'client@example.com',
            address: 'Rue Test 1',
          ),
          vehicle: const DocumentVehicle(
            make: 'Porsche',
            model: '911',
            licensePlate: '1-BIL-001',
          ),
          vehicleSize: 'M',
          items: const [
            DocumentLineItem(
              description: 'Pack Brillance',
              quantity: 1,
              unitPrice: 450,
            ),
          ],
          applyVat: true,
        ),
      );

      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    },
  );
}
