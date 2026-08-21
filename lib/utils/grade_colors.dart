import 'package:flutter/material.dart';

/// Helper statico per i colori dei voti, usato in tutta l'app.
/// Evita la duplicazione di getColorForValue/getTextColorForBackground
/// in home_page, subject_detail_page, stats_page.
class GradeColors {
  GradeColors._();

  /// Colore di sfondo per un badge voto.
  /// Accetta stringhe numeriche (es. "28.5"), "Idon.", "30L", o "N/A".
  static Color background(String value, {double passingGrade = 18.0}) {
    if (value == 'Idon.') return Colors.blue.withValues(alpha: 0.15);
    final val = double.tryParse(value);
    if (val == null) return Colors.grey.withValues(alpha: 0.2);
    return val >= passingGrade
        ? Colors.green.withValues(alpha: 0.2)
        : Colors.red.withValues(alpha: 0.2);
  }

  /// Colore testo per un badge voto.
  static Color foreground(String value, {double passingGrade = 18.0}) {
    if (value == 'Idon.') return Colors.blue;
    final val = double.tryParse(value);
    if (val == null) return Colors.grey;
    return val >= passingGrade ? Colors.green : Colors.red;
  }

  /// Colore per la lode (30L).
  static Color get lode => Colors.amber[800]!;
}
