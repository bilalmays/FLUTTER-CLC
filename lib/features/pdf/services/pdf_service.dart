import 'package:barcode/barcode.dart';
import 'package:car_luxe_cleaning_flutter/core/utils/date_money_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final pdfServiceProvider = Provider<PdfService>(
  (ref) => const FlutterPdfService(),
);

class DocumentParty {
  const DocumentParty({
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.companyName = '',
    this.vatNumber = '',
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final String companyName;
  final String vatNumber;
}

class DocumentVehicle {
  const DocumentVehicle({
    required this.make,
    required this.model,
    this.licensePlate = '',
    this.vin = '',
    this.year = '',
    this.color = '',
  });

  final String make;
  final String model;
  final String licensePlate;
  final String vin;
  final String year;
  final String color;
}

class DocumentLineItem {
  const DocumentLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.vatRate = 21,
    this.note = '',
  });

  final String description;
  final int quantity;
  final int unitPrice;
  final int vatRate;
  final String note;

  int get subtotal => quantity * unitPrice;
  double get vatAmount => subtotal * vatRate / 100;
  double get total => subtotal + vatAmount;
}

class DocumentPhoto {
  const DocumentPhoto({
    required this.fileName,
    required this.bytes,
    this.caption = '',
  });

  final String fileName;
  final Uint8List bytes;
  final String caption;
}

class QuotePdfInput {
  const QuotePdfInput({
    required this.reference,
    required this.date,
    required this.language,
    required this.client,
    required this.vehicle,
    required this.items,
    required this.applyVat,
    this.vehicleSize = '',
    this.includePackDetails = true,
    this.showQrCode = true,
  });

  final String reference;
  final DateTime date;
  final String language;
  final DocumentParty client;
  final DocumentVehicle vehicle;
  final List<DocumentLineItem> items;
  final bool applyVat;
  final String vehicleSize;
  final bool includePackDetails;
  final bool showQrCode;
}

class DepositPdfInput {
  const DepositPdfInput({
    required this.reference,
    required this.date,
    required this.language,
    required this.client,
    required this.vehicle,
    required this.amount,
    required this.paymentMethod,
    required this.reason,
  });

  final String reference;
  final DateTime date;
  final String language;
  final DocumentParty client;
  final DocumentVehicle vehicle;
  final int amount;
  final String paymentMethod;
  final String reason;
}

class PickupPdfInput {
  const PickupPdfInput({
    required this.reference,
    required this.date,
    required this.client,
    required this.vehicle,
    required this.pickupAddress,
    required this.distanceKm,
    required this.price,
    required this.condition,
    required this.notes,
    required this.clientSignatureRequired,
    required this.companySignatureRequired,
    this.clientSignatureBytes,
    this.companySignatureBytes,
    this.photos = const [],
  });

  final String reference;
  final DateTime date;
  final DocumentParty client;
  final DocumentVehicle vehicle;
  final String pickupAddress;
  final double distanceKm;
  final int price;
  final String condition;
  final String notes;
  final bool clientSignatureRequired;
  final bool companySignatureRequired;
  final Uint8List? clientSignatureBytes;
  final Uint8List? companySignatureBytes;
  final List<DocumentPhoto> photos;
}

class CarnetEntryPdf {
  const CarnetEntryPdf({
    required this.visitNumber,
    required this.date,
    required this.category,
    required this.pack,
    required this.remark,
  });

  final String visitNumber;
  final DateTime date;
  final String category;
  final String pack;
  final String remark;
}

class CarnetPdfInput {
  const CarnetPdfInput({
    required this.reference,
    required this.createdDate,
    required this.client,
    required this.vehicle,
    required this.entries,
  });

  final String reference;
  final DateTime createdDate;
  final DocumentParty client;
  final DocumentVehicle vehicle;
  final List<CarnetEntryPdf> entries;
}

class InspectionPdfInput {
  const InspectionPdfInput({
    required this.reference,
    required this.date,
    required this.client,
    required this.vehicle,
    required this.checklist,
    required this.photoNames,
    required this.notes,
    required this.clientSignatureCaptured,
    this.photos = const [],
    this.clientSignatureBytes,
  });

  final String reference;
  final DateTime date;
  final DocumentParty client;
  final DocumentVehicle vehicle;
  final Map<String, bool> checklist;
  final List<String> photoNames;
  final String notes;
  final bool clientSignatureCaptured;
  final List<DocumentPhoto> photos;
  final Uint8List? clientSignatureBytes;
}

class SecretPdfInput {
  const SecretPdfInput({
    required this.reference,
    required this.date,
    required this.client,
    required this.vehicle,
    required this.vehicleSize,
    required this.items,
    required this.notes,
    required this.showVatNumber,
  });

  final String reference;
  final DateTime date;
  final DocumentParty client;
  final DocumentVehicle vehicle;
  final String vehicleSize;
  final List<DocumentLineItem> items;
  final String notes;
  final bool showVatNumber;
}

abstract class PdfService {
  Future<List<int>> buildQuotePdf(QuotePdfInput input);
  Future<List<int>> buildDepositPdf(DepositPdfInput input);
  Future<List<int>> buildPickupPdf(PickupPdfInput input);
  Future<List<int>> buildMaintenanceBookPdf(CarnetPdfInput input);
  Future<List<int>> buildInspectionPdf(InspectionPdfInput input);
  Future<List<int>> buildSecretPdf(SecretPdfInput input);
}

class FlutterPdfService implements PdfService {
  const FlutterPdfService();

