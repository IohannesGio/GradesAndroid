import 'package:flutter/material.dart';
import 'database_helper.dart'; // Assicurati che questo import punti al tuo file database_helper.dart
import 'package:intl/intl.dart'; // Importa il pacchetto intl per la formattazione della data
import 'package:shared_preferences/shared_preferences.dart'; // Importa SharedPreferences per salvare i periodi e i voti min/max
import 'package:fl_chart/fl_chart.dart'; // Importa la libreria fl_chart
import 'dart:math'; // Importa per max
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'Gestione Voti',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme ??
              ColorScheme.fromSeed(
                seedColor: Colors.indigo,
              ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme ??
              ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
        ),
        home: MainNavigation(),
      );
    });
  }
}

class MainNavigation extends StatefulWidget {
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _pages = [HomePage(), StatisticsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        // Le icone standard di Material Design (come Icons.home, Icons.bar_chart, Icons.settings)
        // hanno automaticamente l'animazione di riempimento/contorno quando selezionate.
        // Non è necessario fare modifiche qui per ottenere l'effetto desiderato.
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Statistiche'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Impostazioni'),
        ],
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
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
      MaterialPageRoute(
        builder: (context) => SubjectDetailPage(subjectName: subjectName),
      ),
    );
    // Ricarica i dati quando si torna dalla pagina dei dettagli
    _loadData();
  }

  // Metodo per costruire le card statistiche nella HomePage
  Widget _buildStatCard(String label, String value) {
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
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(context) {
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
                final objective = _subjects[i].$2; // Obiettivo della materia
                final average =
                    _subjects[i].$3; // Media della materia del periodo corrente

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child:
                      // Avvolgi il Container con un Hero widget
                      Hero(
                    tag:
                        subjectName, // Usa il nome della materia come tag unico
                    child: InkWell(
                      onTap: () => _navigateToSubjectDetails(subjectName),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          // Usa Row per allineare nome e media
                          mainAxisAlignment: MainAxisAlignment
                              .spaceBetween, // Spazia tra nome e media
                          children: [
                            Text(subjectName,
                                style: Theme.of(context).textTheme.titleMedium),
                            // Mostra la media della materia con stile prominente, senza etichetta
                            Text(
                              average, // Mostra la media del periodo corrente per la materia
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    // Stile simile a quello prominente
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary, // Colore primario
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Correzione: Usa FloatingActionButton.extended
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuova Materia'), // Aggiunta l'etichetta
        tooltip: 'Aggiungi Nuova Materia', // Aggiornato il tooltip
      ),
    );
  }
}

// Helper function to format intYYYYMMDD to String DD-MM-YYYY
String formatIntDateToDisplay(int? dateInt) {
  if (dateInt == null) return 'N/A';
  try {
    final dateString = dateInt.toString();
    if (dateString.length != 8) return 'Invalid Date'; // Basic validation
    final dateTime = DateTime.parse(
        '${dateString.substring(0, 4)}-${dateString.substring(4, 6)}-${dateString.substring(6, 8)}');
    return DateFormat('dd-MM-yyyy').format(dateTime);
  } catch (e) {
    print('Error formatting date $dateInt: $e');
    return 'Invalid Date';
  }
}

// Helper function to parse String DD-MM-YYYY to intYYYYMMDD
int? parseDisplayDateToInt(String dateString) {
  if (dateString.isEmpty) return null;
  try {
    final dateTime = DateFormat('dd-MM-yyyy').parse(dateString);
    return int.parse(DateFormat('yyyyMMdd').format(dateTime));
  } catch (e) {
    print('Error parsing date $dateString: $e');
    return null;
  }
}

class SubjectDetailPage extends StatefulWidget {
  final String subjectName;

  const SubjectDetailPage({required this.subjectName});

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  final dbHelper = DatabaseHelper();
  List<Grade> _grades = [];
  String _averagePeriod =
      'N/A'; // Media del periodo corrente per questa materia
  String _averageFirstPeriod = 'N/A'; // Media del primo quadrimestre
  String _objective = 'N/A';

  // Variabili per gestire lo stato dei selettori nell'AlertDialog
  final TextEditingController _dateController = TextEditingController();
  String _selectedType = 'orale'; // Valore predefinito per il tipo

  // Variabili per i messaggi di errore
  String? _gradeErrorText;
  String? _dateErrorText;
  String? _weightErrorText;

  // Variabili per i voti di sufficienza e massimo
  double _passingGrade = 6.0; // Valore predefinito per la sufficienza
  double _maxGrade = 10.0; // Valore predefinito

  @override
  void initState() {
    super.initState();
    _loadSubjectData();
    _loadPassingAndMaxGrades(); // Carica i voti di sufficienza e massimo
  }

  @override
  void dispose() {
    // Pulisci i controller quando il widget viene eliminato
    _dateController.dispose();
    super.dispose();
  }

  // Carica i voti di sufficienza e massimo da SharedPreferences
  Future<void> _loadPassingAndMaxGrades() async {
    final grades = await SettingsPage.loadPassingAndMaxGrades();
    setState(() {
      _passingGrade = grades['passing_grade']!;
      _maxGrade = grades['max_grade']!;
    });
  }

  // Carica i dati della materia (voti e medie per periodo)
  Future<void> _loadSubjectData() async {
    // Carica tutti i voti per la materia (la lista visibile non è filtrata per periodo)
    // La funzione listGrades nel database_helper.dart già ordina per data DESC
    final grades = await dbHelper.listGrades(widget.subjectName);

    // Calcola la media per il periodo corrente usando returnAverageByPeriodBis
    final avgPeriod =
        await dbHelper.returnAverageByPeriodBis(widget.subjectName);

    // Calcola la media per il primo quadrimestre (sempre) usando returnAverageByPeriod
    int? firstPeriodStart;
    int? firstPeriodEnd;
    final periods = await SettingsPage._loadPeriodsFromPreferences();
    if (periods != null &&
        periods.containsKey('first_period_start') &&
        periods.containsKey('first_period_end')) {
      try {
        // Parsifica le date dal formato salvato (DD-MM-YYYY) e converti in intYYYYMMDD
        final DateTime startDateTime =
            DateFormat('dd-MM-yyyy').parse(periods['first_period_start']!);
        firstPeriodStart =
            int.parse(DateFormat('yyyyMMdd').format(startDateTime));

        final DateTime endDateTime =
            DateFormat('dd-MM-yyyy').parse(periods['first_period_end']!);
        firstPeriodEnd = int.parse(DateFormat('yyyyMMdd').format(endDateTime));
      } catch (e) {
        print(
            'Errore nel parsing delle date del primo periodo per il calcolo della media: $e');
      }
    }

    String avg1 = 'N/A';
    if (firstPeriodStart != null && firstPeriodEnd != null) {
      avg1 = await dbHelper.returnAverageByPeriod(
          widget.subjectName, firstPeriodStart, firstPeriodEnd);
    }

    final obj = await dbHelper
        .returnObjective(widget.subjectName); // Ottieni l'obiettivo

    setState(() {
      _grades =
          grades; // La lista dei voti mostrata è sempre completa e ordinata
      _averagePeriod = avgPeriod; // Media del periodo corrente
      _averageFirstPeriod = avg1; // Media del primo quadrimestre
      _objective = obj; // Obiettivo
    });
  }

  // Funzione per mostrare il selettore di data
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      // Formatta la data per la visualizzazione (DD-MM-YYYY)
      final String formattedDateDisplay =
          DateFormat('dd-MM-yyyy').format(picked);
      controller.text = formattedDateDisplay;
      // Resetta l'errore della data quando una data viene selezionata
      setState(() {
        _dateErrorText = null;
      });
    }
  }

  void _showGradeDialog({Grade? existing}) {
    final gradeController =
        TextEditingController(text: existing?.grade.toString());
    // Inizializza il dateController con la data esistente formattata per la visualizzazione (DD-MM-YYYY)
    if (existing?.date != null) {
      _dateController.text = formatIntDateToDisplay(existing!.date);
    } else {
      _dateController.text = '';
    }

    final weightController =
        TextEditingController(text: existing?.weight.toString());
    // Imposta il tipo selezionato in base al voto esistente o al valore predefinito
    _selectedType = existing?.type ?? 'orale';

    // Resetta i messaggi di errore all'apertura del dialogo
    _gradeErrorText = null;
    _dateErrorText = null;
    _weightErrorText = null;

    // Mostra il dialogo e attendi la sua chiusura
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Usa StatefulBuilder per aggiornare il dialogo
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Aggiungi Voto' : 'Modifica Voto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: gradeController,
                    decoration: InputDecoration(
                      labelText:
                          'Voto (range 0 - $_maxGrade)', // Mostra il range di voti (0 al voto massimo)
                      errorText: _gradeErrorText, // Mostra l'errore per il voto
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Resetta l'errore quando l'utente digita
                      setState(() {
                        _gradeErrorText = null;
                      });
                    },
                  ),
                  // TextField per la data con onTap per aprire il selettore
                  TextField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText:
                          'Data (DD-MM-YYYY)', // Aggiorna l'etichetta per mostrare il formato
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context, _dateController),
                      ),
                      errorText: _dateErrorText, // Mostra l'errore per la data
                    ),
                    keyboardType: TextInputType
                        .text, // Cambia il tipo di tastiera a testo
                    readOnly:
                        true, // Rendi il campo di sola lettura per usare il selettore
                    onTap: () => _selectDate(context,
                        _dateController), // Assicura che onTap funzioni
                  ),
                  TextField(
                    controller: weightController,
                    decoration: InputDecoration(
                      labelText: 'Peso',
                      errorText:
                          _weightErrorText, // Mostra l'errore per il peso
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Resetta l'errore quando l'utente digita
                      setState(() {
                        _weightErrorText = null;
                      });
                    },
                  ),
                  // DropdownButton per il tipo
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: ['orale', 'scritto', 'pratico', 'altro']
                        .map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          // Aggiorna lo stato del dialogo
                          _selectedType = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      // Chiudi il dialogo passando false per indicare annullamento
                      Navigator.pop(context, false);
                      // Pulisci i controller e il tipo selezionato alla chiusura
                      gradeController.dispose();
                      _dateController.text =
                          ''; // Resetta solo il testo, non fare dispose qui
                      weightController.dispose();
                      _selectedType = 'orale'; // Resetta al valore predefinito
                    },
                    child: const Text('Annulla')),
                FilledButton(
                  onPressed: () async {
                    // Resetta i messaggi di errore prima di ogni tentativo di salvataggio
                    setState(() {
                      _gradeErrorText = null;
                      _dateErrorText = null;
                      _weightErrorText = null;
                    });

                    bool hasError = false;

                    final grade = double.tryParse(gradeController.text);
                    // Validazione: il voto deve essere tra 0 e il voto massimo
                    if (gradeController.text.isEmpty ||
                        grade == null ||
                        grade < 0 ||
                        grade > _maxGrade) {
                      setState(() {
                        _gradeErrorText =
                            'Il voto deve essere tra 0 e $_maxGrade';
                      });
                      hasError = true;
                    }

                    final dateForSaving =
                        parseDisplayDateToInt(_dateController.text);
                    if (dateForSaving == null) {
                      setState(() {
                        _dateErrorText = 'Seleziona una data valida';
                      });
                      hasError = true;
                    }

                    final weight = double.tryParse(weightController.text);
                    if (weightController.text.isEmpty || weight == null) {
                      setState(() {
                        _weightErrorText = 'Inserisci un peso valido';
                      });
                      hasError = true;
                    }

                    final type = _selectedType; // Usa _selectedType

                    if (!hasError) {
                      // Procedi solo se non ci sono errori
                      if (existing == null) {
                        await dbHelper.addGrade(widget.subjectName, grade!,
                            dateForSaving!, weight!, type);
                      } else {
                        await dbHelper.editGrade({
                          'grade_id': existing.id,
                          'subject': widget.subjectName,
                          'grade': grade!,
                          'date':
                              dateForSaving!, // Usa la data formattata per il salvataggio
                          'grade_weight': weight!,
                          'type': type
                        });
                      }
                      // Chiudi il dialogo passando true per indicare successo
                      Navigator.pop(context, true);
                      // Non chiamare _loadSubjectData() qui
                    }
                  },
                  child: const Text('Salva'),
                )
              ],
            );
          },
        );
      },
    ).then((result) {
      // Questo codice viene eseguito dopo che il dialogo è stato chiuso
      // Ricarica i dati solo se il dialogo è stato chiuso con successo (pulsante Salva)
      if (result == true) {
        _loadSubjectData(); // Ricarica i dati della materia dopo aver aggiunto/modificato un voto
      }
    });
  }

  // Metodo per mostrare il dialogo di modifica nome materia
  void _showEditSubjectNameDialog() {
    final nameController = TextEditingController(text: widget.subjectName);
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica Nome'), // Testo più corto
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nuovo nome materia',
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
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty && newName != widget.subjectName) {
                      try {
                        // CHIAMA LA FUNZIONE renameSubject DAL DATABASE HELPER
                        await dbHelper.renameSubject(
                            widget.subjectName, newName);
                        // Chiudi il dialogo
                        Navigator.pop(context);
                        // Torna alla schermata precedente (HomePage)
                        Navigator.pop(context);
                      } catch (e) {
                        setState(() => errorText = e.toString());
                      }
                    } else if (newName == widget.subjectName) {
                      setState(() => errorText =
                          'Il nuovo nome è uguale a quello attuale');
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

  void _deleteGrade(int id) async {
    await dbHelper.deleteGrade(id);
    _loadSubjectData(); // Ricarica i dati dopo aver eliminato un voto
  }

  // Modificato per includere un pulsante "Elimina Obiettivo" e chiamare removeObjective
  void _updateObjectiveDialog() {
    final controller =
        TextEditingController(text: _objective != 'N/A' ? _objective : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Imposta Obiettivo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Obiettivo'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          // Pulsante per eliminare l'obiettivo
          TextButton(
            onPressed: () async {
              // Chiama la funzione removeObjective fornita dall'utente
              final success =
                  await dbHelper.removeObjective(widget.subjectName);
              if (success) {
                Navigator.pop(context); // Chiudi il dialogo
                _loadSubjectData(); // Ricarica i dati per aggiornare l'UI
              } else {
                // Gestisci l'errore se l'eliminazione non è andata a buon fine
                print('Errore nell\'eliminazione dell\'obiettivo');
                // Potresti mostrare un messaggio all'utente
                Navigator.pop(context); // Chiudi comunque il dialogo
              }
            },
            child: const Text('Elimina Obiettivo'),
            style: TextButton.styleFrom(
                foregroundColor: Colors
                    .red), // Rendi il testo rosso per indicare eliminazione
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value != null) {
                await dbHelper.setObjective(widget.subjectName, value);
                Navigator.pop(context);
                _loadSubjectData(); // Ricarica i dati dopo aver impostato l'obiettivo
              }
            },
            child: const Text('Salva'),
          )
        ],
      ),
    );
  }

  // Metodo per mostrare il popup di conferma eliminazione materia
  void _confirmDeleteSubject() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conferma Eliminazione'),
          content: Text(
              'Sei sicuro di voler eliminare la materia "${widget.subjectName}" e tutti i suoi voti?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(false), // Chiudi il dialogo, non eliminare
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(true), // Chiudi il dialogo, procedi con l'eliminazione
              child: const Text('Elimina'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    ).then((confirmed) {
      // Questo codice viene eseguito dopo che il dialogo di conferma è stato chiuso
      if (confirmed == true) {
        _deleteSubject(); // Chiama la funzione di eliminazione solo se confermato
      }
    });
  }

  void _deleteSubject() async {
    await dbHelper.deleteSubject(widget.subjectName);
    // Torna alla schermata precedente dopo l'eliminazione
    Navigator.pop(context);
  }

  // Metodo per costruire le card statistiche nella SubjectDetailPage
  // Reso tappabile per l'obiettivo
  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    // Determina il valore da mostrare per l'obiettivo
    String displayedValue = value;
    // Controlla se è la card Obiettivo e il valore è 'N/A' (come restituito dal DB quando è NULL)
    if (label == 'Obiettivo' && value == 'N/A') {
      displayedValue = 'N/A';
    } else if (label == 'Obiettivo' && value == '0.0') {
      // Se il valore è 0.0 ma non è 'N/A', mostralo comunque (potrebbe essere un obiettivo valido 0.0)
      displayedValue = value;
    }

    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          // Rendi la Card tappabile
          onTap: onTap, // Assegna l'handler onTap
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(
                  displayedValue, // Usa displayedValue
                  // Applica uno stile leggermente più grande per il valore
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 20), // Esempio: fontSize 20
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Metodo per calcolare e mostrare il cambio media tra primo quadrimestre e periodo corrente con icone
  Widget _buildAverageChangeCard() {
    double? avg1 = double.tryParse(_averageFirstPeriod);
    double? avgCurrent = double.tryParse(_averagePeriod);

    String changeText;
    Color changeColor = Colors.grey; // Default color
    IconData changeIcon = Icons.remove; // Default icon for no change or N/A

    if (avg1 != null && avgCurrent != null) {
      final difference = avgCurrent - avg1;
      changeText = difference.toStringAsFixed(2); // Formatta la differenza

      if (difference > 0) {
        changeColor = Colors.green;
        changeText = '+' + changeText; // Aggiungi il + per differenze positive
        changeIcon = Icons.arrow_upward; // Icona freccia su
      } else if (difference < 0) {
        changeColor = Colors.red;
        changeText = changeText; // Mantieni il segno negativo
        changeIcon = Icons.arrow_downward; // Icona freccia giù
      } else {
        changeColor = Colors.grey;
        changeText = '0.00'; // Mostra 0.00 per differenza zero
        changeIcon = Icons.arrow_forward; // Icona freccia destra per uguale
      }
    } else {
      changeText = 'N/A'; // Non calcolabile se una delle medie è N/A
      changeColor = Colors.grey;
      changeIcon = Icons.remove; // Icona trattino per N/A
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Variazione Media',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium), // Etichetta aggiornata
            const SizedBox(height: 6),
            Row(
              // Usa una Row per allineare icona e testo
              mainAxisAlignment:
                  MainAxisAlignment.center, // Centra gli elementi nella Row
              children: [
                Icon(changeIcon, color: changeColor, size: 24), // Icona
                const SizedBox(width: 4), // Spazio tra icona e testo
                Text(
                  changeText,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Imposta il titolo della AppBar al nome della materia
      appBar: AppBar(title: Text(widget.subjectName)),
      body:
          // Avvolgi il corpo con un Hero widget per la transizione
          Hero(
        tag: widget.subjectName, // Usa lo stesso tag della HomePage
        child: Material(
          // Necessario per evitare errori di rendering con Hero
          type: MaterialType.transparency, // Mantieni lo sfondo trasparente
          child: Column(
            // Usiamo Column per posizionare la lista e i pulsanti in basso
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // Distribuisci le card
                  children: [
                    // Card Media della Materia (media del periodo corrente)
                    _buildStatCard(
                      'Media', // Etichetta ripristinata
                      _averagePeriod,
                    ),
                    // Card Media Primo Quadrimestre (normale)
                    _buildStatCard('Media 1Q', _averageFirstPeriod),
                    // Card Obiettivo (normale, tappabile)
                    _buildStatCard('Obiettivo', _objective,
                        onTap: _updateObjectiveDialog),
                  ],
                ),
              ),
              // Nuova sezione per la variazione media
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0), // Aggiungi padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Centra la card
                  children: [
                    Expanded(
                        child:
                            _buildAverageChangeCard()), // Aggiungi la card della variazione media e espandila
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Aggiungi padding orizzontale
                child:
                    Text('Voti', style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Expanded(
                // Espandi la lista per occupare lo spazio rimanente
                child: ListView.builder(
                  // Usa ListView.builder
                  padding: const EdgeInsets.symmetric(
                      horizontal:
                          16), // Aggiungi padding orizzontale alla lista
                  itemCount: _grades.length,
                  itemBuilder: (_, i) {
                    final g = _grades[i];
                    return Card(
                      // Avvolgi ListTile in una Card per un aspetto migliore
                      child: ListTile(
                        title: Text('${g.grade} (${g.type})'),
                        // Mostra la data formattata in DD-MM-YYYY nella ListTile
                        subtitle: Text(
                            'Data: ${formatIntDateToDisplay(g.date)} - Peso: ${g.weight}'), // Usa la helper function
                        onTap: () => _showGradeDialog(existing: g),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteGrade(g.id!),
                        ),
                      ),
                    );
                  },
                  // Rimosso separatorBuilder
                ),
              ),
              // Sposta i pulsanti di modifica/eliminazione materia e aggiunta voto in basso
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  // Usa Column per impilare i pulsanti
                  children: [
                    FilledButton(
                      // Pulsante Aggiungi Voto ripristinato
                      onPressed: () => _showGradeDialog(),
                      child: const Text('Aggiungi Voto'),
                    ),
                    const SizedBox(height: 8), // Spazio tra i pulsanti
                    Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceEvenly, // Distribuisci i pulsanti
                      children: [
                        Expanded(
                          // Usa Expanded per dare spazio ai pulsanti
                          child: OutlinedButton(
                            onPressed:
                                _showEditSubjectNameDialog, // Chiama il nuovo dialogo per modificare il nome
                            child: const Text(
                                'Modifica Nome'), // Testo del pulsante più corto
                          ),
                        ),
                        const SizedBox(width: 8), // Spazio tra i pulsanti
                        Expanded(
                          // Usa Expanded per dare spazio ai pulsanti
                          child: OutlinedButton(
                            onPressed:
                                _confirmDeleteSubject, // Chiama il popup di conferma
                            child: const Text('Elimina Materia'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      // Passa null per "Tutte le materie" o il nome della materia selezionata
      // NOTA: La funzione returnAverageByDatePeriod nel database_helper.dart
      // sembra calcolare la media generale (di tutte le materie) per un periodo.
      // Per il grafico di andamento generale, chiamiamo questa funzione per entrambi i periodi.
      // Se _selectedSubject non è 'Tutte le materie', dovremmo forse usare una funzione diversa
      // che calcoli l'andamento della media per una singola materia?
      // Basandoci sulla richiesta ("media (generale, di tutte le materie)"), assumiamo
      // che il grafico di andamento sia sempre generale, indipendentemente dalla materia selezionata nel dropdown.
      // Il dropdown influenzerà solo il grafico a barre.

      // Carica i dati per il grafico di andamento della media generale
      // Chiamiamo returnAverageByDatePeriod per il primo e secondo periodo esplicitamente
      final firstPeriodAverages =
          await dbHelper.returnAverageByDatePeriod(periodName: 'first_period');
      final secondPeriodAverages =
          await dbHelper.returnAverageByDatePeriod(periodName: 'second_period');

      // Carica i dati per il grafico a barre della distribuzione dei voti
      // Questa funzione nel database_helper.dart non prende il nome della materia.
      // Se vogliamo filtrare per materia, dovremmo modificare returnGradeProportionsByPeriod
      // o implementare la logica di filtro qui.
      // Basandoci sulla richiesta ("secondo è un semplice grafico a barre in cui viengono mostrati i voti in base a quante volte compaiono come puoi vedere nell'immagine"),
      // e sull'immagine che sembra mostrare voti per una materia,
      // modifichiamo la logica per filtrare i voti PRIMA di contare la distribuzione.
      // La funzione returnGradeProportionsByPeriod nel database_helper (3).dart
      // conta le proporzioni per un periodo ('first'/'second') su *tutti* i voti.
      // Dobbiamo adattare questa logica per filtrare per materia se necessario.

      // Opzione 1 (Modifica database_helper): Aggiungi un parametro subjectName a returnGradeProportionsByPeriod.
      // Opzione 2 (Elabora qui): Recupera tutti i voti (filtrati per materia), poi conta le proporzioni qui.
      // Scegliamo l'opzione 2 per non modificare il database_helper fornito.

      List<Grade> gradesForDistribution = [];
      if (_selectedSubject == 'Tutte le materie') {
        // Recupera tutti i voti
        final allSubjects = await dbHelper.listSubjects();
        for (var subjectTuple in allSubjects) {
          final subjectGrades = await dbHelper.listGrades(subjectTuple.$1);
          gradesForDistribution.addAll(subjectGrades);
        }
      } else {
        // Recupera voti per la materia selezionata
        gradesForDistribution = await dbHelper.listGrades(_selectedSubject!);
      }

      // Ora, conta le proporzioni per periodo dai voti filtrati
      final periods = await SettingsPage._loadPeriodsFromPreferences();
      int? firstPeriodStartInt;
      int? firstPeriodEndInt;
      int? secondPeriodStartInt;
      int? secondPeriodEndInt;

      if (periods != null) {
        try {
          if (periods.containsKey('first_period_start') &&
              periods.containsKey('first_period_end')) {
            firstPeriodStartInt = int.parse(DateFormat('yyyyMMdd').format(
                DateFormat('dd-MM-yyyy')
                    .parse(periods['first_period_start']!)));
            firstPeriodEndInt = int.parse(DateFormat('yyyyMMdd').format(
                DateFormat('dd-MM-yyyy').parse(periods['first_period_end']!)));
          }
          if (periods.containsKey('second_period_start') &&
              periods.containsKey('second_period_end')) {
            secondPeriodStartInt = int.parse(DateFormat('yyyyMMdd').format(
                DateFormat('dd-MM-yyyy')
                    .parse(periods['second_period_start']!)));
            secondPeriodEndInt = int.parse(DateFormat('yyyyMMdd').format(
                DateFormat('dd-MM-yyyy').parse(periods['second_period_end']!)));
          }
        } catch (e) {
          print(
              'Errore nel parsing delle date dei periodi da SharedPreferences per distribuzione voti: $e');
        }
      }

      Map<int, int> firstPeriodCounts = {};
      Map<int, int> secondPeriodCounts = {};
      int maxGradeValue = 0; // Per definire l'asse X del grafico a barre

      // Inizializza i conteggi per tutti i voti interi da 0 al voto massimo consentito (es. 10)
      final gradesSettings = await SettingsPage.loadPassingAndMaxGrades();
      final int maxPossibleGrade = gradesSettings['max_grade']?.toInt() ?? 10;

      for (int i = 0; i <= maxPossibleGrade; i++) {
        firstPeriodCounts[i] = 0;
        secondPeriodCounts[i] = 0;
      }

      for (var grade in gradesForDistribution) {
        final gradeIntPart =
            grade.grade.floor(); // Considera solo la parte intera
        maxGradeValue = max(
            maxGradeValue, gradeIntPart); // Aggiorna il voto massimo trovato

        // Controlla in quale periodo rientra il voto
        if (firstPeriodStartInt != null &&
            firstPeriodEndInt != null &&
            grade.date >= firstPeriodStartInt &&
            grade.date <= firstPeriodEndInt) {
          firstPeriodCounts[gradeIntPart] =
              (firstPeriodCounts[gradeIntPart] ?? 0) + 1;
        } else if (secondPeriodStartInt != null &&
            secondPeriodEndInt != null &&
            grade.date >= secondPeriodStartInt &&
            grade.date <= secondPeriodEndInt) {
          secondPeriodCounts[gradeIntPart] =
              (secondPeriodCounts[gradeIntPart] ?? 0) + 1;
        }
        // I voti fuori dai periodi definiti non vengono conteggiati per i grafici a barre per periodo
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
  Widget _buildAverageTrendChart() {
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
      return FlSpot(index.toDouble(),
          firstPeriodOriginal[index]['average_grade'] as double);
    });
    final List<FlSpot> firstPeriodRoundedAvgSpots =
        List.generate(firstPeriodRounded.length, (index) {
      return FlSpot(index.toDouble(),
          firstPeriodRounded[index]['average_grade'] as double);
    });
    final List<FlSpot> secondPeriodAvgSpots =
        List.generate(secondPeriodOriginal.length, (index) {
      return FlSpot(index.toDouble(),
          secondPeriodOriginal[index]['average_grade'] as double);
    });
    final List<FlSpot> secondPeriodRoundedAvgSpots =
        List.generate(secondPeriodRounded.length, (index) {
      return FlSpot(index.toDouble(),
          secondPeriodRounded[index]['average_grade'] as double);
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
    // Aggiunto async
    // Usiamo _firstPeriodGradeDistribution e _secondPeriodGradeDistribution
    if (_firstPeriodGradeDistribution.isEmpty &&
        _secondPeriodGradeDistribution.isEmpty) {
      return const Center(
          child:
              Text('Nessun dato disponibile per il grafico di distribuzione.'));
    }

    // Trova il voto massimo presente nei dati per definire l'asse X
    int maxGradeValue = 0;
    // Considera i voti presenti in entrambi i periodi
    final allGrades = [
      ..._firstPeriodGradeDistribution.keys,
      ..._secondPeriodGradeDistribution.keys
    ];
    if (allGrades.isNotEmpty) {
      maxGradeValue = allGrades.reduce(max);
    }

    // Inizializza i conteggi per tutti i voti interi da 0 al voto massimo consentito (es. 10)
    // per assicurare che l'asse X vada da 0 al massimo possibile.
    final gradesSettings =
        await SettingsPage.loadPassingAndMaxGrades(); // await richiede async
    final int maxPossibleGrade = gradesSettings['max_grade']?.toInt() ?? 10;
    int effectiveMaxX = max(maxGradeValue, maxPossibleGrade);

    // Crea i BarChartGroupData per ogni voto da 0 al voto massimo effettivo sull'asse X
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i <= effectiveMaxX; i++) {
      final firstPeriodCount = _firstPeriodGradeDistribution[i] ?? 0;
      final secondPeriodCount = _secondPeriodGradeDistribution[i] ?? 0;

      // Aggiungi il gruppo di barre solo se c'è almeno un conteggio > 0 per questo voto
      // o se è un voto fino al massimo effettivo per mostrare l'asse X completo
      if (firstPeriodCount > 0 || secondPeriodCount > 0 || i <= effectiveMaxX) {
        barGroups.add(
          BarChartGroupData(
            x: i, // Il voto è il valore sull'asse X
            barRods: [
              // Barra Primo Quadrimestre
              BarChartRodData(
                toY: firstPeriodCount.toDouble(),
                color: Colors.blueAccent,
                width: 7, // Larghezza della barra
              ),
              // Barra Secondo Quadrimestre
              BarChartRodData(
                toY: secondPeriodCount.toDouble(),
                color: Colors.orangeAccent,
                width: 7, // Larghezza della barra
              ),
            ],
            // Aggiungi spazio tra i gruppi di barre
            barsSpace: 2,
          ),
        );
      }
    }
    // Ordina i gruppi di barre per voto (asse X)
    barGroups.sort((a, b) => a.x.compareTo(b.x));

    // Determina il valore massimo sull'asse Y (conteggio massimo)
    double maxY = 0;
    final allCounts = [
      ..._firstPeriodGradeDistribution.values,
      ..._secondPeriodGradeDistribution.values
    ];
    if (allCounts.isNotEmpty) {
      maxY = allCounts.reduce(max).toDouble();
    }
    maxY = (maxY + 1).ceilToDouble(); // Aggiungi un po' di margine

    return AspectRatio(
      aspectRatio: 1.5, // Rapporto d'aspetto del grafico
      child: Padding(
        padding:
            const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            gridData: FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: false, reservedSize: 40, interval: 1),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1, // Mostra un'etichetta per ogni voto
                  getTitlesWidget: (value, meta) {
                    // Aggiunto 'meta'
                    // Mostra il voto sull'asse X
                    return SideTitleWidget(
                      meta: meta, // Usa meta.axisSide
                      space: 8,
                      child: Text('${value.toInt()}',
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
            minY: 0,
            maxY: maxY,
          ),
        ),
      ),
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
                      'Andamento della Media Generale nel Tempo', // Aggiornato titolo grafico
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildAverageTrendChart(), // Non ha bisogno di await qui
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

// Nuova implementazione della pagina Impostazioni
class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();

  // Funzione per caricare i periodi per l'uso in altre pagine (es. SubjectDetailPage)
  // Resa statica per essere accessibile senza un'istanza della classe
  static Future<Map<String, String>?> _loadPeriodsFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Leggi le date come stringhe (il database le gestisce come INTEGER, ma SharedPreferences no)
    final firstStart = prefs.getString('first_period_start');
    final firstEnd = prefs.getString('first_period_end');
    final secondStart = prefs.getString('second_period_start');
    final secondEnd = prefs.getString('second_period_end');

    // Restituisce una mappa solo se tutte le date dei periodi sono presenti
    if (firstStart != null &&
        firstEnd != null &&
        secondStart != null &&
        secondEnd != null) {
      return {
        'first_period_start': firstStart,
        'first_period_end': firstEnd,
        'second_period_start': secondStart,
        'second_period_end': secondEnd,
      };
    }
    return null;
  }

  // Funzione statica per caricare i voti di sufficienza e massimo
  static Future<Map<String, double>> loadPassingAndMaxGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final passingGrade =
        prefs.getDouble('passing_grade') ?? 6.0; // Valore predefinito 6.0
    final maxGrade =
        prefs.getDouble('max_grade') ?? 10.0; // Valore predefinito 10.0
    return {'passing_grade': passingGrade, 'max_grade': maxGrade};
  }
}

class _SettingsPageState extends State<SettingsPage> {
  // Variabili di stato per le date dei quadrimestri
  DateTime? _firstPeriodStart;
  DateTime? _firstPeriodEnd;
  DateTime? _secondPeriodStart;
  DateTime? _secondPeriodEnd;

  // Variabili di stato per i voti di sufficienza e massimo
  double _passingGrade = 6.0; // Valore predefinito
  double _maxGrade = 10.0; // Valore predefinito

  // Formatter per visualizzare le date
  final DateFormat _displayFormat = DateFormat('dd-MM-yyyy');
  // Formatter per salvare le date come interoMMDD
  final DateFormat _saveFormat = DateFormat('yyyyMMdd');

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Carica sia i periodi che i voti min/max all'avvio
  }

  // Carica sia i periodi che i voti di sufficienza e massimo
  Future<void> _loadSettings() async {
    await _loadPeriods();
    await _loadPassingAndMaxGrades();
  }

  // Implementa la logica di caricamento dei periodi all'avvio della pagina
  Future<void> _loadPeriods() async {
    final periods = await SettingsPage._loadPeriodsFromPreferences();
    if (periods != null) {
      setState(() {
        try {
          // Parsifica le date dal formato salvato (DD-MM-YYYY)
          _firstPeriodStart =
              DateFormat('dd-MM-yyyy').parse(periods['first_period_start']!);
          _firstPeriodEnd =
              DateFormat('dd-MM-yyyy').parse(periods['first_period_end']!);
          _secondPeriodStart =
              DateFormat('dd-MM-yyyy').parse(periods['second_period_start']!);
          _secondPeriodEnd =
              DateFormat('dd-MM-yyyy').parse(periods['second_period_end']!);
        } catch (e) {
          print(
              'Errore nel parsing delle date caricate da SharedPreferences: $e');
          // Potresti voler resettare i periodi in caso di errore di parsing
          _firstPeriodStart = null;
          _firstPeriodEnd = null;
          _secondPeriodStart = null;
          _secondPeriodEnd = null;
        }
      });
    }
  }

  // Implementa la logica di caricamento dei voti di sufficienza e massimo
  Future<void> _loadPassingAndMaxGrades() async {
    final grades = await SettingsPage.loadPassingAndMaxGrades();
    setState(() {
      _passingGrade = grades['passing_grade']!;
      _maxGrade = grades['max_grade']!;
    });
  }

  // Implementa la logica di salvataggio dei periodi e dei voti di sufficienza/massimo
  void _saveSettings() async {
    await _savePeriods();
    // La logica di salvataggio dei voti di sufficienza/massimo avviene nei rispettivi dialoghi
    // Dopo aver salvato le impostazioni, potresti voler notificare altre parti dell'app
    // che le impostazioni sono cambiate, in modo che possano ricaricare i dati.
    // Un modo semplice è ricaricare i dati nella HomePage e SubjectDetailPage
    // quando si torna da questa pagina.
  }

  // Implementa la logica di salvataggio dei periodi usando SharedPreferences
  Future<void> _savePeriods() async {
    final prefs = await SharedPreferences.getInstance();

    // Salva le date nel formato DD-MM-YYYY come stringhe solo se non sono null
    if (_firstPeriodStart != null)
      await prefs.setString(
          'first_period_start', _displayFormat.format(_firstPeriodStart!));
    if (_firstPeriodEnd != null)
      await prefs.setString(
          'first_period_end', _displayFormat.format(_firstPeriodEnd!));
    if (_secondPeriodStart != null)
      await prefs.setString(
          'second_period_start', _displayFormat.format(_secondPeriodStart!));
    if (_secondPeriodEnd != null)
      await prefs.setString(
          'second_period_end', _displayFormat.format(_secondPeriodEnd!));

    // Non è necessario interagire direttamente con il database qui per i periodi,
    // poiché il database helper legge le date da SharedPreferences tramite _getCurrentPeriodDates().
  }

  // Implementa la logica di salvataggio del voto di sufficienza
  Future<void> _savePassingGrade(double passingGrade) async {
    final prefs = await SharedPreferences.getInstance();
    // Aggiungi validazione per assicurare che passingGrade sia >= 0 e <= maxGrade
    if (passingGrade >= 0 && passingGrade <= _maxGrade) {
      await prefs.setDouble('passing_grade', passingGrade);
      setState(() {
        _passingGrade = passingGrade;
      });
    } else {
      print('Voto di sufficienza non valido (deve essere tra 0 e $_maxGrade)');
      // Potresti mostrare un messaggio di errore all'utente
    }
  }

  // Implementa la logica di salvataggio del voto massimo
  Future<void> _saveMaxGrade(double maxGrade) async {
    final prefs = await SharedPreferences.getInstance();
    // Aggiungi validazione per assicurare che maxGrade sia > 0 e >= passingGrade
    if (maxGrade > 0 && maxGrade >= _passingGrade) {
      await prefs.setDouble('max_grade', maxGrade);
      setState(() {
        _maxGrade = maxGrade;
      });
    } else {
      print(
          'Voto massimo non valido (deve essere maggiore di 0 e >= $_passingGrade)');
      // Potresti mostrare un messaggio all'utente
    }
  }

  // Funzione per mostrare il selettore di data in un dialogo
  Future<DateTime?> _selectDateInDialog(
      BuildContext context, DateTime? initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    return picked;
  }

  // Funzione per mostrare il dialogo di modifica periodo
  Future<void> _showEditPeriodDialog(String periodName, DateTime? currentStart,
      DateTime? currentEnd, Function(DateTime?, DateTime?) onSave) async {
    DateTime? selectedStart = currentStart;
    DateTime? selectedEnd = currentEnd;
    String? errorText; // Per mostrare errori di validazione date

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Modifica $periodName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Data Inizio'),
                    // Correzione: Utilizza l'operatore ! per asserire che selectedStart non è null quando lo formatti
                    subtitle: Text(selectedStart != null
                        ? _displayFormat.format(selectedStart!)
                        : 'Seleziona data'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked =
                          await _selectDateInDialog(context, selectedStart);
                      if (picked != null) {
                        setState(() {
                          selectedStart = picked;
                          errorText = null; // Resetta l'errore
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Data Fine'),
                    // Correzione: Utilizza l'operatore ! per asserire che selectedEnd non è null quando lo formatti
                    subtitle: Text(selectedEnd != null
                        ? _displayFormat.format(selectedEnd!)
                        : 'Seleziona data'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked =
                          await _selectDateInDialog(context, selectedEnd);
                      if (picked != null) {
                        setState(() {
                          selectedEnd = picked;
                          errorText = null; // Resetta l'errore
                        });
                      }
                    },
                  ),
                  if (errorText != null) // Mostra l'errore se presente
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorText!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                // Pulsante Annulla
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                // Pulsante Salva
                FilledButton(
                  onPressed: () async {
                    // Validazione date: inizio non può essere dopo fine
                    if (selectedStart != null &&
                        selectedEnd != null &&
                        selectedStart!.isAfter(selectedEnd!)) {
                      setState(() {
                        errorText =
                            'La data di inizio non può essere successiva alla data di fine.';
                      });
                      return; // Non salvare se c'è errore
                    }

                    // Ulteriore validazione per sovrapposizione con l'altro periodo
                    // (Questa logica è nel database helper setPeriod, ma possiamo fare un controllo preliminare qui)
                    // Per semplicità, ci basiamo sulla validazione del database helper.

                    // Chiamiamo la funzione setPeriod del database helper
                    // Converti DateTime in intMMDD per il database helper
                    final int? startInt = selectedStart != null
                        ? int.parse(_saveFormat.format(selectedStart!))
                        : null;
                    final int? endInt = selectedEnd != null
                        ? int.parse(_saveFormat.format(selectedEnd!))
                        : null;

                    // Il database helper gestisce la validazione della sovrapposizione.
                    // La validazione nel database helper (usando BETWEEN) è inclusiva.
                    final result = await DatabaseHelper().setPeriod(
                        periodName == 'Primo Quadrimestre'
                            ? 'first_period'
                            : 'second_period',
                        startInt!,
                        endInt!); // Passa gli int

                    if (result == 'invalid dates') {
                      setState(() {
                        errorText =
                            'Date non valide o si sovrappongono con l\'altro periodo.';
                      });
                    } else if (result == true) {
                      // Salvataggio riuscito
                      onSave(selectedStart,
                          selectedEnd); // Aggiorna lo stato locale solo se salvato nel DB
                      Navigator.pop(context);
                    } else {
                      // Errore generico nel salvataggio
                      setState(() {
                        errorText = 'Errore nel salvataggio delle date.';
                      });
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

  // Funzione per mostrare il dialogo di modifica voto di sufficienza
  Future<void> _showEditPassingGradeDialog() async {
    final TextEditingController controller =
        TextEditingController(text: _passingGrade.toString());
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica Voto di Sufficienza'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      'Voto di Sufficienza (max $_maxGrade)', // Mostra il voto massimo nel label
                  errorText: errorText,
                ),
                onChanged: (value) {
                  setState(() {
                    errorText = null; // Resetta l'errore quando l'utente digita
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    final double? newPassingGrade =
                        double.tryParse(controller.text);
                    // Validazione: il voto di sufficienza deve essere >= 0 e <= voto massimo
                    if (newPassingGrade != null &&
                        newPassingGrade >= 0 &&
                        newPassingGrade <= _maxGrade) {
                      _savePassingGrade(
                          newPassingGrade); // Salva il nuovo voto di sufficienza
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        errorText =
                            'Inserisci un voto di sufficienza valido (tra 0 e $_maxGrade)';
                      });
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

  // Funzione per mostrare il dialogo di modifica voto massimo
  Future<void> _showEditMaxGradeDialog() async {
    final TextEditingController controller =
        TextEditingController(text: _maxGrade.toString());
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica Voto Massimo'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      'Voto Massimo (min sufficienza $_passingGrade)', // Aggiornato label
                  errorText: errorText,
                ),
                onChanged: (value) {
                  setState(() {
                    errorText = null; // Resetta l'errore quando l'utente digita
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    final double? newMaxGrade =
                        double.tryParse(controller.text);
                    // Validazione: il voto massimo deve essere > 0 e >= voto di sufficienza
                    if (newMaxGrade != null &&
                        newMaxGrade > 0 &&
                        newMaxGrade >= _passingGrade) {
                      _saveMaxGrade(newMaxGrade); // Salva il nuovo voto massimo
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        errorText =
                            'Inserisci un voto massimo valido (> 0 e >= $_passingGrade)';
                      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          // Usa ListView per permettere lo scroll se necessario
          children: [
            Text(
              'Imposta Periodi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Blocco Primo Quadrimestre
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showEditPeriodDialog(
                    'Primo Quadrimestre',
                    _firstPeriodStart,
                    _firstPeriodEnd,
                    (newStart, newEnd) {
                      setState(() {
                        _firstPeriodStart = newStart;
                        _firstPeriodEnd = newEnd;
                      });
                      _savePeriods(); // Salva dopo la modifica
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primo Quadrimestre',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inizio: ${_firstPeriodStart != null ? _displayFormat.format(_firstPeriodStart!) : 'Non impostato'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Fine: ${_firstPeriodEnd != null ? _displayFormat.format(_firstPeriodEnd!) : 'Non impostato'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Blocco Secondo Quadrimestre
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showEditPeriodDialog(
                    'Secondo Quadrimestre',
                    _secondPeriodStart,
                    _secondPeriodEnd,
                    (newStart, newEnd) {
                      setState(() {
                        _secondPeriodStart = newStart;
                        _secondPeriodEnd = newEnd;
                      });
                      _savePeriods(); // Salva dopo la modifica
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secondo Quadrimestre',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inizio: ${_secondPeriodStart != null ? _displayFormat.format(_secondPeriodStart!) : 'Non impostato'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Fine: ${_secondPeriodEnd != null ? _displayFormat.format(_secondPeriodEnd!) : 'Non impostato'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sezione Voti di Sufficienza e Massimo
            Text(
              'Imposta Voti di Sufficienza e Massimo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Blocco Voto di Sufficienza
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                // Rendi la Card tappabile
                borderRadius: BorderRadius.circular(12),
                onTap:
                    _showEditPassingGradeDialog, // Apri il dialogo di modifica voto di sufficienza
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voto di Sufficienza',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        // Mostra il voto di sufficienza corrente
                        _passingGrade.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Blocco Voto Massimo
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                // Rendi la Card tappabile
                borderRadius: BorderRadius.circular(12),
                onTap:
                    _showEditMaxGradeDialog, // Apri il dialogo di modifica voto massimo
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voto Massimo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        // Mostra il voto massimo corrente
                        _maxGrade.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Il pulsante "Salva Periodi" esplicito non è più necessario
            // FilledButton(
            //   onPressed: _saveSettings, // Usa questa funzione per salvare tutto insieme
            //   child: const Text('Salva Impostazioni'),
            // ),
          ],
        ),
      ),
    );
  }
}
