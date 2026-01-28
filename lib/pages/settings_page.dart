import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../database_helper.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();

  // Funzione per caricare i periodi per l'uso in altre pagine (es. SubjectDetailPage)
  // Resa statica per essere accessibile senza un'istanza della classe
  static Future<Map<String, String>?> loadPeriodsFromPreferences() async {
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
    final periods = await SettingsPage.loadPeriodsFromPreferences();
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

    // Salva le date nel formato DD-MM-YYYY as stringhe solo se non sono null
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

  void _handleExportDatabase() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esportazione del database in corso...'),
      ),
    );

    final result = await DatabaseHelper().exportDatabase();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result)),
    );
  }

  void _handleImportDatabase() async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Database SQLite',
        extensions: ['sqlite3'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importazione in corso...')),
      );

      final result = await DatabaseHelper().importDatabase(file.path);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );

      // Ricarica i dati se l'importazione ha avuto successo
      if (result.contains('successo')) {
        _loadSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'importazione: $e')),
      );
    }
  }

  void _handleClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text(
          'Sei sicuro di voler eliminare tutti i dati? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await DatabaseHelper().clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Tutti i dati sono stati eliminati.'
                      : 'Errore durante l\'eliminazione dei dati.'),
                ),
              );
              if (success) {
                _loadSettings();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
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
            // Blocco Periodi
            Row(
              children: [
                Icon(Icons.calendar_month,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Periodi', style: Theme.of(context).textTheme.titleLarge),
              ],
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),

            // Card dei periodi
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
                      _savePeriods();
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, // Icona per il primo quadrimestre
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
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
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 200.ms).fadeIn(delay: 200.ms),
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
                      _savePeriods();
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                          Icons.date_range, // Icona per il secondo quadrimestre
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
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
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 200.ms).fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // Blocco Voti
            Row(
              children: [
                Icon(Icons.grade, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Voti di Sufficienza e Massimo',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms)
                .slideX(begin: -0.2, end: 0),

            // Card dei voti
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showEditPassingGradeDialog,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                          Icons
                              .check_circle_outline, // Icona per il voto di sufficienza
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voto di Sufficienza',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _passingGrade.toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 400.ms).fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            // Blocco Voto Massimo
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showEditMaxGradeDialog,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.grade, // Icona per il voto massimo
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voto Massimo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _maxGrade.toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 400.ms).fadeIn(delay: 400.ms),

            const SizedBox(height: 24),

            // Blocco Gestione Dati
            Row(
              children: [
                Icon(Icons.data_usage,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Gestione Dati',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 400.ms)
                .slideX(begin: -0.2, end: 0),

            // Card della gestione dati
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _handleExportDatabase,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.backup, // Icona per l'esportazione
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Esporta Database',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Salva una copia di backup del database',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 600.ms).fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            // Blocco Importa Database
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _handleImportDatabase,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.download, // Icona per l'importazione
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Importa Database',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Carica un database esistente',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 600.ms).fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            // Blocco Elimina Tutti i Dati
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _handleClearData,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, // Icona per l'eliminazione
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Elimina Tutti i Dati',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rimuovi tutti i dati dall\'app',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(delay: 600.ms).fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
