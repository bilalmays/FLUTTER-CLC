import 'package:car_luxe_cleaning_flutter/features/assistant/presentation/assistant_page.dart';
import 'package:car_luxe_cleaning_flutter/features/basket/presentation/basket_composer_page.dart';
import 'package:car_luxe_cleaning_flutter/features/clients/presentation/clients_page.dart';
import 'package:car_luxe_cleaning_flutter/features/dashboard/presentation/dashboard_page.dart';
import 'package:car_luxe_cleaning_flutter/features/documents/presentation/documents_page.dart';
import 'package:car_luxe_cleaning_flutter/features/packages/presentation/packages_page.dart';
import 'package:car_luxe_cleaning_flutter/features/secret_document/presentation/secret_document_page.dart';
import 'package:car_luxe_cleaning_flutter/features/settings/presentation/settings_page.dart';
import 'package:car_luxe_cleaning_flutter/features/subscriptions/presentation/subscriptions_page.dart';
import 'package:car_luxe_cleaning_flutter/features/trash/presentation/trash_page.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/basket',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/basket'),
    GoRoute(
      path: '/basket',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/basket', child: BasketComposerPage()),
      ),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/dashboard', child: DashboardPage()),
      ),
    ),
    GoRoute(
      path: '/subscriptions',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(
          currentPath: '/subscriptions',
          child: SubscriptionsPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/documents',
      pageBuilder: (context, state) => _page(
        state,
        AppScaffold(
          currentPath: '/documents',
          child: DocumentsPage(
            initialModuleId: state.uri.queryParameters['module'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/packages',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/packages', child: PackagesPage()),
      ),
    ),
    GoRoute(
      path: '/clients',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/clients', child: ClientsPage()),
      ),
    ),
    GoRoute(
      path: '/assistant',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/assistant', child: AssistantPage()),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/settings', child: SettingsPage()),
      ),
    ),
    GoRoute(
      path: '/secret-document',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(
          currentPath: '/secret-document',
          child: SecretDocumentPage(),
        ),
      ),
    ),
    GoRoute(
      path: '/trash',
      pageBuilder: (context, state) => _page(
        state,
        const AppScaffold(currentPath: '/trash', child: TrashPage()),
      ),
    ),
  ],
);

Page<void> _page(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}
