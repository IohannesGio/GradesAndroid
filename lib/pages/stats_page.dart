import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import 'settings_page.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final dbHelper = DatabaseHelper();
  
  // Variabili per Scuola
  List<Map<String, dynamic>> _historicalOriginalAverages = [];
  List<Map<String, dynamic>> _historicalRoundedAverages = [];
  Map<int, int> _firstPeriodGradeDistribution = {};
  Map<int, int> _secondPeriodGradeDistribution = {};

  // Variabili per Università
  Map<String, int> _universityGradeDistribution = {};

  // Variabili per l'analisi per tipologia
  Map<String, double> _averagesByType = {};
  Map<String, int> _countsByType = {};

  bool _isLoading = true;
  double _maxGrade = 10.0;
  String? _errorMessage;

  // Opzione per selezionare la materia
  String? _selectedSubject;
  List<String> _subjectNames = [];

  @override
  void initState() {
    super.initState();
    _loadSubjectNames();
    _loadMaxGrade();
  }

  Future<void> _loadSubjectNames() async {
    try {
      final subjects = await dbHelper.listSubjects();
      setState(() {
        _subjectNames = subjects.map((s) => s.$1).toList();
        _subjectNames.insert(0, 'Tutte le materie');
        _selectedSubject = _subjectNames.first;
      });
      _loadChartData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento delle materie: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMaxGrade() async {
    final settings = await SettingsPage.loadPassingAndMaxGrades();
    setState(() {
      _maxGrade = settings['max_grade'] ?? 10.0;
    });
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _historicalOriginalAverages = [];
      _historicalRoundedAverages = [];
      _firstPeriodGradeDistribution = {};
      _secondPeriodGradeDistribution = {};
      _universityGradeDistribution = {};
      _averagesByType = {};
      _countsByType = {};
    });

    try {
      final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
      final isUni = modeProvider.isUniversity;

      if (isUni) {
        // Caricamento dati Università
        _universityGradeDistribution = await dbHelper.getUniversityGradeDistribution();
      } else {
        // Caricamento dati Scuola (periodi)
        (
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>
        ) firstPeriodAverages;
        (
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>
        ) secondPeriodAverages;

        if (_selectedSubject == 'Tutte le materie') {
          firstPeriodAverages = await dbHelper.returnAverageByDatePeriod(
              periodName: 'first_period');
          secondPeriodAverages = await dbHelper.returnAverageByDatePeriod(
              periodName: 'second_period');
        } else {
          firstPeriodAverages = await dbHelper.returnAverageBySubjectAndPeriod(
              periodName: 'first_period', subjectName: _selectedSubject!);
          secondPeriodAverages = await dbHelper.returnAverageBySubjectAndPeriod(
              periodName: 'second_period', subjectName: _selectedSubject!);
        }

        Map<int, int> firstPeriodCounts;
        Map<int, int> secondPeriodCounts;

        if (_selectedSubject == 'Tutte le materie') {
          firstPeriodCounts =
              await dbHelper.returnGradeProportionsByPeriod('first_period');
          secondPeriodCounts =
              await dbHelper.returnGradeProportionsByPeriod('second_period');
        } else {
          firstPeriodCounts =
              await dbHelper.returnGradeProportionsByPeriodAndSubject(
                  'first_period', _selectedSubject!);
          secondPeriodCounts =
              await dbHelper.returnGradeProportionsByPeriodAndSubject(
                  'second_period', _selectedSubject!);
        }

        List<Map<String, dynamic>> combinedHistoricalAverages = [];
        for (var avgData in firstPeriodAverages.$1) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'first_period',
            'type': 'original'
          });
        }
        for (var avgData in firstPeriodAverages.$2) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'first_period',
            'type': 'rounded'
          });
        }
        for (var avgData in secondPeriodAverages.$1) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'second_period',
            'type': 'original'
          });
        }
        for (var avgData in secondPeriodAverages.$2) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'second_period',
            'type': 'rounded'
          });
        }
        combinedHistoricalAverages
            .sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));

        _historicalOriginalAverages = combinedHistoricalAverages
            .where((data) => data['type'] == 'original')
            .toList();
        _historicalRoundedAverages = combinedHistoricalAverages
            .where((data) => data['type'] == 'rounded')
            .toList();
        _firstPeriodGradeDistribution = firstPeriodCounts;
        _secondPeriodGradeDistribution = secondPeriodCounts;
      }

      // Analisi per Tipologia
      Map<String, double> averagesByType;
      Map<String, int> countsByType;

      if (_selectedSubject == 'Tutte le materie') {
        averagesByType = await dbHelper.getOverallAveragesByType();
        countsByType = await dbHelper.getGradeCountByType(null);
      } else {
        averagesByType = await dbHelper.getAveragesByType(_selectedSubject!);
        countsByType = await dbHelper.getGradeCountByType(_selectedSubject);
      }

      setState(() {
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
            colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
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
                    color: color.withOpacity(0.2),
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

    final List<Map<String, dynamic>> firstPeriodOriginal =
        _historicalOriginalAverages
            .where((data) => data['period'] == 'first_period')
            .toList();
    final List<Map<String, dynamic>> firstPeriodRounded =
        _historicalRoundedAverages
            .where((data) => data['period'] == 'first_period')
            .toList();
    final List<Map<String, dynamic>> secondPeriodOriginal =
        _historicalOriginalAverages
            .where((data) => data['period'] == 'second_period')
            .toList();
    final List<Map<String, dynamic>> secondPeriodRounded =
        _historicalRoundedAverages
            .where((data) => data['period'] == 'second_period')
            .toList();

    final List<FlSpot> firstPeriodAvgSpots = List.generate(
        firstPeriodOriginal.length,
        (index) => FlSpot(
            index.toDouble(),
            double.parse((firstPeriodOriginal[index]['average_grade'] as double)
                .toStringAsFixed(2))));
    final List<FlSpot> firstPeriodRoundedAvgSpots = List.generate(
        firstPeriodRounded.length,
        (index) => FlSpot(
            index.toDouble(),
            double.parse((firstPeriodRounded[index]['average_grade'] as double)
                .toStringAsFixed(2))));
    final List<FlSpot> secondPeriodAvgSpots = List.generate(
        secondPeriodOriginal.length,
        (index) => FlSpot(
            index.toDouble(),
            double.parse(
                (secondPeriodOriginal[index]['average_grade'] as double)
                    .toStringAsFixed(2))));
    final List<FlSpot> secondPeriodRoundedAvgSpots = List.generate(
        secondPeriodRounded.length,
        (index) => FlSpot(
            index.toDouble(),
            double.parse((secondPeriodRounded[index]['average_grade'] as double)
                .toStringAsFixed(2))));

    double minY = 0;
    double maxY = _maxGrade;
    final allYValues = [
      ...firstPeriodAvgSpots.map((e) => e.y),
      ...firstPeriodRoundedAvgSpots.map((e) => e.y),
      ...secondPeriodAvgSpots.map((e) => e.y),
      ...secondPeriodRoundedAvgSpots.map((e) => e.y)
    ];
    if (allYValues.isNotEmpty) {
      minY = allYValues.reduce((a, b) => a < b ? a : b).floorToDouble();
      maxY = allYValues.reduce((a, b) => a > b ? a : b).ceilToDouble();
      minY = (minY - 1).clamp(0.0, minY);
      maxY = (maxY + 1).clamp(0.0, maxY + maxY * 0.1);
    }
    final int maxPoints =
        max(firstPeriodOriginal.length, secondPeriodOriginal.length);
    final double maxX = (maxPoints > 0 ? maxPoints - 1 : 0).toDouble();

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots
                      .map((spot) => LineTooltipItem(
                          spot.y.toStringAsFixed(2),
                          TextStyle(
                              color: spot.bar.color ?? Colors.white,
                              fontWeight: FontWeight.bold)))
                      .toList();
                },
              ),
            ),
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
              bottomTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1)),
            minX: 0,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                  spots: firstPeriodAvgSpots,
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false)),
              LineChartBarData(
                  spots: firstPeriodRoundedAvgSpots,
                  isCurved: true,
                  color: Colors.purpleAccent,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false)),
              LineChartBarData(
                  spots: secondPeriodAvgSpots,
                  isCurved: true,
                  color: Colors.orangeAccent,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false)),
              LineChartBarData(
                  spots: secondPeriodRoundedAvgSpots,
                  isCurved: true,
                  color: Colors.pinkAccent,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false)),
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
          child:
              Text('Nessun dato disponibile per il grafico di distribuzione.'));
    }

    int maxGradeValue = 0;
    final allGrades = [
      ..._firstPeriodGradeDistribution.keys,
      ..._secondPeriodGradeDistribution.keys
    ];
    if (allGrades.isNotEmpty) maxGradeValue = allGrades.reduce(max);

    int effectiveMaxX = max(maxGradeValue, 10);

    double maxCount = 0;
    final allCounts = [
      ..._firstPeriodGradeDistribution.values,
      ..._secondPeriodGradeDistribution.values
    ];
    if (allCounts.isNotEmpty) maxCount = allCounts.reduce(max).toDouble();
    double maxY = (maxCount + 1).ceilToDouble();

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i <= effectiveMaxX; i++) {
      barGroups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
                toY: (_firstPeriodGradeDistribution[i] ?? 0).toDouble(),
                color: Colors.blueAccent,
                width: 7),
            BarChartRodData(
                toY: (_secondPeriodGradeDistribution[i] ?? 0).toDouble(),
                color: Colors.orangeAccent,
                width: 7),
          ],
          barsSpace: 2));
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: BarChart(BarChartData(
            barGroups: barGroups,
            barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                        '${r.toY.toInt()}',
                        const TextStyle(color: Colors.white)))),
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (v, m) => SideTitleWidget(
                          meta: m,
                          space: 8,
                          child: Text('${v.toInt()}',
                              style: const TextStyle(fontSize: 10))))),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1)),
            minY: 0,
            maxY: maxY)),
      ),
    );
  }

  Widget _buildUniversityGradeDistributionChart() {
    final keys = ['18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '30L'];
    
    int maxCount = 0;
    for (var k in keys) {
      final cnt = _universityGradeDistribution[k] ?? 0;
      if (cnt > maxCount) maxCount = cnt;
    }
    final double maxY = (maxCount + 1).toDouble();

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final count = _universityGradeDistribution[key] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: key == '30L' ? Colors.amber : Colors.blueAccent,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
                  '${keys[g.x]}: ${r.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (v, m) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < keys.length) {
                      return SideTitleWidget(
                        meta: m,
                        space: 4,
                        child: Text(
                          keys[idx],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: keys[idx] == '30L' ? FontWeight.bold : FontWeight.normal,
                            color: keys[idx] == '30L' ? Colors.amber[800] : null,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Errore: $_errorMessage'))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Dropdown per selezionare la materia/insegnamento
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSubject,
                      decoration: InputDecoration(
                        labelText: isUni ? 'Seleziona Insegnamento' : 'Seleziona Materia',
                        border: const OutlineInputBorder(),
                      ),
                      items: _subjectNames.map((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedSubject = newValue;
                          });
                          _loadChartData();
                        }
                      },
                    ),

                    if (!isUni) ...[
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
                          _buildLegendRow(
                              Colors.blueAccent, 'Primo Quadrimestre - Media'),
                          _buildLegendRow(Colors.purpleAccent,
                              'Primo Quadrimestre - Arrotondata'),
                          _buildLegendRow(Colors.orangeAccent,
                              'Secondo Quadrimestre - Media'),
                          _buildLegendRow(Colors.pinkAccent,
                              'Secondo Quadrimestre - Arrotondata'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Divider(thickness: 2),
                      const SizedBox(height: 16),
                    ],

                    // Distribuzione dei Voti
                    Text(
                      isUni ? 'Distribuzione Voti Esami (18 - 30L)' : 'Distribuzione dei Voti',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    isUni
                        ? _buildUniversityGradeDistributionChart()
                        : _buildSchoolGradeDistributionChart(),

                    const SizedBox(height: 16),

                    if (isUni)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendRow(Colors.blueAccent, 'Esami (18 - 30)'),
                          const SizedBox(width: 24),
                          _buildLegendRow(Colors.amber, '30 e Lode (30L)'),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendRow(
                              Colors.blueAccent, 'Primo Quadrimestre'),
                          _buildLegendRow(
                              Colors.orangeAccent, 'Secondo Quadrimestre'),
                        ],
                      ),

                    const SizedBox(height: 32),
                    const Divider(thickness: 2),
                    const SizedBox(height: 16),

                    // Analisi per Tipologia
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
                            style: TextStyle(color: Theme.of(context).disabledColor),
                          ),
                        ),
                      )
                    else ...[
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
                  ],
                ),
    );
  }
}
