import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database_helper.dart';
import 'settings_page.dart';

class StatisticsPage extends StatefulWidget {
  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final dbHelper = DatabaseHelper();
  // Variabili per i dati dei grafici
  // Aggiornato per riflettere il tipo di ritorno di returnAverageByDatePeriod
  List<Map<String, dynamic>> _historicalOriginalAverages = [];
  List<Map<String, dynamic>> _historicalRoundedAverages = [];
  // Aggiornato per riflettere il tipo di ritorno di returnGradeProportionsByPeriod
  Map<int, int> _firstPeriodGradeDistribution = {};
  Map<int, int> _secondPeriodGradeDistribution = {};

  bool _isLoading = true;
  double _maxGrade = 10.0;
  String? _errorMessage;

  // Opzione per selezionare la materia (null per tutte le materie)
  String? _selectedSubject;
  List<String> _subjectNames =
      []; // Lista dei nomi delle materie per il dropdown

  @override
  void initState() {
    super.initState();
    _loadSubjectNames(); // Carica i nomi delle materie all'avvio
    _loadMaxGrade();
  }

  // Carica i nomi delle materie per il dropdown
  Future<void> _loadSubjectNames() async {
    try {
      final subjects = await dbHelper.listSubjects();
      setState(() {
        _subjectNames = subjects.map((s) => s.$1).toList();
        _subjectNames.insert(
            0, 'Tutte le materie'); // Aggiungi l'opzione "Tutte le materie"
        _selectedSubject =
            _subjectNames.first; // Seleziona l'opzione predefinita
      });
      // Carica i dati dei grafici dopo aver caricato i nomi delle materie
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

  // Carica i dati per entrambi i grafici
  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Resetta i dati dei grafici prima di caricarli nuovamente
      _historicalOriginalAverages = [];
      _historicalRoundedAverages = [];
      _firstPeriodGradeDistribution = {};
      _secondPeriodGradeDistribution = {};
    });
    try {
      // Dichiarazione delle variabili per contenere i risultati delle medie
      (
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      ) firstPeriodAverages;
      (
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      ) secondPeriodAverages;

      // Controlla la materia selezionata per decidere quale funzione chiamare per il grafico di andamento
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

      // Logica per il grafico a barre di distribuzione dei voti
      // Qui dobbiamo chiamare la funzione corretta in base a _selectedSubject
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

      setState(() {
        // Per il grafico di andamento, combiniamo i dati dei due periodi
        // returnAverageByDatePeriod restituisce (originali, arrotondate) per *quel* periodo.
        // Dobbiamo etichettare i punti con il loro periodo per il grafico.
        // Modifichiamo la struttura dati per includere l'informazione del periodo.
        List<Map<String, dynamic>> combinedHistoricalAverages = [];

        // Aggiungi dati del primo periodo
        for (var avgData in firstPeriodAverages.$1) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'first_period',
            'type': 'original',
          });
        }
        for (var avgData in firstPeriodAverages.$2) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'first_period',
            'type': 'rounded',
          });
        }

        // Aggiungi dati del secondo periodo
        for (var avgData in secondPeriodAverages.$1) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'second_period',
            'type': 'original',
          });
        }
        for (var avgData in secondPeriodAverages.$2) {
          combinedHistoricalAverages.add({
            'date': avgData['date'],
            'average_grade': avgData['average_grade'],
            'period': 'second_period',
            'type': 'rounded',
          });
        }

        // Ordina i dati combinati per data per il grafico di andamento
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

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento dei dati dei grafici: $e';
        _isLoading = false;
      });
      print('Errore nel caricamento dei dati dei grafici: $e');
    }
  }

  // Costruisce il grafico a linee per l'andamento della media
  Widget _buildAverageTrendChart(BuildContext context) {
    // Usiamo _historicalOriginalAverages e _historicalRoundedAverages che contengono i dati combinati
    if (_historicalOriginalAverages.isEmpty &&
        _historicalRoundedAverages.isEmpty) {
      return const Center(
          child: Text('Nessun dato disponibile per il grafico di andamento.'));
    }

    // Separa i dati per periodo e tipo per poterli indicizzare separatamente
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

    // Crea i FlSpot usando l'indice all'interno di ciascun periodo come valore X
    final List<FlSpot> firstPeriodAvgSpots =
        List.generate(firstPeriodOriginal.length, (index) {
      return FlSpot(
        index.toDouble(),
        double.parse((firstPeriodOriginal[index]['average_grade'] as double)
            .toStringAsFixed(2)),
      );
    });

    final List<FlSpot> firstPeriodRoundedAvgSpots =
        List.generate(firstPeriodRounded.length, (index) {
      return FlSpot(
        index.toDouble(),
        double.parse((firstPeriodRounded[index]['average_grade'] as double)
            .toStringAsFixed(2)),
      );
    });

    final List<FlSpot> secondPeriodAvgSpots =
        List.generate(secondPeriodOriginal.length, (index) {
      return FlSpot(
        index.toDouble(),
        double.parse((secondPeriodOriginal[index]['average_grade'] as double)
            .toStringAsFixed(2)),
      );
    });

    final List<FlSpot> secondPeriodRoundedAvgSpots =
        List.generate(secondPeriodRounded.length, (index) {
      return FlSpot(
        index.toDouble(),
        double.parse((secondPeriodRounded[index]['average_grade'] as double)
            .toStringAsFixed(2)),
      );
    });

    // Determina i valori min/max per l'asse Y
    double minY = 0;
    double maxY = _maxGrade;

    final allYValues = [
      ...firstPeriodAvgSpots.map((e) => e.y),
      ...firstPeriodRoundedAvgSpots.map((e) => e.y),
      ...secondPeriodAvgSpots.map((e) => e.y),
      ...secondPeriodRoundedAvgSpots.map((e) => e.y),
    ];
    if (allYValues.isNotEmpty) {
      minY = allYValues.reduce((a, b) => a < b ? a : b).floorToDouble();
      maxY = allYValues.reduce((a, b) => a > b ? a : b).ceilToDouble();
      // Aggiungi un po' di margine
      minY = (minY - 1).clamp(0.0, minY);
      maxY = (maxY + 1).clamp(0.0, maxY + maxY * 0.1);
    }

    // Determina il numero massimo di punti in un singolo periodo per definire maxX
    final int maxPoints =
        max(firstPeriodOriginal.length, secondPeriodOriginal.length);
    final double maxX = (maxPoints > 0 ? maxPoints - 1 : 0).toDouble();

    return AspectRatio(
      aspectRatio: 1.5, // Rapporto d'aspetto del grafico
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
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(2)}',
                      TextStyle(
                        color: spot.bar.color ?? Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: false,
                  reservedSize: 30,
                  interval: 1, // Mostra un'etichetta per ogni punto sull'asse X
                  getTitlesWidget: (value, meta) {
                    // Mostra l'indice del punto dati sull'asse X (partendo da 1)
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      child: Text('${value.toInt() + 1}',
                          style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
              ),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xff37434d), width: 1),
            ),
            minX: 0,
            maxX: maxX, // Usa il numero massimo di punti in un periodo
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              // Linea Media Primo Quadrimestre (Originale)
              LineChartBarData(
                spots: firstPeriodAvgSpots,
                isCurved: true,
                color: Colors.blueAccent,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
              // Linea Media Arrotondata Primo Quadrimestre
              LineChartBarData(
                spots: firstPeriodRoundedAvgSpots,
                isCurved: true,
                color: Colors.purpleAccent,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
              // Linea Media Secondo Quadrimestre (Originale)
              LineChartBarData(
                spots: secondPeriodAvgSpots,
                isCurved: true,
                color: Colors.orangeAccent,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
              // Linea Media Arrotondata Secondo Quadrimestre
              LineChartBarData(
                spots: secondPeriodRoundedAvgSpots,
                isCurved: true,
                color: Colors.pinkAccent,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Costruisce il grafico a barre per la distribuzione dei voti
  Future<Widget> _buildGradeDistributionChart() async {
    // Usiamo _firstPeriodGradeDistribution e _secondPeriodGradeDistribution
    if (_firstPeriodGradeDistribution.isEmpty &&
        _secondPeriodGradeDistribution.isEmpty) {
      return const Center(
          child:
              Text('Nessun dato disponibile per il grafico di distribuzione.'));
    }

    // Trova il voto massimo presente nei dati
    int maxGradeValue = 0;
    final allGrades = [
      ..._firstPeriodGradeDistribution.keys,
      ..._secondPeriodGradeDistribution.keys
    ];
    if (allGrades.isNotEmpty) {
      maxGradeValue = allGrades.reduce(max);
    }

    final gradesSettings = await SettingsPage.loadPassingAndMaxGrades();
    final int maxPossibleGrade = gradesSettings['max_grade']?.toInt() ?? 10;
    int effectiveMaxX = max(maxGradeValue, maxPossibleGrade);

    // Determina il valore massimo sull'asse Y (conteggio massimo)
    double maxCount = 0;
    final allCounts = [
      ..._firstPeriodGradeDistribution.values,
      ..._secondPeriodGradeDistribution.values
    ];
    if (allCounts.isNotEmpty) {
      maxCount = allCounts.reduce(max).toDouble();
    }
    double maxY = (maxCount + 1).ceilToDouble();

    // Crea i BarChartGroupData
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i <= effectiveMaxX; i++) {
      final firstPeriodCount = _firstPeriodGradeDistribution[i] ?? 0;
      final secondPeriodCount = _secondPeriodGradeDistribution[i] ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: firstPeriodCount.toDouble(),
              color: Colors.blueAccent,
              width: 7,
            ),
            BarChartRodData(
              toY: secondPeriodCount.toDouble(),
              color: Colors.orangeAccent,
              width: 7,
            ),
          ],
          barsSpace: 2,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcola la larghezza necessaria per il grafico
        final int barCount = effectiveMaxX + 1;
        const double minWidthPerBar = 40.0;
        final double requiredWidth = barCount * minWidthPerBar;
        final bool needsScroll = requiredWidth > constraints.maxWidth;

        Widget chartWidget = AspectRatio(
          aspectRatio: 1.5,
          child: Padding(
            padding:
                const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipColor: (group) {
                      final brightness = Theme.of(context).brightness;
                      return brightness == Brightness.dark
                          ? Colors.grey[800]!.withOpacity(0.9)
                          : Colors.white.withOpacity(0.9);
                    },
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()}',
                        TextStyle(
                          color: rod.color ?? Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text('${value.toInt()}',
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xff37434d), width: 1),
                ),
                minY: 0,
                maxY: maxY,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        );

        // Se serve lo scroll, avvolgi in SingleChildScrollView
        if (needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: requiredWidth,
              child: chartWidget,
            ),
          );
        } else {
          return chartWidget;
        }
      },
    );
  }

  // Helper per costruire una riga della legenda
  Widget _buildLegendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
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
                      decoration:
                          const InputDecoration(labelText: 'Seleziona Materia'),
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
                          _loadChartData(); // Ricarica i dati quando la materia cambia
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _selectedSubject == 'Tutte le materie'
                          ? 'Andamento della Media Generale nel Tempo'
                          : 'Andamento Media: $_selectedSubject',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildAverageTrendChart(
                        context), // Non ha bisogno di await qui
                    const SizedBox(height: 16),
                    // Legenda per il grafico a linee
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendRow(
                            Colors.blueAccent, 'Primo Quadrimestre - Media'),
                        _buildLegendRow(Colors.purpleAccent,
                            'Primo Quadrimestre - Media Arrotondata'),
                        _buildLegendRow(Colors.orangeAccent,
                            'Secondo Quadrimestre - Media'),
                        _buildLegendRow(Colors.pinkAccent,
                            'Secondo Quadrimestre - Media Arrotondata'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Distribuzione dei Voti', // Rimosso "(Periodo Selezionato)"
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Chiama _buildGradeDistributionChart con await
                    FutureBuilder<Widget>(
                      future: _buildGradeDistributionChart(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(
                                  'Errore nel grafico: ${snapshot.error}'));
                        } else {
                          return snapshot.data ??
                              const SizedBox
                                  .shrink(); // Mostra il grafico o un widget vuoto
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Legenda per il grafico a barre
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendRow(
                            Colors.blueAccent, 'Primo Quadrimestre'),
                        _buildLegendRow(
                            Colors.orangeAccent, 'Secondo Quadrimestre'),
                      ],
                    ),
                  ],
                ),
    );
  }
}
