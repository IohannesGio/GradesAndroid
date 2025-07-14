import 'package:flutter/material.dart';
import 'database_helper.dart'; // Importa il tuo database helper
import 'package:intl/intl.dart'; // Per la formattazione delle date/ore
import 'package:table_calendar/table_calendar.dart'; // Importa la libreria del calendario

class DiaryPage extends StatefulWidget {
  @override
  _DiaryPageState createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Lesson> _lessons = [];
  int _selectedDayOfWeek = DateTime.now().weekday; // 1=Lunedì, ..., 7=Domenica
  List<String> _subjectNames = []; // Per il dropdown delle materie

  // Variabili per il calendario
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay; // Giorno selezionato nel calendario
  Map<DateTime, List<CalendarEvent>> _events =
      {}; // Mappa degli eventi per data
  List<CalendarEvent> _selectedEvents = []; // Eventi del giorno selezionato

  @override
  void initState() {
    super.initState();
    _selectedDay =
        _focusedDay; // Inizializza il giorno selezionato al giorno corrente
    _loadSubjectNames(); // Carica i nomi delle materie
    _loadLessons(); // Carica le lezioni per il giorno corrente
    _loadCalendarEvents(); // Carica gli eventi del calendario
  }

  // Carica i nomi delle materie dal database per il dropdown
  Future<void> _loadSubjectNames() async {
    try {
      final subjects = await _dbHelper.listSubjects();
      setState(() {
        _subjectNames = subjects.map((s) => s.$1).toList();
        // Aggiungi un'opzione vuota o "Seleziona Materia" se necessario
        if (!_subjectNames.contains('Seleziona Materia')) {
          _subjectNames.insert(0, 'Seleziona Materia');
        }
      });
    } catch (e) {
      print('Errore nel caricamento dei nomi delle materie: $e');
    }
  }

  // Carica le lezioni per il giorno della settimana selezionato
  Future<void> _loadLessons() async {
    setState(() {
      _lessons = []; // Resetta la lista prima di caricare
    });
    try {
      final lessons = await _dbHelper.getLessonsForDay(_selectedDayOfWeek);
      setState(() {
        _lessons = lessons;
      });
    } catch (e) {
      print('Errore nel caricamento delle lezioni: $e');
      // Potresti mostrare un messaggio di errore all'utente
    }
  }

  // Carica tutti gli eventi del calendario e li raggruppa per data
  Future<void> _loadCalendarEvents() async {
    try {
      final allEvents = await _dbHelper.getAllCalendarEvents();
      _events = {}; // Resetta la mappa degli eventi
      for (var event in allEvents) {
        // Normalizza la data per la chiave della mappa (senza ora, minuti, secondi)
        final DateTime kDay =
            DateTime.utc(event.date.year, event.date.month, event.date.day);
        _events.putIfAbsent(kDay, () => []).add(event);
      }
      // Aggiorna gli eventi del giorno selezionato
      _selectedEvents = _getEventsForDay(_selectedDay!);
      setState(() {});
    } catch (e) {
      print('Errore nel caricamento degli eventi del calendario: $e');
    }
  }

