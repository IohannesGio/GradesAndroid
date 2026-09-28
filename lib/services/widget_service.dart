import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.school.grades/widget');

  /// Aggiorna i dati del widget per la schermata home di Android
  static Future<void> updateNextExamWidget() async {
    try {
      final dbHelper = DatabaseHelper();
      final fullSubjects = await dbHelper.listSubjectsFull();
      final today = DateTime.now();

      Subject? nextExam;
      int minDaysDiff = 999999;
      String countdownText = '';
      String formattedDateText = '';

      for (var s in fullSubjects) {
        if (s.examDate == null) continue;

        // Verifica se l'esame è già stato verbalizzato / superato
        final grades = await dbHelper.listGrades(s.subjectName);
        final isPassed = grades.any((g) => g.isIdoneita || g.grade >= 18);
        if (isPassed) continue;

        final dateInt = s.examDate!;
        final year = dateInt ~/ 10000;
        final month = (dateInt ~/ 100) % 100;
        final day = dateInt % 100;
        final examDateTime = DateTime(year, month, day);

        final diffInDays = examDateTime.difference(DateTime(today.year, today.month, today.day)).inDays;

        if (diffInDays >= 0 && diffInDays < minDaysDiff) {
          minDaysDiff = diffInDays;
          nextExam = s;
          if (diffInDays == 0) {
            countdownText = 'OGGI!';
          } else if (diffInDays == 1) {
            countdownText = 'DOMANI';
          } else {
            countdownText = '$diffInDays GIORNI';
          }
          formattedDateText = DateFormat('d MMM yyyy', 'it_IT').format(examDateTime);
        }
      }

      final prefs = await SharedPreferences.getInstance();

      if (nextExam != null) {
        await prefs.setString('widget_exam_name', nextExam.subjectName);
        await prefs.setString('widget_exam_days', countdownText);
        await prefs.setString('widget_exam_date', formattedDateText);
        await prefs.setString('widget_exam_cfu', '${nextExam.cfu}');
      } else {
        await prefs.remove('widget_exam_name');
        await prefs.remove('widget_exam_days');
        await prefs.remove('widget_exam_date');
        await prefs.remove('widget_exam_cfu');
      }

      // Notifica l'AppWidgetManager su Android
      if (Platform.isAndroid) {
        await _channel.invokeMethod('updateWidget');
      }
    } catch (e) {
      print('Errore durante l\'aggiornamento del widget: $e');
    }
  }
}
