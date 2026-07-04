import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_card.dart';
import 'package:car_luxe_cleaning_flutter/features/documents/domain/document_module.dart';
import 'package:car_luxe_cleaning_flutter/features/documents/presentation/document_builders.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({this.initialModuleId, super.key});

  final String? initialModuleId;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  DocumentModule? _activeModule;

  @override
  void initState() {
    super.initState();
    _activeModule = _moduleFromInitialId(widget.initialModuleId);
  }

  @override
  void didUpdateWidget(covariant DocumentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialModuleId != widget.initialModuleId) {
      _activeModule = _moduleFromInitialId(widget.initialModuleId);
    }
  }

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
            child: _DocumentsHeader(
              eyebrow: _activeModule == null ? 'Documents' : 'Module document',
              title: _activeModule?.label ?? 'Documents',
              subtitle:
                  _activeModule?.note ??
                  'Devis, carnets, acomptes, etats des lieux, service pick-up et historique.',
              trailing: _activeModule == null
                  ? null
                  : AppButton(
                      label: 'Retour',
                      icon: Icons.arrow_back_rounded,
                      tone: AppButtonTone.secondary,
                      onPressed: () => setState(() => _activeModule = null),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _activeModule == null
                ? _DocumentModuleGrid(
                    onOpen: (module) => setState(() => _activeModule = module),
                  )
                : _DocumentModuleView(module: _activeModule!),
          ),
        ],
      ),
    );
  }
}

DocumentModule? _moduleFromInitialId(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final module in documentModules) {
    if (module.id.name == id) return module;
  }
  return null;
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: 0.95,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFA1A1AA),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (trailing == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 18),
        trailing!,
      ],
    );
  }
}

class _DocumentModuleGrid extends StatelessWidget {
  const _DocumentModuleGrid({required this.onOpen});

  final ValueChanged<DocumentModule> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('document-grid'),
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720
            ? 1
            : constraints.maxWidth < 1080
            ? 2
            : 3;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final module in documentModules)
              SizedBox(
                width: width,
                child: _DocumentModuleCard(
                  module: module,
                  onTap: () => onOpen(module),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DocumentModuleCard extends StatelessWidget {
  const _DocumentModuleCard({required this.module, required this.onTap});

  final DocumentModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: const Color(0xFF050505),
      borderColor: const Color(0x1AFFFFFF),
      padding: const EdgeInsets.all(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 178),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(module.icon, color: AppColors.accent),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF71717A),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              module.label.toUpperCase(),
              style: AppTextStyles.cardTitle.copyWith(
                color: Colors.white,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              module.note,
              style: AppTextStyles.body.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentModuleView extends StatelessWidget {
  const _DocumentModuleView({required this.module});

  final DocumentModule module;

  @override
  Widget build(BuildContext context) {
    return switch (module.id) {
      DocumentModuleId.devis => const DevisDocumentBuilder(),
      DocumentModuleId.carnet => const CarnetDocumentBuilder(),
      DocumentModuleId.acompte => const DepositDocumentBuilder(),
      DocumentModuleId.etat => const EtatDocumentBuilder(),
      DocumentModuleId.pickup => const PickupDocumentBuilder(),
      DocumentModuleId.historique => const DocumentsHistoryBuilder(),
    };
  }
}