  // Funzione per ottenere gli eventi per un dato giorno
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    // Normalizza la data per la ricerca
    final DateTime kDay = DateTime.utc(day.year, day.month, day.day);
    return _events[kDay] ?? [];
  }

  // Gestisce la selezione di un giorno nel calendario
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay; // Aggiorna il giorno focalizzato
      _selectedEvents = _getEventsForDay(
          selectedDay); // Aggiorna gli eventi del giorno selezionato
    });
  }

  // Helper per ottenere il nome del giorno della settimana
  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Lunedì';
      case 2:
        return 'Martedì';
      case 3:
        return 'Mercoledì';
      case 4:
        return 'Giovedì';
      case 5:
        return 'Venerdì';
      case 6:
        return 'Sabato';
      case 7:
        return 'Domenica';
      default:
        return '';
    }
  }

  // Helper per parsare una stringa di tempo "HH:MM" in TimeOfDay
  TimeOfDay _parseTime(String timeString) {
    if (timeString.isEmpty) return TimeOfDay.now(); // Default se stringa vuota

    try {
      // Prova a parsare come HH:MM (formato database)
      final parts = timeString.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      // Fallisce se non è HH:MM, prova altri formati
    }

    try {
      // Prova a parsare con DateFormat.jm() per AM/PM (formato TimeOfDay.format(context))
      final format = DateFormat.jm(); // e.g., "8:00 AM" or "8:00 PM"
      final dateTime = format.parse(timeString);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      // Fallback in caso di errore di parsing
      print('Errore nel parsing dell\'orario "$timeString": $e');
      return TimeOfDay.now(); // Ritorna l'ora corrente come fallback
    }
  }

  // Helper per convertire TimeOfDay in stringa "HH:MM" (formato database)
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Dialogo per aggiungere o modificare una lezione (parte orario)
  void _showAddEditLessonDialog({Lesson? existingLesson}) {
    final TextEditingController startTimeController = TextEditingController(
        text: existingLesson != null
            ? _formatTime(_parseTime(existingLesson.startTime))
            : '');
    final TextEditingController endTimeController = TextEditingController(
        text: existingLesson != null
            ? _formatTime(_parseTime(existingLesson.endTime))
            : '');
    final TextEditingController roomController =
        TextEditingController(text: existingLesson?.room ?? '');
    final TextEditingController teacherController =
        TextEditingController(text: existingLesson?.teacher ?? '');

    String? selectedSubject = existingLesson?.subjectName;
    if (selectedSubject == null && _subjectNames.isNotEmpty) {
      selectedSubject = _subjectNames.firstWhere(
          (element) => element == 'Seleziona Materia',
          orElse: () => _subjectNames.isNotEmpty ? _subjectNames.first : '');
    } else if (selectedSubject != null &&
        !_subjectNames.contains(selectedSubject)) {
      // Se la materia della lezione esistente non è nell'elenco attuale, aggiungila temporaneamente
      _subjectNames.add(selectedSubject);
    }

    // Il giorno della settimana per la lezione sarà basato sul giorno attualmente selezionato
    // nella vista principale (_selectedDayOfWeek) se è una nuova lezione,
    // o il giorno della lezione esistente se si sta modificando.
    final int lessonDayOfWeek = existingLesson?.dayOfWeek ?? _selectedDayOfWeek;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingLesson == null
                  ? 'Aggiungi Lezione'
                  : 'Modifica Lezione'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration: const InputDecoration(labelText: 'Materia'),
                      items: _subjectNames.map((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null ||
                            value == 'Seleziona Materia' ||
                            value.isEmpty) {
                          return 'Seleziona una materia';
                        }
                        return null;
                      },
                    ),
                    // Rimosso il DropdownButtonFormField per il Giorno della Settimana
                    TextField(
                      controller: startTimeController,
                      readOnly: true, // Rendi il campo di sola lettura
                      decoration: InputDecoration(
                        labelText: 'Ora Inizio (HH:MM)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: startTimeController.text.isNotEmpty
                                  ? _parseTime(startTimeController.text)
                                  : TimeOfDay.now(),
                            );
                            if (picked != null) {
                              startTimeController.text = _formatTime(picked);
                            }
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: endTimeController,
                      readOnly: true, // Rendi il campo di sola lettura
                      decoration: InputDecoration(
                        labelText: 'Ora Fine (HH:MM)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: endTimeController.text.isNotEmpty
                                  ? _parseTime(endTimeController.text)
                                  : TimeOfDay.now(),
                            );
                            if (picked != null) {
                              endTimeController.text = _formatTime(picked);
                            }
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: roomController,
                      decoration:
                          const InputDecoration(labelText: 'Aula (Opzionale)'),
                    ),
                    TextField(
                      controller: teacherController,
                      decoration: const InputDecoration(
                          labelText: 'Professore (Opzionale)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedSubject == null ||
                        selectedSubject == 'Seleziona Materia' ||
                        selectedSubject!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleziona una materia.')),
                      );
                      return;
                    }

                    if (startTimeController.text.isEmpty ||
                        endTimeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Inserisci orari di inizio e fine.')),
                      );
                      return;
                    }

                    // Validazione orari
                    final TimeOfDay start =
                        _parseTime(startTimeController.text);
                    final TimeOfDay end = _parseTime(endTimeController.text);

                    if (start.hour > end.hour ||
                        (start.hour == end.hour &&
                            start.minute >= end.minute)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'L\'ora di fine deve essere successiva all\'ora di inizio.')),
                      );
                      return;
                    }

                    final newLesson = Lesson(
                      id: existingLesson?.id,
                      subjectName: selectedSubject!,
                      dayOfWeek:
                          lessonDayOfWeek, // Usa il giorno della settimana determinato
                      startTime: startTimeController.text,
                      endTime: endTimeController.text,
                      room: roomController.text.isNotEmpty
                          ? roomController.text
                          : null,
                      teacher: teacherController.text.isNotEmpty
                          ? teacherController.text
                          : null,
                    );

                    if (existingLesson == null) {
                      await _dbHelper.addLesson(newLesson);
                    } else {
                      await _dbHelper.updateLesson(newLesson);
                    }
                    Navigator.pop(context);
                    _loadLessons(); // Ricarica le lezioni dopo l'operazione
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Rimuovi la materia temporaneamente aggiunta se non è stata salvata
      _loadSubjectNames(); // Ricarica l'elenco delle materie per pulire
    });
  }

  // Funzione per eliminare una lezione
  void _deleteLesson(int id) async {
    await _dbHelper.deleteLesson(id);
    _loadLessons(); // Ricarica le lezioni dopo l'eliminazione
  }

  // Mostra un dialogo con le opzioni Modifica/Elimina per le lezioni
  void _showLessonOptionsDialog(Lesson lesson) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Opzioni Lezione'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context); // Chiudi il dialogo delle opzioni
                    _showAddEditLessonDialog(
                        existingLesson: lesson); // Apri il dialogo di modifica
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit,
                            color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 8),
                        Text('Modifica Lezione',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context); // Chiudi il dialogo delle opzioni
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Conferma Eliminazione'),
                        content: Text(
                            'Sei sicuro di voler eliminare la lezione di ${lesson.subjectName} del ${_getDayName(lesson.dayOfWeek)} dalle ${lesson.startTime} alle ${lesson.endTime}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: () {
                              _deleteLesson(lesson.id!);
                              Navigator.pop(context);
                            },
                            child: const Text('Elimina'),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete,
                            color: Theme.of(context).colorScheme.error),
                        SizedBox(width: 8),
                        Text('Elimina Lezione',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialogo per aggiungere o modificare un evento del calendario
  void _showAddEditEventDialog({CalendarEvent? existingEvent}) {
    final TextEditingController titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: existingEvent?.description ?? '');
    String? selectedType = existingEvent?.type ??
        'compiti'; // Default type, changed from 'compito'
    String? selectedSubject = existingEvent?.subject;

    // Se l'evento è nuovo, imposta la data al giorno selezionato nel calendario
    DateTime eventDate = existingEvent?.date ?? _selectedDay!;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingEvent == null
                  ? 'Aggiungi Evento'
                  : 'Modifica Evento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Titolo'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Descrizione (Opzionale)'),
                      maxLines: 3,
                    ),
                    ListTile(
                      title: const Text('Data'),
                      subtitle:
                          Text(DateFormat('dd-MM-yyyy').format(eventDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: eventDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() {
                            eventDate = picked;
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items:
                          ['compiti', 'verifica', 'altro'].map((String type) {
                        // 'compito' changed to 'compiti', 'appunto' removed
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedType = newValue;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration: const InputDecoration(
                          labelText: 'Materia (Opzionale)'),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Nessuna Materia')),
                        ..._subjectNames
                            .where((s) => s != 'Seleziona Materia')
                            .map((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Il titolo non può essere vuoto.')),
                      );
                      return;
                    }

                    final newEvent = CalendarEvent(
                      id: existingEvent?.id,
                      title: titleController.text,
                      description: descriptionController.text,
                      date: eventDate,
                      type: selectedType!,
                      subject: selectedSubject,
                    );

                    if (existingEvent == null) {
                      await _dbHelper.addCalendarEvent(newEvent);
                    } else {
                      await _dbHelper.updateCalendarEvent(newEvent);
                    }
                    Navigator.pop(context);
                    _loadCalendarEvents(); // Ricarica gli eventi dopo l'operazione
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

  // Mostra un dialogo con le opzioni Modifica/Elimina per gli eventi del calendario
  void _showEventOptionsDialog(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Opzioni Evento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context); // Chiudi il dialogo delle opzioni
                    _showAddEditEventDialog(
                        existingEvent: event); // Apri il dialogo di modifica
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit,
                            color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 8),
                        Text('Modifica Evento',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context); // Chiudi il dialogo delle opzioni
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Conferma Eliminazione'),
                        content: Text(
                            'Sei sicuro di voler eliminare l\'evento "${event.title}" del ${DateFormat('dd-MM-yyyy').format(event.date)}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await _dbHelper.deleteCalendarEvent(event.id!);
                              Navigator.pop(
                                  context); // Chiudi il dialogo di conferma
                              _loadCalendarEvents(); // Ricarica gli eventi
                            },
                            child: const Text('Elimina'),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete,
                            color: Theme.of(context).colorScheme.error),
                        SizedBox(width: 8),
                        Text('Elimina Evento',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario e Orario'),
      ),
      body: SingleChildScrollView(
        // Permette lo scroll di tutta la pagina
        child: Column(
          children: [
            // Sezione Orario Scolastico
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orario Scolastico',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48.0,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final day =
                            index + 1; // 1-7 per i giorni della settimana
                        final isSelected = day == _selectedDayOfWeek;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(_getDayName(day)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedDayOfWeek = day;
                                });
                                _loadLessons(); // Carica le lezioni per il nuovo giorno
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _lessons.isEmpty
                      ? Center(
                          child: Text(
                            'Nessuna lezione per ${_getDayName(_selectedDayOfWeek)}.\nPremi "+" per aggiungerne una!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap:
                              true, // Importante per ListView annidati in SingleChildScrollView
                          physics:
                              NeverScrollableScrollPhysics(), // Disabilita lo scroll interno
                          padding:
                              EdgeInsets.zero, // Rimuovi padding predefinito
                          itemCount: _lessons.length,
                          itemBuilder: (context, index) {
                            final lesson = _lessons[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: InkWell(
                                onTap: () => _showLessonOptionsDialog(lesson),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lesson.subjectName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        '${lesson.startTime} - ${lesson.endTime}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      if (lesson.room != null &&
                                          lesson.room!.isNotEmpty)
                                        Text('Aula: ${lesson.room}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      if (lesson.teacher != null &&
                                          lesson.teacher!.isNotEmpty)
                                        Text('Prof.: ${lesson.teacher}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20.0), // Spazio aggiunto qui
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.extended(
                      onPressed: () => _showAddEditLessonDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi Lezione'),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32, thickness: 1), // Separatore

            // Sezione Calendario
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calendario',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) {
                      // Usa isSameDay per confrontare solo anno, mese e giorno
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader:
                        _getEventsForDay, // Carica gli eventi per il calendario
                    startingDayOfWeek:
                        StartingDayOfWeek.monday, // Calendar starts on Monday
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      formatButtonTextStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    'Eventi per il ${_selectedDay != null ? DateFormat('dd-MM-yyyy').format(_selectedDay!) : 'data non selezionata'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10.0),
                  // Lista degli eventi per il giorno selezionato
                  _selectedEvents.isEmpty
                      ? Center(child: Text('Nessun evento per questo giorno.'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _selectedEvents.length,
                          itemBuilder: (context, index) {
                            final event = _selectedEvents[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: InkWell(
                                onTap: () => _showEventOptionsDialog(
                                    event), // Opzioni per l'evento
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      if (event.description
                                          .isNotEmpty) // Spostato qui
                                        Text(event.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      if (event.subject != null &&
                                          event.subject!.isNotEmpty)
                                        Text('Materia: ${event.subject}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      Text('Tipo: ${event.type}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20.0),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.extended(
                      onPressed: () => _showAddEditEventDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi Evento'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
