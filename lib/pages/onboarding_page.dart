import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/education_mode_provider.dart';
import '../database_helper.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  EducationMode _selectedMode = EducationMode.school;

  // Custom parameters
  double _passingGrade = 6.0;
  double _maxGrade = 10.0;
  int _targetCfu = 180;
  String _lodeRule = 'equal_30';
  double _lodeCustomValue = 31.0;
  double _lodeDegreeBonus = 0.5;

  // Pre-added initial subjects
  final List<String> _initialSubjects = [];
  final TextEditingController _subjectInputController = TextEditingController();

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final provider = Provider.of<EducationModeProvider>(context, listen: false);

    // Save initial subjects if provided
    final dbHelper = DatabaseHelper();
    for (String s in _initialSubjects) {
      if (s.trim().isNotEmpty) {
        await dbHelper.addSubject(
          s.trim(),
          cfu: _selectedMode == EducationMode.university ? 6 : 0,
        );
      }
    }

    await provider.completeOnboarding(
      mode: _selectedMode,
      passingGrade: _passingGrade,
      maxGrade: _maxGrade,
      targetCfu: _targetCfu,
      lodeRule: _lodeRule,
      lodeCustomValue: _lodeCustomValue,
      lodeDegreeBonus: _lodeDegreeBonus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Header & Progress Dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _previousPage,
                    )
                  else
                    const SizedBox(width: 48),
                  
                  // Progress Dots
                  Row(
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colorScheme.primary
                              : colorScheme.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Page Content View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1ModeSelection(theme, colorScheme),
                  _buildStep2ParametersConfig(theme, colorScheme),
                  _buildStep3InitialSubjects(theme, colorScheme),
                ],
              ),
            ),

            // Bottom Navigation Action
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _nextPage,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == 2
                            ? 'Completa Configurazione'
                            : 'Continua',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentPage == 2
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 1: MODE SELECTION ---
  Widget _buildStep1ModeSelection(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Benvenuto in Grades! 👋',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Text(
            'Scegli il tuo percorso attuale per costruire l\'interfaccia ideale per i tuoi studi.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 32),

          // Card 1: Scuola
          _buildModeCard(
            title: 'Scuola (Medie / Superiori)',
            subtitle: 'Materie, voti da 0 a 10, quadrimestri e diario con compiti.',
            icon: Icons.school,
            badge: 'Voti 0 - 10',
            mode: EducationMode.school,
            colorScheme: colorScheme,
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),

          const SizedBox(height: 20),

          // Card 2: Università
          _buildModeCard(
            title: 'Università',
            subtitle: 'Libretto esami, voti 18-30L, CFU, media ponderata e proiezione laurea.',
            icon: Icons.account_balance,
            badge: 'Voti 18 - 30L & CFU',
            mode: EducationMode.university,
            colorScheme: colorScheme,
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required EducationMode mode,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMode = mode;
            if (mode == EducationMode.university) {
              _passingGrade = 18.0;
              _maxGrade = 30.0;
            } else {
              _passingGrade = 6.0;
              _maxGrade = 10.0;
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.4)
                : colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withOpacity(0.15)
                            : colorScheme.outline.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? colorScheme.primary
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
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

  // --- STEP 2: PARAMETERS CONFIG ---
  Widget _buildStep2ParametersConfig(ThemeData theme, ColorScheme colorScheme) {
    final isUni = _selectedMode == EducationMode.university;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Impostazioni Iniziali ⚙️',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 8),
          Text(
            isUni
                ? 'Personalizza i parametri per il tuo percorso universitario.'
                : 'Imposta la scala di valutazione per il tuo anno scolastico.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 28),

          // Passing grade card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Voto di Sufficienza',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(
                          _passingGrade.toStringAsFixed(1),
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                        ),
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _passingGrade,
                    min: isUni ? 10.0 : 1.0,
                    max: isUni ? 25.0 : 8.0,
                    divisions: isUni ? 15 : 14,
                    label: _passingGrade.toStringAsFixed(1),
                    onChanged: (val) => setState(() => _passingGrade = val),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Max grade card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Voto Massimo',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(
                          isUni && _maxGrade == 30.0 ? '30 / 30L' : _maxGrade.toStringAsFixed(1),
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                        ),
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _maxGrade,
                    min: isUni ? 25.0 : 8.0,
                    max: isUni ? 30.0 : 10.0,
                    divisions: isUni ? 5 : 4,
                    label: _maxGrade.toStringAsFixed(1),
                    onChanged: (val) => setState(() => _maxGrade = val),
                  ),
                ],
              ),
            ),
          ),

          if (isUni) ...[
            const SizedBox(height: 16),
            // Target CFU setup card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CFU Totali Corso di Laurea',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCfuChoiceChip(180, 'Triennale (180 CFU)', colorScheme),
                        _buildCfuChoiceChip(120, 'Magistrale (120 CFU)', colorScheme),
                        _buildCfuChoiceChip(300, 'Ciclo Unico (300 CFU)', colorScheme),
                        _buildCfuChoiceChip(360, 'Medicina (360 CFU)', colorScheme),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 30 e Lode rule setup card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valutazione "30 e Lode" 🎖️',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seleziona il regolamento del tuo ateneo per il calcolo della lode:',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _lodeRule,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'equal_30', child: Text('30L = 30 (Standard)')),
                        DropdownMenuItem(value: 'equal_31', child: Text('30L = 31 nella media')),
                        DropdownMenuItem(value: 'equal_32', child: Text('30L = 32 nella media')),
                        DropdownMenuItem(value: 'bonus_degree_0_5', child: Text('30L = +0.50 punti su voto laurea')),
                        DropdownMenuItem(value: 'custom', child: Text('Valore Personalizzato')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _lodeRule = val);
                      },
                    ),
                    if (_lodeRule == 'custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Valore numerico per 30L (es. 31.5)',
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) _lodeCustomValue = parsed;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCfuChoiceChip(int cfu, String label, ColorScheme colorScheme) {
    final isSelected = _targetCfu == cfu;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _targetCfu = cfu);
      },
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.primary : null,
      ),
    );
  }

  // --- STEP 3: INITIAL SUBJECTS ---
  Widget _buildStep3InitialSubjects(ThemeData theme, ColorScheme colorScheme) {
    final isUni = _selectedMode == EducationMode.university;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            isUni ? 'Insegnamenti / Esami 📚' : 'Materie Scolastiche 📚',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 8),
          Text(
            isUni
                ? 'Aggiungi i tuoi primi esami (potrai sempre farlo dopo).'
                : 'Aggiungi le tue prime materie (potrai sempre aggiungerne altre in seguito).',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subjectInputController,
                  decoration: InputDecoration(
                    hintText: isUni ? 'Es. Analisi Matematica' : 'Es. Matematica',
                    prefixIcon: const Icon(Icons.book_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() {
                        _initialSubjects.add(val.trim());
                        _subjectInputController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: () {
                  final text = _subjectInputController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _initialSubjects.add(text);
                      _subjectInputController.clear();
                    });
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _initialSubjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 48,
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isUni ? 'Nessun esame aggiunto ancora' : 'Nessuna materia aggiunta ancora',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _initialSubjects.length,
                    itemBuilder: (context, index) {
                      final item = _initialSubjects[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _initialSubjects.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
