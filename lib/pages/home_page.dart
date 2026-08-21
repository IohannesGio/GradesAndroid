import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import 'subject_detail_page.dart';
import 'settings_page.dart';

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
  String _degreePrediction = 'N/A';

  double _passingGrade = 6.0;

  @override
  void initState() {
    super.initState();
    _loadPassingGrade();
    _loadData();
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

    subjectsWithAverage.sort((a, b) {
      final double? avgA = double.tryParse(a.$3);
      final double? avgB = double.tryParse(b.$3);
      if (avgA == null && avgB == null) return 0;
      if (avgA == null) return 1;
      if (avgB == null) return -1;
      return avgB.compareTo(avgA);
    });

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
        double sum = 0;
        double wSum = 0;
        for (var g in grades) {
          sum += g.grade * g.weight;
          wSum += g.weight;
        }
        if (wSum > 0) {
          averagesMap[s.subjectName] = (sum / wSum).toStringAsFixed(1);
        } else {
          averagesMap[s.subjectName] = 'N/A';
        }
      } else {
        averagesMap[s.subjectName] = 'N/A';
      }
    }

    if (mounted) {
      setState(() {
        _uniSubjects = fullSubjects;
        _uniSubjectAverages = averagesMap;
        _weightedAverage = weightedAvg;
        _acquiredCfu = totalCfu;
        _degreePrediction = degreePred;
      });
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
      if (customColor != null) return customColor.withOpacity(0.2);
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey.withOpacity(0.2);
      if (label == 'Obiettivo' || label == 'CFU Conseguiti') {
        return Colors.blue.withOpacity(0.2);
      }
      return val >= _passingGrade
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2);
    }

    Color getTextColorForBackground(String label, String value) {
      if (customColor != null) return customColor;
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey;
      if (label == 'Obiettivo' || label == 'CFU Conseguiti') {
        return Colors.blue;
      }
      return val >= _passingGrade ? Colors.green : Colors.red;
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
              Container(
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

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    Color getColorForValue(String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey.withOpacity(0.2);
      return val >= _passingGrade
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2);
    }

    Color getTextColorForBackground(String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey;
      return val >= _passingGrade ? Colors.green : Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isUni ? 'Libretto Esami' : 'Home Materie'),
      ),
      body: Column(
        children: [
          // Stat Cards Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: isUni
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard('Media Ponderata', _weightedAverage),
                          _buildStatCard('CFU Conseguiti', '$_acquiredCfu / ${modeProvider.targetCfu}'),
                          _buildStatCard('Voto Laurea', '$_degreePrediction / 110', customColor: Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress bar for CFU
                      if (modeProvider.targetCfu > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progresso CFU Laurea',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${((_acquiredCfu / modeProvider.targetCfu) * 100).clamp(0, 100).toStringAsFixed(1)}%',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: (_acquiredCfu / modeProvider.targetCfu).clamp(0.0, 1.0),
                                borderRadius: BorderRadius.circular(6),
                                minHeight: 8,
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

          // Subjects / Exams List
          Expanded(
            child: isUni
                ? (_uniSubjects.isEmpty
                    ? Center(
                        child: Text(
                          'Nessun esame inserito nel libretto.',
                          style: TextStyle(color: Theme.of(context).disabledColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _uniSubjects.length,
                        itemBuilder: (_, i) {
                          final subject = _uniSubjects[i];
                          final average = _uniSubjectAverages[subject.subjectName] ?? 'N/A';

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
                                        Row(
                                          children: [
                                            Text(
                                              subject.subjectName,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
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
                                        SizedBox(
                                          width: 80,
                                          height: 40,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: getColorForValue(average),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              average,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: getTextColorForBackground(average),
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
                        },
                      ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.2, end: 0))
                : (_subjects.isEmpty
                    ? Center(
                        child: Text(
                          'Nessuna materia inserita.',
                          style: TextStyle(color: Theme.of(context).disabledColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _subjects.length,
                        itemBuilder: (_, i) {
                          final subjectName = _subjects[i].$1;
                          final average = _subjects[i].$3;

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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            subjectName,
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 80,
                                          height: 40,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: getColorForValue(average),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              average,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: getTextColorForBackground(average),
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
                        },
                      ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.2, end: 0)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubjectDialog,
        icon: const Icon(Icons.add),
        label: Text(isUni ? 'Nuovo Esame' : 'Nuova Materia'),
        tooltip: isUni ? 'Aggiungi Nuovo Esame' : 'Aggiungi Nuova Materia',
      ),
    );
  }
}
