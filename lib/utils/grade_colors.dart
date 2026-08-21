import 'package:flutter/material.dart';

/// Helper statico per i colori dei voti e delle card, usato in tutta l'app.
class GradeColors {
  GradeColors._();

  /// Colore di sfondo per un badge voto o stat card.
  static Color background(String value, {required double passingGrade}) {
    if (value == 'Idon.') return Colors.blue.withValues(alpha: 0.15);
    final cleanVal = value.replaceAll(' CFU', '').split('/').first.trim();
    final val = double.tryParse(cleanVal);
    if (val == null) return Colors.grey.withValues(alpha: 0.2);
    return val >= passingGrade
        ? Colors.green.withValues(alpha: 0.2)
        : Colors.red.withValues(alpha: 0.2);
  }

  /// Colore testo per un badge voto o stat card.
  static Color foreground(String value, {required double passingGrade}) {
    if (value == 'Idon.') return Colors.blue;
    final cleanVal = value.replaceAll(' CFU', '').split('/').first.trim();
    final val = double.tryParse(cleanVal);
    if (val == null) return Colors.grey;
    return val >= passingGrade ? Colors.green : Colors.red;
  }

  /// Colore per la lode (30L).
  static Color get lode => Colors.amber[800]!;

  /// Colori per card statistiche neutre/speciali (es. CFU, Obiettivo)
  static Color get cfuBackground => Colors.blue.withValues(alpha: 0.2);
  static Color get cfuForeground => Colors.blue;
}
