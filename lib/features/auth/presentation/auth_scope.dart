import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:flutter/widgets.dart';

class AuthScope extends InheritedWidget {
  const AuthScope({
    required this.session,
    required this.logout,
    required super.child,
    super.key,
  });

  final AuthSession session;
  final Future<void> Function() logout;

  static AuthScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing from the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) {
    return session != oldWidget.session || logout != oldWidget.logout;
  }
}
