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

  bool get isAdmin => session.isAdmin;

  static AuthScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>();
  }

  static AuthScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AuthScope is missing from the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) {
    return session != oldWidget.session || logout != oldWidget.logout;
  }
}
