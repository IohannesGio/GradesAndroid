import 'dart:async';
import 'dart:io'; // Per Directory
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; // Per formattare DateTime se necessario

// --- Model Classes (Rappresentano le tabelle del DB) ---

class Subject {
  final int? id;
  final String subjectName;
  final double? objective; // REAL in SQLite corrisponde a double in Dart

  Subject({this.id, required this.subjectName, this.objective});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subjectName
          .toUpperCase(), // Assicura maiuscolo come nel codice Python
      'objective': objective,
    };
  }

  // Metodo factory per creare un Subject da una Map (risultato query)
  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      subjectName: map['subject'] as String,
      objective: map['objective'] as double?,
    );
  }

  @override
  String toString() {
    return 'Subject{id: $id, subjectName: $subjectName, objective: $objective}';
  }
}

class Grade {
  final int? id;
  final String subjectName;
  final double grade; // REAL
  final int date; // INTEGER YYYYMMDD come nel codice Python
  final double weight; // REAL
  final String type; // TEXT

  Grade({
    this.id,
    required this.subjectName,
    required this.grade,
    required this.date,
    required this.weight,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_name': subjectName,
      'grade': grade,
      'date': date,
      'weight': weight,
      'type': type,
    };
  }

  factory Grade.fromMap(Map<String, dynamic> map) {
    return Grade(
      id: map['id'] as int?,
      subjectName: map['subject_name'] as String,
      grade: map['grade'] as double,
      date: map['date'] as int,
      weight: map['weight'] as double,
      type: map['type'] as String,
    );
  }

  // Helper per ottenere DateTime (opzionale, se vuoi lavorarci)
  DateTime get dateTime {
    final dateStr = date.toString();
    if (dateStr.length == 8) {
      try {
        return DateTime.parse(
            '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}');
      } catch (e) {
        // Gestisci errore di parsing se il formato non è valido
        return DateTime(1970); // O un valore di default
      }
    }
    return DateTime(1970); // Valore di default se formato non valido
  }

  @override
  String toString() {
    return 'Grade{id: $id, subjectName: $subjectName, grade: $grade, date: $date, weight: $weight, type: $type}';
  }
}

class Period {
  final String name; // PRIMARY KEY
  final int? startDate; // INTEGER YYYYMMDD o null se 'N/A'
  final int? endDate; // INTEGER YYYYMMDD o null se 'N/A'

  Period({required this.name, this.startDate, this.endDate});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      // Salva 'N/A' se null, altrimenti il valore int
      'start_date': startDate ?? 'N/A',
      'end_date': endDate ?? 'N/A',
    };
  }

  factory Period.fromMap(Map<String, dynamic> map) {
    // Converte 'N/A' in null, altrimenti fa il parsing dell'intero
    int? parseDate(dynamic value) {
      if (value is int) return value;
      if (value is String && value != 'N/A') {
        return int.tryParse(value);
      }
      return null;
    }

    return Period(
      name: map['name'] as String,
      startDate: parseDate(map['start_date']),
      endDate: parseDate(map['end_date']),
    );
  }
  @override
  String toString() {
    return 'Period{name: $name, startDate: $startDate, endDate: $endDate}';
  }
}

