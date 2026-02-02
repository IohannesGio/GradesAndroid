import 'package:flutter/material.dart';
import '../database_helper.dart'; // Importa il tuo database helper e modelli (incluso Grade)
import 'package:intl/intl.dart'; // Per la formattazione delle date/ore
import 'package:table_calendar/table_calendar.dart'; // Importa la libreria del calendario
import 'package:intl/date_symbol_data_local.dart'; // Importa i dati locali per le date

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

  // Mappe per eventi e voti
  Map<DateTime, List<CalendarEvent>> _events = {};
  Map<DateTime, List<Grade>> _grades = {};

  // Liste per il giorno selezionato
  List<CalendarEvent> _selectedEvents = [];
  List<Grade> _selectedGrades = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting(
        'it_IT', null); // Inizializza la localizzazione italiana
    _selectedDay =
        _focusedDay; // Inizializza il giorno selezionato al giorno corrente
    _loadSubjectNames(); // Carica i nomi delle materie
    _loadLessons(); // Carica le lezioni per il giorno corrente
    _loadCalendarEvents(); // Carica gli eventi del calendario
    _loadGrades(); // Carica i voti per il calendario
  }

  // Carica i nomi delle materie dal database per il dropdown
  Future<void> _loadSubjectNames() async {
    try {
      final subjects = await _dbHelper.listSubjects();
      setState(() {
        _subjectNames = subjects.map((s) => s.$1).toList();
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
    }
  }

  // Carica tutti gli eventi del calendario e li raggruppa per data
  Future<void> _loadCalendarEvents() async {
    try {
      final allEvents = await _dbHelper.getAllCalendarEvents();
      _events = {}; // Resetta la mappa degli eventi
      for (var event in allEvents) {
        final DateTime kDay =
            DateTime.utc(event.date.year, event.date.month, event.date.day);
        _events.putIfAbsent(kDay, () => []).add(event);
      }
      _updateSelectedItems();
    } catch (e) {
      print('Errore nel caricamento degli eventi del calendario: $e');
    }
  }

  // Carica tutti i voti e li raggruppa per data
  Future<void> _loadGrades() async {
    try {
      // Recupera tutti i voti. Usa un intervallo ampio o aggiungi un metodo getAllGrades se preferisci
      // Qui usiamo getGradesForCalendar senza date per prenderli tutti (se implementato così) o con un range ampio
      final allGrades = await _dbHelper.getGradesForCalendar(
          startDate: DateTime(2020), endDate: DateTime(2030));

      _grades = {};
      for (var grade in allGrades) {
        final date = grade
            .dateTime; // Usa il getter dateTime per convertire correttamente da YYYYMMDD
        final DateTime kDay = DateTime.utc(date.year, date.month, date.day);
        _grades.putIfAbsent(kDay, () => []).add(grade);
      }
      _updateSelectedItems();
    } catch (e) {
      print('Errore nel caricamento dei voti: $e');
    }
  }

  void _updateSelectedItems() {
    if (_selectedDay != null) {
      setState(() {
        final DateTime kDay = DateTime.utc(
            _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
        _selectedEvents = _events[kDay] ?? [];
        _selectedGrades = _grades[kDay] ?? [];
      });
    }
  }

  // Funzione utilizzata dal TableCalendar per i marker (combina eventi e voti)
  List<dynamic> _getEventsForDay(DateTime day) {
    final DateTime kDay = DateTime.utc(day.year, day.month, day.day);
    final events = _events[kDay] ?? [];
    final grades = _grades[kDay] ?? [];
    return [...events, ...grades];
  }

  // Gestisce la selezione di un giorno nel calendario
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _updateSelectedItems();
  }

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

  TimeOfDay _parseTime(String timeString) {
    if (timeString.isEmpty) return TimeOfDay.now();
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {}
    try {
      final format = DateFormat.jm();
      final dateTime = format.parse(timeString);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ... (Dialoghi per lezioni ed eventi rimangono invariati, li includo per completezza)
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
      _subjectNames.add(selectedSubject);
    }
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
                            value: subject, child: Text(subject));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue;
                        });
                      },
                      validator: (value) => (value == null ||
                              value == 'Seleziona Materia' ||
                              value.isEmpty)
                          ? 'Seleziona una materia'
                          : null,
                    ),
                    TextField(
                      controller: startTimeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ora Inizio (HH:MM)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: startTimeController.text.isNotEmpty
                                    ? _parseTime(startTimeController.text)
                                    : TimeOfDay.now());
                            if (picked != null)
                              startTimeController.text = _formatTime(picked);
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: endTimeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Ora Fine (HH:MM)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: endTimeController.text.isNotEmpty
                                    ? _parseTime(endTimeController.text)
                                    : TimeOfDay.now());
                            if (picked != null)
                              endTimeController.text = _formatTime(picked);
                          },
                        ),
                      ),
                    ),
                    TextField(
                        controller: roomController,
                        decoration: const InputDecoration(
                            labelText: 'Aula (Opzionale)')),
                    TextField(
                        controller: teacherController,
                        decoration: const InputDecoration(
                            labelText: 'Professore (Opzionale)')),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla')),
                FilledButton(
                  onPressed: () async {
                    if (selectedSubject == null ||
                        selectedSubject == 'Seleziona Materia' ||
                        selectedSubject!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Seleziona una materia.')));
                      return;
                    }
                    if (startTimeController.text.isEmpty ||
                        endTimeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Inserisci orari di inizio e fine.')));
                      return;
                    }
                    final TimeOfDay start =
                        _parseTime(startTimeController.text);
                    final TimeOfDay end = _parseTime(endTimeController.text);
                    if (start.hour > end.hour ||
                        (start.hour == end.hour &&
                            start.minute >= end.minute)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'L\'ora di fine deve essere successiva all\'ora di inizio.')));
                      return;
                    }
                    final newLesson = Lesson(
                      id: existingLesson?.id,
                      subjectName: selectedSubject!,
                      dayOfWeek: lessonDayOfWeek,
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
                    _loadLessons();
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _loadSubjectNames();
    });
  }

  void _deleteLesson(int id) async {
    await _dbHelper.deleteLesson(id);
    _loadLessons();
  }

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
                    Navigator.pop(context);
                    _showAddEditLessonDialog(existingLesson: lesson);
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
                                    color:
                                        Theme.of(context).colorScheme.primary))
                          ])),
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: const Text('Conferma Eliminazione'),
                                content: Text(
                                    'Vuoi eliminare la lezione di ${lesson.subjectName}?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Annulla')),
                                  FilledButton(
                                      onPressed: () {
                                        _deleteLesson(lesson.id!);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Elimina'))
                                ]));
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
                                    color: Theme.of(context).colorScheme.error))
                          ])),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddEditEventDialog({CalendarEvent? existingEvent}) {
    final TextEditingController titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: existingEvent?.description ?? '');
    String? selectedType = existingEvent?.type ?? 'compiti';
    String? selectedSubject = existingEvent?.subject;
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
                        decoration: const InputDecoration(labelText: 'Titolo')),
                    TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                            labelText: 'Descrizione (Opzionale)'),
                        maxLines: 3),
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
                            lastDate: DateTime(2101));
                        if (picked != null)
                          setState(() {
                            eventDate = picked;
                          });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: ['compiti', 'verifica', 'altro']
                          .map((String type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedType = v),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration: const InputDecoration(
                          labelText: 'Materia (Opzionale)'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Nessuna Materia')),
                        ..._subjectNames
                            .where((s) => s != 'Seleziona Materia')
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList()
                      ],
                      onChanged: (v) => setState(() => selectedSubject = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla')),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Il titolo non può essere vuoto.')));
                      return;
                    }
                    final newEvent = CalendarEvent(
                        id: existingEvent?.id,
                        title: titleController.text,
                        description: descriptionController.text,
                        date: eventDate,
                        type: selectedType!,
                        subject: selectedSubject);
                    if (existingEvent == null)
                      await _dbHelper.addCalendarEvent(newEvent);
                    else
                      await _dbHelper.updateCalendarEvent(newEvent);
                    Navigator.pop(context);
                    _loadCalendarEvents();
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
                  child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showAddEditEventDialog(existingEvent: event);
                      },
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(children: [
                            Icon(Icons.edit,
                                color: Theme.of(context).colorScheme.primary),
                            SizedBox(width: 8),
                            Text('Modifica Evento',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary))
                          ])))),
              Card(
                  child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                    title: const Text('Conferma Eliminazione'),
                                    content:
                                        Text('Eliminare "${event.title}"?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Annulla')),
                                      FilledButton(
                                          onPressed: () async {
                                            await _dbHelper
                                                .deleteCalendarEvent(event.id!);
                                            Navigator.pop(context);
                                            _loadCalendarEvents();
                                          },
                                          child: const Text('Elimina'))
                                    ]));
                      },
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(children: [
                            Icon(Icons.delete,
                                color: Theme.of(context).colorScheme.error),
                            SizedBox(width: 8),
                            Text('Elimina Evento',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error))
                          ])))),
            ],
          ),
        );
      },
    );
  }

  Color _getColorForGradeType(String? type) {
    if (type == null) return Colors.grey;
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

  IconData _getIconForGradeType(String? type) {
    if (type == null) return Icons.grade;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diario e Orario')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sezione Orario Scolastico
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Orario Scolastico',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48.0,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final day = index + 1;
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
                                _loadLessons();
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
                              style: Theme.of(context).textTheme.titleMedium))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
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
                                      Text(lesson.subjectName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(
                                          '${lesson.startTime} - ${lesson.endTime}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                      if (lesson.room?.isNotEmpty ?? false)
                                        Text('Aula: ${lesson.room}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      if (lesson.teacher?.isNotEmpty ?? false)
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
                  const SizedBox(height: 20.0),
                  Align(
                      alignment: Alignment.centerRight,
                      child: FloatingActionButton.extended(
                          onPressed: () => _showAddEditLessonDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Aggiungi Lezione'))),
                ],
              ),
            ),

            const Divider(height: 32, thickness: 1),

            // Sezione Calendario Integrata
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calendario',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TableCalendar(
                    locale: 'it_IT', // Aggiunto IT locale
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) =>
                        setState(() => _calendarFormat = format),
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    eventLoader:
                        _getEventsForDay, // Mostra indicatori sia per eventi che per voti
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
                          shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle),
                      markerDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      formatButtonDecoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(20.0)),
                      formatButtonTextStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer),
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Sezione Eventi
                  Text(
                      'Eventi per il ${_selectedDay != null ? DateFormat('dd-MM-yyyy').format(_selectedDay!) : ''}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10.0),
                  _selectedEvents.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Nessun evento registrato.',
                              style: TextStyle(fontStyle: FontStyle.italic)))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedEvents.length,
                          itemBuilder: (context, index) {
                            final event = _selectedEvents[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: InkWell(
                                onTap: () => _showEventOptionsDialog(event),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(event.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      if (event.description.isNotEmpty)
                                        Text(event.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (event.subject?.isNotEmpty ??
                                              false)
                                            Chip(
                                                label: Text(event.subject!,
                                                    style: const TextStyle(
                                                        fontSize: 10)),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero),
                                          Chip(
                                              label: Text(event.type,
                                                  style: const TextStyle(
                                                      fontSize: 10)),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 20.0),

                  // Sezione Voti Nuova
                  Text('Voti ricevuti',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10.0),
                  _selectedGrades.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Nessun voto registrato in questa data.',
                              style: TextStyle(fontStyle: FontStyle.italic)))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedGrades.length,
                          itemBuilder: (context, index) {
                            final grade = _selectedGrades[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getColorForGradeType(grade.type)
                                          .withOpacity(0.2),
                                  child: Icon(_getIconForGradeType(grade.type),
                                      color: _getColorForGradeType(grade.type),
                                      size: 20),
                                ),
                                title: Text(grade.grade.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                subtitle: Text(grade.subjectName),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(grade.type,
                                        style: const TextStyle(fontSize: 12)),
                                    if (grade.weight != 1.0)
                                      Text('Peso: ${grade.weight}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey)),
                                  ],
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
                          label: const Text('Aggiungi Evento'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
