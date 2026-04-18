import 'package:flutter/widgets.dart';

/// Responsive scaling utilities for SmartDesk.
///
/// All helpers are relative to a **design reference width of 392 dp**
/// (≈ Pixel 9 Pro XL / 1080 px physical).
///
/// On narrower screens (e.g. 720×1600 → ~360 dp) values scale down
/// proportionally.  On wider screens they scale up slightly.
///
/// Usage:
///   Padding(padding: EdgeInsets.all(rw(context, 16)))
///   Text('Hello', style: TextStyle(fontSize: rw(context, 14)))
class Responsive {
  Responsive._();

  /// Design reference logical width (dp).
  static const double _referenceWidth = 392.0;

  /// Design reference logical height (dp).
  static const double _referenceHeight = 852.0;

  /// Scale [value] relative to the reference **width**.
  /// Best for: font sizes, horizontal padding, icon sizes, border radii.
  static double w(BuildContext context, double value) {
    final screenWidth = MediaQuery.of(context).size.width;
    return value * (screenWidth / _referenceWidth);
  }

  /// Scale [value] relative to the reference **height**.
  /// Best for: vertical padding, spacer heights, fixed-height containers.
  static double h(BuildContext context, double value) {
    final screenHeight = MediaQuery.of(context).size.height;
    return value * (screenHeight / _referenceHeight);
  }

  /// Whether the screen is compact (< 370 dp logical width).
  static bool isCompact(BuildContext context) {
    return MediaQuery.of(context).size.width < 370;
  }

  /// The current logical width of the screen.
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
}

// ── Shorthand top-level functions ──────────────────────────────────────────────

/// Scale [value] relative to design reference width (392 dp).
double rw(BuildContext context, double value) => Responsive.w(context, value);

/// Scale [value] relative to design reference height (852 dp).
double rh(BuildContext context, double value) => Responsive.h(context, value);

/// Scale [value] for icons (alias for [rw]).
double ri(BuildContext context, double value) => Responsive.w(context, value);
