import 'package:car_luxe_cleaning_flutter/app/theme.dart';
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
    final colors = ClcThemeColors.of(context);
    final title = _activeModule?.label ?? 'Documents';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_activeModule != null) ...[
                TextButton.icon(
                  onPressed: () => setState(() => _activeModule = null),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 14,
                    color: colors.muted,
                  ),
                  label: Text(
                    'RETOUR',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: isMobile ? 36 : 48,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 26 : 38),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _activeModule == null
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 896),
                      child: _DocumentModuleGrid(
                        onOpen: (module) =>
                            setState(() => _activeModule = module),
                      ),
                    ),
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

class _DocumentModuleGrid extends StatelessWidget {
  const _DocumentModuleGrid({required this.onOpen});

  final ValueChanged<DocumentModule> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('document-grid'),
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 720 ? 1 : 2;
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
    final colors = ClcThemeColors.of(context);

    return AppCard(
      onTap: onTap,
      color: colors.isLight ? colors.surface : colors.shell,
      borderColor: colors.isLight ? colors.borderStrong : colors.border,
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 3,
                color: colors.isLight
                    ? colors.borderStrong
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.isLight ? colors.surface : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.isLight
                            ? colors.borderStrong
                            : colors.border,
                      ),
                    ),
                    child: Icon(
                      module.icon,
                      color: colors.isLight ? colors.mutedStrong : colors.muted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    module.label.toUpperCase(),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    module.note,
                    style: TextStyle(
                      color: colors.isLight ? colors.textStrong : colors.muted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