  @override
  Future<List<int>> buildQuotePdf(QuotePdfInput input) async {
    final doc = pw.Document();
    final logo = await _loadLogo();
    final subtotal = input.items.fold<int>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final vat = input.applyVat
        ? input.items.fold<double>(0, (sum, item) => sum + item.vatAmount)
        : 0.0;
    final total = subtotal + vat;
    final quoteFont = await _loadFontAsset(
      'assets/carnet/fonts/Barlow-Regular.ttf',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: quoteFont == null
            ? null
            : pw.ThemeData.withFont(
                base: quoteFont,
                bold: quoteFont,
                italic: quoteFont,
                boldItalic: quoteFont,
              ),
        margin: pw.EdgeInsets.fromLTRB(_mm(18), _mm(15), _mm(18), _mm(18)),
        header: (context) => _quoteHeader(
          logo: logo,
          input: input,
          continued: context.pageNumber > 1,
        ),
        footer: (context) => _quoteFooter(
          context: context,
          reference: input.reference,
          amount: total,
          showQrCode: input.showQrCode,
        ),
        build: (context) => [
          pw.SizedBox(height: _mm(10)),
          _quotePartyAndVehicle(input),
          pw.SizedBox(height: _mm(12)),
          pw.Divider(color: _pdfGrey200, thickness: 0.7),
          pw.SizedBox(height: _mm(9)),
          _quoteLineItems(
            input.items,
            applyVat: input.applyVat,
            language: input.language,
          ),
          pw.SizedBox(height: _mm(7)),
          _quoteTotals(
            subtotal: subtotal.toDouble(),
            vat: vat,
            total: total,
            applyVat: input.applyVat,
            language: input.language,
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Future<List<int>> buildDepositPdf(DepositPdfInput input) async {
    final doc = pw.Document();
    final logo = await _loadLogo();
    doc.addPage(
      _page(
        logo: logo,
        title: "RECU D'ACOMPTE",
        reference: input.reference,
        date: input.date,
        content: [
          _partyAndVehicle(input.client, input.vehicle),
          pw.SizedBox(height: 18),
          _summaryGrid([
            ('Montant recu', formatMoney(input.amount)),
            ('Mode de paiement', input.paymentMethod),
            ('Motif', input.reason),
            ('Langue', input.language),
          ]),
          pw.SizedBox(height: 18),
          _noteBox(
            'CONFIRMATION',
            "Cet acompte est lie au dossier client et sera deduit du solde final.",
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Future<List<int>> buildPickupPdf(PickupPdfInput input) async {
    final doc = pw.Document();
    final logo = await _loadLogo();
    doc.addPage(
      _page(
        logo: logo,
        title: 'SERVICE PICK-UP',
        reference: input.reference,
        date: input.date,
        content: [
          _partyAndVehicle(input.client, input.vehicle),
          pw.SizedBox(height: 18),
          _summaryGrid([
            ('Adresse', input.pickupAddress),
            ('Distance retenue', '${input.distanceKm.toStringAsFixed(2)} km'),
            ('Prix', formatMoney(input.price)),
            ('Etat vehicule', input.condition),
          ]),
          if (input.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _noteBox('REMARQUES', input.notes),
          ],
          if (input.photos.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _photoGrid(input.photos),
          ],
          pw.SizedBox(height: 20),
          _signatures(
            clientRequired: input.clientSignatureRequired,
            companyRequired: input.companySignatureRequired,
            clientSignatureBytes: input.clientSignatureBytes,
            companySignatureBytes: input.companySignatureBytes,
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Future<List<int>> buildMaintenanceBookPdf(CarnetPdfInput input) async {
    final doc = pw.Document();
    final assets = await _loadCarnetAssets();
    final entries = input.entries.isEmpty
        ? [
            CarnetEntryPdf(
              visitNumber: '01',
              date: input.createdDate,
              category: '',
              pack: '',
              remark: '',
            ),
          ]
        : input.entries.take(55).toList();

    doc.addPage(_carnetImagePage(background: assets.cover, children: const []));

    doc.addPage(
      _carnetImagePage(
        background: assets.vehicleBackground,
        footerMark: assets.footerMark,
        pageLabel: '2',
        children: [
          _carnetLogo(assets.logo, left: 62, top: 8.8, width: 86, height: 21.4),
          _carnetCenteredText(
            'IDENTIFICATION',
            top: 47.4,
            fontSize: 20.4,
            font: assets.barlow,
            color: PdfColors.white,
            bold: true,
          ),
          _carnetCenteredText(
            'DU VEHICULE',
            top: 59.0,
            fontSize: 9.2,
            font: assets.barlow,
            color: PdfColors.white,
            letterSpacing: 2.15,
          ),
          _carnetVehicleField(
            label: 'MARQUE',
            value: input.vehicle.make,
            top: 95.7,
            font: assets.barlow,
          ),
          _carnetVehicleField(
            label: 'MODELE',
            value: input.vehicle.model,
            top: 132.4,
            font: assets.barlow,
          ),
          _carnetVehicleField(
            label: 'ANNEE DE PRODUCTION',
            value: _vehicleYearText(input.vehicle.year),
            top: 168.9,
            font: assets.barlow,
          ),
          _carnetVehicleField(
            label: 'NUMERO DE CHASSIS (VIN)',
            value: input.vehicle.vin,
            top: 205.6,
            font: assets.barlow,
          ),
        ],
      ),
    );

    final chunks = <List<CarnetEntryPdf>>[];
    for (var index = 0; index < entries.length; index += 5) {
      chunks.add(entries.skip(index).take(5).toList());
    }

    for (var pageIndex = 0; pageIndex < chunks.length; pageIndex += 1) {
      final firstVisit = pageIndex * 5 + 1;
      final lastVisit = firstVisit + chunks[pageIndex].length - 1;
      doc.addPage(
        _carnetImagePage(
          background: assets.historyBackground,
          footerMark: assets.footerMark,
          pageLabel: '${3 + pageIndex}',
          visitRange:
              'VISITES ${firstVisit.toString().padLeft(2, '0')} A ${lastVisit.toString().padLeft(2, '0')}',
          children: [
            if (pageIndex == 0) ...[
              _carnetLogo(
                assets.logo,
                left: 62,
                top: 8.2,
                width: 86,
                height: 21.5,
              ),
              _carnetCenteredText(
                'VOTRE VEHICULE,',
                top: 41.2,
                fontSize: 18.2,
                font: assets.barlow,
                color: PdfColors.white,
                bold: true,
              ),
              _carnetCenteredText(
                'SUIVI DANS LE DETAIL',
                top: 52.2,
                fontSize: 18.2,
                font: assets.barlow,
                color: PdfColors.white,
                bold: true,
              ),
              _carnetGlowLine(top: 59.1, left: 67.5, right: 142.5),
              _carnetCenteredText(
                "CARNET D'ENTRETIEN ESTHETIQUE",
                top: 67.0,
                fontSize: 7.6,
                font: assets.barlow,
                color: _lime,
                bold: true,
                letterSpacing: 1.28,
              ),
              _carnetCenteredParagraph(
                "Ce carnet rassemble l'historique des prestations esthetiques realisees par Car Luxe Cleaning. Il assure un suivi clair des interventions, conserve une preuve professionnelle des prestations effectuees et contribue a preserver la valeur du vehicule dans le temps.",
                top: 75.5,
                width: 176,
                fontSize: 7.65,
                font: assets.barlow,
              ),
            ],
            for (var index = 0; index < chunks[pageIndex].length; index += 1)
              _carnetHistoryCard(
                entry: chunks[pageIndex][index],
                visitIndex: firstVisit + index,
                stamp: assets.stamp,
                font: assets.barlow,
                left: pageIndex == 0 ? 12.6 : 14.0,
                top: pageIndex == 0
                    ? 88.9 + index * (35.5 + 2.4)
                    : 25.6 + index * (43.4 + 3.0),
                width: pageIndex == 0 ? 184.8 : 182.0,
                height: pageIndex == 0 ? 35.5 : 43.4,
                compact: pageIndex == 0,
              ),
          ],
        ),
      );
    }

    doc.addPage(_carnetLegalPage(assets, firstGroup: true));
    doc.addPage(_carnetLegalPage(assets, firstGroup: false));
    doc.addPage(_carnetClosingPage(assets, input));

    return doc.save();
  }

  @override
  Future<List<int>> buildInspectionPdf(InspectionPdfInput input) async {
    final doc = pw.Document();
    final logo = await _loadLogo();
    doc.addPage(
      _page(
        logo: logo,
        title: 'ETAT DES LIEUX',
        reference: input.reference,
        date: input.date,
        content: [
          _partyAndVehicle(input.client, input.vehicle),
          pw.SizedBox(height: 18),
          pw.Text('CHECKLIST', style: _sectionTitle),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in input.checklist.entries)
                pw.Container(
                  width: 236,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: _boxDecoration(),
                  child: pw.Row(
                    children: [
                      pw.Text(entry.value ? 'OK' : 'A VERIFIER', style: _bold),
                      pw.SizedBox(width: 10),
                      pw.Expanded(child: pw.Text(entry.key, style: _body)),
                    ],
                  ),
                ),
            ],
          ),
          if (input.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _noteBox('REMARQUES', input.notes),
          ],
          if (input.photos.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _photoGrid(input.photos),
          ] else if (input.photoNames.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _noteBox('PHOTOS', input.photoNames.join('\n')),
          ],
          pw.SizedBox(height: 20),
          _signatures(
            clientRequired: !input.clientSignatureCaptured,
            companyRequired: false,
            clientSignatureBytes: input.clientSignatureBytes,
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Future<List<int>> buildSecretPdf(SecretPdfInput input) async {
    final doc = pw.Document();
    final logo = await _loadLogo();
    final total = input.items.fold<int>(0, (sum, item) => sum + item.subtotal);
    final client = input.showVatNumber
        ? input.client
        : DocumentParty(
            name: input.client.name,
            email: input.client.email,
            phone: input.client.phone,
            address: input.client.address,
            companyName: input.client.companyName,
          );

    doc.addPage(
      _page(
        logo: logo,
        title: 'DOCUMENT',
        reference: input.reference,
        date: input.date,
        content: [
          _partyAndVehicle(client, input.vehicle),
          pw.SizedBox(height: 18),
          _summaryGrid([
            ('Taille vehicule', input.vehicleSize),
            ('Total', formatMoney(total)),
            ('TVA visible', input.showVatNumber ? 'Oui' : 'Non'),
          ]),
          pw.SizedBox(height: 18),
          _lineItems(input.items, applyVat: false),
          pw.SizedBox(height: 16),
          _secretTotal(total),
          if (input.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _noteBox('REMARQUES', input.notes),
          ],
        ],
      ),
    );
    return doc.save();
  }

  Future<_CarnetAssets> _loadCarnetAssets() async {
    return _CarnetAssets(
      cover: await _loadImageAsset('assets/carnet/cover-page.jpg'),
      vehicleBackground: await _loadImageAsset(
        'assets/carnet/vehicle-page.jpg',
      ),
      historyBackground: await _loadImageAsset(
        'assets/carnet/history-background.jpg',
      ),
      innerBackground: await _loadImageAsset(
        'assets/carnet/inner-background.jpg',
      ),
      logo:
          await _loadImageAsset('assets/carnet/clc-logo-transparent.png') ??
          await _loadLogo(),
      stamp: await _loadImageAsset('assets/carnet/clc-stamp.png'),
      footerMark: await _loadImageAsset('assets/carnet/clc-footer-mark.png'),
      barlow: await _loadFontAsset('assets/carnet/fonts/Barlow-Regular.ttf'),
      serif: await _loadFontAsset(
        'assets/carnet/fonts/DMSerifDisplay-Regular.ttf',
      ),
    );
  }

  Future<pw.Font?> _loadFontAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  pw.Page _carnetImagePage({
    required pw.ImageProvider? background,
    required List<pw.Widget> children,
    pw.ImageProvider? footerMark,
    String? pageLabel,
    String? visitRange,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Stack(
        children: [
          pw.Positioned.fill(
            child: background == null
                ? pw.Container(color: PdfColors.black)
                : pw.Image(background, fit: pw.BoxFit.cover),
          ),
          ...children,
          if (footerMark != null)
            _carnetFooter(
              footerMark: footerMark,
              pageText:
                  '${pageLabel ?? context.pageNumber}/${context.pagesCount}',
              visitRange: visitRange,
            ),
        ],
      ),
    );
  }

  pw.Widget _carnetLogo(
    pw.ImageProvider? logo, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    if (logo == null) return pw.SizedBox.shrink();
    return pw.Positioned(
      left: _mm(left),
      top: _mm(top),
      child: pw.Image(
        logo,
        width: _mm(width),
        height: _mm(height),
        fit: pw.BoxFit.contain,
      ),
    );
  }

  pw.Widget _carnetCenteredText(
    String text, {
    required double top,
    required double fontSize,
    required PdfColor color,
    pw.Font? font,
    bool bold = false,
    double letterSpacing = 0,
  }) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: _mm(top),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }

  pw.Widget _carnetCenteredParagraph(
    String text, {
    required double top,
    required double width,
    required double fontSize,
    pw.Font? font,
  }) {
    return pw.Positioned(
      left: _mm((210 - width) / 2),
      top: _mm(top),
      child: pw.SizedBox(
        width: _mm(width),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: font,
            color: PdfColors.white,
            fontSize: fontSize,
            lineSpacing: 2.2,
          ),
        ),
      ),
    );
  }

  pw.Widget _carnetVehicleField({
    required String label,
    required String value,
    required double top,
    required pw.Font? font,
  }) {
    final text = _safeText(value).toUpperCase();
    return pw.Positioned(
      left: _mm(71.4),
      top: _mm(top),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              color: _lime,
              fontSize: 6.15,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.42,
            ),
          ),
          pw.SizedBox(height: _mm(4.4)),
          pw.SizedBox(
            width: _mm(103.5),
            child: pw.Text(
              text,
              maxLines: 1,
              style: pw.TextStyle(
                font: font,
                color: PdfColors.white,
                fontSize: text.length > 24 ? 8.4 : 11.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _carnetGlowLine({
    required double top,
    required double left,
    required double right,
  }) {
    return pw.Positioned(
      left: _mm(left),
      top: _mm(top),
      child: pw.Container(width: _mm(right - left), height: 1.8, color: _lime),
    );
  }

  pw.Widget _carnetHistoryCard({
    required CarnetEntryPdf entry,
    required int visitIndex,
    required pw.ImageProvider? stamp,
    required pw.Font? font,
    required double left,
    required double top,
    required double width,
    required double height,
    required bool compact,
  }) {
    final numberColumn = compact ? 30.7 : 31.8;
    final contentX = numberColumn + (compact ? 7.7 : 8.4);
    final dateX = compact ? 102.4 : 102.3;
    final stampWidth = compact ? 25.0 : 27.0;
    final stampHeight = compact ? 22.4 : 31.0;
    final stampX = width - stampWidth - 4.0;
    final stampY = (height - stampHeight) / 2;
    final visitNumber = _safeText(
      entry.visitNumber,
      visitIndex.toString().padLeft(2, '0'),
    );

    return pw.Positioned(
      left: _mm(left),
      top: _mm(top),
      child: pw.Container(
        width: _mm(width),
        height: _mm(height),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#060708'),
          borderRadius: pw.BorderRadius.circular(_mm(3)),
          border: pw.Border.all(color: _lime, width: 0.9),
        ),
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: _mm(numberColumn),
              top: _mm(4.2),
              child: pw.Container(
                width: 0.7,
                height: _mm(height - 8.4),
                color: PdfColor.fromHex('#636D5B'),
              ),
            ),
            pw.Positioned(
              left: 0,
              top: _mm(compact ? 7.2 : 8.2),
              child: pw.SizedBox(
                width: _mm(numberColumn),
                child: pw.Text(
                  'VISITE',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: font,
                    color: _lime,
                    fontSize: compact ? 5.25 : 5.9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: compact ? 0.8 : 1.0,
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: 0,
              top: _mm(compact ? 13.0 : 14.5),
              child: pw.SizedBox(
                width: _mm(numberColumn),
                child: pw.Text(
                  visitNumber,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: font,
                    color: PdfColors.white,
                    fontSize: compact ? 24.5 : 30.0,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: _mm(contentX),
              top: _mm(compact ? 6.1 : 7.2),
              child: pw.Text('PACK', style: _carnetLabel(font, compact)),
            ),
            pw.Positioned(
              left: _mm(dateX),
              top: _mm(compact ? 6.1 : 7.2),
              child: pw.Text(
                'DATE DE PASSAGE',
                style: _carnetLabel(font, compact),
              ),
            ),
            pw.Positioned(
              left: _mm(contentX),
              top: _mm(compact ? 12.3 : 14.8),
              child: pw.SizedBox(
                width: _mm(dateX - contentX - 6),
                child: pw.Text(
                  _safeText(entry.pack, 'Pack non renseigne'),
                  maxLines: 1,
                  style: pw.TextStyle(
                    font: font,
                    color: PdfColors.white,
                    fontSize: compact ? 10.9 : 12.0,
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: _mm(dateX),
              top: _mm(compact ? 12.3 : 14.8),
              child: pw.Text(
                formatDate(entry.date),
                style: pw.TextStyle(
                  font: font,
                  color: PdfColors.white,
                  fontSize: compact ? 10.0 : 11.0,
                ),
              ),
            ),
            pw.Positioned(
              left: _mm(contentX),
              top: _mm(compact ? 17.0 : 19.8),
              child: pw.Container(
                width: _mm(stampX - contentX - 5.2),
                height: 0.4,
                color: PdfColor.fromHex('#787F76'),
              ),
            ),
            pw.Positioned(
              left: _mm(contentX),
              top: _mm(compact ? 22.2 : 25.2),
              child: pw.Text('REMARQUE', style: _carnetLabel(font, compact)),
            ),
            pw.Positioned(
              left: _mm(contentX),
              top: _mm(compact ? 27.2 : 31.0),
              child: pw.SizedBox(
                width: _mm(stampX - contentX - 5.2),
                child: pw.Text(
                  _safeText(entry.remark, 'Aucune remarque.'),
                  maxLines: compact ? 3 : 4,
                  style: pw.TextStyle(
                    font: font,
                    color: PdfColors.white,
                    fontSize: compact ? 10.9 : 12.0,
                    lineSpacing: 1.2,
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: _mm(stampX),
              top: _mm(stampY),
              child: pw.Container(
                width: _mm(stampWidth),
                height: _mm(stampHeight),
                padding: pw.EdgeInsets.symmetric(horizontal: _mm(2.4)),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#040506'),
                  borderRadius: pw.BorderRadius.circular(_mm(2.8)),
                  border: pw.Border.all(color: _lime, width: 0.8),
                ),
                child: stamp == null
                    ? pw.SizedBox.shrink()
                    : pw.Center(
                        child: pw.Image(
                          stamp,
                          width: _mm(stampWidth - 4.8),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.TextStyle _carnetLabel(pw.Font? font, bool compact) {
    return pw.TextStyle(
      font: font,
      color: _lime,
      fontSize: compact ? 6.55 : 7.0,
      fontWeight: pw.FontWeight.bold,
    );
  }

  pw.Widget _carnetFooter({
    required pw.ImageProvider footerMark,
    required String pageText,
    String? visitRange,
  }) {
    return pw.Positioned(
      left: _mm(14.8),
      right: _mm(18.7),
      top: _mm(281.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'carluxecleaning.com',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 6.25),
          ),
          pw.Spacer(),
          if ((visitRange ?? '').isNotEmpty) ...[
            pw.Container(width: _mm(17.8), height: 0.8, color: _lime),
            pw.SizedBox(width: _mm(5)),
            pw.Text(
              visitRange!,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 5.9),
            ),
            pw.SizedBox(width: _mm(5)),
            pw.Image(footerMark, width: _mm(21), height: _mm(4)),
            pw.SizedBox(width: _mm(5)),
            pw.Container(width: _mm(17.8), height: 0.8, color: _lime),
            pw.Spacer(),
          ],
          pw.Text(
            pageText,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 7.2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Page _carnetLegalPage(_CarnetAssets assets, {required bool firstGroup}) {
    final sections = firstGroup
        ? _carnetLegalSections.take(3).toList()
        : _carnetLegalSections.skip(3).toList();
    return _carnetImagePage(
      background: assets.innerBackground,
      footerMark: assets.footerMark,
      children: [
        _carnetLogo(assets.logo, left: 61, top: 11.2, width: 88, height: 22),
        _carnetCenteredText(
          'MENTIONS LEGALES',
          top: 48,
          fontSize: 22.2,
          font: assets.serif ?? assets.barlow,
          color: PdfColors.white,
          bold: true,
        ),
        _carnetCenteredText(
          firstGroup
              ? 'INFORMATIONS IMPORTANTES'
              : 'INFORMATIONS COMPLEMENTAIRES',
          top: 62,
          fontSize: 7.7,
          font: assets.barlow,
          color: _lime,
          letterSpacing: 1.7,
        ),
        _carnetGlowLine(top: 69, left: 77, right: 133),
        for (var index = 0; index < sections.length; index += 1)
          _carnetLegalBlock(
            title: sections[index].$1,
            body: sections[index].$2,
            top: 82 + index * 55,
            font: assets.barlow,
          ),
      ],
    );
  }

  pw.Widget _carnetLegalBlock({
    required String title,
    required String body,
    required double top,
    required pw.Font? font,
  }) {
    return pw.Positioned(
      left: _mm(23),
      top: _mm(top),
      child: pw.SizedBox(
        width: _mm(164),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                font: font,
                color: _lime,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: _mm(3)),
            pw.Text(
              body,
              style: pw.TextStyle(
                font: font,
                color: PdfColors.white,
                fontSize: 7.35,
                lineSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Page _carnetClosingPage(_CarnetAssets assets, CarnetPdfInput input) {
    return _carnetImagePage(
      background: assets.innerBackground,
      footerMark: assets.footerMark,
      children: [
        _carnetLogo(assets.logo, left: 61, top: 17, width: 88, height: 22),
        _carnetCenteredText(
          'MERCI',
          top: 66,
          fontSize: 28,
          font: assets.serif ?? assets.barlow,
          color: PdfColors.white,
          bold: true,
        ),
        _carnetCenteredText(
          'DE VOTRE CONFIANCE,',
          top: 81,
          fontSize: 12,
          font: assets.barlow,
          color: PdfColors.white,
          letterSpacing: 1.35,
        ),
        _carnetCenteredText(
          'ET BONNE ROUTE !',
          top: 91,
          fontSize: 12,
          font: assets.barlow,
          color: PdfColors.white,
          letterSpacing: 1.35,
        ),
        _carnetGlowLine(top: 99, left: 74, right: 136),
        pw.Positioned(
          left: _mm(77),
          top: _mm(119),
          child: pw.Container(
            width: _mm(56),
            height: _mm(56),
            decoration: pw.BoxDecoration(
              color: _lime,
              borderRadius: pw.BorderRadius.circular(_mm(4)),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'CLC',
              style: pw.TextStyle(
                color: PdfColors.black,
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        _carnetCenteredText(
          'SCANNEZ POUR NOUS RETROUVER',
          top: 191,
          fontSize: 9,
          font: assets.barlow,
          color: PdfColors.white,
          bold: true,
        ),
        _carnetCenteredText(
          'Carnet ${_safeText(input.reference)} - ${_safeText(input.vehicle.licensePlate)}',
          top: 202,
          fontSize: 7.5,
          font: assets.barlow,
          color: PdfColor.fromHex('#B0B3B7'),
        ),
        _carnetCenteredText(
          'carluxecleaning.com - info@carluxecleaning.be',
          top: 210,
          fontSize: 7.5,
          font: assets.barlow,
          color: PdfColor.fromHex('#B0B3B7'),
        ),
      ],
    );
  }

  pw.Page _page({
    required pw.ImageProvider? logo,
    required String title,
    required String reference,
    required DateTime date,
    required List<pw.Widget> content,
    pw.ImageProvider? footerMark,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(_mm(18), _mm(15), _mm(18), _mm(18)),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.SizedBox(
                  width: _mm(38),
                  height: _mm(24),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(width: _mm(38), height: _mm(24)),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    title,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: title.length > 16 ? 21 : 30,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfBlack,
                    ),
                  ),
                  pw.SizedBox(height: _mm(2)),
                  pw.Text(
                    'Reference : $reference',
                    style: _quoteMuted(size: 8.2),
                  ),
                  pw.SizedBox(height: _mm(1.2)),
                  pw.Text(
                    'Date : ${formatDate(date)}',
                    style: _quoteMuted(size: 8.2),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: _mm(10)),
          pw.Divider(color: _pdfGrey200, thickness: 0.7),
          pw.SizedBox(height: _mm(7)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: content,
          ),
          pw.Spacer(),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _quoteDots(width: _mm(98), columns: 29),
              pw.Spacer(),
              if (footerMark != null) ...[
                pw.Image(
                  footerMark,
                  width: _mm(22),
                  height: _mm(7),
                  fit: pw.BoxFit.contain,
                ),
                pw.SizedBox(width: _mm(8)),
              ],
              _quoteDots(width: _mm(48), columns: 16, fadeLeft: true),
            ],
          ),
          pw.SizedBox(height: _mm(3)),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: _quoteMuted(size: 6.8),
            ),
          ),
          pw.Container(height: 0.7, color: _pdfGrey300),
          pw.SizedBox(height: _mm(2.2)),
          pw.Row(
            children: [
              pw.Text('GSM : $_companyPhone', style: _quoteMuted(size: 7.8)),
              pw.Spacer(),
              pw.Text(
                _companyWebsite,
                style: _quoteText(size: 7.8, bold: true),
              ),
              pw.Spacer(),
              pw.Text(_companyEmail, style: _quoteMuted(size: 7.8)),
            ],
          ),
          pw.SizedBox(height: _mm(1.3)),
          pw.Text(
            '$_companyAddress \u00b7 $_companyPostalCity \u00b7 TVA : $_companyVatNumber',
            textAlign: pw.TextAlign.center,
            style: _quoteMuted(size: 7.2, color: _pdfGrey500),
          ),
        ],
      ),
    );
  }

  Future<pw.ImageProvider?> _loadLogo() async {
    return _loadImageAsset('assets/clc-logo.png');
  }

  Future<pw.ImageProvider?> _loadImageAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _quoteHeader({
    required pw.ImageProvider? logo,
    required QuotePdfInput input,
    required bool continued,
  }) {
    final copy = _quoteCopy(input.language);
    final expiryDate = input.date.add(const Duration(days: 30));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.SizedBox(
                width: _mm(38),
                height: _mm(24),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              )
            else
              pw.SizedBox(width: _mm(38), height: _mm(24)),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  copy.quote,
                  style: pw.TextStyle(
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfBlack,
                  ),
                ),
                pw.SizedBox(height: _mm(2)),
                pw.Text(
                  '${copy.documentNumber} : ${input.reference}',
                  style: _quoteMuted(size: 8.2),
                ),
                pw.SizedBox(height: _mm(1.2)),
                pw.Text(
                  '${copy.date} : ${formatDate(input.date)}',
                  style: _quoteMuted(size: 8.2),
                ),
                if (!continued) ...[
                  pw.SizedBox(height: _mm(1.2)),
                  pw.Text(
                    "Valable jusqu'au : ${formatDate(expiryDate)}",
                    style: _quoteText(size: 7.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _quotePartyAndVehicle(QuotePdfInput input) {
    final copy = _quoteCopy(input.language);
    final party = input.client;
    final vehicle = input.vehicle;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _quoteLabel(copy.client),
              pw.SizedBox(height: _mm(5)),
              pw.Text(
                _safeText(party.name, 'Client'),
                style: _quoteText(size: 10.2, bold: true),
              ),
              if (party.companyName.trim().isNotEmpty)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: _mm(2)),
                  child: pw.Text(
                    party.companyName,
                    style: _quoteMuted(size: 8.2),
                  ),
                ),
              for (final line in [
                party.address,
                party.email,
                if (party.vatNumber.trim().isNotEmpty)
                  'TVA : ${party.vatNumber}',
              ])
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: _mm(2)),
                  child: pw.Text(
                    _safeText(line),
                    style: _quoteMuted(size: 8.2),
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: _mm(20)),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _quoteLabel(copy.vehicle),
              pw.SizedBox(height: _mm(5)),
              pw.Text(
                _safeText('${vehicle.make} ${vehicle.model}'.trim()),
                style: _quoteText(size: 10.2, bold: true),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.only(top: _mm(2)),
                child: pw.Text(
                  'Plaque : ${_safeText(vehicle.licensePlate)}',
                  style: _quoteMuted(size: 8.2),
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.only(top: _mm(2)),
                child: pw.Text(
                  'Taille : ${_safeText(input.vehicleSize)}',
                  style: _quoteMuted(size: 8.2),
                ),
              ),
              if (vehicle.vin.trim().isNotEmpty)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: _mm(2)),
                  child: pw.Text(
                    'VIN : ${vehicle.vin}',
                    style: _quoteMuted(size: 8.2),
                  ),
                ),
              if (vehicle.color.trim().isNotEmpty)
                pw.Padding(
                  padding: pw.EdgeInsets.only(top: _mm(2)),
                  child: pw.Text(
                    'Couleur : ${vehicle.color}',
                    style: _quoteMuted(size: 8.2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _quoteLineItems(
    List<DocumentLineItem> items, {
    required bool applyVat,
    required String language,
  }) {
    return pw.Column(
      children: [
        _quoteTableHeader(applyVat: applyVat, language: language),
        for (var index = 0; index < items.length; index += 1)
          _quoteTableRow(
            item: items[index],
            applyVat: applyVat,
            alternate: index.isEven,
          ),
      ],
    );
  }

  pw.Widget _quoteTableHeader({
    required bool applyVat,
    required String language,
  }) {
    final copy = _quoteCopy(language);
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _quoteCell(copy.service.toUpperCase(), flex: applyVat ? 44 : 52),
            _quoteCell(
              copy.quantity.toUpperCase(),
              flex: 10,
              align: pw.TextAlign.center,
            ),
            _quoteCell(
              copy.unitHTVA.toUpperCase(),
              flex: 17,
              align: pw.TextAlign.right,
            ),
            if (applyVat)
              _quoteCell(
                copy.vat.toUpperCase(),
                flex: 13,
                align: pw.TextAlign.right,
              ),
            _quoteCell(
              (applyVat ? copy.totalTVAC : copy.totalHTVA).toUpperCase(),
              flex: 18,
              align: pw.TextAlign.right,
            ),
          ],
        ),
        pw.SizedBox(height: _mm(2.5)),
        pw.Container(height: 1.2, color: _pdfBlack),
        pw.SizedBox(height: _mm(3.5)),
      ],
    );
  }

  pw.Widget _quoteTableRow({
    required DocumentLineItem item,
    required bool applyVat,
    required bool alternate,
  }) {
    final included = _isIncludedQuoteLine(item.description);
    final hasPrice = item.unitPrice > 0;
    final quantity = item.quantity <= 0 ? 1 : item.quantity;
    final subtotal = item.unitPrice * quantity;
    final vat = applyVat ? subtotal * item.vatRate / 100 : 0.0;
    final total = subtotal + vat;
    final missingPrice = included ? 'Inclus' : 'Prix a definir';
    final priceStyle = hasPrice || included
        ? _quoteText(size: 8)
        : _quoteMuted(size: 8);

    return pw.Container(
      color: alternate ? _pdfGrey100 : PdfColors.white,
      padding: pw.EdgeInsets.symmetric(horizontal: _mm(1), vertical: _mm(2.2)),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: applyVat ? 44 : 52,
                child: pw.Text(
                  _safeText(item.description),
                  style: _quoteText(size: 8),
                ),
              ),
              pw.Expanded(
                flex: 10,
                child: pw.Text(
                  '$quantity',
                  textAlign: pw.TextAlign.center,
                  style: _quoteText(size: 8),
                ),
              ),
              pw.Expanded(
                flex: 17,
                child: pw.Text(
                  hasPrice ? _quoteMoney(item.unitPrice) : missingPrice,
                  textAlign: pw.TextAlign.right,
                  style: priceStyle,
                ),
              ),
              if (applyVat)
                pw.Expanded(
                  flex: 13,
                  child: pw.Text(
                    hasPrice ? _quoteMoney(vat) : missingPrice,
                    textAlign: pw.TextAlign.right,
                    style: priceStyle,
                  ),
                ),
              pw.Expanded(
                flex: 18,
                child: pw.Text(
                  hasPrice
                      ? _quoteMoney(applyVat ? total : subtotal)
                      : missingPrice,
                  textAlign: pw.TextAlign.right,
                  style: hasPrice || included
                      ? _quoteText(size: 8, bold: true)
                      : _quoteMuted(size: 8),
                ),
              ),
            ],
          ),
          if (item.note.trim().isNotEmpty)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: _mm(1.5)),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  item.note,
                  style: pw.TextStyle(
                    fontSize: 7.2,
                    color: _pdfGrey500,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: _mm(1.8)),
          pw.Container(height: 0.55, color: _pdfGrey200),
        ],
      ),
    );
  }

  pw.Widget _quoteCell(
    String value, {
    required int flex,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        value,
        textAlign: align,
        style: _quoteMuted(size: 7, bold: true),
      ),
    );
  }

  pw.Widget _quoteTotals({
    required double subtotal,
    required double vat,
    required double total,
    required bool applyVat,
    required String language,
  }) {
    final copy = _quoteCopy(language);
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: _mm(66),
        child: pw.Column(
          children: [
            pw.Container(height: 0.7, color: _pdfGrey200),
            pw.SizedBox(height: _mm(2.8)),
            if (applyVat) ...[
              _quoteTotalLine(copy.subtotalHTVA, subtotal),
              pw.SizedBox(height: _mm(2.4)),
              _quoteTotalLine(copy.vatTotal, vat),
              pw.SizedBox(height: _mm(2.4)),
              pw.Container(height: 0.6, color: _pdfGrey200),
              pw.SizedBox(height: _mm(3.4)),
              _quoteTotalLine(
                copy.totalTVAC.toUpperCase(),
                total,
                strong: true,
              ),
            ] else
              _quoteTotalLine(
                copy.totalHTVA.toUpperCase(),
                total,
                strong: true,
              ),
            pw.SizedBox(height: _mm(2.2)),
            pw.Container(height: 0.6, color: _pdfGrey300),
          ],
        ),
      ),
    );
  }

  pw.Widget _quoteTotalLine(String label, num value, {bool strong = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: strong
                ? _quoteText(size: 9.2, bold: true)
                : _quoteMuted(size: 8.2),
          ),
        ),
        pw.Text(
          _quoteMoney(value),
          style: strong
              ? _quoteText(size: 13.2, bold: true)
              : _quoteMuted(size: 8.2),
        ),
      ],
    );
  }

  pw.Widget _quoteFooter({
    required pw.Context context,
    required String reference,
    required double amount,
    required bool showQrCode,
  }) {
    return pw.Column(
      children: [
        pw.SizedBox(height: _mm(7)),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (showQrCode) ...[
              pw.BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: _quoteQrData(reference: reference, amount: amount),
                width: _mm(20),
                height: _mm(20),
              ),
              pw.SizedBox(width: _mm(5)),
            ],
            _quoteDots(width: _mm(showQrCode ? 74 : 99), columns: 24),
            pw.Spacer(),
            _quoteDots(width: _mm(48), columns: 16, fadeLeft: true),
          ],
        ),
        pw.SizedBox(height: _mm(3.5)),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: _quoteMuted(size: 6.8),
          ),
        ),
        pw.Container(height: 0.7, color: _pdfGrey300),
        pw.SizedBox(height: _mm(2.2)),
        pw.Row(
          children: [
            pw.Text('GSM : $_companyPhone', style: _quoteMuted(size: 7.8)),
            pw.Spacer(),
            pw.Text(_companyWebsite, style: _quoteText(size: 7.8, bold: true)),
            pw.Spacer(),
            pw.Text(_companyEmail, style: _quoteMuted(size: 7.8)),
          ],
        ),
        pw.SizedBox(height: _mm(1.3)),
        pw.Text(
          '$_companyAddress \u00b7 $_companyPostalCity \u00b7 TVA : $_companyVatNumber',
          textAlign: pw.TextAlign.center,
          style: _quoteMuted(size: 7.2, color: _pdfGrey500),
        ),
      ],
    );
  }

  pw.Widget _quoteDots({
    required double width,
    required int columns,
    bool fadeLeft = false,
  }) {
    return pw.SizedBox(
      width: width,
      child: pw.Wrap(
        spacing: _mm(2.75),
        runSpacing: _mm(2.75),
        children: [
          for (var row = 0; row < 4; row += 1)
            for (var column = 0; column < columns; column += 1)
              pw.Container(
                width: _mm(0.64),
                height: _mm(0.64),
                decoration: pw.BoxDecoration(
                  color:
                      (row == 3 ||
                          (!fadeLeft && column > columns - 8) ||
                          (fadeLeft && column < 3))
                      ? _pdfDotLight
                      : _pdfDot,
                  shape: pw.BoxShape.circle,
                ),
              ),
        ],
      ),
    );
  }

  pw.Widget _partyAndVehicle(DocumentParty party, DocumentVehicle vehicle) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoCard('CLIENT', [
            party.companyName.trim().isNotEmpty
                ? party.companyName
                : party.name,
            if (party.name.trim().isNotEmpty &&
                party.companyName.trim().isNotEmpty)
              party.name,
            party.phone,
            party.email,
            party.address,
            if (party.vatNumber.trim().isNotEmpty) 'TVA ${party.vatNumber}',
          ]),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: _infoCard('VEHICULE', [
            '${vehicle.make} ${vehicle.model}'.trim(),
            if (vehicle.licensePlate.trim().isNotEmpty)
              'Plaque: ${vehicle.licensePlate}',
            if (vehicle.vin.trim().isNotEmpty) 'VIN: ${vehicle.vin}',
            if (vehicle.color.trim().isNotEmpty) 'Couleur: ${vehicle.color}',
            if (vehicle.year.trim().isNotEmpty) 'Annee: ${vehicle.year}',
          ]),
        ),
      ],
    );
  }

  pw.Widget _infoCard(String title, List<String> values) {
    final cleanValues = values
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _sectionTitle),
          pw.SizedBox(height: 8),
          for (final value in cleanValues)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(value, style: _body),
            ),
        ],
      ),
    );
  }

  pw.Widget _lineItems(List<DocumentLineItem> items, {required bool applyVat}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
          children: [
            _tableCell('Service', header: true),
            _tableCell('Qte', header: true),
            _tableCell('Prix HTVA', header: true),
            _tableCell(applyVat ? 'Total TVAC' : 'Total', header: true),
          ],
        ),
        for (final item in items)
          pw.TableRow(
            children: [
              _tableCell(item.description),
              _tableCell('${item.quantity}'),
              _tableCell(formatMoney(item.unitPrice)),
              _tableCell(formatMoney(applyVat ? item.total : item.subtotal)),
            ],
          ),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: pw.Text(text, style: header ? _bold : _body),
    );
  }

  pw.Widget _totalRow(String label, double value, {bool strong = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: strong ? _bold : _body)),
          pw.Text(formatMoney(value), style: strong ? _bold : _body),
        ],
      ),
    );
  }

  pw.Widget _summaryGrid(List<(String, String)> rows) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final row in rows)
          pw.Container(
            width: 238,
            padding: const pw.EdgeInsets.all(14),
            decoration: _boxDecoration(),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(row.$1.toUpperCase(), style: _sectionTitle),
                pw.SizedBox(height: 7),
                pw.Text(row.$2.trim().isEmpty ? '-' : row.$2, style: _bold),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _noteBox(String title, String body) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _sectionTitle),
          pw.SizedBox(height: 7),
          pw.Text(body, style: _body),
        ],
      ),
    );
  }

  pw.Widget _signatures({
    required bool clientRequired,
    required bool companyRequired,
    Uint8List? clientSignatureBytes,
    Uint8List? companySignatureBytes,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _signatureBox(
            'Signature client',
            clientRequired ? 'Obligatoire' : 'Facultative',
            signatureBytes: clientSignatureBytes,
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: _signatureBox(
            'Signature Car Luxe Cleaning',
            companyRequired ? 'Obligatoire' : 'Facultative',
            signatureBytes: companySignatureBytes,
          ),
        ),
      ],
    );
  }

  pw.Widget _signatureBox(
    String title,
    String status, {
    Uint8List? signatureBytes,
  }) {
    final hasSignature = signatureBytes != null && signatureBytes.isNotEmpty;
    return pw.Container(
      height: 104,
      padding: const pw.EdgeInsets.all(12),
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _sectionTitle),
          pw.Spacer(),
          if (hasSignature)
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(signatureBytes),
                height: 42,
                fit: pw.BoxFit.contain,
              ),
            )
          else
            pw.Container(height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text(
            hasSignature ? 'Signature capturée' : status,
            style: _smallMuted,
          ),
        ],
      ),
    );
  }

  pw.Widget _photoGrid(List<DocumentPhoto> photos) {
    final visiblePhotos = photos.take(8).toList();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PHOTOS', style: _sectionTitle),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final photo in visiblePhotos)
                pw.Container(
                  width: 112,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: pw.Image(
                          pw.MemoryImage(photo.bytes),
                          width: 100,
                          height: 72,
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        photo.caption.trim().isEmpty
                            ? photo.fileName
                            : photo.caption,
                        maxLines: 1,
                        style: _smallMuted,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  pw.Widget _qrPaymentBox({
    required String reference,
    required double amount,
    required String label,
  }) {
    final data =
        'Car Luxe Cleaning | $reference | ${amount.toStringAsFixed(2)} EUR';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: data,
            width: 74,
            height: 74,
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label.toUpperCase(), style: _sectionTitle),
                pw.SizedBox(height: 8),
                pw.Text('Communication : $reference', style: _bold),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Montant indicatif : ${formatMoney(amount)}',
                  style: _body,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Le paiement reste à confirmer par Car Luxe Cleaning.',
                  style: _smallMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.BoxDecoration _boxDecoration() {
    return pw.BoxDecoration(
      color: PdfColor.fromHex('#F9FAFB'),
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.7),
    );
  }

  pw.Widget _secretTotal(int total) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 210,
        padding: const pw.EdgeInsets.all(14),
        decoration: _boxDecoration(),
        child: _totalRow('TOTAL', total.toDouble(), strong: true),
      ),
    );
  }
}

