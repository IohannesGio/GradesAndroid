import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import '../utils/grade_colors.dart';
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
  String _weightedAverage = 'N/A';
  int _acquiredCfu = 0;
  String _degreePrediction = 'N/A';
  // Andamento media ponderata nel tempo: lista ordinata per data di {x: esame_n, y: media}
  List<FlSpot> _uniAverageTrend = [];

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
    if (!mounted) return;
    setState(() {
      _passingGrade = settings['passing_grade'] ?? 6.0;
      _maxGrade = settings['max_grade'] ?? 10.0;
    });

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
      final averagesByType = await dbHelper.getOverallAveragesByType(
        lodeNumericValue: modeProvider.getLodeNumericValue(),
      );
      final countsByType = await dbHelper.getGradeCountByType(null);

      // Calcola andamento media ponderata nel tempo
      final List<FlSpot> trendSpots = [];
      final allGrades = await dbHelper.getAllGradesSortedByDate();
      final lodeVal = modeProvider.getLodeNumericValue();
      double runningSum = 0;
      double runningWeight = 0;
      int examIndex = 0;
      for (final g in allGrades) {
        if (!g.isIdoneita && g.weight > 0) {
          final val = g.isLode ? lodeVal : g.grade;
          runningSum += val * g.weight;
          runningWeight += g.weight;
          examIndex++;
          trendSpots.add(FlSpot(examIndex.toDouble(), runningSum / runningWeight));
        }
      }

      if (mounted) {
        setState(() {
          _weightedAverage = weightedAvg;
          _acquiredCfu = acquiredCfu;
          _degreePrediction = degreePred;
          _universityGradeDistribution = distribution;
          _averagesByType = averagesByType;
          _countsByType = countsByType;
          _uniAverageTrend = trendSpots;
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

  Widget _buildStatCard(String label, String value, {Color? customColor}) {
    Color getColorForValue(String label, String value) {
      if (label == 'Obiettivo' || label.contains('CFU')) {
        return Colors.blue.withValues(alpha: 0.2);
      }
      return GradeColors.background(value, passingGrade: _passingGrade);
    }

    Color getTextColorForBackground(String label, String value) {
      if (label == 'Obiettivo' || label.contains('CFU')) {
        return Colors.blue;
      }
      return GradeColors.foreground(value, passingGrade: _passingGrade);
    }

    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: customColor != null
                      ? customColor.withValues(alpha: 0.2)
                      : getColorForValue(label, value),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColor ?? getTextColorForBackground(label, value),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUniSummaryCards(EducationModeProvider modeProvider) {
    return Row(
      children: [
        _buildStatCard('Media Ponderata', _weightedAverage),
        _buildStatCard('CFU Acquisiti', '$_acquiredCfu CFU'),
        _buildStatCard('Voto Laurea', '$_degreePrediction/110', customColor: Colors.purple),
      ],
    );
  }

  Widget _buildUniAverageTrendChart() {
    if (_uniAverageTrend.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Nessun esame con voto numerico registrato per tracciare l\'andamento.',
            style: TextStyle(color: Theme.of(context).disabledColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Calcola il range Y in base ai punti per un grafico bilanciato ed elegante
    double minVal = _uniAverageTrend.map((e) => e.y).reduce(min);
    double maxVal = _uniAverageTrend.map((e) => e.y).reduce(max);
    double minY = max(18.0, (minVal - 1.0).floorToDouble());
    double maxY = min(31.0, (maxVal + 1.0).ceilToDouble());
    if (minY >= maxY) maxY = minY + 2.0;

    return AspectRatio(
      aspectRatio: 1.6,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 8, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      'Esame #${spot.x.toInt()}: ${spot.y.toStringAsFixed(2)}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: const FlGridData(show: true),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 1 || idx > _uniAverageTrend.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Text(
                        '#$idx',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1),
            ),
            minX: 1,
            maxX: max(1, _uniAverageTrend.length.toDouble()),
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: _uniAverageTrend,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
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
    switch (type.toLowerCase().trim()) {
      case 'scritto':
        return Colors.blue;
      case 'orale':
        return Colors.green;
      case 'scritto + orale':
        return Colors.indigo;
      case 'pratico':
      case 'pratico / laboratorio':
        return Colors.orange;
      case 'esame':
        return Colors.blueAccent;
      default:
        return Colors.purple;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'scritto':
        return Icons.edit_note;
      case 'orale':
        return Icons.record_voice_over;
      case 'scritto + orale':
        return Icons.assignment_turned_in;
      case 'pratico':
      case 'pratico / laboratorio':
        return Icons.science;
      case 'esame':
        return Icons.workspace_premium;
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

    LineChartBarData buildLine(List<FlSpot> spots, Color color) {
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
              buildLine(firstOrigSpots, Colors.blueAccent),
              buildLine(firstRoundSpots, Colors.purpleAccent),
              buildLine(secondOrigSpots, Colors.orangeAccent),
              buildLine(secondRoundSpots, Colors.pinkAccent),
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

        // 2. Andamento della Media Ponderata
        Text(
          'Andamento della Media Ponderata',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildUniAverageTrendChart(),

        const SizedBox(height: 24),
        const Divider(thickness: 1),
        const SizedBox(height: 8),

        // 3. Grafico distribuzione voti
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
