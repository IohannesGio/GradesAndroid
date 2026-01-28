import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../database_helper.dart';
import 'subject_detail_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dbHelper = DatabaseHelper();
  // Modificato per includere la media della materia nel tuple: (Nome, Obiettivo, Media Periodo)
  List<(String, String, String)> _subjects = [];
  String _overallAveragePeriod =
      'N/A'; // Media generale del periodo corrente (non arrotondata)
  String _overallRoundedAveragePeriod =
      'N/A'; // Media generale del periodo corrente (arrotondata)
  String _averageObjective = 'N/A'; // Obiettivo generale
  double _passingGrade = 6.0; // Default, poi caricato dalle preferenze

  @override
  void initState() {
    super.initState();
    _loadPassingGrade();
    _loadData();
  }

  // Funzione per caricare i dati della HomePage (medie per periodo)
  Future<void> _loadData() async {
    // Ottieni la lista di tutte le materie con i loro obiettivi
    final subjectsWithObjectives = await dbHelper.listSubjects();
    final List<(String, String, String)> subjectsWithAverage = [];

    // Ottieni le medie per materia filtrate per il periodo corrente
    final subjectAveragesPeriod = await dbHelper.returnAveragesByPeriod();

    // Crea una mappa per accedere facilmente alle medie per materia
    final Map<String, String> subjectAveragesMap = Map.fromEntries(
        subjectAveragesPeriod.map((item) => MapEntry(item.$1, item.$2)));

    double sumOfRoundedSubjectAverages =
        0.0; // Somma delle medie arrotondate delle materie nel periodo
    int countOfSubjectsWithAverageInPeriod =
        0; // Contatore per le medie valide nel periodo

    // Per ogni materia, ottieni il suo obiettivo e la sua media del periodo corrente
    for (var subjectInfo in subjectsWithObjectives) {
      final subjectName = subjectInfo.$1;
      final objective = subjectInfo.$2;
      // Prendi la media dal risultato di returnAveragesByPeriod
      final average = subjectAveragesMap[subjectName] ?? 'N/A';

      subjectsWithAverage.add((subjectName, objective, average));

      // Calcola la somma delle medie arrotondate delle materie nel periodo
      if (average != 'N/A') {
        final double? avgDouble = double.tryParse(average);
        if (avgDouble != null) {
          final roundedAvgSubject = dbHelper.roundCustom(
              avgDouble); // Usa la funzione di arrotondamento del DB Helper
          sumOfRoundedSubjectAverages += roundedAvgSubject;
          countOfSubjectsWithAverageInPeriod++;
        }
      }
    }

    // Calcola la media delle medie arrotondate delle materie nel periodo
    String calculatedOverallRoundedAveragePeriod = 'N/A';
    if (countOfSubjectsWithAverageInPeriod > 0) {
      calculatedOverallRoundedAveragePeriod =
          (sumOfRoundedSubjectAverages / countOfSubjectsWithAverageInPeriod)
              .toStringAsFixed(2);
    }

    // Ordina le materie per media (dalla più alta alla più bassa)
    // Gestisce i casi in cui la media è 'N/A' (li mette alla fine)
    subjectsWithAverage.sort((a, b) {
      final double? avgA = double.tryParse(a.$3);
      final double? avgB = double.tryParse(b.$3);

      if (avgA == null && avgB == null)
        return 0; // Entrambe N/A, mantieni l'ordine relativo
      if (avgA == null) return 1; // A è N/A, mettilo dopo B
      if (avgB == null) return -1; // B è N/A, mettilo dopo A

      return avgB.compareTo(avgA); // Ordine decrescente per media
    });

    // Ottieni la media generale del periodo corrente (non arrotondata)
    final overallAvgPeriod = await dbHelper.returnGeneralAverageByPeriod();

    // Ottieni la media degli obiettivi generali (non filtrata per periodo)
    final avgObj = await dbHelper.returnAverageObjective();

    setState(() {
      _subjects =
          subjectsWithAverage; // Aggiorna la lista delle materie con le medie ordinata
      _overallAveragePeriod =
          overallAvgPeriod; // Aggiorna la media generale del periodo (non arrotondata)
      _overallRoundedAveragePeriod =
          calculatedOverallRoundedAveragePeriod; // Aggiorna la media generale del periodo (arrotondata)
      _averageObjective = avgObj; // Aggiorna l'obiettivo generale
    });
  }

  Future<void> _loadPassingGrade() async {
    final grades = await SettingsPage.loadPassingAndMaxGrades();
    setState(() {
      _passingGrade = grades['passing_grade'] ?? 6.0;
    });
  }

  void _showAddSubjectDialog() {
    final nameController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Aggiungi Materia'),
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nome materia',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      try {
                        await dbHelper.addSubject(name);
                        Navigator.pop(context);
                        _loadData(); // Ricarica i dati dopo aver aggiunto una materia
                      } catch (e) {
                        setState(() => errorText = e.toString());
                      }
                    } else {
                      setState(
                          () => errorText = 'Il campo non può essere vuoto');
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

  // Naviga alla SubjectDetailPage e ricarica i dati al ritorno
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
    // Ricarica i dati quando si torna dalla pagina dei dettagli
    _loadData();
  }

  // Metodo per costruire le card statistiche nella HomePage
  Widget _buildStatCard(String label, String value) {
    Color _getColorForValue(String label, String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey.withOpacity(0.2); // Se è N/A o errore
      if (label == 'Obiettivo') {
        return Colors.blue.withOpacity(0.2); // Blu chiaro per obiettivo
      }
      return val >= _passingGrade
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2);
    }

    Color _getTextColorForBackground(String label, String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey;
      if (label == 'Obiettivo') {
        return Colors.blue;
      }
      return val >= _passingGrade ? Colors.green : Colors.red;
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
              SizedBox(
                width: 80,
                height: 40,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getColorForValue(label, value),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    textAlign: TextAlign.center,
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getTextColorForBackground(label, value),
                    ),
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
  Widget build(context) {
    Color _getColorForValue(String label, String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey.withOpacity(0.2);
      if (label == 'Obiettivo') {
        return Colors.blue.withOpacity(0.2);
      }
      return val >= _passingGrade
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2);
    }

    Color _getTextColorForBackground(String label, String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey;
      if (label == 'Obiettivo') {
        return Colors.blue;
      }
      return val >= _passingGrade ? Colors.green : Colors.red;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Prima card: Media (media generale del periodo corrente non arrotondata)
                _buildStatCard(
                    'Media', _overallAveragePeriod), // Etichetta ripristinata
                // Seconda card: Media Arrotondata (media generale del periodo corrente arrotondata)
                _buildStatCard('Media Arrotondata',
                    _overallRoundedAveragePeriod), // Etichetta ripristinata
                // Terza card: Obiettivo Generale (media degli obiettivi delle materie)
                _buildStatCard('Obiettivo', _averageObjective),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _subjects.length,
              itemBuilder: (_, i) {
                final subjectName = _subjects[i].$1;
                final average = _subjects[i].$3;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: InkWell(
                    onTap: () => _navigateToSubjectDetails(subjectName),
                    borderRadius: BorderRadius.circular(20),
                    child: Hero(
                      tag: subjectName,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  subjectName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                height: 40,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getColorForValue('Media', average),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    average,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _getTextColorForBackground(
                                          'Media', average),
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
            ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.2, end: 0),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuova Materia'),
        tooltip: 'Aggiungi Nuova Materia',
      ),
    );
  }
}
