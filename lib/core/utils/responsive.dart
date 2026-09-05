import 'package:flutter/material.dart';

class Responsive {
  static const double _desktop = 1400;
  static const double _laptop  = 1100;
  static const double _tablet  = 800;

  static double width(BuildContext context) => MediaQuery.of(context).size.width;

  static bool isCompact(BuildContext context) => width(context) < _tablet;
  static bool isTablet(BuildContext context)  => width(context) < _laptop;
  static bool isLaptop(BuildContext context)  => width(context) >= _laptop && width(context) < _desktop;
  static bool isDesktop(BuildContext context) => width(context) >= _desktop;

  // Sidebar collapses to icon-rail between tablet and laptop breakpoints
  static bool collapsedSidebar(BuildContext context) => width(context) < _laptop;

  // Number of stat card columns
  static int statColumns(BuildContext context) {
    final w = width(context);
    if (w >= _desktop) return 6;
    if (w >= _laptop)  return 3;
    if (w >= _tablet)  return 2;
    return 1;
  }
}
