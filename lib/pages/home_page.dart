import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import '../services/widget_service.dart';
import '../utils/grade_colors.dart';
import '../widgets/smart_import_dialog.dart';
import 'subject_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DatabaseHelper();
  
  // School mode state
  List<(String, String, String)> _subjects = [];
  String _overallAveragePeriod = 'N/A';
  String _overallRoundedAveragePeriod = 'N/A';
  String _averageObjective = 'N/A';
  
  // University mode state
  List<Subject> _uniSubjects = [];
  Map<String, String> _uniSubjectAverages = {};
  String _weightedAverage = 'N/A';
  int _acquiredCfu = 0;
  int _totalPlannedCfu = 0;
  String _degreePrediction = 'N/A';

  double _passingGrade = 6.0;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _uniFilter = 'all'; // 'all', 'pending', 'passed'
  String _schoolFilter = 'all'; // 'all', 'passed', 'failed'
  String _sortBy = 'default'; // 'default' (inserimento), 'name_asc', 'name_desc', 'cfu_desc', 'grade_desc', 'date_asc'

  @override
  void initState() {
    super.initState();
    _loadPassingGrade();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Subject> get _filteredUniSubjects {
    final list = _uniSubjects.where((subject) {
      final nameMatches = subject.subjectName.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!nameMatches) return false;

      final avg = _uniSubjectAverages[subject.subjectName];
      final isPassed = avg != null && avg != 'N/A';

      if (_uniFilter == 'pending' && isPassed) return false;
      if (_uniFilter == 'passed' && !isPassed) return false;

      return true;
    }).toList();

    if (_sortBy == 'default') {
      return list; // Ordine predefinito: ordine di inserimento naturale
    }

    return list..sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          return b.subjectName.compareTo(a.subjectName);
        case 'name_asc':
          return a.subjectName.compareTo(b.subjectName);
        case 'cfu_desc':
          return b.cfu.compareTo(a.cfu);
        case 'grade_desc':
          double parseGrade(String? s) {
            if (s == null || s == 'N/A') return -1.0;
            if (s == '30L') return 31.0;
            if (s == 'Idon.') return 30.0;
            return double.tryParse(s) ?? -1.0;
          }
          return parseGrade(_uniSubjectAverages[b.subjectName]).compareTo(parseGrade(_uniSubjectAverages[a.subjectName]));
        case 'date_asc':
          final dateA = a.examDate ?? 99999999;
          final dateB = b.examDate ?? 99999999;
          return dateA.compareTo(dateB);
        default:
          return 0;
      }
    });
  }

  List<(String, String, String)> get _filteredSchoolSubjects {
    final list = _subjects.where((item) {
      final name = item.$1;
      final avgStr = item.$3;
      final nameMatches = name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!nameMatches) return false;

      final avg = double.tryParse(avgStr);
      final isPassed = avg != null && avg >= _passingGrade;

      if (_schoolFilter == 'passed' && !isPassed) return false;
      if (_schoolFilter == 'failed' && isPassed) return false;

      return true;
    }).toList();

    if (_sortBy == 'default') {
      return list; // Ordine predefinito: ordine di inserimento naturale
    }

    return list..sort((a, b) {
      switch (_sortBy) {
        case 'name_desc':
          return b.$1.compareTo(a.$1);
        case 'name_asc':
          return a.$1.compareTo(b.$1);
        case 'grade_desc':
          final avgA = double.tryParse(a.$3) ?? -1.0;
          final avgB = double.tryParse(b.$3) ?? -1.0;
          return avgB.compareTo(avgA);
        default:
          return 0;
      }
    });
  }

  Subject? get _nextUpcomingExam {
    final today = DateTime.now();
    Subject? closest;
    int minDays = 999999;

    for (var s in _uniSubjects) {
      if (s.examDate == null) continue;
      final avg = _uniSubjectAverages[s.subjectName];
      final isPassed = avg != null && avg != 'N/A';
      if (isPassed) continue;

      final y = s.examDate! ~/ 10000;
      final m = (s.examDate! ~/ 100) % 100;
      final d = s.examDate! % 100;
      final examDate = DateTime(y, m, d);
      final diff = examDate.difference(DateTime(today.year, today.month, today.day)).inDays;

      if (diff >= 0 && diff < minDays) {
        minDays = diff;
        closest = s;
      }
    }
    return closest;
  }

  Future<void> _loadData() async {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);

    if (modeProvider.isUniversity) {
      await _loadUniversityData();
    } else {
      await _loadSchoolData();
    }
  }

  Future<void> _loadSchoolData() async {
    final subjectsWithObjectives = await dbHelper.listSubjects();
    final List<(String, String, String)> subjectsWithAverage = [];
    final subjectAveragesPeriod = await dbHelper.returnAveragesByPeriod();
    final Map<String, String> subjectAveragesMap = Map.fromEntries(
        subjectAveragesPeriod.map((item) => MapEntry(item.$1, item.$2)));

    double sumOfRoundedSubjectAverages = 0.0;
    int countOfSubjectsWithAverageInPeriod = 0;

    for (var subjectInfo in subjectsWithObjectives) {
      final subjectName = subjectInfo.$1;
      final objective = subjectInfo.$2;
      final average = subjectAveragesMap[subjectName] ?? 'N/A';

      subjectsWithAverage.add((subjectName, objective, average));

      if (average != 'N/A') {
        final double? avgDouble = double.tryParse(average);
        if (avgDouble != null) {
          final roundedAvgSubject = dbHelper.roundCustom(avgDouble);
          sumOfRoundedSubjectAverages += roundedAvgSubject;
          countOfSubjectsWithAverageInPeriod++;
        }
      }
    }

    String calculatedOverallRoundedAveragePeriod = 'N/A';
    if (countOfSubjectsWithAverageInPeriod > 0) {
      calculatedOverallRoundedAveragePeriod =
          (sumOfRoundedSubjectAverages / countOfSubjectsWithAverageInPeriod)
              .toStringAsFixed(2);
    }

    final overallAvgPeriod = await dbHelper.returnGeneralAverageByPeriod();
    final avgObj = await dbHelper.returnAverageObjective();

    if (mounted) {
      setState(() {
        _subjects = subjectsWithAverage;
        _overallAveragePeriod = overallAvgPeriod;
        _overallRoundedAveragePeriod = calculatedOverallRoundedAveragePeriod;
        _averageObjective = avgObj;
      });
    }
  }

  Future<void> _loadUniversityData() async {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final fullSubjects = await dbHelper.listSubjectsFull();
    final weightedAvg = await dbHelper.returnWeightedAverage(
      lodeNumericValue: modeProvider.getLodeNumericValue(),
    );
    final totalCfu = await dbHelper.returnAcquiredCfu();
    final degreePred = await dbHelper.returnDegreePrediction(
      lodeNumericValue: modeProvider.getLodeNumericValue(),
      lodeDegreeBonus: modeProvider.lodeRule == 'bonus_degree_0_5' ? modeProvider.lodeDegreeBonus : 0.0,
    );

    Map<String, String> averagesMap = {};
    for (var s in fullSubjects) {
      final grades = await dbHelper.listGrades(s.subjectName);
      if (grades.isNotEmpty) {
        // Se l'esame è un'Idoneità, non mostrare un voto numerico
        final hasIdoneita = grades.any((g) => g.isIdoneita);
        if (hasIdoneita) {
          averagesMap[s.subjectName] = 'Idon.';
        } else {
          double sum = 0;
          double wSum = 0;
          for (var g in grades) {
            final gradeValue = g.isLode
                ? modeProvider.getLodeNumericValue()
                : g.grade;
            sum += gradeValue * g.weight;
            wSum += g.weight;
          }
          if (wSum > 0) {
            final isLode = grades.any((g) => g.isLode) && (grades.length == 1 || (sum / wSum) >= 30.0);
            if (isLode) {
              averagesMap[s.subjectName] = '30L';
            } else {
              final avg = sum / wSum;
              averagesMap[s.subjectName] = avg % 1 == 0 ? avg.toInt().toString() : avg.toStringAsFixed(1);
            }
          } else {
            averagesMap[s.subjectName] = 'N/A';
          }
        }
      } else {
        averagesMap[s.subjectName] = 'N/A';
      }
    }

    final plannedCfuSum = fullSubjects.fold<int>(0, (sum, s) => sum + s.cfu);

    if (mounted) {
      setState(() {
        _uniSubjects = fullSubjects;
        _uniSubjectAverages = averagesMap;
        _weightedAverage = weightedAvg;
        _acquiredCfu = totalCfu;
        _totalPlannedCfu = plannedCfuSum;
        _degreePrediction = degreePred;
      });
      await WidgetService.updateNextExamWidget();
    }
  }

  Future<void> _loadPassingGrade() async {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    setState(() {
      _passingGrade = modeProvider.passingGrade;
    });
  }

  void _showAddSubjectDialog() {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final isUni = modeProvider.isUniversity;
    final nameController = TextEditingController();
    final cfuController = TextEditingController(text: '6');
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isUni ? 'Aggiungi Insegnamento / Esame' : 'Aggiungi Materia'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isUni ? 'Nome insegnamento' : 'Nome materia',
                      errorText: errorText,
                    ),
                  ),
                  if (isUni) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: cfuController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Crediti Formativi (CFU)',
                      ),
                    ),
                    if (modeProvider.targetCfu > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Piano di studi: $_totalPlannedCfu / ${modeProvider.targetCfu} CFU inseriti'
                        '${_totalPlannedCfu < modeProvider.targetCfu ? " (mancano ${modeProvider.targetCfu - _totalPlannedCfu} CFU)" : " (completo)"}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _totalPlannedCfu < modeProvider.targetCfu ? Colors.amber.shade800 : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final cfuVal = int.tryParse(cfuController.text) ?? 6;
                    if (name.isNotEmpty) {
                      try {
                        await dbHelper.addSubject(
                          name,
                          cfu: isUni ? cfuVal : 0,
                        );
                        HapticFeedback.lightImpact();
                        if (context.mounted) Navigator.pop(context);
                        _loadData();
                      } catch (e) {
                        setState(() => errorText = e.toString());
                      }
                    } else {
                      setState(() => errorText = 'Il campo non può essere vuoto');
                    }
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToSubjectDetails(String subjectName) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SubjectDetailPage(subjectName: subjectName)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.2, end: 0),
      ),
    );
    _loadData();
  }

  Widget _buildStatCard(String label, String value, {Color? customColor}) {
    Color getColorForValue(String label, String value) {
      if (customColor != null) return customColor.withValues(alpha: 0.2);
      if (label == 'Obiettivo' || label.contains('CFU')) {
        return GradeColors.cfuBackground;
      }
      return GradeColors.background(value, passingGrade: _passingGrade);
    }

    Color getTextColorForBackground(String label, String value) {
      if (customColor != null) return customColor;
      if (label == 'Obiettivo' || label.contains('CFU')) {
        return GradeColors.cfuForeground;
      }
      return GradeColors.foreground(value, passingGrade: _passingGrade);
    }

    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              GradeColors.isLode(value)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      decoration: BoxDecoration(
                        color: getColorForValue(label, value),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: getTextColorForBackground(label, value),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCfuWarningBanner(EducationModeProvider modeProvider) {
    if (modeProvider.targetCfu <= 0 || _totalPlannedCfu >= modeProvider.targetCfu) {
      return const SizedBox.shrink();
    }

    final missingCfu = modeProvider.targetCfu - _totalPlannedCfu;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Attenzione: piano di studi incompleto. Hai inserito $_totalPlannedCfu su ${modeProvider.targetCfu} CFU previsti (mancano $missingCfu CFU da pianificare).',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildNextExamCountdownCard(Subject exam) {
    final today = DateTime.now();
    final y = exam.examDate! ~/ 10000;
    final m = (exam.examDate! ~/ 100) % 100;
    final d = exam.examDate! % 100;
    final examDate = DateTime(y, m, d);
    final diff = examDate.difference(DateTime(today.year, today.month, today.day)).inDays;

    String countdownBig;
    String countdownSub;
    Color accentColor;

    if (diff < 0) {
      countdownBig = 'TERMINATO';
      countdownSub = '${diff.abs()} giorni fa';
      accentColor = Colors.grey;
    } else if (diff == 0) {
      countdownBig = 'OGGI!';
      countdownSub = 'Il giorno dell\'esame';
      accentColor = Colors.orange;
    } else if (diff == 1) {
      countdownBig = 'DOMANI';
      countdownSub = '1 giorno rimanente';
      accentColor = Colors.amber.shade800;
    } else {
      countdownBig = '$diff';
      countdownSub = 'giorni all\'appello';
      accentColor = Theme.of(context).colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentColor.withValues(alpha: 0.35), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToSubjectDetails(exam.subjectName),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        countdownBig,
                        style: TextStyle(
                          fontSize: diff <= 1 && diff >= 0 ? 16 : 22,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        countdownSub,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 14, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'PROSSIMO APPELLO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exam.subjectName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('EEEE d MMMM yyyy', 'it_IT').format(examDate)} • ${exam.cfu} CFU',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSearchAndFilterBar(bool isUni) {
    final colorScheme = Theme.of(context).colorScheme;

    int totalCount = isUni ? _uniSubjects.length : _subjects.length;
    int passedCount = isUni
        ? _uniSubjects.where((s) {
            final avg = _uniSubjectAverages[s.subjectName];
            return avg != null && avg != 'N/A';
          }).length
        : _subjects.where((s) {
            final avg = double.tryParse(s.$3);
            return avg != null && avg >= _passingGrade;
          }).length;
    int pendingCount = totalCount - passedCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: isUni ? 'Cerca esame...' : 'Cerca materia...',
                      hintStyle: TextStyle(fontSize: 14, color: colorScheme.outline),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                HapticFeedback.lightImpact();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.sort, size: 22, color: colorScheme.onSurfaceVariant),
                ),
                tooltip: 'Ordina per',
                onSelected: (val) {
                  setState(() => _sortBy = val);
                  HapticFeedback.lightImpact();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'default',
                    child: Row(
                      children: [
                        Icon(Icons.format_list_numbered, size: 18),
                        SizedBox(width: 10),
                        Text('Inserimento (Predefinito)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'name_asc',
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha, size: 18),
                        SizedBox(width: 10),
                        Text('Nome (A - Z)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'name_desc',
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha, size: 18),
                        SizedBox(width: 10),
                        Text('Nome (Z - A)'),
                      ],
                    ),
                  ),
                  if (isUni)
                    const PopupMenuItem(
                      value: 'cfu_desc',
                      child: Row(
                        children: [
                          Icon(Icons.school_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('CFU (più alti)'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'grade_desc',
                    child: Row(
                      children: [
                        Icon(Icons.grade_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Voto (più alti)'),
                      ],
                    ),
                  ),
                  if (isUni)
                    const PopupMenuItem(
                      value: 'date_asc',
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Appello più vicino'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: isUni
                  ? [
                      FilterChip(
                        selected: _uniFilter == 'all',
                        label: Text('Tutti ($totalCount)'),
                        onSelected: (_) {
                          setState(() => _uniFilter = 'all');
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _uniFilter == 'pending',
                        avatar: const Icon(Icons.pending_actions, size: 16),
                        label: Text('Da sostenere ($pendingCount)'),
                        onSelected: (_) {
                          setState(() => _uniFilter = 'pending');
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _uniFilter == 'passed',
                        avatar: const Icon(Icons.check_circle_outline, size: 16),
                        label: Text('Verbalizzati ($passedCount)'),
                        onSelected: (_) {
                          setState(() => _uniFilter = 'passed');
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ]
                  : [
                      FilterChip(
                        selected: _schoolFilter == 'all',
                        label: Text('Tutte ($totalCount)'),
                        onSelected: (_) {
                          setState(() => _schoolFilter = 'all');
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _schoolFilter == 'passed',
                        label: Text('Sufficienti ($passedCount)'),
                        onSelected: (_) {
                          setState(() => _schoolFilter = 'passed');
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _schoolFilter == 'failed',
                        label: Text('Da recuperare ($pendingCount)'),
                        onSelected: (_) {
                          setState(() => _schoolFilter = 'failed');
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniSubjectCard(Subject subject, String average) {
    String? examCountdownLabel;
    Color examCountdownColor = Colors.grey;
    if (average == 'N/A' && subject.examDate != null) {
      final today = DateTime.now();
      final y = subject.examDate! ~/ 10000;
      final m = (subject.examDate! ~/ 100) % 100;
      final d = subject.examDate! % 100;
      final examDate = DateTime(y, m, d);
      final diff = examDate.difference(DateTime(today.year, today.month, today.day)).inDays;

      if (diff < 0) {
        examCountdownLabel = 'Appello terminato (${diff.abs()} gg fa)';
        examCountdownColor = Colors.grey;
      } else if (diff == 0) {
        examCountdownLabel = 'Appello Oggi!';
        examCountdownColor = Colors.orange;
      } else if (diff == 1) {
        examCountdownLabel = 'Appello Domani';
        examCountdownColor = Colors.amber.shade800;
      } else {
        examCountdownLabel = 'Tra $diff giorni';
        examCountdownColor = Theme.of(context).colorScheme.primary;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _navigateToSubjectDetails(subject.subjectName),
        borderRadius: BorderRadius.circular(20),
        child: Hero(
          tag: subject.subjectName,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subject.subjectName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${subject.cfu} CFU',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (examCountdownLabel != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.event, size: 13, color: examCountdownColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  examCountdownLabel,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: examCountdownColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: GradeColors.isLode(average)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  '30L',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: GradeColors.background(average, passingGrade: _passingGrade),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              average,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: GradeColors.foreground(average, passingGrade: _passingGrade),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolSubjectCard(String subjectName, String average) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _navigateToSubjectDetails(subjectName),
        borderRadius: BorderRadius.circular(20),
        child: Hero(
          tag: subjectName,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        subjectName,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: GradeColors.isLode(average)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  average,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: GradeColors.background(average, passingGrade: _passingGrade),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              average,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: GradeColors.foreground(average, passingGrade: _passingGrade),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
        children: [
          // Stat Cards Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: isUni
                ? Column(
                    children: [
                      Row(
                        children: [
                          _buildStatCard('Media Ponderata', _weightedAverage),
                          _buildStatCard('CFU Acquisiti', '$_acquiredCfu CFU'),
                          _buildStatCard('Voto Laurea', '$_degreePrediction/110', customColor: Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress bars for CFU
                      if (modeProvider.targetCfu > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Progresso CFU (Verbalizzati: $_acquiredCfu | Inseriti: $_totalPlannedCfu/${modeProvider.targetCfu})',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${((_acquiredCfu / modeProvider.targetCfu) * 100).clamp(0, 100).toStringAsFixed(1)}%',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Stack(
                                children: [
                                  // Total planned progress (lighter)
                                  LinearProgressIndicator(
                                    value: (_totalPlannedCfu / modeProvider.targetCfu).clamp(0.0, 1.0),
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                    minHeight: 8,
                                  ),
                                  // Acquired progress (solid)
                                  LinearProgressIndicator(
                                    value: (_acquiredCfu / modeProvider.targetCfu).clamp(0.0, 1.0),
                                    backgroundColor: Colors.transparent,
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                    minHeight: 8,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard('Media', _overallAveragePeriod),
                      _buildStatCard('Media Arrotondata', _overallRoundedAveragePeriod),
                      _buildStatCard('Obiettivo', _averageObjective),
                    ],
                  ),
          ),

          if (isUni) ...[
            _buildCfuWarningBanner(modeProvider),
            if (_nextUpcomingExam != null)
              _buildNextExamCountdownCard(_nextUpcomingExam!),
          ],
          _buildSearchAndFilterBar(isUni),
          const SizedBox(height: 4),

          // Subjects / Exams List
          Expanded(
            child: isUni
                ? (_uniSubjects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_outlined, size: 56, color: Theme.of(context).disabledColor),
                            const SizedBox(height: 12),
                            Text(
                              'Nessun esame inserito nel libretto.',
                              style: TextStyle(color: Theme.of(context).disabledColor),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () => _showSmartImport(),
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: const Text('Importa da Testo (IA)'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUniSubjects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).disabledColor),
                                const SizedBox(height: 12),
                                Text(
                                  'Nessun esame corrisponde ai criteri.',
                                  style: TextStyle(color: Theme.of(context).disabledColor),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _uniFilter = 'all';
                                      _sortBy = 'default';
                                    });
                                  },
                                  child: const Text('Reimposta filtri'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _filteredUniSubjects.length,
                            itemBuilder: (_, i) {
                              final subject = _filteredUniSubjects[i];
                              final average = _uniSubjectAverages[subject.subjectName] ?? 'N/A';
                              return _buildUniSubjectCard(subject, average);
                            },
                          ))
                : (_subjects.isEmpty
                    ? Center(
                        child: Text(
                          'Nessuna materia inserita.',
                          style: TextStyle(color: Theme.of(context).disabledColor),
                        ),
                      )
                    : _filteredSchoolSubjects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).disabledColor),
                                const SizedBox(height: 12),
                                Text(
                                  'Nessuna materia corrisponde ai criteri.',
                                  style: TextStyle(color: Theme.of(context).disabledColor),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _schoolFilter = 'all';
                                      _sortBy = 'default';
                                    });
                                  },
                                  child: const Text('Reimposta filtri'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _filteredSchoolSubjects.length,
                            itemBuilder: (_, i) {
                              final subjectName = _filteredSchoolSubjects[i].$1;
                              final average = _filteredSchoolSubjects[i].$3;
                              return _buildSchoolSubjectCard(subjectName, average);
                            },
                          )),
          ),
        ],
      ),
      ),
      floatingActionButton: isUni
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'smart_import_fab',
                  onPressed: () => _showSmartImport(),
                  tooltip: 'Importa da Testo (IA)',
                  child: const Icon(Icons.auto_awesome, size: 20),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'add_exam_fab',
                  onPressed: _showAddSubjectDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuovo Esame'),
                  tooltip: 'Aggiungi Nuovo Esame',
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: _showAddSubjectDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nuova Materia'),
              tooltip: 'Aggiungi Nuova Materia',
            ),
    );
  }

  void _showSmartImport() async {
    final result = await showSmartImportDialog(context);
    if (result != null && result.selectedExams.isNotEmpty) {
      int importedCount = 0;
      int importedCfu = 0;
      int duplicateCount = 0;
      for (final exam in result.selectedExams) {
        try {
          await dbHelper.addSubject(exam.title, cfu: exam.cfu);
          importedCount++;
          importedCfu += exam.cfu;
        } catch (e) {
          if (e.toString().contains('duplicate')) {
            duplicateCount++;
          }
        }
      }
      _loadData();
      if (mounted) {
        String message = '$importedCount esami importati con successo ($importedCfu CFU totali aggiunti al tuo piano!).';
        if (duplicateCount > 0) {
          message += ' ($duplicateCount duplicati ignorati)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
}
