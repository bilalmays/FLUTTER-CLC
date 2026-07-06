import 'package:flutter/widgets.dart';

enum AppBreakpoint { mobile, tablet, wide }

class Responsive {
  const Responsive._();

  static AppBreakpoint breakpointOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return AppBreakpoint.mobile;
    if (width <= 1024) return AppBreakpoint.tablet;
    return AppBreakpoint.wide;
  }

  static bool isMobile(BuildContext context) =>
      breakpointOf(context) == AppBreakpoint.mobile;
  static bool isTablet(BuildContext context) =>
      breakpointOf(context) == AppBreakpoint.tablet;
  static bool isWide(BuildContext context) =>
      breakpointOf(context) == AppBreakpoint.wide;

  static double pagePadding(BuildContext context) {
    switch (breakpointOf(context)) {
      case AppBreakpoint.mobile:
        return 16;
      case AppBreakpoint.tablet:
        return 24;
      case AppBreakpoint.wide:
        return 40;
    }
  }
}
