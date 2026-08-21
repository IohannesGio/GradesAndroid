import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';

enum EducationMode {
  school,
  university,
}

class EducationModeProvider extends ChangeNotifier {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyEducationMode = 'education_mode';
  static const String _keyTargetCfu = 'target_cfu';
  static const String _keyPassingGrade = 'passing_grade';
  static const String _keyMaxGrade = 'max_grade';

  EducationMode _mode = EducationMode.school;
  bool _isOnboardingCompleted = false;
  bool _isLoading = true;
  int _targetCfu = 180;
  double _passingGrade = 6.0;
  double _maxGrade = 10.0;

  EducationMode get mode => _mode;
  bool get isSchool => _mode == EducationMode.school;
  bool get isUniversity => _mode == EducationMode.university;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isLoading => _isLoading;
  int get targetCfu => _targetCfu;
  double get passingGrade => _passingGrade;
  double get maxGrade => _maxGrade;

  EducationModeProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _isOnboardingCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;
    
    final modeStr = prefs.getString(_keyEducationMode) ?? 'school';
    _mode = modeStr == 'university' ? EducationMode.university : EducationMode.school;

    _targetCfu = prefs.getInt(_keyTargetCfu) ?? 180;

    if (_mode == EducationMode.university) {
      _passingGrade = prefs.getDouble(_keyPassingGrade) ?? 18.0;
      _maxGrade = prefs.getDouble(_keyMaxGrade) ?? 30.0;
    } else {
      _passingGrade = prefs.getDouble(_keyPassingGrade) ?? 6.0;
      _maxGrade = prefs.getDouble(_keyMaxGrade) ?? 10.0;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required EducationMode mode,
    double? passingGrade,
    double? maxGrade,
    int? targetCfu,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    _mode = mode;
    _isOnboardingCompleted = true;
    _targetCfu = targetCfu ?? (mode == EducationMode.university ? 180 : 0);

    if (mode == EducationMode.university) {
      _passingGrade = passingGrade ?? 18.0;
      _maxGrade = maxGrade ?? 30.0;
    } else {
      _passingGrade = passingGrade ?? 6.0;
      _maxGrade = maxGrade ?? 10.0;
    }

    await prefs.setBool(_keyOnboardingCompleted, true);
    await prefs.setString(_keyEducationMode, mode == EducationMode.university ? 'university' : 'school');
    await prefs.setInt(_keyTargetCfu, _targetCfu);
    await prefs.setDouble(_keyPassingGrade, _passingGrade);
    await prefs.setDouble(_keyMaxGrade, _maxGrade);

    notifyListeners();
  }

  /// Changes the mode, clears database data as per requirements, and optionally restarts onboarding.
  Future<void> setEducationMode(EducationMode newMode, {required bool resetData}) async {
    if (resetData) {
      await DatabaseHelper().clearAllData();
    }

    final prefs = await SharedPreferences.getInstance();
    _mode = newMode;

    if (newMode == EducationMode.university) {
      _passingGrade = 18.0;
      _maxGrade = 30.0;
      _targetCfu = 180;
    } else {
      _passingGrade = 6.0;
      _maxGrade = 10.0;
      _targetCfu = 0;
    }

    await prefs.setString(_keyEducationMode, newMode == EducationMode.university ? 'university' : 'school');
    await prefs.setDouble(_keyPassingGrade, _passingGrade);
    await prefs.setDouble(_keyMaxGrade, _maxGrade);
    await prefs.setInt(_keyTargetCfu, _targetCfu);

    notifyListeners();
  }

  /// Completely resets all data and triggers onboarding again
  Future<void> resetAllDataAndRestartOnboarding() async {
    await DatabaseHelper().clearAllData();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove('first_period_start');
    await prefs.remove('first_period_end');
    await prefs.remove('second_period_start');
    await prefs.remove('second_period_end');

    _isOnboardingCompleted = false;
    notifyListeners();
  }

  Future<void> setTargetCfu(int cfu) async {
    _targetCfu = cfu;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTargetCfu, cfu);
    notifyListeners();
  }

  Future<void> setPassingGrade(double grade) async {
    _passingGrade = grade;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPassingGrade, grade);
    notifyListeners();
  }

  Future<void> setMaxGrade(double grade) async {
    _maxGrade = grade;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMaxGrade, grade);
    notifyListeners();
  }
}
