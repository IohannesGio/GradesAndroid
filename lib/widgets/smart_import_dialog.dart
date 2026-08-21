import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/local_exam_parser.dart';

/// Result returned by SmartImportDialog.
/// Contains the list of exams selected by the user.
class SmartImportResult {
  final List<ParsedExamItem> selectedExams;
  SmartImportResult(this.selectedExams);
}

/// A dialog that lets the user paste text from a university course page
/// and uses the local AI parser to automatically extract exams and CFUs.
///
/// Usage:
/// ```dart
/// final result = await showSmartImportDialog(context);
/// if (result != null) {
///   for (final exam in result.selectedExams) {
///     await dbHelper.addSubject(exam.title, cfu: exam.cfu);
///   }
/// }
/// ```
Future<SmartImportResult?> showSmartImportDialog(BuildContext context) {
  return showModalBottomSheet<SmartImportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SmartImportSheet(),
  );
}

class _SmartImportSheet extends StatefulWidget {
  const _SmartImportSheet();

  @override
  State<_SmartImportSheet> createState() => _SmartImportSheetState();
}

class _SmartImportSheetState extends State<_SmartImportSheet> {
  final TextEditingController _pasteController = TextEditingController();
  List<ParsedExamItem> _parsedItems = [];
  bool _hasParsed = false;
  bool _isParsing = false;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _pasteController.text = data.text!;
      });
      _runParsing(data.text!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun testo trovato negli appunti.')),
        );
      }
    }
  }

  void _runParsing(String text) {
    setState(() {
      _isParsing = true;
    });

    // Simulate a brief delay to show the parsing animation
    Future.delayed(const Duration(milliseconds: 400), () {
      final results = LocalExamParser.parseText(text);
      if (mounted) {
        setState(() {
          _parsedItems = results;
          _hasParsed = true;
          _isParsing = false;
        });
      }
    });
  }

  void _selectAll(bool select) {
    setState(() {
      for (var item in _parsedItems) {
        item.isSelected = select;
      }
    });
  }

  int get _selectedCount => _parsedItems.where((e) => e.isSelected).length;

  void _importSelected() {
    final selected = _parsedItems.where((e) => e.isSelected).toList();
    if (selected.isEmpty) return;
    Navigator.of(context).pop(SmartImportResult(selected));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.auto_awesome, color: colorScheme.onPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Importa Esami da Testo',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Incolla il testo dalla pagina del tuo corso di laurea',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const Divider(height: 1),

              // Content
              Expanded(
                child: _hasParsed
                    ? _buildResultsView(scrollController)
                    : _buildPasteView(scrollController),
              ),

              // Bottom action bar
              if (_hasParsed && _parsedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasParsed = false;
                              _parsedItems = [];
                              _pasteController.clear();
                            });
                          },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Indietro'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _selectedCount > 0 ? _importSelected : null,
                          icon: const Icon(Icons.download_done, size: 20),
                          label: Text(
                            'Importa $_selectedCount ${_selectedCount == 1 ? 'esame' : 'esami'}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPasteView(ScrollController scrollController) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction card
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Come funziona',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Apri la pagina del piano di studi del tuo corso di laurea\n'
                    '2. Seleziona e copia tutto il testo della pagina\n'
                    '3. Incollalo qui sotto e il sistema estrarrà automaticamente gli esami e i CFU',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

          const SizedBox(height: 16),

          // Paste button
          FilledButton.tonalIcon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste),
            label: const Text('Incolla dagli Appunti'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

          const SizedBox(height: 12),

          // Or paste manually into text area
          Text(
            'oppure incolla manualmente:',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _pasteController,
            maxLines: 10,
            minLines: 5,
            decoration: InputDecoration(
              hintText: 'Incolla qui il testo del piano di studi...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 300.ms),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _isParsing
                ? null
                : () {
                    final text = _pasteController.text.trim();
                    if (text.isNotEmpty) {
                      _runParsing(text);
                    }
                  },
            icon: _isParsing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isParsing ? 'Analisi in corso...' : 'Analizza Testo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
        ],
      ),
    );
  }

  Widget _buildResultsView(ScrollController scrollController) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_parsedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Nessun esame riconosciuto',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prova a incollare un testo diverso o verifica\nche contenga nomi di esami e CFU.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _hasParsed = false;
                  _parsedItems = [];
                  _pasteController.clear();
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.checklist, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_parsedItems.length} esami rilevati',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => _selectAll(true),
                child: const Text('Tutti'),
              ),
              TextButton(
                onPressed: () => _selectAll(false),
                child: const Text('Nessuno'),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 200.ms),

        // Exam list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _parsedItems.length,
            itemBuilder: (context, index) {
              final item = _parsedItems[index];
              return _ExamCard(
                item: item,
                onChanged: () => setState(() {}),
              ).animate(delay: (50 * index).ms).fadeIn(duration: 250.ms).slideX(begin: 0.15, end: 0);
            },
          ),
        ),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ParsedExamItem item;
  final VoidCallback onChanged;

  const _ExamCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: item.isSelected ? 1 : 0,
      color: item.isSelected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: item.isSelected
            ? BorderSide(color: colorScheme.primary.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          item.isSelected = !item.isSelected;
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: (val) {
                  item.isSelected = val ?? false;
                  onChanged();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showEditDialog(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: item.isSelected ? null : TextDecoration.lineThrough,
                          color: item.isSelected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.school_outlined, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${item.cfu} CFU',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit_outlined, size: 12, color: colorScheme.outline),
                          const SizedBox(width: 2),
                          Text(
                            'Modifica',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final titleController = TextEditingController(text: item.title);
    final cfuController = TextEditingController(text: item.cfu.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifica Esame'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Nome Esame'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cfuController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CFU'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newCfu = int.tryParse(cfuController.text) ?? item.cfu;
              if (newTitle.isNotEmpty) {
                item.title = newTitle;
                item.cfu = newCfu;
                onChanged();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
