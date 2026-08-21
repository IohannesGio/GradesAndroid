import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Lesson> _lessons = [];
  int _selectedDayOfWeek = DateTime.now().weekday;
  List<String> _subjectNames = [];

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<CalendarEvent>> _events = {};
  Map<DateTime, List<Grade>> _grades = {};

  List<CalendarEvent> _selectedEvents = [];
  List<Grade> _selectedGrades = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('it_IT', null);
    _selectedDay = _focusedDay;
    _loadSubjectNames();
    _loadLessons();
    _loadCalendarEvents();
    _loadGrades();
  }

  Future<void> _loadSubjectNames() async {
    try {
      final subjects = await _dbHelper.listSubjects();
      if (mounted) {
        setState(() {
          _subjectNames = subjects.map((s) => s.$1).toList();
          if (!_subjectNames.contains('Seleziona Materia')) {
            _subjectNames.insert(0, 'Seleziona Materia');
          }
        });
      }
    } catch (e) {
      print('Errore nel caricamento dei nomi delle materie: $e');
    }
  }

  Future<void> _loadLessons() async {
    setState(() {
      _lessons = [];
    });
    try {
      final lessons = await _dbHelper.getLessonsForDay(_selectedDayOfWeek);
      if (mounted) {
        setState(() {
          _lessons = lessons;
        });
      }
    } catch (e) {
      print('Errore nel caricamento delle lezioni: $e');
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      final allEvents = await _dbHelper.getAllCalendarEvents();
      _events = {};
      for (var event in allEvents) {
        final DateTime kDay = DateTime.utc(event.date.year, event.date.month, event.date.day);
        _events.putIfAbsent(kDay, () => []).add(event);
      }
      _updateSelectedItems();
    } catch (e) {
      print('Errore nel caricamento degli eventi del calendario: $e');
    }
  }

  Future<void> _loadGrades() async {
    try {
      final allGrades = await _dbHelper.getGradesForCalendar(
          startDate: DateTime(2020), endDate: DateTime(2030));

      _grades = {};
      for (var grade in allGrades) {
        final date = grade.dateTime;
        final DateTime kDay = DateTime.utc(date.year, date.month, date.day);
        _grades.putIfAbsent(kDay, () => []).add(grade);
      }
      _updateSelectedItems();
    } catch (e) {
      print('Errore nel caricamento dei voti: $e');
    }
  }

  void _updateSelectedItems() {
    if (_selectedDay != null && mounted) {
      setState(() {
        final DateTime kDay = DateTime.utc(
            _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
        _selectedEvents = _events[kDay] ?? [];
        _selectedGrades = _grades[kDay] ?? [];
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final DateTime kDay = DateTime.utc(day.year, day.month, day.day);
    final events = _events[kDay] ?? [];
    final grades = _grades[kDay] ?? [];
    return [...events, ...grades];
  }

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
    } catch (_) {}
    try {
      final format = DateFormat.jm();
      final dateTime = format.parse(timeString);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (_) {
      return TimeOfDay.now();
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showAddEditLessonDialog({Lesson? existingLesson}) {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final isUni = modeProvider.isUniversity;

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
    } else if (selectedSubject != null && !_subjectNames.contains(selectedSubject)) {
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
                  ? (isUni ? 'Aggiungi Lezione Universitaria' : 'Aggiungi Lezione')
                  : 'Modifica Lezione'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration: InputDecoration(labelText: isUni ? 'Insegnamento' : 'Materia'),
                      items: _subjectNames.map((String subject) {
                        return DropdownMenuItem<String>(
                            value: subject, child: Text(subject));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue;
                        });
                      },
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
                            if (picked != null) {
                              startTimeController.text = _formatTime(picked);
                            }
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
                            if (picked != null) {
                              endTimeController.text = _formatTime(picked);
                            }
                          },
                        ),
                      ),
                    ),
                    TextField(
                        controller: roomController,
                        decoration: const InputDecoration(labelText: 'Aula (Opzionale)')),
                    TextField(
                        controller: teacherController,
                        decoration: InputDecoration(
                            labelText: isUni ? 'Docente (Opzionale)' : 'Professore (Opzionale)')),
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
                    final newLesson = Lesson(
                      id: existingLesson?.id,
                      subjectName: selectedSubject!,
                      dayOfWeek: lessonDayOfWeek,
                      startTime: startTimeController.text,
                      endTime: endTimeController.text,
                      room: roomController.text.isNotEmpty ? roomController.text : null,
                      teacher: teacherController.text.isNotEmpty ? teacherController.text : null,
                    );
                    if (existingLesson == null) {
                      await _dbHelper.addLesson(newLesson);
                    } else {
                      await _dbHelper.updateLesson(newLesson);
                    }
                    if (context.mounted) Navigator.pop(context);
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

  void _showAddEditEventDialog({CalendarEvent? existingEvent}) {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final isUni = modeProvider.isUniversity;

    final TextEditingController titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    final TextEditingController descriptionController =
        TextEditingController(text: existingEvent?.description ?? '');
    String? selectedType = existingEvent?.type ?? (isUni ? 'appello' : 'compiti');
    String? selectedSubject = existingEvent?.subject;
    DateTime eventDate = existingEvent?.date ?? _selectedDay!;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingEvent == null
                  ? (isUni ? 'Aggiungi Appello / Evento' : 'Aggiungi Evento')
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
                      subtitle: Text(DateFormat('dd-MM-yyyy').format(eventDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: eventDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101));
                        if (picked != null) {
                          setState(() {
                            eventDate = picked;
                          });
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo Evento'),
                      items: (isUni
                              ? ['appello', 'esame', 'consegna', 'altro']
                              : ['compiti', 'verifica', 'altro'])
                          .map((String type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedType = v),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedSubject,
                      decoration: InputDecoration(
                          labelText: isUni ? 'Insegnamento (Opzionale)' : 'Materia (Opzionale)'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Nessuna Materia')),
                        ..._subjectNames
                            .where((s) => s != 'Seleziona Materia')
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                    if (existingEvent == null) {
                      await _dbHelper.addCalendarEvent(newEvent);
                    } else {
                      await _dbHelper.updateCalendarEvent(newEvent);
                    }
                    if (context.mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      appBar: AppBar(title: Text(isUni ? 'Appelli & Orario' : 'Diario e Orario')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUni ? 'Orario Lezioni Universitarie' : 'Orario Scolastico',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
                              child: ListTile(
                                title: Text(lesson.subjectName,
                                    style: Theme.of(context).textTheme.titleMedium),
                                subtitle: Text(
                                  '${lesson.startTime} - ${lesson.endTime} ${lesson.room != null ? '| Aula: ${lesson.room}' : ''}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteLesson(lesson.id!),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 16),
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
            const Divider(height: 32, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUni ? 'Calendario Appelli & Eventi' : 'Calendario Verifiche & Eventi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TableCalendar(
                    locale: 'it_IT',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onFormatChanged: (format) =>
                        setState(() => _calendarFormat = format),
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    eventLoader: _getEventsForDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.extended(
                      onPressed: () => _showAddEditEventDialog(),
                      icon: const Icon(Icons.event),
                      label: Text(isUni ? 'Aggiungi Appello' : 'Aggiungi Evento'),
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
