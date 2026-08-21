import 'package:flutter_test/flutter_test.dart';
import 'package:grades/database_helper.dart';

void main() {
  group('Grade.isIdoneita Tests', () {
    Grade makeGrade({String? note, double grade = 30.0}) {
      return Grade(
        subjectName: 'TEST',
        grade: grade,
        date: 20260101,
        weight: 1.0,
        type: 'esame',
        note: note,
      );
    }

    test('isIdoneita is true when note contains "Idoneità"', () {
      final g = makeGrade(note: 'Idoneità');
      expect(g.isIdoneita, true);
    });

    test('isIdoneita is true when note starts with "Idoneità - extra text"', () {
      final g = makeGrade(note: 'Idoneità - Lingua Inglese B2');
      expect(g.isIdoneita, true);
    });

    test('isIdoneita is true when note contains "idoneita" (no accent)', () {
      final g = makeGrade(note: 'idoneita');
      expect(g.isIdoneita, true);
    });

    test('isIdoneita is true when note contains "approvato"', () {
      final g = makeGrade(note: 'approvato');
      expect(g.isIdoneita, true);
    });

    test('isIdoneita is false for a normal 30L note', () {
      final g = makeGrade(note: '30L');
      expect(g.isIdoneita, false);
    });

    test('isIdoneita is false for a normal numeric grade with no note', () {
      final g = makeGrade(note: null, grade: 28.0);
      expect(g.isIdoneita, false);
    });

    test('isIdoneita is false for a regular note text', () {
      final g = makeGrade(note: 'Ottimo professore', grade: 25.0);
      expect(g.isIdoneita, false);
    });

    test('isIdoneita is false when note is empty string', () {
      final g = makeGrade(note: '', grade: 27.0);
      expect(g.isIdoneita, false);
    });
  });

  group('Idoneità exclusion from numeric statistics', () {
    // Verifica la logica di esclusione delle idoneità dal calcolo della media

    test('Idoneità grade should NOT contribute to weighted average', () {
      // Simula il loop in returnWeightedAverage
      final grades = [
        Grade(subjectName: 'MATH', grade: 28.0, date: 20260101, weight: 1.0, type: 'esame', note: null),
        Grade(subjectName: 'ENG', grade: 30.0, date: 20260101, weight: 1.0, type: 'esame', note: 'Idoneità'),
      ];

      double sum = 0;
      double wSum = 0;
      for (var g in grades) {
        // Replica la logica di returnWeightedAverage
        if (g.weight > 0 && !g.isIdoneita) {
          sum += g.grade * g.weight;
          wSum += g.weight;
        }
      }

      // Solo MATH (28.0) contribuisce; ENG Idoneità è esclusa
      expect(wSum, 1.0);
      expect(sum / wSum, 28.0);
    });

    test('Idoneità grade SHOULD count as acquired CFU', () {
      final grades = [
        Grade(subjectName: 'ENG', grade: 30.0, date: 20260101, weight: 1.0, type: 'esame', note: 'Idoneità'),
      ];

      // Replica la logica di returnAcquiredCfu
      final counts = grades.any((g) => g.isIdoneita || g.grade >= 18);
      expect(counts, true);
    });

    test('Idoneità grade should NOT appear in grade distribution', () {
      final grades = [
        Grade(subjectName: 'MATH', grade: 28.0, date: 20260101, weight: 1.0, type: 'esame', note: null),
        Grade(subjectName: 'ENG', grade: 30.0, date: 20260101, weight: 1.0, type: 'esame', note: 'Idoneità'),
      ];

      Map<String, int> distribution = {for (var i = 18; i <= 30; i++) '$i': 0, '30L': 0};

      for (var g in grades) {
        // Replica la logica di getUniversityGradeDistribution
        if (!g.isIdoneita && g.grade >= 18) {
          final isLode = g.grade >= 30 && (g.note?.toLowerCase().contains('lode') ?? false);
          if (isLode) {
            distribution['30L'] = (distribution['30L'] ?? 0) + 1;
          } else {
            final key = g.grade.floor().toString();
            if (distribution.containsKey(key)) {
              distribution[key] = (distribution[key] ?? 0) + 1;
            }
          }
        }
      }

      // Solo MATH 28 compare nel grafico; English Idoneità è esclusa
      expect(distribution['28'], 1);
      expect(distribution['30'], 0);
      expect(distribution['30L'], 0);
    });
  });
}
