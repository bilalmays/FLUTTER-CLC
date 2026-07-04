import 'dart:convert';
import 'dart:typed_data';

import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_scope.dart';
import 'package:file_picker/file_picker.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _backupPrefixes = ['car_luxe_cleaning.'];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            color: const Color(0xFF050505),
            borderColor: const Color(0x1AFFFFFF),
            padding: EdgeInsets.all(isMobile ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'CONTROL PANEL // BASE SETTINGS',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Reglages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Parametres visuels, contenus documentaires, integrations et maintenance.',
                  style: TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SettingsSection(
            icon: Icons.palette_outlined,
            title: 'Apparence',
            children: [
              _SettingsRow(
                label: 'Theme actif',
                value: 'Premium dark / #050505',
              ),
              _SettingsRow(label: 'Accent', value: '#AFF700'),
              _SettingsRow(label: 'Interface', value: 'iPad optimized'),
            ],
          ),
          const SizedBox(height: 14),
          const _SettingsSection(
            icon: Icons.description_outlined,
            title: 'Documents',
            children: [
              _SettingsRow(label: 'Logo PDF', value: 'assets/clc-logo.png'),
              _SettingsRow(
                label: 'Carnet',
                value: 'Templates officiels embarques',
              ),
              _SettingsRow(
                label: 'PDFs',
                value: 'Devis, acompte, pick-up, carnet, etat des lieux',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            icon: Icons.storage_outlined,
            title: 'Donnees',
            children: [
              const _SettingsRow(
                label: 'Stockage',
                value: 'Local + repositories Flutter',
              ),
              const _SettingsRow(
                label: 'Catalogue vehicules',
                value: 'vehicle-brands.json / vehicle-models.json',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppButton(
                    label: 'Exporter backup',
                    icon: Icons.file_download_outlined,
                    tone: AppButtonTone.secondary,
                    onPressed: () => _exportBackup(context),
                  ),
                  AppButton(
                    label: 'Importer backup',
                    icon: Icons.upload_file_outlined,
                    tone: AppButtonTone.secondary,
                    onPressed: () => _importBackup(context),
                  ),
                  AppButton(
                    label: 'Catalogue services',
                    icon: Icons.sell_outlined,
                    tone: AppButtonTone.secondary,
                    onPressed: () => context.go('/packages'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsSection(
            icon: Icons.logout_rounded,
            title: 'Session',
            children: [
              const _SettingsRow(label: 'Utilisateur', value: 'Interne'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Deconnectez-vous de la session actuelle.',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.10),
                      foregroundColor: const Color(0xFFF87171),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.25),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    onPressed: () => AuthScope.of(context).logout(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('DECONNEXION'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storage = <String, String>{};
      for (final key in preferences.getKeys()) {
        final isClcKey = _backupPrefixes.any(
          (prefix) => key.startsWith(prefix),
        );
        if (!isClcKey) continue;
        final value = preferences.getString(key);
        if (value != null) storage[key] = value;
      }

      final payload = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'storage': storage,
      };
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter backup Car Luxe Cleaning',
        fileName: 'car-luxe-cleaning-backup.json',
        bytes: bytes,
      );
      if (context.mounted) {
        _showSnack(context, 'Backup exporte.');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Export backup impossible.');
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null) return;

      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup');
      }
      final storage = decoded['storage'];
      if (storage is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup storage');
      }

      final preferences = await SharedPreferences.getInstance();
      var imported = 0;
      for (final entry in storage.entries) {
        final key = entry.key;
        final value = entry.value;
        final isClcKey = _backupPrefixes.any(
          (prefix) => key.startsWith(prefix),
        );
        if (!isClcKey || value is! String) continue;
        await preferences.setString(key, value);
        imported += 1;
      }

      if (context.mounted) {
        _showSnack(
          context,
          '$imported entree${imported > 1 ? 's' : ''} importee${imported > 1 ? 's' : ''}. Redemarre la vue si necessaire.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Import backup impossible.');
      }
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFF050505),
      borderColor: const Color(0x1AFFFFFF),
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          leading: Icon(icon, color: AppColors.accent, size: 18),
          iconColor: AppColors.accent,
          collapsedIconColor: Colors.white54,
          title: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
