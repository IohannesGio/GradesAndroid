import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../database_helper.dart';
import '../utils/date_utils.dart';
import 'settings_page.dart';

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

    final periods = await SettingsPage.loadPeriodsFromPreferences();
    if (periods != null) {
      if (periods.containsKey('first_period_start') &&
          periods.containsKey('first_period_end')) {
        try {
          final DateTime startDateTime =
              DateFormat('dd-MM-yyyy').parse(periods['first_period_start']!);
          firstPeriodStart =
              int.parse(DateFormat('yyyyMMdd').format(startDateTime));

          final DateTime endDateTime =
              DateFormat('dd-MM-yyyy').parse(periods['first_period_end']!);
          firstPeriodEnd =
              int.parse(DateFormat('yyyyMMdd').format(endDateTime));
        } catch (e) {
          print('Errore nel parsing delle date del primo periodo: $e');
        }
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
      _grades = grades;
      _averagePeriod = avgPeriod; // Media del periodo corrente
      _averageFirstPeriod = avg1; // Media del primo quadrimestre
      _objective = obj; // Obiettivo

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

    // Controller per la nota
    final noteController = TextEditingController(text: existing?.note);

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
                  TextField(
                    controller: noteController,
                    decoration:
                        const InputDecoration(labelText: 'Nota (Opzionale)'),
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
                      _dateController.text =
                          ''; // Resetta solo il testo, non fare dispose qui
                      weightController.dispose();
                      noteController.dispose();
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
                    final note = noteController.text;

                    if (!hasError) {
                      // Procedi solo se non ci sono errori
                      if (existing == null) {
                        await dbHelper.addGrade(widget.subjectName, grade!,
                            dateForSaving!, weight!, type,
                            note: note);
                      } else {
                        await dbHelper.editGrade({
                          'grade_id': existing.id,
                          'subject': widget.subjectName,
                          'grade': grade!,
                          'date':
                              dateForSaving!, // Usa la data formattata per il salvataggio
                          'grade_weight': weight!,
                          'type': type,
                          'note': note
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
                SizedBox(
                  width: 80,
                  height: 40,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getColorForValue(
                          label, value), // Assicurati che 'value' sia corretto
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      value, // Qui passi la media o altro testo
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getTextColorForBackground(label, value),
                      ),
                    ),
                  ),
                )
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
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: g.grade >= _passingGrade
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                g.grade.toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: g.grade >= _passingGrade
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('(${g.type})'), // Tipo di voto accanto
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Data: ${formatIntDateToDisplay(g.date)} - Peso: ${g.weight}'), // Usa la helper function
                            if (g.note != null && g.note!.isNotEmpty)
                              Text('Nota: ${g.note}',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                        onTap: () => _showGradeDialog(existing: g),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteGrade(g.id!),
                        ),
                      ),
                    );
                  },
                  // Rimosso separatorBuilder
                ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.2, end: 0),
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
