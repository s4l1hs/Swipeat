import 'package:flutter/material.dart';

extension ColorUtils on Color {
  /// Safe alternative to `.withOpacity()` that avoids the deprecation warning.
  /// It preserves RGB channels and sets the alpha via `fromARGB` using an
  /// integer alpha value (0-255).
  Color withOpacitySafe(double opacity) {
    final o = (opacity.clamp(0.0, 1.0) * 255).round();
  final v = toARGB32();
  final r = (v >> 16) & 0xFF;
  final g = (v >> 8) & 0xFF;
  final b = v & 0xFF;
    return Color.fromARGB(o, r, g, b);
  }
}
