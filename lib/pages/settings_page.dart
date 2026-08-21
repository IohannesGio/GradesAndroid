import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/education_mode_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<Map<String, String>?> loadPeriodsFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final firstStart = prefs.getString('first_period_start');
    final firstEnd = prefs.getString('first_period_end');
    final secondStart = prefs.getString('second_period_start');
    final secondEnd = prefs.getString('second_period_end');

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

  static Future<Map<String, double>> loadPassingAndMaxGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final passingGrade = prefs.getDouble('passing_grade') ?? 6.0;
    final maxGrade = prefs.getDouble('max_grade') ?? 10.0;
    return {'passing_grade': passingGrade, 'max_grade': maxGrade};
  }
}

class _SettingsPageState extends State<SettingsPage> {
  DateTime? _firstPeriodStart;
  DateTime? _firstPeriodEnd;
  DateTime? _secondPeriodStart;
  DateTime? _secondPeriodEnd;

  final DateFormat _displayFormat = DateFormat('dd-MM-yyyy');
  final DateFormat _saveFormat = DateFormat('yyyyMMdd');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    final periods = await SettingsPage.loadPeriodsFromPreferences();
    if (periods != null && mounted) {
      setState(() {
        try {
          _firstPeriodStart = DateFormat('dd-MM-yyyy').parse(periods['first_period_start']!);
          _firstPeriodEnd = DateFormat('dd-MM-yyyy').parse(periods['first_period_end']!);
          _secondPeriodStart = DateFormat('dd-MM-yyyy').parse(periods['second_period_start']!);
          _secondPeriodEnd = DateFormat('dd-MM-yyyy').parse(periods['second_period_end']!);
        } catch (e) {
          print('Errore nel parsing delle date: $e');
        }
      });
    }
  }

  Future<void> _savePeriods() async {
    final prefs = await SharedPreferences.getInstance();
    if (_firstPeriodStart != null) {
      await prefs.setString('first_period_start', _displayFormat.format(_firstPeriodStart!));
    }
    if (_firstPeriodEnd != null) {
      await prefs.setString('first_period_end', _displayFormat.format(_firstPeriodEnd!));
    }
    if (_secondPeriodStart != null) {
      await prefs.setString('second_period_start', _displayFormat.format(_secondPeriodStart!));
    }
    if (_secondPeriodEnd != null) {
      await prefs.setString('second_period_end', _displayFormat.format(_secondPeriodEnd!));
    }
  }

  void _confirmChangeMode(EducationMode newMode) {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);
    final targetModeName = newMode == EducationMode.university ? 'Università' : 'Scuola';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ Conferma Cambio Percorso'),
        content: Text(
          'Passare a "$targetModeName" comporterà il RESET COMPLETO DI TUTTI I DATI dell\'applicazione per garantire la coerenza dei voti e delle materie.\n\nSei sicuro di voler proseguire?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await modeProvider.setEducationMode(newMode, resetData: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Percorso impostato su $targetModeName. Dati resettati.')),
                );
                _loadSettings();
              }
            },
            child: const Text('Resetta e Cambia'),
          ),
        ],
      ),
    );
  }

  void _confirmRestartOnboarding() {
    final modeProvider = Provider.of<EducationModeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Riavvia Configurazione Iniziale'),
        content: const Text(
          'Riavviare la configurazione guidata comporterà il RESET COMPLETO DEI DATI attuali.\n\nVuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await modeProvider.resetAllDataAndRestartOnboarding();
            },
            child: const Text('Riavvia e Resetta'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _selectDateInDialog(BuildContext context, DateTime? initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
  }

  Future<void> _showEditPeriodDialog(String periodName, DateTime? currentStart,
      DateTime? currentEnd, Function(DateTime?, DateTime?) onSave) async {
    DateTime? selectedStart = currentStart;
    DateTime? selectedEnd = currentEnd;
    String? errorText;

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
                    subtitle: Text(selectedStart != null
                        ? _displayFormat.format(selectedStart!)
                        : 'Seleziona data'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await _selectDateInDialog(context, selectedStart);
                      if (picked != null) {
                        setState(() {
                          selectedStart = picked;
                          errorText = null;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Data Fine'),
                    subtitle: Text(selectedEnd != null
                        ? _displayFormat.format(selectedEnd!)
                        : 'Seleziona data'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await _selectDateInDialog(context, selectedEnd);
                      if (picked != null) {
                        setState(() {
                          selectedEnd = picked;
                          errorText = null;
                        });
                      }
                    },
                  ),
                  if (errorText != null)
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (selectedStart != null &&
                        selectedEnd != null &&
                        selectedStart!.isAfter(selectedEnd!)) {
                      setState(() {
                        errorText =
                            'La data di inizio non può essere successiva alla data di fine.';
                      });
                      return;
                    }

                    final int? startInt = selectedStart != null
                        ? int.parse(_saveFormat.format(selectedStart!))
                        : null;
                    final int? endInt = selectedEnd != null
                        ? int.parse(_saveFormat.format(selectedEnd!))
                        : null;

                    final result = await DatabaseHelper().setPeriod(
                        periodName.contains('Primo') || periodName.contains('1°')
                            ? 'first_period'
                            : 'second_period',
                        startInt!,
                        endInt!);

                    if (result == 'invalid dates') {
                      setState(() {
                        errorText =
                            'Date non valide o si sovrappongono con l\'altro periodo.';
                      });
                    } else if (result == true) {
                      onSave(selectedStart, selectedEnd);
                      if (context.mounted) Navigator.pop(context);
                    } else {
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

  void _handleExportDatabase() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esportazione del database in corso...')),
    );
    final result = await DatabaseHelper().exportDatabase();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  void _handleImportDatabase() async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'Database SQLite',
        extensions: ['sqlite3'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importazione in corso...')),
        );
      }

      final result = await DatabaseHelper().importDatabase(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
        if (result.contains('successo')) {
          _loadSettings();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'importazione: $e')),
        );
      }
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Tutti i dati sono stati eliminati.'
                        : 'Errore durante l\'eliminazione dei dati.'),
                  ),
                );
              }
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
    final modeProvider = Provider.of<EducationModeProvider>(context);
    final isUni = modeProvider.isUniversity;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // --- SECTION 1: PERCORSO DI STUDI ---
            Row(
              children: [
                Icon(isUni ? Icons.account_balance : Icons.school,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Percorso di Studi', style: Theme.of(context).textTheme.titleLarge),
              ],
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: 8),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isUni ? Icons.school : Icons.menu_book,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUni ? 'Modalità Università' : 'Modalità Scuola',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isUni
                                    ? 'Libretto esami, voti 18-30L, CFU e media ponderata'
                                    : 'Materie scolastiche, voti 0-10 e quadrimestri',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(isUni ? 'Passa a Scuola' : 'Passa a Università'),
                            onPressed: () {
                              _confirmChangeMode(isUni
                                  ? EducationMode.school
                                  : EducationMode.university);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Riavvia Configurazione Iniziale'),
                            onPressed: _confirmRestartOnboarding,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- SECTION 2: PERIODI / SEMESTRI ---
            Row(
              children: [
                Icon(Icons.calendar_month,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(isUni ? 'Semestri' : 'Periodi / Quadrimestri',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: 8),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showEditPeriodDialog(
                    isUni ? 'Primo Semestre' : 'Primo Quadrimestre',
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
                      Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUni ? 'Primo Semestre' : 'Primo Quadrimestre',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
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
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showEditPeriodDialog(
                    isUni ? 'Secondo Semestre' : 'Secondo Quadrimestre',
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
                      Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUni ? 'Secondo Semestre' : 'Secondo Quadrimestre',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
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
            ),

            const SizedBox(height: 24),

            // --- SECTION 3: GESTIONE DATI ---
            Row(
              children: [
                Icon(Icons.data_usage, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Gestione Dati', style: Theme.of(context).textTheme.titleLarge),
              ],
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: 8),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.backup, color: Theme.of(context).colorScheme.primary),
                title: const Text('Esporta Database'),
                subtitle: const Text('Salva un backup del database'),
                onTap: _handleExportDatabase,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
                title: const Text('Importa Database'),
                subtitle: const Text('Ripristina un backup SQLite'),
                onTap: _handleImportDatabase,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Elimina Tutti i Dati', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Cancella l\'intero database dell\'app'),
                onTap: _handleClearData,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
