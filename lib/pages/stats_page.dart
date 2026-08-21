import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import '../utils/grade_colors.dart';
import '../utils/date_utils.dart';
import 'settings_page.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final dbHelper = DatabaseHelper();

  // — Scuola
  List<Map<String, dynamic>> _historicalOriginalAverages = [];
  List<Map<String, dynamic>> _historicalRoundedAverages = [];
  Map<int, int> _firstPeriodGradeDistribution = {};
  Map<int, int> _secondPeriodGradeDistribution = {};
  Map<String, double> _averagesByType = {};
  Map<String, int> _countsByType = {};
  String? _selectedSubject;
  List<String> _subjectNames = [];

  // — Università
  Map<String, int> _universityGradeDistribution = {};
  List<Subject> _uniSubjects = [];
  Map<String, String> _uniSubjectGrades = {}; // subjectName -> voto display
  String _weightedAverage = 'N/A';
  int _acquiredCfu = 0;
  int _totalPlannedCfu = 0;
  String _degreePrediction = 'N/A';

  bool _isLoading = true;
  double _passingGrade = 6.0;
  double _maxGrade = 10.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final settings = await SettingsPage.loadPassingAndMaxGrades();
    if (mounted) {
      setState(() {
        _passingGrade = settings['passing_grade'] ?? 6.0;
        _maxGrade = settings['max_grade'] ?? 10.0;
      });
    }

    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    if (modeProvider.isUniversity) {
      await _loadUniversityStats();
    } else {
      await _loadSchoolSubjectNames();
    }
  }

  // ─── Università ───────────────────────────────────────────────────────────

  Future<void> _loadUniversityStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
      final fullSubjects = await dbHelper.listSubjectsFull();
      final weightedAvg = await dbHelper.returnWeightedAverage(
        lodeNumericValue: modeProvider.getLodeNumericValue(),
      );
      final acquiredCfu = await dbHelper.returnAcquiredCfu();
      final degreePred = await dbHelper.returnDegreePrediction(
        lodeNumericValue: modeProvider.getLodeNumericValue(),
        lodeDegreeBonus: modeProvider.lodeRule == 'bonus_degree_0_5'
            ? modeProvider.lodeDegreeBonus
            : 0.0,
      );
      final distribution = await dbHelper.getUniversityGradeDistribution();
      final averagesByType = await dbHelper.getOverallAveragesByType();
      final countsByType = await dbHelper.getGradeCountByType(null);

      // Calcola il voto display per ogni insegnamento
      Map<String, String> gradesMap = {};
      for (final s in fullSubjects) {
        final grades = await dbHelper.listGrades(s.subjectName);
        if (grades.isEmpty) {
          gradesMap[s.subjectName] = '–';
        } else {
          final g = grades.first;
          if (g.isIdoneita) {
            gradesMap[s.subjectName] = 'Idon.';
          } else {
            final isLode = g.grade >= 30 &&
                (g.note?.toLowerCase().contains('lode') ?? false);
            gradesMap[s.subjectName] = isLode ? '30L' : g.grade.toInt().toString();
          }
        }
      }

      final plannedCfu = fullSubjects.fold<int>(0, (s, e) => s + e.cfu);

      if (mounted) {
        setState(() {
          _uniSubjects = fullSubjects;
          _uniSubjectGrades = gradesMap;
          _weightedAverage = weightedAvg;
          _acquiredCfu = acquiredCfu;
          _totalPlannedCfu = plannedCfu;
          _degreePrediction = degreePred;
          _universityGradeDistribution = distribution;
          _averagesByType = averagesByType;
          _countsByType = countsByType;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore nel caricamento dati università: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ─── Scuola ───────────────────────────────────────────────────────────────

  Future<void> _loadSchoolSubjectNames() async {
    try {
      final subjects = await dbHelper.listSubjects();
      setState(() {
        _subjectNames = subjects.map((s) => s.$1).toList();
        _subjectNames.insert(0, 'Tutte le materie');
        _selectedSubject = _subjectNames.first;
      });
      await _loadSchoolChartData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento delle materie: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSchoolChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _historicalOriginalAverages = [];
      _historicalRoundedAverages = [];
      _firstPeriodGradeDistribution = {};
      _secondPeriodGradeDistribution = {};
      _averagesByType = {};
      _countsByType = {};
    });

    try {
      final (
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      ) firstPeriodAverages;
      final (
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      ) secondPeriodAverages;

      if (_selectedSubject == 'Tutte le materie') {
        firstPeriodAverages =
            await dbHelper.returnAverageByDatePeriod(periodName: 'first_period');
        secondPeriodAverages =
            await dbHelper.returnAverageByDatePeriod(periodName: 'second_period');
      } else {
        firstPeriodAverages = await dbHelper.returnAverageBySubjectAndPeriod(
            periodName: 'first_period', subjectName: _selectedSubject!);
        secondPeriodAverages = await dbHelper.returnAverageBySubjectAndPeriod(
            periodName: 'second_period', subjectName: _selectedSubject!);
      }

      final Map<int, int> firstCounts;
      final Map<int, int> secondCounts;

      if (_selectedSubject == 'Tutte le materie') {
        firstCounts =
            await dbHelper.returnGradeProportionsByPeriod('first_period');
        secondCounts =
            await dbHelper.returnGradeProportionsByPeriod('second_period');
      } else {
        firstCounts = await dbHelper.returnGradeProportionsByPeriodAndSubject(
            'first_period', _selectedSubject!);
        secondCounts = await dbHelper.returnGradeProportionsByPeriodAndSubject(
            'second_period', _selectedSubject!);
      }

      List<Map<String, dynamic>> combined = [];
      for (var d in firstPeriodAverages.$1) {
        combined.add({...d, 'period': 'first_period', 'type': 'original'});
      }
      for (var d in firstPeriodAverages.$2) {
        combined.add({...d, 'period': 'first_period', 'type': 'rounded'});
      }
      for (var d in secondPeriodAverages.$1) {
        combined.add({...d, 'period': 'second_period', 'type': 'original'});
      }
      for (var d in secondPeriodAverages.$2) {
        combined.add({...d, 'period': 'second_period', 'type': 'rounded'});
      }
      combined.sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));

      final Map<String, double> averagesByType;
      final Map<String, int> countsByType;

      if (_selectedSubject == 'Tutte le materie') {
        averagesByType = await dbHelper.getOverallAveragesByType();
        countsByType = await dbHelper.getGradeCountByType(null);
      } else {
        averagesByType = await dbHelper.getAveragesByType(_selectedSubject!);
        countsByType = await dbHelper.getGradeCountByType(_selectedSubject);
      }

      setState(() {
        _historicalOriginalAverages =
            combined.where((d) => d['type'] == 'original').toList();
        _historicalRoundedAverages =
            combined.where((d) => d['type'] == 'rounded').toList();
        _firstPeriodGradeDistribution = firstCounts;
        _secondPeriodGradeDistribution = secondCounts;
        _averagesByType = averagesByType;
        _countsByType = countsByType;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore nel caricamento dei dati: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ─── Widget: Università ───────────────────────────────────────────────────

  Widget _buildUniSummaryCards(EducationModeProvider modeProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget _statChip(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _statChip('Media\nPonderata', _weightedAverage, colorScheme.primary),
            const SizedBox(width: 8),
            _statChip(
                'CFU\nAcquisiti',
                '$_acquiredCfu / $_totalPlannedCfu',
                Colors.green),
            const SizedBox(width: 8),
            _statChip('Previsione\nLaurea', _degreePrediction, Colors.orange),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildUniExamList(EducationModeProvider modeProvider) {
    if (_uniSubjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Nessun insegnamento aggiunto.')),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pGrade = modeProvider.passingGrade;

    return Column(
      children: _uniSubjects.asMap().entries.map((entry) {
        final i = entry.key;
        final subject = entry.value;
        final gradeDisplay = _uniSubjectGrades[subject.subjectName] ?? '–';
        final isPending = gradeDisplay == '–';
        final isIdoneita = gradeDisplay == 'Idon.';
        final isLode = gradeDisplay == '30L';

        final badgeColor = isPending
            ? colorScheme.surfaceContainerHighest
            : GradeColors.background(
                isIdoneita
                    ? 'Idon.'
                    : isLode
                        ? '30'
                        : gradeDisplay,
                passingGrade: pGrade,
              );
        final badgeTextColor = isPending
            ? colorScheme.onSurfaceVariant
            : isLode
                ? GradeColors.lode
                : GradeColors.foreground(
                    isIdoneita ? 'Idon.' : gradeDisplay,
                    passingGrade: pGrade,
                  );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    gradeDisplay,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: gradeDisplay.length > 2 ? 11 : 16,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ),
              title: Text(
                subject.subjectName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${subject.cfu} CFU${isPending ? ' · Da sostenere' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              trailing: isPending
                  ? Icon(Icons.pending_outlined,
                      color: colorScheme.onSurfaceVariant)
                  : Icon(Icons.verified,
                      color: isIdoneita ? Colors.blue : Colors.green),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 40 * i), duration: 250.ms),
        );
      }).toList(),
    );
  }

  Widget _buildUniversityGradeDistributionChart() {
    final keys = [
      '18', '19', '20', '21', '22', '23', '24', '25',
      '26', '27', '28', '29', '30', '30L'
    ];

    int maxCount = 0;
    for (var k in keys) {
      final cnt = _universityGradeDistribution[k] ?? 0;
      if (cnt > maxCount) maxCount = cnt;
    }
    // Se tutti i voti sono 0, mostra un grafico vuoto con maxY = 1
    final double maxY = maxCount == 0 ? 1.0 : (maxCount + 1).toDouble();

    final barGroups = List.generate(keys.length, (i) {
      final key = keys[i];
      final count = _universityGradeDistribution[key] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: key == '30L' ? Colors.amber[700] : Colors.blueAccent,
            width: 14,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return AspectRatio(
      aspectRatio: 1.6,
      child: Padding(
        padding:
            const EdgeInsets.only(right: 18, left: 8, top: 24, bottom: 12),
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                  '${keys[g.x]}: ${r.toY.toInt()}',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            gridData: const FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, m) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, m) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= keys.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: m,
                      space: 4,
                      child: Text(
                        keys[idx],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: keys[idx] == '30L'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: keys[idx] == '30L'
                              ? Colors.amber[800]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                  color: const Color(0xff37434d), width: 1),
            ),
            minY: 0,
            maxY: maxY,
          ),
        ),
      ),
    );
  }

  // ─── Widget: Scuola ───────────────────────────────────────────────────────

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'scritto':
        return Colors.blue;
      case 'orale':
        return Colors.green;
      case 'pratico':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'scritto':
        return Icons.edit_note;
      case 'orale':
        return Icons.record_voice_over;
      case 'pratico':
        return Icons.science;
      default:
        return Icons.grade;
    }
  }

  Widget _buildTypeCard(String type, double average, int count) {
    final color = _getColorForType(type);
    final icon = _getIconForType(type);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '$count ${count == 1 ? 'voto' : 'voti'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Media', style: TextStyle(fontSize: 14)),
                Text(
                  average.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAverageTrendChart(BuildContext context) {
    if (_historicalOriginalAverages.isEmpty &&
        _historicalRoundedAverages.isEmpty) {
      return const Center(
          child: Text('Nessun dato disponibile per il grafico di andamento.'));
    }

    final firstOrig = _historicalOriginalAverages
        .where((d) => d['period'] == 'first_period')
        .toList();
    final firstRound = _historicalRoundedAverages
        .where((d) => d['period'] == 'first_period')
        .toList();
    final secondOrig = _historicalOriginalAverages
        .where((d) => d['period'] == 'second_period')
        .toList();
    final secondRound = _historicalRoundedAverages
        .where((d) => d['period'] == 'second_period')
        .toList();

    List<FlSpot> toSpots(List<Map<String, dynamic>> data) {
      return List.generate(
        data.length,
        (i) => FlSpot(
          i.toDouble(),
          double.parse(
              (data[i]['average_grade'] as double).toStringAsFixed(2)),
        ),
      );
    }

    final firstOrigSpots = toSpots(firstOrig);
    final firstRoundSpots = toSpots(firstRound);
    final secondOrigSpots = toSpots(secondOrig);
    final secondRoundSpots = toSpots(secondRound);

    final allY = [
      ...firstOrigSpots.map((e) => e.y),
      ...firstRoundSpots.map((e) => e.y),
      ...secondOrigSpots.map((e) => e.y),
      ...secondRoundSpots.map((e) => e.y),
    ];
    double minY = 0;
    double maxY = _maxGrade;
    if (allY.isNotEmpty) {
      minY = (allY.reduce((a, b) => a < b ? a : b).floorToDouble() - 1)
          .clamp(0.0, double.infinity);
      maxY = (allY.reduce((a, b) => a > b ? a : b).ceilToDouble() + 1)
          .clamp(0.0, double.infinity);
    }

    final maxPoints = max(firstOrig.length, secondOrig.length);
    final double maxX = (maxPoints > 0 ? maxPoints - 1 : 0).toDouble();

    LineChartBarData _line(List<FlSpot> spots, Color color) {
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      );
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding:
            const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          s.y.toStringAsFixed(2),
                          TextStyle(
                              color: s.bar.color ?? Colors.white,
                              fontWeight: FontWeight.bold),
                        ))
                    .toList(),
              ),
            ),
            gridData: const FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border:
                  Border.all(color: const Color(0xff37434d), width: 1),
            ),
            minX: 0,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              _line(firstOrigSpots, Colors.blueAccent),
              _line(firstRoundSpots, Colors.purpleAccent),
              _line(secondOrigSpots, Colors.orangeAccent),
              _line(secondRoundSpots, Colors.pinkAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolGradeDistributionChart() {
    if (_firstPeriodGradeDistribution.isEmpty &&
        _secondPeriodGradeDistribution.isEmpty) {
      return const Center(
          child: Text(
              'Nessun dato disponibile per il grafico di distribuzione.'));
    }

    final allGrades = [
      ..._firstPeriodGradeDistribution.keys,
      ..._secondPeriodGradeDistribution.keys
    ];
    final int maxGradeValue =
        allGrades.isNotEmpty ? allGrades.reduce(max) : 10;
    final int effectiveMaxX = max(maxGradeValue, 10);

    final allCounts = [
      ..._firstPeriodGradeDistribution.values,
      ..._secondPeriodGradeDistribution.values
    ];
    final double maxY =
        (allCounts.isNotEmpty ? allCounts.reduce(max).toDouble() : 0) + 1;

    final barGroups = List.generate(effectiveMaxX + 1, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (_firstPeriodGradeDistribution[i] ?? 0).toDouble(),
            color: Colors.blueAccent,
            width: 7,
          ),
          BarChartRodData(
            toY: (_secondPeriodGradeDistribution[i] ?? 0).toDouble(),
            color: Colors.orangeAccent,
            width: 7,
          ),
        ],
        barsSpace: 2,
      );
    });

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding:
            const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                  '${r.toY.toInt()}',
                  const TextStyle(color: Colors.white),
                ),
              ),
            ),
            gridData: const FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (v, m) => SideTitleWidget(
                    meta: m,
                    space: 8,
                    child: Text(
                      '${v.toInt()}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1),
            ),
            minY: 0,
            maxY: maxY,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
            onPressed: () => isUni
                ? _loadUniversityStats()
                : _loadSchoolChartData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Errore: $_errorMessage'))
              : isUni
                  ? _buildUniversityBody(modeProvider)
                  : _buildSchoolBody(),
    );
  }

  Widget _buildUniversityBody(EducationModeProvider modeProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Riepilogo statistiche globali
        _buildUniSummaryCards(modeProvider),

        const SizedBox(height: 24),
        const Divider(thickness: 1),
        const SizedBox(height: 8),

        // 2. Grafico distribuzione voti
        Text(
          'Distribuzione Voti (18 – 30L)',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildUniversityGradeDistributionChart(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendRow(Colors.blueAccent, 'Esami (18 – 30)'),
            const SizedBox(width: 24),
            _buildLegendRow(Colors.amber[700]!, '30 e Lode'),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(thickness: 1),
        const SizedBox(height: 8),

        // 3. Lista esami
        Text(
          'Esami (${_uniSubjects.length})',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildUniExamList(modeProvider),

        const SizedBox(height: 24),
        const Divider(thickness: 1),
        const SizedBox(height: 8),

        // 4. Analisi per Tipologia Esame
        Text(
          'Analisi per Tipologia Esame',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_averagesByType.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun dato disponibile per tipologia.',
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
            ),
          )
        else
          Column(
            children: _averagesByType.entries.map((entry) {
              final count = _countsByType[entry.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTypeCard(entry.key, entry.value, count),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSchoolBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dropdown selezione materia (utile in modalità scuola)
        DropdownButtonFormField<String>(
          initialValue: _selectedSubject,
          decoration: const InputDecoration(
            labelText: 'Seleziona Materia',
            border: OutlineInputBorder(),
          ),
          items: _subjectNames.map((s) {
            return DropdownMenuItem<String>(value: s, child: Text(s));
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _selectedSubject = newValue);
              _loadSchoolChartData();
            }
          },
        ),

        const SizedBox(height: 24),
        Text(
          _selectedSubject == 'Tutte le materie'
              ? 'Andamento della Media Generale'
              : 'Andamento Media: $_selectedSubject',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildAverageTrendChart(context),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendRow(Colors.blueAccent, '1° Quadrimestre – Media'),
            _buildLegendRow(Colors.purpleAccent, '1° Quadrimestre – Arrotondata'),
            _buildLegendRow(Colors.orangeAccent, '2° Quadrimestre – Media'),
            _buildLegendRow(Colors.pinkAccent, '2° Quadrimestre – Arrotondata'),
          ],
        ),

        const SizedBox(height: 32),
        const Divider(thickness: 2),
        const SizedBox(height: 16),

        Text(
          'Distribuzione dei Voti',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildSchoolGradeDistributionChart(),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendRow(Colors.blueAccent, '1° Quadrimestre'),
            _buildLegendRow(Colors.orangeAccent, '2° Quadrimestre'),
          ],
        ),

        const SizedBox(height: 32),
        const Divider(thickness: 2),
        const SizedBox(height: 16),

        Text(
          'Analisi per Tipologia',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_averagesByType.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun dato disponibile per tipologia.',
                style:
                    TextStyle(color: Theme.of(context).disabledColor),
              ),
            ),
          )
        else
          Column(
            children: _averagesByType.entries.map((entry) {
              final count = _countsByType[entry.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTypeCard(entry.key, entry.value, count),
              );
            }).toList(),
          ),
      ],
    );
  }
}