class _CarnetAssets {
  const _CarnetAssets({
    required this.cover,
    required this.vehicleBackground,
    required this.historyBackground,
    required this.innerBackground,
    required this.logo,
    required this.stamp,
    required this.footerMark,
    required this.barlow,
    required this.serif,
  });

  final pw.ImageProvider? cover;
  final pw.ImageProvider? vehicleBackground;
  final pw.ImageProvider? historyBackground;
  final pw.ImageProvider? innerBackground;
  final pw.ImageProvider? logo;
  final pw.ImageProvider? stamp;
  final pw.ImageProvider? footerMark;
  final pw.Font? barlow;
  final pw.Font? serif;
}

double _mm(double value) => value * PdfPageFormat.mm;

String _safeText(String value, [String fallback = '-']) {
  final text = value.trim();
  return text.isEmpty ? fallback : text;
}

String _vehicleYearText(String value) {
  final match = RegExp(r'\b(?:19|20)\d{2}\b').firstMatch(value);
  return match?.group(0) ?? _safeText(value);
}

final _lime = PdfColor.fromHex('#AFF700');
final _pdfBlack = PdfColor.fromHex('#181818');
final _pdfGrey700 = PdfColor.fromHex('#5A5A5A');
final _pdfGrey500 = PdfColor.fromHex('#919191');
final _pdfGrey300 = PdfColor.fromHex('#D6D6D6');
final _pdfGrey200 = PdfColor.fromHex('#E8E8E8');
final _pdfGrey100 = PdfColor.fromHex('#F7F7F7');
final _pdfDot = PdfColor.fromHex('#BEBEBE');
final _pdfDotLight = PdfColor.fromHex('#E4E4E4');

