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
  
  // 30 e Lode rule keys
  static const String _keyLodeRule = 'lode_rule';
  static const String _keyLodeCustomValue = 'lode_custom_value';
  static const String _keyLodeDegreeBonus = 'lode_degree_bonus';

  EducationMode _mode = EducationMode.school;
  bool _isOnboardingCompleted = false;
  bool _isLoading = true;
  int _targetCfu = 180;
  double _passingGrade = 6.0;
  double _maxGrade = 10.0;

  // 30L rules: 'equal_30', 'equal_31', 'equal_32', 'bonus_degree_0_5', 'custom'
  String _lodeRule = 'equal_30';
  double _lodeCustomValue = 31.0;
  double _lodeDegreeBonus = 0.5;

  EducationMode get mode => _mode;
  bool get isSchool => _mode == EducationMode.school;
  bool get isUniversity => _mode == EducationMode.university;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isLoading => _isLoading;
  int get targetCfu => _targetCfu;
  double get passingGrade => _passingGrade;
  double get maxGrade => _maxGrade;

  String get lodeRule => _lodeRule;
  double get lodeCustomValue => _lodeCustomValue;
  double get lodeDegreeBonus => _lodeDegreeBonus;

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
    _lodeRule = prefs.getString(_keyLodeRule) ?? 'equal_30';
    _lodeCustomValue = prefs.getDouble(_keyLodeCustomValue) ?? 31.0;
    _lodeDegreeBonus = prefs.getDouble(_keyLodeDegreeBonus) ?? 0.5;

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

  double getLodeNumericValue() {
    switch (_lodeRule) {
      case 'equal_31':
        return 31.0;
      case 'equal_32':
        return 32.0;
      case 'custom':
        return _lodeCustomValue;
      case 'equal_30':
      case 'bonus_degree_0_5':
      default:
        return 30.0;
    }
  }

  Future<void> setLodeRule(String rule, {double? customValue, double? degreeBonus}) async {
    _lodeRule = rule;
    if (customValue != null) _lodeCustomValue = customValue;
    if (degreeBonus != null) _lodeDegreeBonus = degreeBonus;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLodeRule, _lodeRule);
    await prefs.setDouble(_keyLodeCustomValue, _lodeCustomValue);
    await prefs.setDouble(_keyLodeDegreeBonus, _lodeDegreeBonus);

    notifyListeners();
  }

  Future<void> completeOnboarding({
    required EducationMode mode,
    double? passingGrade,
    double? maxGrade,
    int? targetCfu,
    String? lodeRule,
    double? lodeCustomValue,
    double? lodeDegreeBonus,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    _mode = mode;
    _isOnboardingCompleted = true;
    _targetCfu = targetCfu ?? (mode == EducationMode.university ? 180 : 0);
    if (lodeRule != null) _lodeRule = lodeRule;
    if (lodeCustomValue != null) _lodeCustomValue = lodeCustomValue;
    if (lodeDegreeBonus != null) _lodeDegreeBonus = lodeDegreeBonus;

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
    await prefs.setString(_keyLodeRule, _lodeRule);
    await prefs.setDouble(_keyLodeCustomValue, _lodeCustomValue);
    await prefs.setDouble(_keyLodeDegreeBonus, _lodeDegreeBonus);

    notifyListeners();
  }

  Future<void> setEducationMode(EducationMode newMode, {required bool resetData}) async {
    final prefs = await SharedPreferences.getInstance();
    _mode = newMode;
    await prefs.setString(_keyEducationMode, newMode == EducationMode.university ? 'university' : 'school');

    await DatabaseHelper().resetConnections();

    if (resetData) {
      await DatabaseHelper().clearCurrentModeData();
    }

    if (newMode == EducationMode.university) {
      _passingGrade = 18.0;
      _maxGrade = 30.0;
      _targetCfu = 180;
    } else {
      _passingGrade = 6.0;
      _maxGrade = 10.0;
      _targetCfu = 0;
    }

    await prefs.setDouble(_keyPassingGrade, _passingGrade);
    await prefs.setDouble(_keyMaxGrade, _maxGrade);
    await prefs.setInt(_keyTargetCfu, _targetCfu);

    notifyListeners();
  }

  Future<void> resetAllDataAndRestartOnboarding() async {
    await DatabaseHelper().clearAllData();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove('first_period_start');
    await prefs.remove('first_period_end');
    await prefs.remove('second_period_start');
    await prefs.remove('second_period_end');
    await prefs.remove(_keyLodeRule);
    await prefs.remove(_keyLodeCustomValue);
    await prefs.remove(_keyLodeDegreeBonus);

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
