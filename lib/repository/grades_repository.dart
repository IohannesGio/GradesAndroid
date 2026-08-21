import 'package:flutter/foundation.dart';
import '../database_helper.dart';

/// A simple repository that wraps `DatabaseHelper` and exposes data via `ChangeNotifier`.
class GradesRepository extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Cached data
  List<String> _subjects = [];
  List<dynamic> _grades = [];

  List<String> get subjects => List.unmodifiable(_subjects);
  List<dynamic> get grades => List.unmodifiable(_grades);

  /// Load subjects from the database.
  Future<void> loadSubjects() async {
    try {
      final subjectsWithObjectives = await _dbHelper.listSubjects();
      _subjects = subjectsWithObjectives.map((e) => e.$1).toList();
      notifyListeners();
    } catch (e) {
      // In a real app you might surface this via UI
      if (kDebugMode) print('Error loading subjects: $e');
    }
  }

  /// Load grades for a given subject.
  Future<void> loadGrades(String subject) async {
    try {
      _grades = await _dbHelper.listGrades(subject);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading grades for $subject: $e');
    }
  }

  /// Add a new subject and refresh the list.
  Future<void> addSubject(String name) async {
    await _dbHelper.addSubject(name);
    await loadSubjects();
  }

  /// Add a new grade and refresh the list for the subject.
  Future<void> addGrade(String subject, double grade, int date, double weight, String type) async {
    await _dbHelper.addGrade(subject, grade, date, weight, type);
    await loadGrades(subject);
  }

  // Additional wrapper methods can be added as needed.
}