const _companyLegalName = 'CAR LUXE CLEANING';
const _companyAddress = 'Chauss\u00e9e de Jette 366';
const _companyPostalCity = '1081 Koekelberg';
const _companyPhone = '0471 36 56 54';
const _companyIban = 'BE94 0636 1191 2714';
const _companyEmail = 'contact@carluxecleaning.com';
const _companyWebsite = 'www.carluxecleaning.com';
const _companyVatNumber = 'BE 0803.842.166';

({
  String quote,
  String date,
  String documentNumber,
  String client,
  String vehicle,
  String service,
  String quantity,
  String unitHTVA,
  String vat,
  String totalHTVA,
  String totalTVAC,
  String subtotalHTVA,
  String vatTotal,
})
_quoteCopy(String language) {
  switch (language.toUpperCase()) {
    case 'EN':
      return (
        quote: 'QUOTE',
        date: 'Date',
        documentNumber: 'Quote number',
        client: 'Client',
        vehicle: 'Vehicle',
        service: 'Service',
        quantity: 'Qty',
        unitHTVA: 'Unit price',
        vat: 'VAT',
        totalHTVA: 'Total excl. VAT',
        totalTVAC: 'Total incl. VAT',
        subtotalHTVA: 'Subtotal excl. VAT',
        vatTotal: 'VAT 21%',
      );
    case 'NL':
      return (
        quote: 'OFFERTE',
        date: 'Datum',
        documentNumber: 'Offertenummer',
        client: 'Klant',
        vehicle: 'Voertuig',
        service: 'Dienst',
        quantity: 'Aantal',
        unitHTVA: 'Prijs excl. btw',
        vat: 'Btw',
        totalHTVA: 'Totaal excl. btw',
        totalTVAC: 'Totaal incl. btw',
        subtotalHTVA: 'Subtotaal excl. btw',
        vatTotal: 'Btw 21%',
      );
    default:
      return (
        quote: 'DEVIS',
        date: 'Date',
        documentNumber: 'Numero de devis',
        client: 'Client',
        vehicle: 'Vehicule',
        service: 'Service',
        quantity: 'Qte',
        unitHTVA: 'Prix HTVA',
        vat: 'TVA',
        totalHTVA: 'Total HTVA',
        totalTVAC: 'Total TVAC',
        subtotalHTVA: 'Sous-total HTVA',
        vatTotal: 'TVA 21%',
      );
  }
}