// --- Database Helper Class ---

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _dbName = "grades.sqlite3"; // Nome file DB

  // Getter per il database (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inizializzazione del database
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);

    return await openDatabase(
      path,
      version: 1, // Inizia con la versione 1
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // Definisci se devi gestire migrazioni future
    );
  }

  // Creazione delle tabelle alla prima apertura del DB
  Future<void> _onCreate(Database db, int version) async {
    // NOTA: Usiamo INTEGER per le date YYYYMMDD come nel codice Python
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subject_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT UNIQUE,
        objective REAL
      )
    '''); //
    await db.execute('''
      CREATE TABLE IF NOT EXISTS grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_name TEXT,
        grade REAL,
        date INTEGER,
        weight REAL,
        type TEXT
      )
    '''); //
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        primary_colour TEXT
      )
    '''); //
    await db.execute('''
      CREATE TABLE IF NOT EXISTS periods (
        name TEXT PRIMARY KEY,
        start_date INTEGER, -- Memorizza come YYYYMMDD o NULL
        end_date INTEGER   -- Memorizza come YYYYMMDD o NULL
      )
    '''); //

    // Inserisci periodi di default (memorizza NULL invece di 'N/A')
    // Usiamo INSERT OR IGNORE come nel codice Python
    await db.execute('''
      INSERT OR IGNORE INTO periods (name, start_date, end_date)
      VALUES
      ('first_period', NULL, NULL),
      ('second_period', NULL, NULL)
    '''); //
  }

  // --- Funzioni Convertite ---

  /// Arrotonda un numero all'intero successivo se la parte decimale è >= 0.5
  int roundCustom(double n) {
    return (n + 0.5)
        .floor(); // .floor() è equivalente a int() in Python per questo scopo
  }

  /// Aggiunge una materia. Ritorna true se successo, lancia eccezione altrimenti.
  /// Lancia 'duplicate subject' in caso di violazione UNIQUE.
  Future<bool> addSubject(String subject) async {
    final db = await database;
    try {
      await db.insert(
        'subject_list',
        {'subject': subject.toUpperCase()}, // Assicura maiuscolo
        conflictAlgorithm:
            ConflictAlgorithm.fail, // Lancia eccezione se duplicato
      );
      return true;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        // Potresti voler lanciare un'eccezione personalizzata o ritornare un codice/stringa
        throw 'duplicate subject'; // Simile al comportamento Python
      } else {
        print('Errore Database in addSubject: $e');
        rethrow; // Rilancia altre eccezioni DB
      }
    } catch (e) {
      print('Errore generico in addSubject: $e');
      return false;
    }
  }

  /// Ritorna la lista di tutte le materie con i loro obiettivi.
  /// Ritorna una lista di tuple (SubjectName, ObjectiveString)
  Future<List<(String, String)>> listSubjects() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('subject_list'); //
      List<(String, String)> result = [];
      for (var map in maps) {
        final subject = Subject.fromMap(map);
        result.add(
            (subject.subjectName, subject.objective?.toString() ?? 'N/A')); //
      }
      return result;
    } catch (e) {
      print('Errore in listSubjects: $e');
      return []; // Ritorna lista vuota in caso di errore
    }
  }

  /// Ritorna l'obiettivo (come stringa) per una data materia.
  Future<String> returnObjective(String subject) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'subject_list',
        columns: ['objective'],
        where: 'subject = ?', // Usa '?' per sicurezza
        whereArgs: [subject.toUpperCase()], // Usa parametri
      ); //
      if (maps.isNotEmpty) {
        final objective = maps.first['objective'];
        return objective?.toString() ?? 'N/A'; // Se null, ritorna 'N/A'
      } else {
        return 'N/A'; // Materia non trovata
      }
    } catch (e) {
      print('Errore in returnObjective: $e');
      return 'N/A'; //
    }
  }

  /// Ritorna l'obiettivo medio (come stringa) di tutte le materie.
  Future<String> returnAverageObjective() async {
    final db = await database;
    try {
      // Usiamo rawQuery perché AVG() è una funzione aggregata
      final result = await db
          .rawQuery('SELECT ROUND(AVG(objective), 2) FROM subject_list'); //
      if (result.isNotEmpty && result.first.values.first != null) {
        return result.first.values.first.toString();
      } else {
        return 'N/A'; // Nessun obiettivo impostato o nessuna materia
      }
    } catch (e) {
      print('Errore in returnAverageObjective: $e');
      return 'N/A'; //
    }
  }

  /// Aggiunge un voto. Ritorna true se successo, false altrimenti.
  /// `date` deve essere un intero nel formato YYYYMMDD.
  Future<bool> addGrade(String subjectName, double grade, int date,
      double weight, String type) async {
    final db = await database;
    try {
      final gradeObj = Grade(
          subjectName: subjectName.toUpperCase(), // Assicura consistenza
          grade: grade,
          date: date,
          weight: weight,
          type: type);
      await db.insert(
        'grades',
        gradeObj.toMap()..remove('id'), // Rimuovi id perché è AUTOINCREMENT
        conflictAlgorithm:
            ConflictAlgorithm.ignore, // O scegli un altro algoritmo
      ); //
      return true;
    } catch (e) {
      print('Errore in addGrade: $e');
      return false; //
    }
  }

  /// Ritorna la lista di tutti i voti (come oggetti Grade) per una data materia.
  /// Ordina per data come sembra implicito nel codice Python originale.
  Future<List<Grade>> listGrades(String subject) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'grades',
        where: 'subject_name = ?',
        whereArgs: [subject.toUpperCase()],
        orderBy: 'date ASC', // Ordina per data
      ); //
      return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
    } catch (e) {
      print('Errore in listGrades: $e');
      return []; // Ritorna lista vuota in caso di errore
    }
  }

  /// Ritorna la lista dei voti (oggetti Grade) per materia in un range di date (YYYYMMDD).
  Future<List<Grade>> listGradesByPeriod(String subject,
      {int? startDate, int? endDate}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    final subjectUpper = subject.toUpperCase();

    if (startDate != null && endDate != null) {
      whereClause = 'subject_name = ? AND date BETWEEN ? AND ?'; //
      whereArgs = [subjectUpper, startDate, endDate];
    } else {
      whereClause = 'subject_name = ?'; //
      whereArgs = [subjectUpper];
    }

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'grades',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'date ASC',
      );
      return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
    } catch (e) {
      print('Errore in listGradesByPeriod: $e');
      return []; //
    }
  }

  /// Ritorna una lista di tutti i valori dei voti (solo i numeri).
  Future<List<double>> listAllGrades() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result =
          await db.query('grades', columns: ['grade']); //
      return result.map((map) => map['grade'] as double).toList();
    } catch (e) {
      print('Errore in listAllGrades: $e');
      return []; //
    }
  }

  /// Ritorna una mappa con la proporzione dei voti (solo la parte intera) per periodo.
  Future<Map<int, int>> returnGradeProportionsByPeriod(
      String periodName) async {
    // periodName dovrebbe essere 'first_period' o 'second_period'
    final db = await database;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int? maxGradeFromPrefs = prefs.getDouble("max_grade")?.toInt();
    int maxGrade = maxGradeFromPrefs ?? 10;

    Map<int, int> gradeProportions = {for (var i = 0; i <= maxGrade; i++) i: 0};

    try {
      // Ottieni le date del periodo specificato
      final periodData = await db.query('periods',
          where: 'name = ?',
          whereArgs: [
            periodName == 'first' ? 'first_period' : 'second_period'
          ] //
          );

      if (periodData.isEmpty) return gradeProportions; // Periodo non trovato

      final period = Period.fromMap(periodData.first);
      final startDate = period.startDate;
      final endDate = period.endDate;

      if (startDate == null || endDate == null) {
        print('Date per il periodo $periodName non impostate.');
        return gradeProportions; // Date non valide ('N/A' nel DB Python)
      }

      // Ottieni i voti nel range di date
      final List<Map<String, dynamic>> gradesMaps = await db.query(
        'grades',
        columns: ['grade'],
        where: 'date BETWEEN ? AND ?', //
        whereArgs: [startDate, endDate],
      ); //

      // Conta le proporzioni
      for (var map in gradesMaps) {
        final gradeValue = map['grade'] as double;
        final gradeIntPart = gradeValue.floor(); // Prende solo la parte intera
        if (gradeProportions.containsKey(gradeIntPart)) {
          gradeProportions[gradeIntPart] =
              gradeProportions[gradeIntPart]! + 1; //
        }
      }
      return gradeProportions;
    } catch (e) {
      print('Errore in returnGradeProportionsByPeriod: $e');
      return gradeProportions; // Ritorna la mappa (possibilmente vuota o parziale)
    }
  }

  // --- Funzioni per le Medie Complessive (return_average_by_date, etc.) ---
  // Queste funzioni usano query SQL complesse (CTE).
  // La traduzione diretta è possibile con rawQuery, ma la logica di arrotondamento
  // e combinazione dei risultati in Dart diventa complessa e potrebbe essere
  // meglio gestirla diversamente in un'app Flutter (es. calcoli post-query).
  // Fornisco una traduzione più semplice o un placeholder, data la complessità.

  /// Ritorna le medie cumulative per data, separate per media originale e media arrotondata.
  /// Simula il comportamento di `return_average_by_date` in Python.
  /// `period` può essere 'first' o 'second'.
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      returnAverageByDate(String period) async {
    final db = await database;

    int? startDate;
    int? endDate;
    String targetPeriodName = 'N/A'; // Per logging

    try {
      // Recupera le date dei periodi
      final periodsData = await db.query('periods', orderBy: 'name');
      if (periodsData.length < 2) {
        print("Errore: Dati dei periodi mancanti o incompleti.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }
      // Assumi che la classe Period sia definita correttamente altrove
      final firstPeriod = Period.fromMap(periodsData[0]);
      final secondPeriod = Period.fromMap(periodsData[1]);

      if (period == 'first') {
        targetPeriodName = firstPeriod.name;
        startDate = firstPeriod.startDate;
        endDate = firstPeriod.endDate;
      } else if (period == 'second') {
        targetPeriodName = secondPeriod.name;
        startDate = secondPeriod.startDate;
        endDate = secondPeriod.endDate;
      } else {
        print(
            "Errore: Periodo non valido specificato ('$period'). Usare 'first' o 'second'.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }

      if (startDate == null || endDate == null) {
        print("Errore: Date per il periodo '$targetPeriodName' non impostate.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }
    } catch (e) {
      print("Errore durante il recupero delle date dei periodi: $e");
      return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
    }

    // Query SQL con CTE (Common Table Expressions)
    // Nota: Questa query è complessa e replica la logica Python.
    final String sqlCommand = """
    WITH relevant_grades AS ( -- Filtra voti rilevanti per il periodo e peso
        SELECT date, grade, weight, subject_name
        FROM grades
        WHERE date BETWEEN $startDate AND $endDate AND weight > 0
    ),
    cumulative_grades AS ( -- Calcola somme cumulative per materia/data
        SELECT
            r1.date,
            r1.subject_name,
            r1.grade,
            r1.weight,
            (SELECT SUM(r2.grade * r2.weight) FROM relevant_grades r2 WHERE r2.subject_name = r1.subject_name AND r2.date <= r1.date) as cumulative_weighted_sum,
            (SELECT SUM(r2.weight) FROM relevant_grades r2 WHERE r2.subject_name = r1.subject_name AND r2.date <= r1.date) as cumulative_weight
        FROM relevant_grades r1
    ),
    cumulative_averages AS ( -- Calcola media cumulativa per materia/data
        SELECT
            date,
            subject_name,
            cumulative_weighted_sum * 1.0 / cumulative_weight AS average_grade
        FROM cumulative_grades
        WHERE cumulative_weight > 0 -- Evita divisione per zero
        GROUP BY date, subject_name -- Ottieni l'ultima media per quella data/materia
    ),
    distinct_average_dates AS ( -- Trova le date uniche in cui le medie cambiano
        SELECT DISTINCT date FROM cumulative_averages
    ),
    general_cumulative_average AS ( -- Calcola la media generale *solo* in quelle date specifiche
        SELECT
            dad.date,
            AVG(ca.average_grade) AS general_average -- Media delle medie delle materie
        FROM distinct_average_dates dad
        -- Join per ottenere l'ultima media di ogni materia fino a quella data
        JOIN cumulative_averages ca ON ca.date = (SELECT MAX(ca_inner.date)
                                                   FROM cumulative_averages ca_inner
                                                   WHERE ca_inner.subject_name = ca.subject_name AND ca_inner.date <= dad.date)
        GROUP BY dad.date
    )
    -- Unisce i risultati delle medie per materia e delle medie generali
    SELECT 'Subject Average' AS type, date, subject_name, average_grade
    FROM cumulative_averages
    UNION ALL
    SELECT 'General Average' AS type, date, NULL AS subject_name, general_average
    FROM general_cumulative_average
    ORDER BY date, type DESC; -- Ordina per data, poi per tipo (General prima di Subject)
    """; //

    try {
      final List<Map<String, dynamic>> data = await db.rawQuery(sqlCommand);

      // Elaborazione dati in Dart per separare medie originali e calcolare le arrotondate
      Map<int, Map<String, double>> subjectAveragesByDate =
          {}; // { date: { subject: avg } }
      Map<int, double> originalGeneralAveragesFromQuery = {}; // { date: avg }
      List<Map<String, dynamic>> finalOriginalAverages =
          []; // Lista per medie generali originali
      List<Map<String, dynamic>> finalRoundedAverages =
          []; // Lista per medie generali arrotondate

      // 1. Estrai dati dalla query
      for (var record in data) {
        final recordType = record['type'];
        final date = record['date'] as int;
        final subjectName = record['subject_name'] as String?;
        final average = record['average_grade'] as double?;

        if (average == null || average.isNaN || average.isInfinite)
          continue; // Salta medie non valide

        subjectAveragesByDate.putIfAbsent(date, () => {});

        if (recordType == 'Subject Average' && subjectName != null) {
          subjectAveragesByDate[date]![subjectName] = average;
        } else if (recordType == 'General Average') {
          originalGeneralAveragesFromQuery[date] = average;
        }
      }

      // 2. Calcola la media generale arrotondata in Dart, seguendo la logica Python
      final sortedDates = subjectAveragesByDate.keys.toList()..sort();
      Map<String, double> currentSubjectAveragesState =
          {}; // Mantiene lo stato delle medie per materia

      for (int date in sortedDates) {
        // Aggiorna lo stato con le medie di questa data
        currentSubjectAveragesState.addAll(subjectAveragesByDate[date]!);

        // Calcola la media arrotondata solo se ci sono medie disponibili
        if (currentSubjectAveragesState.isNotEmpty) {
          // Arrotonda *prima* le medie per materia, *poi* calcola la media generale
          double roundedGeneralAvg = currentSubjectAveragesState.values
                  .map((avg) =>
                      roundCustom(avg).toDouble()) // Arrotonda singole medie
                  .reduce((a, b) => a + b) /
              currentSubjectAveragesState.length; // Media delle arrotondate

          // Aggiungi alla lista solo se la query SQL ha prodotto una media generale per questa data
          if (originalGeneralAveragesFromQuery.containsKey(date)) {
            finalRoundedAverages
                .add({'date': date, 'average_grade': roundedGeneralAvg});
          }
        }
      }

      // 3. Formatta la lista delle medie generali originali (già calcolate dalla query)
      originalGeneralAveragesFromQuery.forEach((date, avg) {
        finalOriginalAverages.add({'date': date, 'average_grade': avg});
      });
      // Ordina per data per sicurezza (anche se la query dovrebbe già farlo)
      finalOriginalAverages
          .sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));

      return (finalOriginalAverages, finalRoundedAverages);
    } catch (e) {
      print('Errore in returnAverageByDate (Periodo: $targetPeriodName): $e');
      print(
          'SQL Eseguito: $sqlCommand'); // Logga la query per facilitare il debug
      return (
        <Map<String, dynamic>>[],
        <Map<String, dynamic>>[]
      ); // Ritorna liste vuote in caso di errore
    }
  }

  /// Ritorna le medie cumulative per data (originali e arrotondate)
  /// basandosi sul periodo corrente o su un periodo specificato.
  /// Simula `return_average_by_date_period` in Python.
  /// Se `periodName` è null, determina il periodo corrente.
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      returnAverageByDatePeriod({String? periodName}) async {
    final db = await database;
    int? startDate;
    int? endDate;
    String determinedPeriodName = 'N/A'; // Per logging

    try {
      Period? targetPeriod;
      // Se un nome periodo è fornito, usalo
      if (periodName != null && periodName.isNotEmpty) {
        // Validazione nome periodo
        if (periodName != 'first_period' && periodName != 'second_period') {
          print(
              "Errore: Nome periodo non valido '$periodName'. Usare 'first_period' o 'second_period'.");
          return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
        }
        // Recupera dati del periodo specificato
        final periodData = await db
            .query('periods', where: 'name = ?', whereArgs: [periodName]);
        if (periodData.isNotEmpty) {
          targetPeriod = Period.fromMap(periodData.first);
          determinedPeriodName = targetPeriod.name;
        } else {
          // Non dovrebbe succedere se il DB è inizializzato correttamente
          print(
              "Errore critico: Periodo specificato '$periodName' non trovato nel DB.");
          return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
        }
      } else {
        // Se non è fornito un nome, determina quello corrente
        targetPeriod = await _getCurrentPeriodDates(); // Usa la funzione helper
        if (targetPeriod != null) {
          determinedPeriodName = targetPeriod.name;
          print("Periodo corrente determinato: $determinedPeriodName");
        } else {
          // Gestione fallback se non si trova il periodo corrente
          print(
              "Avviso: Impossibile determinare il periodo corrente. Tentativo di fallback...");
          // Prova a usare il secondo periodo, poi il primo, se hanno date valide
          final periodsData = await db.query('periods',
              orderBy: 'name DESC'); // Leggi second, then first
          if (periodsData.isNotEmpty) {
            for (var pData in periodsData) {
              final fallbackPeriod = Period.fromMap(pData);
              if (fallbackPeriod.startDate != null &&
                  fallbackPeriod.endDate != null) {
                targetPeriod = fallbackPeriod;
                determinedPeriodName = targetPeriod.name;
                print(
                    "Usando periodo di fallback con date valide: $determinedPeriodName");
                break; // Trovato un fallback valido
              }
            }
          }
          // Se ancora non si trova un periodo valido dopo il fallback
          if (targetPeriod == null) {
            print(
                "Errore: Nessun periodo (corrente o fallback) con date valide trovato.");
            return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
          }
        }
      }

      // Ottieni le date di inizio e fine dal periodo determinato (o fallback)
      startDate = targetPeriod.startDate;
      endDate = targetPeriod.endDate;

      // Verifica che le date siano valide
      if (startDate == null || endDate == null) {
        print(
            "Errore: Date per il periodo '$determinedPeriodName' non impostate o non valide.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }

      // --- Logica di calcolo (identica a returnAverageByDate ma con le date determinate) ---
      // Per manutenibilità, potremmo chiamare `returnAverageByDate` passando il nome del periodo
      // trovato, ma per chiarezza e potenziale ottimizzazione futura, duplichiamo la logica qui.

      final String sqlCommand = """
            WITH relevant_grades AS (
                SELECT date, grade, weight, subject_name
                FROM grades
                WHERE date BETWEEN $startDate AND $endDate AND weight > 0
            ),
            cumulative_grades AS (
                SELECT
                    r1.date, r1.subject_name, r1.grade, r1.weight,
                    (SELECT SUM(r2.grade * r2.weight) FROM relevant_grades r2 WHERE r2.subject_name = r1.subject_name AND r2.date <= r1.date) as cumulative_weighted_sum,
                    (SELECT SUM(r2.weight) FROM relevant_grades r2 WHERE r2.subject_name = r1.subject_name AND r2.date <= r1.date) as cumulative_weight
                FROM relevant_grades r1
            ),
            cumulative_averages AS (
                SELECT date, subject_name, cumulative_weighted_sum * 1.0 / cumulative_weight AS average_grade
                FROM cumulative_grades WHERE cumulative_weight > 0
                GROUP BY date, subject_name
            ),
            distinct_average_dates AS ( SELECT DISTINCT date FROM cumulative_averages ),
            general_cumulative_average AS (
                SELECT dad.date, AVG(ca.average_grade) AS general_average
                FROM distinct_average_dates dad
                JOIN cumulative_averages ca ON ca.date = (SELECT MAX(ca_inner.date) FROM cumulative_averages ca_inner WHERE ca_inner.subject_name = ca.subject_name AND ca_inner.date <= dad.date)
                GROUP BY dad.date
            )
            SELECT 'Subject Average' AS type, date, subject_name, average_grade FROM cumulative_averages
            UNION ALL
            SELECT 'General Average' AS type, date, NULL AS subject_name, general_average FROM general_cumulative_average
            ORDER BY date, type DESC;
            """; //

      final List<Map<String, dynamic>> data = await db.rawQuery(sqlCommand);

      // Elaborazione dati (identica a returnAverageByDate)
      Map<int, Map<String, double>> subjectAveragesByDate = {};
      Map<int, double> originalGeneralAveragesFromQuery = {};
      List<Map<String, dynamic>> finalOriginalAverages = [];
      List<Map<String, dynamic>> finalRoundedAverages = [];

      for (var record in data) {
        final recordType = record['type'];
        final date = record['date'] as int;
        final subjectName = record['subject_name'] as String?;
        final average = record['average_grade'] as double?;
        if (average == null || average.isNaN || average.isInfinite) continue;
        subjectAveragesByDate.putIfAbsent(date, () => {});
        if (recordType == 'Subject Average' && subjectName != null) {
          subjectAveragesByDate[date]![subjectName] = average;
        } else if (recordType == 'General Average') {
          originalGeneralAveragesFromQuery[date] = average;
        }
      }

      final sortedDates = subjectAveragesByDate.keys.toList()..sort();
      Map<String, double> currentSubjectAveragesState = {};

      for (int date in sortedDates) {
        currentSubjectAveragesState.addAll(subjectAveragesByDate[date]!);
        if (currentSubjectAveragesState.isNotEmpty) {
          double roundedGeneralAvg = currentSubjectAveragesState.values
                  .map((avg) => roundCustom(avg).toDouble())
                  .reduce((a, b) => a + b) /
              currentSubjectAveragesState.length;
          if (originalGeneralAveragesFromQuery.containsKey(date)) {
            finalRoundedAverages
                .add({'date': date, 'average_grade': roundedGeneralAvg});
          }
        }
      }
      originalGeneralAveragesFromQuery.forEach((date, avg) {
        finalOriginalAverages.add({'date': date, 'average_grade': avg});
      });
      finalOriginalAverages
          .sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));
      // --- Fine Logica Duplicata ---

      return (finalOriginalAverages, finalRoundedAverages);
    } catch (e) {
      print(
          'Errore in returnAverageByDatePeriod (Periodo cercato: ${periodName ?? "corrente"}, determinato: $determinedPeriodName): $e');
      // Considera di loggare anche startDate e endDate se possibile
      return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
    }
  }

  /// Ritorna la media pesata (come stringa formattata "0.00" o "N/A") per una materia.
  Future<String> returnAverage(String subject) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT SUM(grade*weight)/SUM(weight) AS average_grade FROM grades WHERE subject_name = ?', //
        [subject.toUpperCase()],
      );

      if (result.isNotEmpty && result.first['average_grade'] != null) {
        final average = result.first['average_grade'] as double;
        return average.toStringAsFixed(2); // Formatta a 2 decimali
      } else {
        return 'N/A'; // Nessun voto o somma pesi è 0
      }
    } catch (e) {
      print('Errore in returnAverage: $e');
      return 'N/A'; //
    }
  }

  /// Ritorna la media pesata per materia in un range di date (YYYYMMDD).
  Future<String> returnAverageByPeriod(
      String subject, int startDate, int endDate) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT SUM(grade*weight)/SUM(weight) AS average_grade FROM grades WHERE subject_name = ? AND date BETWEEN ? AND ?', //
        [subject.toUpperCase(), startDate, endDate],
      );

      if (result.isNotEmpty && result.first['average_grade'] != null) {
        final average = result.first['average_grade'] as double;
        return average.toStringAsFixed(2); //
      } else {
        return 'N/A'; //
      }
    } catch (e) {
      print('Errore in returnAverageByPeriod: $e');
      return 'N/A'; //
    }
  }

  /// Ritorna la media pesata per materia nel periodo corrente.
  Future<String> returnAverageByPeriodBis(String subject) async {
    final db = await database;
    try {
      final currentPeriod = await _getCurrentPeriodDates(); // Funzione helper
      if (currentPeriod == null) {
        return 'N/A'; // Non riesco a determinare il periodo
      }

      return await returnAverageByPeriod(
          subject, currentPeriod.startDate!, currentPeriod.endDate!); //
    } catch (e) {
      print('Errore in returnAverageByPeriodBis: $e');
      return 'N/A'; //
    }
  }

  /// Ritorna le medie pesate per tutte le materie (inclusi N/A per materie senza voti).
  Future<List<(String, String)>> returnAverages() async {
    final db = await database;
    List<(String, String)> results = [];
    try {
      // Ottieni le medie calcolate
      final avgMaps = await db.rawQuery(
          'SELECT subject_name, SUM(grade*weight)/SUM(weight) AS average_grade FROM grades GROUP BY subject_name'); //

      Map<String, String> calculatedAverages = {};
      for (var map in avgMaps) {
        final subject = map['subject_name'] as String;
        final average = map['average_grade'] as double?;
        calculatedAverages[subject] =
            average != null ? average.toStringAsFixed(2) : 'N/A'; //
      }

      // Ottieni tutte le materie definite
      final allSubjectsList = await listSubjects(); //
      final allSubjectNames = allSubjectsList.map((s) => s.$1).toList();

      // Combina: per ogni materia definita, prendi la media calcolata o 'N/A'
      for (var subjectName in allSubjectNames) {
        results.add((subjectName, calculatedAverages[subjectName] ?? 'N/A')); //
      }

      return results;
    } catch (e) {
      print('Errore in returnAverages: $e');
      return results; // Ritorna quello che ha calcolato finora
    }
  }

  /// Ritorna le medie pesate per tutte le materie nel periodo corrente.
  Future<List<(String, String)>> returnAveragesByPeriod() async {
    final db = await database;
    List<(String, String)> results = [];
    try {
      final currentPeriod = await _getCurrentPeriodDates();
      if (currentPeriod == null ||
          currentPeriod.startDate == null ||
          currentPeriod.endDate == null) {
        print("Periodo corrente non valido o non impostato.");
        // Potresti voler ritornare le medie generali se il periodo non è impostato
        // return await returnAverages();
        // Oppure ritornare N/A per tutte le materie
        final allSubjectsList = await listSubjects();
        return allSubjectsList.map((s) => (s.$1, 'N/A')).toList();
      }
      final startDate = currentPeriod.startDate!;
      final endDate = currentPeriod.endDate!;

      // Calcola medie nel periodo
      final avgMaps = await db.rawQuery(
          '''SELECT subject_name, SUM(grade*weight)/SUM(weight) AS average_grade
               FROM grades
               WHERE date BETWEEN ? AND ?
               GROUP BY subject_name''', //
          [startDate, endDate]);

      Map<String, String> calculatedAverages = {};
      for (var map in avgMaps) {
        final subject = map['subject_name'] as String;
        final average = map['average_grade'] as double?;
        calculatedAverages[subject] =
            average != null ? average.toStringAsFixed(2) : 'N/A'; //
      }

      // Combina con tutte le materie
      final allSubjectsList = await listSubjects(); //
      final allSubjectNames = allSubjectsList.map((s) => s.$1).toList();

      for (var subjectName in allSubjectNames) {
        results.add((subjectName, calculatedAverages[subjectName] ?? 'N/A')); //
      }
      return results;
    } catch (e) {
      print('Errore in returnAveragesByPeriod: $e');
      return results; //
    }
  }

  /// Ritorna la media generale (media delle medie delle materie) nel periodo corrente.
  Future<String> returnGeneralAverageByPeriod() async {
    final db = await database;
    try {
      final currentPeriod = await _getCurrentPeriodDates();
      if (currentPeriod == null ||
          currentPeriod.startDate == null ||
          currentPeriod.endDate == null) {
        return 'N/A';
      }
      final startDate = currentPeriod.startDate!;
      final endDate = currentPeriod.endDate!;

      // Query per calcolare la media delle medie delle materie nel periodo
      final result = await db.rawQuery('''
            SELECT AVG(average_grade) AS overall_average
            FROM (
                SELECT subject_name,
                SUM(grade * weight) / SUM(weight) AS average_grade
                FROM grades
                WHERE date BETWEEN ? AND ?
                GROUP BY subject_name
                HAVING SUM(weight) > 0 -- Evita divisione per zero se materia non ha voti pesati
            ) AS subject_averages;
        ''', [startDate, endDate]); // (Query adattata)

      if (result.isNotEmpty && result.first['overall_average'] != null) {
        final average = result.first['overall_average'] as double;
        return average.toStringAsFixed(2); //
      } else {
        return 'N/A'; //
      }
    } catch (e) {
      print('Errore in returnGeneralAverageByPeriod: $e');
      return 'N/A'; //
    }
  }

  /// Elimina un voto dato il suo ID.
  Future<bool> deleteGrade(int id) async {
    final db = await database;
    try {
      final count = await db.delete(
        'grades',
        where: 'id = ?',
        whereArgs: [id],
      ); // - Adattato per usare ID intero
      return count > 0; // Ritorna true se almeno una riga è stata eliminata
    } catch (e) {
      print('Errore in deleteGrade: $e');
      return false; //
    }
  }

  /// Modifica un voto esistente.
  /// 'data' è una mappa che dovrebbe contenere le chiavi:
  /// 'grade_id', 'subject', 'grade', 'date', 'grade_weight', 'type'.
  Future<bool> editGrade(Map<String, dynamic> data) async {
    final db = await database;
    try {
      // Prepara i dati per l'aggiornamento
      final values = {
        'subject_name': (data['subject'] as String?)?.toUpperCase(),
        'grade': data['grade'], // Assumiamo sia già double
        'date': data['date'], // Assumiamo sia già int YYYYMMDD
        'weight': data['grade_weight'], // Assumiamo sia già double
        'type': data['type'],
      };
      // Rimuovi eventuali valori null per non sovrascrivere colonne con NULL involontariamente
      values.removeWhere((key, value) => value == null);

      if (values.isEmpty) {
        print("Nessun dato valido fornito per l'aggiornamento del voto.");
        return false;
      }

      final count = await db.update(
        'grades',
        values,
        where: 'id = ?',
        whereArgs: [data['grade_id']], // Assumiamo sia già int
      );
      return count > 0; // True se almeno una riga è stata aggiornata
    } catch (e) {
      print('Errore in editGrade: $e');
      return false; //
    }
  }

  /// Imposta (o aggiorna) il colore primario nelle impostazioni.
  Future<bool> setPrimaryColour(String colour) async {
    final db = await database;
    try {
      // Controlla se esiste già una riga (assumiamo id=1 per la riga delle impostazioni)
      final existing =
          await db.query('settings', where: 'id = ?', whereArgs: [1]); //

      if (existing.isNotEmpty) {
        // Aggiorna
        await db.update(
          'settings',
          {'primary_colour': colour},
          where: 'id = ?',
          whereArgs: [1], //
        );
      } else {
        // Inserisci (forzando id=1 se la tabella è vuota, altrimenti lascia fare AUTOINCREMENT se id non è 1)
        await db.insert(
          'settings',
          {
            'id': 1,
            'primary_colour': colour
          }, // Potrebbe essere necessario gestire l'ID se non si vuole forzarlo a 1
          conflictAlgorithm:
              ConflictAlgorithm.replace, // Sostituisce se id 1 esiste per caso
        ); // - Adattato
      }
      return true;
    } catch (e) {
      print('Errore in setPrimaryColour: $e');
      return false; //
    }
  }

  /// Elimina una materia e tutti i voti associati.
  Future<bool> deleteSubject(String subject) async {
    final db = await database;
    final subjectUpper = subject.toUpperCase();
    try {
      // Usare una transazione per assicurare che entrambe le delete avvengano o nessuna
      await db.transaction((txn) async {
        // Elimina i voti associati
        await txn.delete(
          'grades',
          where: 'subject_name = ?',
          whereArgs: [subjectUpper], //
        );
        // Elimina la materia
        await txn.delete(
          'subject_list',
          where: 'subject = ?',
          whereArgs: [subjectUpper], //
        );
      });
      return true;
    } catch (e) {
      print('Errore in deleteSubject: $e');
      return false; //
    }
  }

  /// Rinomina una materia (nella lista materie e nei voti associati).
  /// Lancia 'duplicate subject' se il nuovo nome esiste già.
  Future<bool> renameSubject(
      String oldSubjectName, String newSubjectName) async {
    final db = await database;
    final oldUpper = oldSubjectName.toUpperCase();
    final newUpper = newSubjectName.toUpperCase();

    if (oldUpper == newUpper) return true; // Nessun cambiamento richiesto

    try {
      await db.transaction((txn) async {
        // Aggiorna i voti
        await txn.update(
          'grades',
          {'subject_name': newUpper},
          where: 'subject_name = ?',
          whereArgs: [oldUpper], //
        );
        // Aggiorna la materia
        await txn.update(
          'subject_list',
          {'subject': newUpper},
          where: 'subject = ?',
          whereArgs: [oldUpper], //
        );
      });
      print("Materia rinominata"); //
      return true;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw 'duplicate subject'; // - Simula il comportamento Python
      } else {
        print('Errore Database in renameSubject: $e');
        rethrow;
      }
    } catch (e) {
      print('Errore generico in renameSubject: $e');
      return false; //
    }
  }

  /// Imposta l'obiettivo per una data materia.
  Future<bool> setObjective(String subject, double objective) async {
    final db = await database;
    try {
      final count = await db.update(
        'subject_list',
        {'objective': objective},
        where: 'subject = ?',
        whereArgs: [subject.toUpperCase()], //
      );
      return count > 0; // True se la materia esisteva ed è stata aggiornata
    } catch (e) {
      print('Errore in setObjective: $e');
      return false; //
    }
  }

  /// Rimuove l'obiettivo associato a una materia (imposta a NULL).
  /// Ritorna true se la materia esisteva ed è stata aggiornata.
  Future<bool> removeObjective(String subject) async {
    final db = await database;
    try {
      final count = await db.update(
        'subject_list',
        {'objective': null},
        where: 'subject = ?',
        whereArgs: [subject.toUpperCase()],
      );
      return count > 0;
    } catch (e) {
      print('Errore in removeObjective: $e');
      return false;
    }
  }

  /// Imposta le date di inizio e fine per un periodo ('first_period' o 'second_period').
  /// Ritorna true se successo, 'invalid dates' se start > end o se c'è sovrapposizione invalida.
  Future<dynamic> setPeriod(
      String periodName, int startDate, int endDate) async {
    final db = await database;

    if (startDate > endDate) {
      return 'invalid dates'; //
    }

    try {
      // Controllo sovrapposizione se stiamo impostando il secondo periodo
      if (periodName == 'second_period') {
        final firstPeriodData = await db.query('periods',
            where: 'name = ?', whereArgs: ['first_period']); //
        if (firstPeriodData.isNotEmpty) {
          final firstPeriod = Period.fromMap(firstPeriodData.first);
          // Controlla se la data di fine del primo periodo è valida e successiva all'inizio del secondo
          if (firstPeriod.endDate != null &&
              firstPeriod.endDate! >= startDate) {
            // Python controllava start_date > end_date, qui controllo >=
            return 'invalid dates'; // Date sovrapposte o non sequenziali - Logica adattata
          }
        }
      }
      // Controllo sovrapposizione se stiamo impostando il primo periodo
      else if (periodName == 'first_period') {
        final secondPeriodData = await db
            .query('periods', where: 'name = ?', whereArgs: ['second_period']);
        if (secondPeriodData.isNotEmpty) {
          final secondPeriod = Period.fromMap(secondPeriodData.first);
          if (secondPeriod.startDate != null &&
              secondPeriod.startDate! <= endDate) {
            return 'invalid dates'; // Date sovrapposte o non sequenziali
          }
        }
      }

      // Aggiorna il periodo
      final count = await db.update(
        'periods',
        {'start_date': startDate, 'end_date': endDate},
        where: 'name = ?',
        whereArgs: [periodName], //
      );
      return count > 0; // True se il record esisteva ed è stato aggiornato
    } catch (e) {
      print('Errore in setPeriod: $e');
      return false; //
    }
  }

  /// Ritorna le date di inizio e fine per tutti i periodi (come oggetti Period).
  Future<List<Period>> getPeriods() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps =
          await db.query('periods', orderBy: 'name'); //
      if (maps.isEmpty) {
        // Se la tabella è vuota per qualche motivo, ritorna i default 'N/A'
        return [
          Period(name: 'first_period', startDate: null, endDate: null),
          Period(name: 'second_period', startDate: null, endDate: null),
        ];
      }
      return List.generate(maps.length, (i) => Period.fromMap(maps[i]));
    } catch (e) {
      print('Errore in getPeriods: $e');
      // Ritorna valori di default che rappresentano 'N/A'
      return [
        Period(name: 'first_period', startDate: null, endDate: null),
        Period(name: 'second_period', startDate: null, endDate: null),
      ];
    }
  }

  // --- Funzioni Helper Interne ---

  /// Determina le date del periodo corrente basandosi sulla data odierna.
  Future<Period?> _getCurrentPeriodDates() async {
    final db = await database;
    try {
      final todayInt = int.parse(DateFormat('yyyyMMdd')
          .format(DateTime.now())); // Data odierna come YYYYMMDD

      final periodsData = await db.query('periods', orderBy: 'name'); //
      if (periodsData.length < 2) return null; // Dati periodi mancanti

      final firstPeriod = Period.fromMap(
          periodsData[0]); // Assumendo 'first_period' sia il primo
      final secondPeriod = Period.fromMap(
          periodsData[1]); // Assumendo 'second_period' sia il secondo

      // Controlla se oggi è nel primo periodo
      if (firstPeriod.startDate != null &&
          firstPeriod.endDate != null &&
          todayInt >= firstPeriod.startDate! &&
          todayInt <= firstPeriod.endDate!) {
        return firstPeriod;
      }
      // Controlla se oggi è nel secondo periodo
      // La logica Python (first_period[1] < today <= second_period[1]) implica che
      // il secondo periodo inizia *dopo* la fine del primo.
      if (secondPeriod.startDate != null &&
          secondPeriod.endDate != null &&
          todayInt >= secondPeriod.startDate! &&
          todayInt <= secondPeriod.endDate!) {
        // Controllo aggiuntivo opzionale: verifica che l'inizio del secondo sia dopo la fine del primo
        if (firstPeriod.endDate == null ||
            secondPeriod.startDate! > firstPeriod.endDate!) {
          return secondPeriod;
        }
      }

      // Fallback: se non siamo in nessun periodo definito, quale usare?
      // Il codice Python usa il secondo periodo come fallback
      // Ritorniamo il secondo periodo se ha date valide, altrimenti null
      if (secondPeriod.startDate != null && secondPeriod.endDate != null) {
        return secondPeriod;
      } else if (firstPeriod.startDate != null && firstPeriod.endDate != null) {
        // Se il secondo non è valido ma il primo sì, forse usare il primo?
        // Decidi la logica di fallback migliore per il tuo caso.
        // Qui usiamo il secondo come da Python, anche se potrebbe non avere date.
        return secondPeriod; // Potrebbe avere date null
      }

      return null; // Non riesco a determinare un periodo valido
    } catch (e) {
      print("Errore nel determinare il periodo corrente: $e");
      return null;
    }
  }

  // --- Funzioni di Raggiungimento Obiettivi ---
  // Queste richiedono il calcolo della media nel periodo corrente e il confronto con l'obiettivo

  /// Valuta il raggiungimento dell'obiettivo per una materia nel periodo corrente.
  Future<String> objectiveAchievementSubjectByPeriod(String subject) async {
    final db = await database;
    final subjectUpper = subject.toUpperCase();

    try {
      // 1. Ottieni l'obiettivo per la materia
      final objectiveData = await db.query('subject_list',
          columns: ['objective'],
          where: 'subject = ?',
          whereArgs: [subjectUpper]); //
      if (objectiveData.isEmpty || objectiveData.first['objective'] == null) {
        return "not enough data"; // Obiettivo non impostato
      }
      final objective = objectiveData.first['objective'] as double;

      // 2. Calcola la media della materia nel periodo corrente
      final averageString = await returnAverageByPeriodBis(
          subjectUpper); // Usa la funzione helper
      if (averageString == 'N/A') {
        return "not enough data"; // Media non calcolabile
      }
      final average = double.parse(averageString);

      // 3. Confronta media e obiettivo (logica di confronto identica a Python)
      if (average >= objective) {
        return "completely reached";
      }
      if (roundCustom(average) >= objective) {
        // Usa la funzione roundCustom
        return "reached";
      }
      if (average >= objective - 1) {
        return "almost reached";
      }
      return "not reached";
    } catch (e) {
      print("Errore in objectiveAchievementSubjectByPeriod: $e");
      // Il codice Python ritorna False in caso di errore generico, qui potremmo lanciare l'eccezione o ritornare uno stato di errore
      return "error"; // O lancia Exception('Errore nel calcolo obiettivo: $e'); //
    }
  }

  /// Valuta il raggiungimento degli obiettivi per TUTTE le materie nel periodo corrente.
  /// Ritorna una tupla: (Mappa Risultati per Materia, Mappa Conteggi Risultati, Numero Totale Materie)
  Future<(Map<String, String>, Map<String, int>, int)>
      objectiveAchievementByPeriod() async {
    Map<String, String> resultsBySubject = {};
    Map<String, int> countResult = {
      'completely reached': 0, 'reached': 0, 'almost reached': 0,
      'not reached': 0, 'not enough data': 0,
      'error': 0, // Aggiunto stato errore
    }; //

    try {
      // Ottieni tutte le materie
      final allSubjectsList = await listSubjects();
      final subjectNames = allSubjectsList.map((s) => s.$1).toList();
      final subjectNumber = subjectNames.length; //

      // Calcola lo stato per ogni materia
      for (String subjectName in subjectNames) {
        final status = await objectiveAchievementSubjectByPeriod(
            subjectName); // Riutilizza la funzione singola
        resultsBySubject[subjectName] = status;
        countResult[status] =
            (countResult[status] ?? 0) + 1; // Aggiorna il conteggio
      }

      return (resultsBySubject, countResult, subjectNumber);
    } catch (e) {
      print("Errore generale in objectiveAchievementByPeriod: $e");
      // In caso di errore grave, ritorna mappe vuote e 0 materie
      return (
        <String, String>{},
        countResult..update('error', (v) => v + 1),
        0
      ); // Specifica il tipo Map<String, String>
    }
  }

  // --- Metodo per chiudere il DB (Opzionale) ---
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null; // Resetta la variabile statica
    print("Database chiuso.");
  }
}
