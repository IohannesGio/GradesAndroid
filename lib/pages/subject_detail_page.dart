import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';
import '../utils/date_utils.dart';
import 'settings_page.dart';

class SubjectDetailPage extends StatefulWidget {
  final String subjectName;

  const SubjectDetailPage({super.key, required this.subjectName});

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  final dbHelper = DatabaseHelper();
  List<Grade> _grades = [];
  String _averagePeriod = 'N/A';
  String _averageFirstPeriod = 'N/A';
  String _objective = 'N/A';
  Subject? _subjectDetails;

  final TextEditingController _dateController = TextEditingController();
  String _selectedType = 'orale';

  String? _gradeErrorText;
  String? _dateErrorText;
  String? _weightErrorText;

  double _passingGrade = 6.0;
  double _maxGrade = 10.0;

  @override
  void initState() {
    super.initState();
    _loadPassingAndMaxGrades();
    _loadSubjectData();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadPassingAndMaxGrades() async {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    setState(() {
      _passingGrade = modeProvider.passingGrade;
      _maxGrade = modeProvider.maxGrade;
    });
  }

  Future<void> _loadSubjectData() async {
    final grades = await dbHelper.listGrades(widget.subjectName);
    final avgPeriod = await dbHelper.returnAverageByPeriodBis(widget.subjectName);
    final details = await dbHelper.getSubjectDetails(widget.subjectName);

    int? firstPeriodStart;
    int? firstPeriodEnd;

    final periods = await SettingsPage.loadPeriodsFromPreferences();
    if (periods != null &&
        periods.containsKey('first_period_start') &&
        periods.containsKey('first_period_end')) {
      try {
        final DateTime startDateTime = DateFormat('dd-MM-yyyy').parse(periods['first_period_start']!);
        firstPeriodStart = int.parse(DateFormat('yyyyMMdd').format(startDateTime));
        final DateTime endDateTime = DateFormat('dd-MM-yyyy').parse(periods['first_period_end']!);
        firstPeriodEnd = int.parse(DateFormat('yyyyMMdd').format(endDateTime));
      } catch (e) {
        print('Errore nel parsing delle date: $e');
      }
    }

    String avg1 = 'N/A';
    if (firstPeriodStart != null && firstPeriodEnd != null) {
      avg1 = await dbHelper.returnAverageByPeriod(
          widget.subjectName, firstPeriodStart, firstPeriodEnd);
    }

    final obj = await dbHelper.returnObjective(widget.subjectName);

    if (mounted) {
      setState(() {
        _grades = grades;
        _averagePeriod = avgPeriod;
        _averageFirstPeriod = avg1;
        _objective = obj;
        _subjectDetails = details;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final String formattedDateDisplay = DateFormat('dd-MM-yyyy').format(picked);
      controller.text = formattedDateDisplay;
      setState(() {
        _dateErrorText = null;
      });
    }
  }

  /// Dialogo per la registrazione del Voto Esame Universitario (singolo)
  void _showUniExamGradeDialog({Grade? existing}) {
    double gradeVal = existing != null ? existing.grade : 28.0;
    bool isLode = existing?.note?.contains('30L') ?? false;
    bool isIdoneita = existing?.note?.contains('Idoneità') ?? false;

    if (existing?.date != null) {
      _dateController.text = formatIntDateToDisplay(existing!.date);
    } else {
      _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    }

    final noteController = TextEditingController(
      text: existing?.note?.replaceAll('30L', '').replaceAll('Idoneità', '').trim() ?? '',
    );

    _dateErrorText = null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.workspace_premium, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(existing == null ? 'Registra Voto Esame' : 'Modifica Voto Esame'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Switch Idoneità
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Idoneità / Approvato (senza voto numerico)'),
                      subtitle: const Text('Per tirocini o esami superati senza voto'),
                      value: isIdoneita,
                      onChanged: (val) {
                        setState(() {
                          isIdoneita = val;
                          if (val) isLode = false;
                        });
                      },
                    ),

                    if (!isIdoneita) ...[
                      const SizedBox(height: 12),
                      Text('Voto Esame: ${gradeVal == 30.0 && isLode ? "30 e Lode" : gradeVal.toInt()}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              )),
                      const SizedBox(height: 4),
                      Slider(
                        value: gradeVal,
                        min: 18.0,
                        max: 30.0,
                        divisions: 12,
                        label: gradeVal.toInt().toString(),
                        onChanged: (val) {
                          setState(() {
                            gradeVal = val;
                            if (val < 30.0) isLode = false;
                          });
                        },
                      ),
                      if (gradeVal == 30.0)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('30 e Lode'),
                          value: isLode,
                          onChanged: (val) {
                            setState(() {
                              isLode = val ?? false;
                            });
                          },
                        ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Data di Verbalizzazione',
                        suffixIcon: const Icon(Icons.calendar_today),
                        errorText: _dateErrorText,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, _dateController),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Note (Docente, Note personali)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final dateForSaving = parseDisplayDateToInt(_dateController.text);
                    if (dateForSaving == null) {
                      setState(() => _dateErrorText = 'Seleziona una data valida');
                      return;
                    }

                    String noteText = noteController.text.trim();
                    if (isIdoneita) {
                      noteText = noteText.isEmpty ? 'Idoneità' : 'Idoneità - $noteText';
                    } else if (isLode) {
                      noteText = noteText.isEmpty ? '30L' : '30L - $noteText';
                    }

                    final double finalGrade = isIdoneita ? 30.0 : gradeVal;

                    if (existing == null) {
                      await dbHelper.addGrade(
                        widget.subjectName,
                        finalGrade,
                        dateForSaving,
                        1.0,
                        'esame',
                        note: noteText,
                      );
                    } else {
                      await dbHelper.editGrade({
                        'grade_id': existing.id,
                        'subject': widget.subjectName,
                        'grade': finalGrade,
                        'date': dateForSaving,
                        'grade_weight': 1.0,
                        'type': 'esame',
                        'note': noteText,
                      });
                    }

                    if (context.mounted) Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Salva Voto'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result == true) {
        _loadSubjectData();
      }
    });
  }

  /// Dialogo scuola standard per aggiunta voti multipli
  void _showSchoolGradeDialog({Grade? existing}) {
    final gradeController = TextEditingController(text: existing?.grade.toString());
    if (existing?.date != null) {
      _dateController.text = formatIntDateToDisplay(existing!.date);
    } else {
      _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    }

    final weightController = TextEditingController(text: existing?.weight.toString() ?? '1.0');
    _selectedType = existing?.type ?? 'orale';
    final noteController = TextEditingController(text: existing?.note);

    _gradeErrorText = null;
    _dateErrorText = null;
    _weightErrorText = null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Aggiungi Voto' : 'Modifica Voto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: gradeController,
                    decoration: InputDecoration(
                      labelText: 'Voto (range 0 - $_maxGrade)',
                      errorText: _gradeErrorText,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText: 'Data (DD-MM-YYYY)',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context, _dateController),
                      ),
                      errorText: _dateErrorText,
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, _dateController),
                  ),
                  TextField(
                    controller: weightController,
                    decoration: InputDecoration(
                      labelText: 'Peso',
                      errorText: _weightErrorText,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: ['orale', 'scritto', 'pratico', 'altro'].map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedType = newValue);
                      }
                    },
                  ),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Nota (Opzionale)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    setState(() {
                      _gradeErrorText = null;
                      _dateErrorText = null;
                      _weightErrorText = null;
                    });

                    bool hasError = false;
                    final grade = double.tryParse(gradeController.text);
                    if (gradeController.text.isEmpty ||
                        grade == null ||
                        grade < 0 ||
                        grade > _maxGrade) {
                      setState(() => _gradeErrorText = 'Voto deve essere tra 0 e $_maxGrade');
                      hasError = true;
                    }

                    final dateForSaving = parseDisplayDateToInt(_dateController.text);
                    if (dateForSaving == null) {
                      setState(() => _dateErrorText = 'Data non valida');
                      hasError = true;
                    }

                    final weight = double.tryParse(weightController.text);
                    if (weightController.text.isEmpty || weight == null) {
                      setState(() => _weightErrorText = 'Peso non valido');
                      hasError = true;
                    }

                    if (!hasError) {
                      if (existing == null) {
                        await dbHelper.addGrade(
                            widget.subjectName, grade!, dateForSaving!, weight!, _selectedType,
                            note: noteController.text);
                      } else {
                        await dbHelper.editGrade({
                          'grade_id': existing.id,
                          'subject': widget.subjectName,
                          'grade': grade!,
                          'date': dateForSaving!,
                          'grade_weight': weight!,
                          'type': _selectedType,
                          'note': noteController.text
                        });
                      }
                      if (context.mounted) Navigator.pop(context, true);
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
      if (result == true) {
        _loadSubjectData();
      }
    });
  }

  void _showEditCfuDialog() {
    final cfuController = TextEditingController(text: (_subjectDetails?.cfu ?? 6).toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifica Crediti (CFU)'),
          content: TextField(
            controller: cfuController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'CFU dell\'insegnamento'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                final newCfu = int.tryParse(cfuController.text);
                if (newCfu != null && newCfu > 0) {
                  await dbHelper.updateSubjectCfu(widget.subjectName, newCfu);
                  if (context.mounted) Navigator.pop(context);
                  _loadSubjectData();
                }
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  void _showEditSubjectNameDialog() {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final isUni = modeProvider.isUniversity;
    final nameController = TextEditingController(text: widget.subjectName);
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isUni ? 'Modifica Nome Esame' : 'Modifica Nome Materia'),
              content: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: isUni ? 'Nuovo nome insegnamento' : 'Nuovo nome materia',
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
                        await dbHelper.renameSubject(widget.subjectName, newName);
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        setState(() => errorText = e.toString());
                      }
                    } else if (newName == widget.subjectName) {
                      setState(() => errorText = 'Il nuovo nome è uguale a quello attuale');
                    } else {
                      setState(() => errorText = 'Il campo non può essere vuoto');
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
    _loadSubjectData();
  }

  void _confirmDeleteSubject() {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final isUni = modeProvider.isUniversity;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conferma Eliminazione'),
          content: Text(
              'Sei sicuro di voler eliminare "${widget.subjectName}" e tutti i relativi dati?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isUni ? 'Elimina Esame' : 'Elimina Materia'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _deleteSubject();
      }
    });
  }

  void _deleteSubject() async {
    await dbHelper.deleteSubject(widget.subjectName);
    if (mounted) Navigator.pop(context);
  }

  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    Color getColorForValue(String label, String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey.withOpacity(0.2);
      if (label == 'Obiettivo' || label == 'CFU') {
        return Colors.blue.withOpacity(0.2);
      }
      return val >= _passingGrade
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2);
    }

    Color getTextColorForBackground(String label, String value) {
      double? val = double.tryParse(value);
      if (val == null) return Colors.grey;
      if (label == 'Obiettivo' || label == 'CFU') {
        return Colors.blue;
      }
      return val >= _passingGrade ? Colors.green : Colors.red;
    }

    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: getColorForValue(label, value),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: getTextColorForBackground(label, value),
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

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifica Nome Esame',
            onPressed: _showEditSubjectNameDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Elimina Esame',
            onPressed: _confirmDeleteSubject,
          ),
        ],
      ),
      body: Hero(
        tag: widget.subjectName,
        child: Material(
          type: MaterialType.transparency,
          child: isUni ? _buildUniversityView() : _buildSchoolView(),
        ),
      ),
    );
  }

  /// Vista Università: Scheda Singola Verbalizzazione Esame
  Widget _buildUniversityView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasGrade = _grades.isNotEmpty;
    final Grade? examGrade = hasGrade ? _grades.first : null;

    final bool isLode = examGrade?.note?.contains('30L') ?? false;
    final bool isIdoneita = examGrade?.note?.contains('Idoneità') ?? false;

    String displayGradeText = 'Non verbalizzato';
    if (hasGrade) {
      if (isIdoneita) {
        displayGradeText = 'Idoneità';
      } else if (isLode) {
        displayGradeText = '30L';
      } else {
        displayGradeText = '${examGrade!.grade.toInt()} / 30';
      }
    }

    return Column(
      children: [
        // Scheda CFU Insegnamento
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _showEditCfuDialog,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.school, color: colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Crediti Formativi (CFU)', style: theme.textTheme.labelMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${_subjectDetails?.cfu ?? 6} CFU',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: colorScheme.outline, size: 20),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),

        // Scheda Stato Esame Singolo
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: hasGrade
                          ? Colors.green.withValues(alpha: 0.5)
                          : colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Status Icon & Badge
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: hasGrade
                                ? Colors.green.withValues(alpha: 0.1)
                                : colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasGrade ? Icons.verified : Icons.pending_actions,
                            size: 48,
                            color: hasGrade ? Colors.green : colorScheme.outline,
                          ),
                        ).animate().scale(delay: 100.ms, duration: 400.ms),

                        const SizedBox(height: 16),

                        Text(
                          hasGrade ? 'Esame Sostenuto' : 'Esame da Sostenere',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: hasGrade ? Colors.green : colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 8),

                        if (hasGrade) ...[
                          Text(
                            displayGradeText,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isIdoneita ? colorScheme.primary : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Data verbalizzazione: ${formatIntDateToDisplay(examGrade!.date)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (examGrade.note != null && examGrade.note!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nota: ${examGrade.note}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            'Non hai ancora registrato il voto per questo insegnamento.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Action Buttons
                        if (hasGrade) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showUniExamGradeDialog(existing: examGrade),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Modifica Voto'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.outlined(
                                onPressed: () => _deleteGrade(examGrade!.id!),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Rimuovi Voto',
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          FilledButton.icon(
                            onPressed: () => _showUniExamGradeDialog(),
                            icon: const Icon(Icons.add_task),
                            label: const Text('Registra Voto Esame'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Vista Scuola: Lista di voti multipli con medie e tipi di voto
  Widget _buildSchoolView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Media', _averagePeriod),
              _buildStatCard('Media 1Q', _averageFirstPeriod),
              _buildStatCard('Obiettivo', _objective),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Voti', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _grades.length,
            itemBuilder: (_, i) {
              final g = _grades[i];
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: g.grade >= _passingGrade
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          g.grade.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: g.grade >= _passingGrade ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('(${g.type})'),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data: ${formatIntDateToDisplay(g.date)} - Peso: ${g.weight}'),
                      if (g.note != null && g.note!.isNotEmpty)
                        Text('Nota: ${g.note}',
                            style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  onTap: () => _showSchoolGradeDialog(existing: g),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteGrade(g.id!),
                  ),
                ),
              );
            },
          ).animate().fadeIn(delay: 50.ms).slideX(begin: 0.2, end: 0),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: () => _showSchoolGradeDialog(),
            child: const Text('Aggiungi Voto'),
          ),
        ),
      ],
    );
  }
}