pw.TextStyle _quoteText({
  required double size,
  bool bold = false,
  PdfColor? color,
}) {
  return pw.TextStyle(
    fontSize: size,
    color: color ?? _pdfBlack,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
}

pw.TextStyle _quoteMuted({
  required double size,
  bool bold = false,
  PdfColor? color,
}) {
  return pw.TextStyle(
    fontSize: size,
    color: color ?? _pdfGrey700,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
}

pw.Widget _quoteLabel(String value) {
  return pw.Text(
    value.toUpperCase(),
    style: _quoteMuted(size: 6.8, bold: true, color: _pdfGrey500),
  );
}

String _quoteMoney(num value) {
  final formatted = (value.isFinite ? value : 0).toStringAsFixed(2);
  return '${formatted.replaceAll('.', ',')} \u20AC';
}

bool _isIncludedQuoteLine(String value) =>
    value.trim().toLowerCase().startsWith('inclus');

String _quoteQrData({required String reference, required double amount}) {
  final iban = _companyIban.replaceAll(' ', '');
  return 'BCD\n002\n1\nSCT\n\n$_companyLegalName\n$iban\nEUR${amount.toStringAsFixed(2)}\n\n\n$reference';
}

const _carnetLegalSections = [
  (
    '1. Limitation de responsabilite',
    "Le present carnet d'entretien esthetique constitue un releve des prestations effectuees par Car Luxe Cleaning. Il ne remplace pas un controle mecanique, une expertise ou un certificat general du vehicule.",
  ),
  (
    '2. Garantie des prestations',
    "La durabilite des traitements depend de l'utilisation du vehicule, des methodes de lavage, des produits utilises et des conditions de stockage. Un entretien regulier et adapte reste recommande.",
  ),
  (
    '3. Validite des informations',
    "Les informations consignees sont etablies au moment de l'intervention. Le client est invite a verifier les donnees et a signaler toute correction necessaire au centre Car Luxe Cleaning.",
  ),
  (
    '4. Propriete intellectuelle',
    "Les textes, logos, graphismes, images et mises en page de ce carnet sont proteges. Toute reproduction ou diffusion sans autorisation ecrite prealable est interdite.",
  ),
  (
    '5. Protection des donnees personnelles',
    "Les informations personnelles recueillies sont confidentielles et destinees au suivi des services rendus. Toute demande peut etre adressee a info@carluxecleaning.be.",
  ),
  (
    '6. Conditions generales de vente',
    "Les prestations restent soumises aux conditions generales de vente en vigueur a la date de l'intervention. Ce carnet constitue un historique de services et ne remplace ni devis ni facture.",
  ),
];

final _body = pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#111827'));
final _bold = pw.TextStyle(
  fontSize: 11,
  color: PdfColor.fromHex('#111827'),
  fontWeight: pw.FontWeight.bold,
);
final _sectionTitle = pw.TextStyle(
  fontSize: 8,
  color: PdfColor.fromHex('#71717A'),
  fontWeight: pw.FontWeight.bold,
  letterSpacing: 2,
);
final _smallMuted = pw.TextStyle(
  fontSize: 8,
  color: PdfColor.fromHex('#71717A'),
);
