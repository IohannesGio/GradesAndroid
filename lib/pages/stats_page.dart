import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../database_helper.dart';
import 'settings_page.dart';

class StatisticsPage extends StatefulWidget {
  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final dbHelper = DatabaseHelper();
  // Variabili per i dati dei grafici esistenti
  List<Map<String, dynamic>> _historicalOriginalAverages = [];
  List<Map<String, dynamic>> _historicalRoundedAverages = [];
  Map<int, int> _firstPeriodGradeDistribution = {};
  Map<int, int> _secondPeriodGradeDistribution = {};

  // Variabili per l'analisi per tipologia
  Map<String, double> _averagesByType = {};
  Map<String, int> _countsByType = {};

  bool _isLoading = true;
  double _maxGrade = 10.0;
  String? _errorMessage;

  // Opzione per selezionare la materia (null per tutte le materie)
  String? _selectedSubject;
  List<String> _subjectNames = [];

  @override
  void initState() {
    super.initState();
    _loadSubjectNames();
    _loadMaxGrade();
  }

  // Carica i nomi delle materie per il dropdown
  Future<void> _loadSubjectNames() async {
    try {
      final subjects = await dbHelper.listSubjects();
      setState(() {
        _subjectNames = subjects.map((s) => s.$1).toList();
        _subjectNames.insert(0, 'Tutte le materie');
        _selectedSubject = _subjectNames.first;
      });
      _loadChartData(); // Carica tutti i dati
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

  // Carica tutti i dati (grafici esistenti + analisi tipologia)
  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Resetta dati
      _historicalOriginalAverages = [];
      _historicalRoundedAverages = [];
      _firstPeriodGradeDistribution = {};
      _secondPeriodGradeDistribution = {};
      _averagesByType = {};
      _countsByType = {};
    });
    try {
      // 1. Caricamento dati grafici esistenti
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

      // 2. Caricamento dati Analisi Tipologia
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
        // Elaborazione dati grafici esistenti
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

        // Impostazione dati analisi tipologia
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
      print('Errore nel caricamento dei dati: $e');
    }
  }

  // --- Helpers per Analisi Tipologia ---

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'scritto':
        return Colors.blue;
      case 'orale':
        return Colors.green;
      case 'pratico':
        return Colors.orange;
      default:
        return Colors.grey;
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count ${count == 1 ? 'voto' : 'voti'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Media',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  average.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypeAnalysisBarChart() {
    if (_averagesByType.isEmpty) return const SizedBox.shrink();

    final types = _averagesByType.keys.toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confronto Tipologie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxGrade,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          rod.toY.toStringAsFixed(2),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < types.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                types[value.toInt()],
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    types.length,
                    (index) {
                      final type = types[index];
                      final average = _averagesByType[type]!;
                      final color = _getColorForType(type);

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: average,
                            color: color,
                            width: 30, // Larghezza barra leggermente ridotta
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  // --- Metodi esistenti per i grafici classici ---

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
        padding:
            const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipColor: (spot) {
                  final brightness = Theme.of(context).brightness;
                  return brightness == Brightness.dark
                      ? Colors.grey[800]!.withOpacity(0.9)
                      : Colors.white.withOpacity(0.9);
                },
                getTooltipItems: (touchedSpots) {
                  return touchedSpots
                      .map((spot) => LineTooltipItem(
                          '${spot.y.toStringAsFixed(2)}',
                          TextStyle(
                              color: spot.bar.color ?? Colors.black,
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

  Future<Widget> _buildGradeDistributionChart() async {
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

    final gradesSettings = await SettingsPage.loadPassingAndMaxGrades();
    final int maxPossibleGrade = gradesSettings['max_grade']?.toInt() ?? 10;
    int effectiveMaxX = max(maxGradeValue, maxPossibleGrade);

    double maxCount = 0;
    final allCounts = [
      ..._firstPeriodGradeDistribution.values,
      ..._secondPeriodGradeDistribution.values
    ];
    if (allCounts.isNotEmpty) maxCount = allCounts.reduce(max).toDouble();
    double maxY = (maxCount + 1).ceilToDouble();

    int mostFrequentGrade = 0;
    int maxFrequency = 0;
    for (int i = 0; i <= effectiveMaxX; i++) {
      final totalCount = (_firstPeriodGradeDistribution[i] ?? 0) +
          (_secondPeriodGradeDistribution[i] ?? 0);
      if (totalCount > maxFrequency) {
        maxFrequency = totalCount;
        mostFrequentGrade = i;
      }
    }

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

    return LayoutBuilder(builder: (context, constraints) {
      final int barCount = effectiveMaxX + 1;
      const double minWidthPerBar = 40.0;
      final double requiredWidth = barCount * minWidthPerBar;
      final bool needsScroll = requiredWidth > constraints.maxWidth;
      final ScrollController scrollController = ScrollController();

      Widget chartWidget = AspectRatio(
        aspectRatio: 1.5,
        child: Padding(
          padding:
              const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
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

      if (needsScroll) {
        final double scrollPosition = (mostFrequentGrade * minWidthPerBar) -
            (constraints.maxWidth / 2) +
            (minWidthPerBar / 2);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients)
            scrollController.jumpTo(scrollPosition.clamp(
                0.0, requiredWidth - constraints.maxWidth));
        });
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: scrollController,
            child: SizedBox(width: requiredWidth, child: chartWidget));
      } else {
        return chartWidget;
      }
    });
  }

  Widget _buildLegendRow(Color color, String label) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium)
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Errore: $_errorMessage'))
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Dropdown per selezionare la materia
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      decoration: const InputDecoration(
                          labelText: 'Seleziona Materia',
                          border: OutlineInputBorder()),
                      items: _subjectNames.map((String subject) {
                        return DropdownMenuItem<String>(
                            value: subject, child: Text(subject));
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
                    const SizedBox(height: 24),

                    Text(
                        _selectedSubject == 'Tutte le materie'
                            ? 'Andamento della Media Generale'
                            : 'Andamento Media: $_selectedSubject',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    _buildAverageTrendChart(context),
                    const SizedBox(height: 16),
                    // Legenda grafico a linee
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

                    Text('Distribuzione dei Voti',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FutureBuilder<Widget>(
                      future: _buildGradeDistributionChart(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                              child: CircularProgressIndicator());
                        return snapshot.data ?? const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 16),
                    // Legenda grafico a barre distribuzione
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

                    // --- SEZIONE ANALISI TIPOLOGIA ---
                    Text('Analisi per Tipologia',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    if (_averagesByType.isEmpty)
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                  'Nessun dato disponibile per tipologia.',
                                  style: TextStyle(color: Colors.grey[600]))))
                    else ...[
                      // Grafico confronto tipologie
                      _buildTypeAnalysisBarChart(),
                      const SizedBox(height: 24),
                      // Card dettagliate per tipologia
                      ..._averagesByType.entries.map((entry) {
                        final type = entry.key;
                        final average = entry.value;
                        final count = _countsByType[type] ?? 0;
                        return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildTypeCard(type, average, count));
                      }).toList(),
                    ],
                  ],
                ),
    );
  }
}
