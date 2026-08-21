import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

// ---------- CLASSI ----------

class Subject {
  final int? id;
  final String subjectName;
  final double? objective;
  final int cfu;
  final String status;

  Subject({
    this.id,
    required this.subjectName,
    this.objective,
    this.cfu = 6,
    this.status = 'planned',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subjectName.toUpperCase(),
      'objective': objective,
      'cfu': cfu,
      'status': status,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      subjectName: map['subject'] as String,
      objective: map['objective'] as double?,
      cfu: (map['cfu'] as int?) ?? 6,
      status: (map['status'] as String?) ?? 'planned',
    );
  }

  @override
  String toString() {
    return 'Subject{id: $id, subjectName: $subjectName, objective: $objective, cfu: $cfu, status: $status}';
  }
}

class Grade {
  final int? id;
  final String subjectName;
  final double grade;
  final int date;
  final double weight;
  final String type;
  final String? note;

  Grade({
    this.id,
    required this.subjectName,
    required this.grade,
    required this.date,
    required this.weight,
    required this.type,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_name': subjectName,
      'grade': grade,
      'date': date,
      'weight': weight,
      'type': type,
      'note': note,
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
      note: map['note'] as String?,
    );
  }

  DateTime get dateTime {
    final dateStr = date.toString();
    if (dateStr.length == 8) {
      try {
        return DateTime.parse(
            '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}');
      } catch (e) {
        return DateTime(1970);
      }
    }
    return DateTime(1970);
  }

  @override
  String toString() {
    return 'Grade{id: $id, subjectName: $subjectName, grade: $grade, date: $date, weight: $weight, type: $type}';
  }
}

class Period {
  final String name;
  final int? startDate;
  final int? endDate;

  Period({required this.name, this.startDate, this.endDate});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'start_date': startDate ?? 'N/A',
      'end_date': endDate ?? 'N/A',
    };
  }

  factory Period.fromMap(Map<String, dynamic> map) {
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

class Lesson {
  final int? id;
  final String subjectName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  final String? teacher;

  Lesson({
    this.id,
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.teacher,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_name': subjectName,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'teacher': teacher,
    };
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int?,
      subjectName: map['subject_name'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      room: map['room'] as String?,
      teacher: map['teacher'] as String?,
    );
  }

  @override
  String toString() {
    return 'Lesson{id: $id, subjectName: $subjectName, dayOfWeek: $dayOfWeek, startTime: $startTime, endTime: $endTime, room: $room, teacher: $teacher}';
  }
}

class CalendarEvent {
  final int? id;
  final String title;
  final String description;
  final DateTime date;
  final String type;
  final String? subject;

  CalendarEvent({
    this.id,
    required this.title,
    this.description = '',
    required this.date,
    required this.type,
    this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': DateFormat('yyyyMMdd').format(date),
      'type': type,
      'subject': subject,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    final dateInt = map['date'] as int;
    final year = dateInt ~/ 10000;
    final month = (dateInt ~/ 100) % 100;
    final day = dateInt % 100;
    return CalendarEvent(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      date: DateTime.utc(year, month, day),
      type: map['type'] as String,
      subject: map['subject'] as String?,
    );
  }

  @override
  String toString() {
    return 'CalendarEvent{id: $id, title: $title, date: $date, type: $type, subject: $subject}';
  }
}

// ---------- DATABASE HELPER ----------

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _dbName = "grades.sqlite3"; // Nome file DB

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _dbName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subject_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT UNIQUE,
        objective REAL,
        cfu INTEGER DEFAULT 6,
        status TEXT DEFAULT 'planned'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_name TEXT,
        grade REAL,
        date INTEGER,
        weight REAL,
        type TEXT,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        primary_colour TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS periods (
        name TEXT PRIMARY KEY,
        start_date INTEGER,
        end_date INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timetable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_name TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT,
        teacher TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        date INTEGER NOT NULL,
        type TEXT NOT NULL,
        subject TEXT
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO periods (name, start_date, end_date)
      VALUES
      ('first_period', NULL, NULL),
      ('second_period', NULL, NULL)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE grades ADD COLUMN note TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE subject_list ADD COLUMN cfu INTEGER DEFAULT 6');
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE subject_list ADD COLUMN status TEXT DEFAULT 'planned'");
      } catch (_) {}
    }
  }

  // ---------- GET FUNCTIONS ----------

  Future<String> getDatabasePath() async {
    var databasesPath = await getApplicationDocumentsDirectory();
    return join(databasesPath.path, 'grades.sqlite3');
  }

  Future<String> exportDatabase() async {
    try {
      final String dbPath = await getDatabasePath();
      final File dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return "Errore: il file del database non è stato trovato.";
      }

      final String exportFileName = 'grades.sqlite3';

      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        final FileSaveLocation? saveLocation = await getSaveLocation(
          suggestedName: exportFileName,
        );
        final String? path = saveLocation?.path;
        if (path == null) {
          return "Operazione annullata.";
        }
        await dbFile.copy(path);
        return "Backup esportato in:\n$path";
      } else {
        final XFile fileToShare = XFile(dbPath, name: exportFileName);
        final result = await Share.shareXFiles(
          [fileToShare],
          text: 'Backup del database',
        );
        if (result.status == ShareResultStatus.success) {
          return "Operazione completata!";
        } else {
          return "Operazione annullata.";
        }
      }
    } catch (e) {
      print("Errore durante l'esportazione del database: $e");
      return "Si è verificato un errore durante l'esportazione.";
    }
  }

  Future<String> importDatabase(String sourcePath) async {
    try {
      final String dbPath = await getDatabasePath();
      final File sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        return "Errore: file non trovato.";
      }

      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      await sourceFile.copy(dbPath);
      return "Database importato con successo!";
    } catch (e) {
      print("Errore durante l'importazione del database: $e");
      return "Si è verificato un errore durante l'importazione.";
    }
  }

  Future<List<(String, String)>> listSubjects() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('subject_list');
      List<(String, String)> result = [];
      for (var map in maps) {
        final subject = Subject.fromMap(map);
        result
            .add((subject.subjectName, subject.objective?.toString() ?? 'N/A'));
      }
      return result;
    } catch (e) {
      print('Errore in listSubjects: $e');
      return [];
    }
  }

  Future<String> returnObjective(String subject) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'subject_list',
        columns: ['objective'],
        where: 'subject = ?',
        whereArgs: [subject.toUpperCase()],
      );
      if (maps.isNotEmpty) {
        final objective = maps.first['objective'];
        return objective?.toString() ?? 'N/A';
      } else {
        return 'N/A';
      }
    } catch (e) {
      print('Errore in returnObjective: $e');
      return 'N/A';
    }
  }

  Future<String> returnAverageObjective() async {
    final db = await database;
    try {
      final result = await db
          .rawQuery('SELECT ROUND(AVG(objective), 2) FROM subject_list');
      if (result.isNotEmpty && result.first.values.first != null) {
        return result.first.values.first.toString();
      } else {
        return 'N/A';
      }
    } catch (e) {
      print('Errore in returnAverageObjective: $e');
      return 'N/A';
    }
  }

  Future<List<Grade>> listGrades(String subject) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'grades',
        where: 'subject_name = ?',
        whereArgs: [subject.toUpperCase()],
        orderBy: 'date ASC',
      );
      return List.generate(maps.length, (i) => Grade.fromMap(maps[i]));
    } catch (e) {
      print('Errore in listGrades: $e');
      return [];
    }
  }

  Future<List<Grade>> listGradesByPeriod(String subject,
      {int? startDate, int? endDate}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    final subjectUpper = subject.toUpperCase();

    if (startDate != null && endDate != null) {
      whereClause = 'subject_name = ? AND date BETWEEN ? AND ?';
      whereArgs = [subjectUpper, startDate, endDate];
    } else {
      whereClause = 'subject_name = ?';
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
      return [];
    }
  }

  Future<List<double>> listAllGrades() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result =
          await db.query('grades', columns: ['grade']);
      return result.map((map) => map['grade'] as double).toList();
    } catch (e) {
      print('Errore in listAllGrades: $e');
      return [];
    }
  }

  Future<Map<int, int>> returnGradeProportionsByPeriod(
      String periodName) async {
    final db = await database;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int? maxGradeFromPrefs = prefs.getDouble("max_grade")?.toInt();
    int maxGrade = maxGradeFromPrefs ?? 10;

    Map<int, int> gradeProportions = {for (var i = 0; i <= maxGrade; i++) i: 0};

    try {
      final periodData =
          await db.query('periods', where: 'name = ?', whereArgs: [periodName]);

      if (periodData.isEmpty) return gradeProportions;

      final period = Period.fromMap(periodData.first);
      final startDate = period.startDate;
      final endDate = period.endDate;

      if (startDate == null || endDate == null) {
        print('Date per il periodo $periodName non impostate.');
        return gradeProportions;
      }

      final List<Map<String, dynamic>> gradesMaps = await db.query(
        'grades',
        columns: ['grade'],
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startDate, endDate],
      );

      for (var map in gradesMaps) {
        final gradeValue = map['grade'] as double;
        final gradeIntPart = gradeValue.floor();
        if (gradeProportions.containsKey(gradeIntPart)) {
          gradeProportions[gradeIntPart] = gradeProportions[gradeIntPart]! + 1;
        }
      }
      return gradeProportions;
    } catch (e) {
      print('Errore in returnGradeProportionsByPeriod: $e');
      return gradeProportions;
    }
  }

  Future<Map<int, int>> returnGradeProportionsByPeriodAndSubject(
      String periodName, String subjectName) async {
    final db = await database;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int? maxGradeFromPrefs = prefs.getDouble("max_grade")?.toInt();
    int maxGrade = maxGradeFromPrefs ?? 10;

    Map<int, int> gradeProportions = {for (var i = 0; i <= maxGrade; i++) i: 0};
    final subjectUpper = subjectName.toUpperCase();

    try {
      final periodData =
          await db.query('periods', where: 'name = ?', whereArgs: [periodName]);

      if (periodData.isEmpty) return gradeProportions;

      final period = Period.fromMap(periodData.first);
      final startDate = period.startDate;
      final endDate = period.endDate;

      if (startDate == null || endDate == null) {
        print('Date per il periodo $periodName non impostate.');
        return gradeProportions;
      }

      final List<Map<String, dynamic>> gradesMaps = await db.query(
        'grades',
        columns: ['grade'],
        where: 'date BETWEEN ? AND ? AND subject_name = ?',
        whereArgs: [startDate, endDate, subjectUpper],
      );

      for (var map in gradesMaps) {
        final gradeValue = map['grade'] as double;
        final gradeIntPart = gradeValue.floor();
        if (gradeProportions.containsKey(gradeIntPart)) {
          gradeProportions[gradeIntPart] = gradeProportions[gradeIntPart]! + 1;
        }
      }
      return gradeProportions;
    } catch (e) {
      print(
          'Errore in returnGradeProportionsByPeriodAndSubject (Materia: $subjectName, Periodo: $periodName): $e');
      return gradeProportions;
    }
  }

  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      returnAverageByDate(String period) async {
    final db = await database;

    int? startDate;
    int? endDate;
    String targetPeriodName = 'N/A';

    try {
      final periodsData = await db.query('periods', orderBy: 'name');
      if (periodsData.length < 2) {
        print("Errore: Dati dei periodi mancanti o incompleti.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }
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

    final String sqlCommand = """
    WITH relevant_grades AS (
        SELECT date, grade, weight, subject_name
        FROM grades
        WHERE date BETWEEN $startDate AND $endDate AND weight > 0
    ),
    cumulative_grades AS (
        SELECT
            r1.date,
            r1.subject_name,
            r1.grade,
            r1.weight,
            (SELECT SUM(r2.grade * r2.weight) FROM relevant_grades r2 WHERE r2.subject_name = r1.subject_name AND r2.date <= r1.date) as cumulative_weighted_sum,
            (SELECT SUM(r2.weight) FROM relevant_grades r2 WHERE r2.subject_name = r1.subject_name AND r2.date <= r1.date) as cumulative_weight
        FROM relevant_grades r1
    ),
    cumulative_averages AS (
        SELECT
            date,
            subject_name,
            cumulative_weighted_sum * 1.0 / cumulative_weight AS average_grade
        FROM cumulative_grades
        WHERE cumulative_weight > 0
        GROUP BY date, subject_name
    ),
    distinct_average_dates AS (
        SELECT DISTINCT date FROM cumulative_averages
    ),
    general_cumulative_average AS (
        SELECT
            dad.date,
            AVG(ca.average_grade) AS general_average
        FROM distinct_average_dates dad
        JOIN cumulative_averages ca ON ca.date = (SELECT MAX(ca_inner.date)
                                                   FROM cumulative_averages ca_inner
                                                   WHERE ca_inner.subject_name = ca.subject_name AND ca_inner.date <= dad.date)
        GROUP BY dad.date
    )
    SELECT 'Subject Average' AS type, date, subject_name, average_grade
    FROM cumulative_averages
    UNION ALL
    SELECT 'General Average' AS type, date, NULL AS subject_name, general_average
    FROM general_cumulative_average
    ORDER BY date, type DESC;
    """;

    try {
      final List<Map<String, dynamic>> data = await db.rawQuery(sqlCommand);

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

      return (finalOriginalAverages, finalRoundedAverages);
    } catch (e) {
      print('Errore in returnAverageByDate (Periodo: $targetPeriodName): $e');
      print('SQL Eseguito: $sqlCommand');
      return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
    }
  }

  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      returnAverageByDatePeriod({String? periodName}) async {
    final db = await database;
    int? startDate;
    int? endDate;
    String determinedPeriodName = 'N/A';

    try {
      Period? targetPeriod;
      if (periodName != null && periodName.isNotEmpty) {
        if (periodName != 'first_period' && periodName != 'second_period') {
          print(
              "Errore: Nome periodo non valido '$periodName'. Usare 'first_period' o 'second_period'.");
          return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
        }
        final periodData = await db
            .query('periods', where: 'name = ?', whereArgs: [periodName]);
        if (periodData.isNotEmpty) {
          targetPeriod = Period.fromMap(periodData.first);
          determinedPeriodName = targetPeriod.name;
        } else {
          print(
              "Errore critico: Periodo specificato '$periodName' non trovato nel DB.");
          return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
        }
      } else {
        targetPeriod = await _getCurrentPeriodDates();
        if (targetPeriod != null) {
          determinedPeriodName = targetPeriod.name;
          print("Periodo corrente determinato: $determinedPeriodName");
        } else {
          print(
              "Avviso: Impossibile determinare il periodo corrente. Tentativo di fallback...");
          final periodsData = await db.query('periods', orderBy: 'name DESC');
          if (periodsData.isNotEmpty) {
            for (var pData in periodsData) {
              final fallbackPeriod = Period.fromMap(pData);
              if (fallbackPeriod.startDate != null &&
                  fallbackPeriod.endDate != null) {
                targetPeriod = fallbackPeriod;
                determinedPeriodName = targetPeriod.name;
                print(
                    "Usando periodo di fallback con date valide: $determinedPeriodName");
                break;
              }
            }
          }
          if (targetPeriod == null) {
            print(
                "Errore: Nessun periodo (corrente o fallback) con date valide trovato.");
            return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
          }
        }
      }

      startDate = targetPeriod.startDate;
      endDate = targetPeriod.endDate;

      if (startDate == null || endDate == null) {
        print(
            "Errore: Date per il periodo '$determinedPeriodName' non impostate o non valide.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }

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
            """;

      final List<Map<String, dynamic>> data = await db.rawQuery(sqlCommand);

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

      return (finalOriginalAverages, finalRoundedAverages);
    } catch (e) {
      print(
          'Errore in returnAverageByDatePeriod (Periodo cercato: ${periodName ?? "corrente"}, determinato: $determinedPeriodName): $e');
      return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
    }
  }

  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
      returnAverageBySubjectAndPeriod(
          {String? periodName, required String subjectName}) async {
    final db = await database;
    int? startDate;
    int? endDate;
    String determinedPeriodName = 'N/A';
    final subjectUpper = subjectName.toUpperCase();

    try {
      Period? targetPeriod;
      if (periodName != null && periodName.isNotEmpty) {
        if (periodName != 'first_period' && periodName != 'second_period') {
          print(
              "Errore: Nome periodo non valido '$periodName'. Usare 'first_period' o 'second_period'.");
          return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
        }
        final periodData = await db
            .query('periods', where: 'name = ?', whereArgs: [periodName]);
        if (periodData.isNotEmpty) {
          targetPeriod = Period.fromMap(periodData.first);
          determinedPeriodName = targetPeriod.name;
        } else {
          print(
              "Errore critico: Periodo specificato '$periodName' non trovato nel DB.");
          return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
        }
      } else {
        targetPeriod = await _getCurrentPeriodDates();
        if (targetPeriod != null) {
          determinedPeriodName = targetPeriod.name;
          print("Periodo corrente determinato: $determinedPeriodName");
        } else {
          print(
              "Avviso: Impossibile determinare il periodo corrente. Tentativo di fallback...");
          final periodsData = await db.query('periods', orderBy: 'name DESC');
          if (periodsData.isNotEmpty) {
            for (var pData in periodsData) {
              final fallbackPeriod = Period.fromMap(pData);
              if (fallbackPeriod.startDate != null &&
                  fallbackPeriod.endDate != null) {
                targetPeriod = fallbackPeriod;
                determinedPeriodName = targetPeriod.name;
                print(
                    "Usando periodo di fallback con date valide: $determinedPeriodName");
                break;
              }
            }
          }
          if (targetPeriod == null) {
            print(
                "Errore: Nessun periodo (corrente o fallback) con date valide trovato.");
            return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
          }
        }
      }

      startDate = targetPeriod.startDate;
      endDate = targetPeriod.endDate;

      if (startDate == null || endDate == null) {
        print(
            "Errore: Date per il periodo '$determinedPeriodName' non impostate o non valide.");
        return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
      }

      final String sqlCommand = """
            WITH relevant_grades AS (
                SELECT date, grade, weight, subject_name
                FROM grades
                WHERE date BETWEEN $startDate AND $endDate
                  AND weight > 0
                  AND subject_name = ?
            ),
            cumulative_grades AS (
                SELECT
                    r1.date,
                    r1.subject_name,
                    r1.grade,
                    r1.weight,
                    (SELECT SUM(r2.grade * r2.weight) FROM relevant_grades r2 WHERE r2.date <= r1.date) as cumulative_weighted_sum,
                    (SELECT SUM(r2.weight) FROM relevant_grades r2 WHERE r2.date <= r1.date) as cumulative_weight
                FROM relevant_grades r1
            ),
            cumulative_averages AS (
                SELECT
                    date,
                    subject_name,
                    cumulative_weighted_sum * 1.0 / cumulative_weight AS average_grade
                FROM cumulative_grades
                WHERE cumulative_weight > 0
                GROUP BY date, subject_name
            )
            SELECT date, subject_name, average_grade
            FROM cumulative_averages
            ORDER BY date ASC;
            """;

      final List<Map<String, dynamic>> data =
          await db.rawQuery(sqlCommand, [subjectUpper]);

      List<Map<String, dynamic>> finalOriginalAverages = [];
      List<Map<String, dynamic>> finalRoundedAverages = [];

      for (var record in data) {
        final date = record['date'] as int;
        final average = record['average_grade'] as double?;

        if (average == null || average.isNaN || average.isInfinite) continue;

        finalOriginalAverages.add({'date': date, 'average_grade': average});

        final roundedAverage = roundCustom(average).toDouble();
        finalRoundedAverages
            .add({'date': date, 'average_grade': roundedAverage});
      }

      finalOriginalAverages
          .sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));
      finalRoundedAverages
          .sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));

      return (finalOriginalAverages, finalRoundedAverages);
    } catch (e) {
      print(
          'Errore in returnAverageBySubjectAndPeriod (Materia: $subjectName, Periodo cercato: ${periodName ?? "corrente"}, determinato: $determinedPeriodName): $e');
      return (<Map<String, dynamic>>[], <Map<String, dynamic>>[]);
    }
  }

  Future<String> returnAverage(String subject) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT SUM(grade*weight)/SUM(weight) AS average_grade FROM grades WHERE subject_name = ?',
        [subject.toUpperCase()],
      );

      if (result.isNotEmpty && result.first['average_grade'] != null) {
        final average = result.first['average_grade'] as double;
        return average.toStringAsFixed(2);
      } else {
        return 'N/A';
      }
    } catch (e) {
      print('Errore in returnAverage: $e');
      return 'N/A';
    }
  }

  Future<String> returnAverageByPeriod(
      String subject, int startDate, int endDate) async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT SUM(grade*weight)/SUM(weight) AS average_grade FROM grades WHERE subject_name = ? AND date BETWEEN ? AND ?',
        [subject.toUpperCase(), startDate, endDate],
      );

      if (result.isNotEmpty && result.first['average_grade'] != null) {
        final average = result.first['average_grade'] as double;
        return average.toStringAsFixed(2);
      } else {
        return 'N/A';
      }
    } catch (e) {
      print('Errore in returnAverageByPeriod: $e');
      return 'N/A';
    }
  }

  Future<String> returnAverageByPeriodBis(String subject) async {
    try {
      final currentPeriod = await _getCurrentPeriodDates();
      if (currentPeriod == null) {
        return 'N/A';
      }

      return await returnAverageByPeriod(
          subject, currentPeriod.startDate!, currentPeriod.endDate!);
    } catch (e) {
      print('Errore in returnAverageByPeriodBis: $e');
      return 'N/A';
    }
  }

  Future<List<(String, String)>> returnAverages() async {
    final db = await database;
    List<(String, String)> results = [];
    try {
      final avgMaps = await db.rawQuery(
          'SELECT subject_name, SUM(grade*weight)/SUM(weight) AS average_grade FROM grades GROUP BY subject_name');

      Map<String, String> calculatedAverages = {};
      for (var map in avgMaps) {
        final subject = map['subject_name'] as String;
        final average = map['average_grade'] as double?;
        calculatedAverages[subject] =
            average != null ? average.toStringAsFixed(2) : 'N/A';
      }

      final allSubjectsList = await listSubjects();
      final allSubjectNames = allSubjectsList.map((s) => s.$1).toList();

      for (var subjectName in allSubjectNames) {
        results.add((subjectName, calculatedAverages[subjectName] ?? 'N/A'));
      }

      return results;
    } catch (e) {
      print('Errore in returnAverages: $e');
      return results;
    }
  }

  Future<List<(String, String)>> returnAveragesByPeriod() async {
    final db = await database;
    List<(String, String)> results = [];
    try {
      final currentPeriod = await _getCurrentPeriodDates();
      if (currentPeriod == null ||
          currentPeriod.startDate == null ||
          currentPeriod.endDate == null) {
        print("Periodo corrente non valido o non impostato.");
        final allSubjectsList = await listSubjects();
        return allSubjectsList.map((s) => (s.$1, 'N/A')).toList();
      }
      final startDate = currentPeriod.startDate!;
      final endDate = currentPeriod.endDate!;

      final avgMaps = await db.rawQuery(
          '''SELECT subject_name, SUM(grade*weight)/SUM(weight) AS average_grade
               FROM grades
               WHERE date BETWEEN ? AND ?
               GROUP BY subject_name''', [startDate, endDate]);

      Map<String, String> calculatedAverages = {};
      for (var map in avgMaps) {
        final subject = map['subject_name'] as String;
        final average = map['average_grade'] as double?;
        calculatedAverages[subject] =
            average != null ? average.toStringAsFixed(2) : 'N/A';
      }

      final allSubjectsList = await listSubjects();
      final allSubjectNames = allSubjectsList.map((s) => s.$1).toList();

      for (var subjectName in allSubjectNames) {
        results.add((subjectName, calculatedAverages[subjectName] ?? 'N/A'));
      }
      return results;
    } catch (e) {
      print('Errore in returnAveragesByPeriod: $e');
      return results;
    }
  }

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

      final result = await db.rawQuery('''
            SELECT AVG(average_grade) AS overall_average
            FROM (
                SELECT subject_name,
                SUM(grade * weight) / SUM(weight) AS average_grade
                FROM grades
                WHERE date BETWEEN ? AND ?
                GROUP BY subject_name
                HAVING SUM(weight) > 0
            ) AS subject_averages;
        ''', [startDate, endDate]);

      if (result.isNotEmpty && result.first['overall_average'] != null) {
        final average = result.first['overall_average'] as double;
        return average.toStringAsFixed(2);
      } else {
        return 'N/A';
      }
    } catch (e) {
      print('Errore in returnGeneralAverageByPeriod: $e');
      return 'N/A';
    }
  }

  Future<List<Period>> getPeriods() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps =
          await db.query('periods', orderBy: 'name');
      if (maps.isEmpty) {
        return [
          Period(name: 'first_period', startDate: null, endDate: null),
          Period(name: 'second_period', startDate: null, endDate: null),
        ];
      }
      return List.generate(maps.length, (i) => Period.fromMap(maps[i]));
    } catch (e) {
      print('Errore in getPeriods: $e');
      return [
        Period(name: 'first_period', startDate: null, endDate: null),
        Period(name: 'second_period', startDate: null, endDate: null),
      ];
    }
  }

  Future<List<Lesson>> getLessonsForDay(int dayOfWeek) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'timetable',
        where: 'day_of_week = ?',
        whereArgs: [dayOfWeek],
        orderBy: 'start_time ASC',
      );
      return List.generate(maps.length, (i) => Lesson.fromMap(maps[i]));
    } catch (e) {
      print('Errore in getLessonsForDay: $e');
      return [];
    }
  }

  Future<List<Lesson>> getAllLessons() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'timetable',
        orderBy: 'day_of_week ASC, start_time ASC',
      );
      return List.generate(maps.length, (i) => Lesson.fromMap(maps[i]));
    } catch (e) {
      print('Errore in getAllLessons: $e');
      return [];
    }
  }

  Future<List<CalendarEvent>> getCalendarEventsForDate(DateTime date) async {
    final db = await database;
    final dateInt = int.parse(DateFormat('yyyyMMdd').format(date));
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'calendar_events',
        where: 'date = ?',
        whereArgs: [dateInt],
        orderBy: 'title ASC',
      );
      return List.generate(maps.length, (i) => CalendarEvent.fromMap(maps[i]));
    } catch (e) {
      print('Errore in getCalendarEventsForDate: $e');
      return [];
    }
  }

  Future<List<CalendarEvent>> getAllCalendarEvents() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'calendar_events',
        orderBy: 'date ASC, title ASC',
      );
      return List.generate(maps.length, (i) => CalendarEvent.fromMap(maps[i]));
    } catch (e) {
      print('Errore in getAllCalendarEvents: $e');
      return [];
    }
  }

  // ---------- UPDATE FUNCTIONS ----------

  Future<bool> editGrade(Map<String, dynamic> data) async {
    final db = await database;
    try {
      final values = {
        'subject_name': (data['subject'] as String?)?.toUpperCase(),
        'grade': data['grade'],
        'date': data['date'],
        'weight': data['grade_weight'],
        'type': data['type'],
        'note': data['note'],
      };
      values.removeWhere((key, value) => value == null);

      if (values.isEmpty) {
        print("Nessun dato valido fornito per l'aggiornamento del voto.");
        return false;
      }

      final count = await db.update(
        'grades',
        values,
        where: 'id = ?',
        whereArgs: [data['grade_id']],
      );
      return count > 0;
    } catch (e) {
      print('Errore in editGrade: $e');
      return false;
    }
  }

  Future<bool> setPrimaryColour(String colour) async {
    final db = await database;
    try {
      final existing =
          await db.query('settings', where: 'id = ?', whereArgs: [1]);

      if (existing.isNotEmpty) {
        await db.update(
          'settings',
          {'primary_colour': colour},
          where: 'id = ?',
          whereArgs: [1],
        );
      } else {
        await db.insert(
          'settings',
          {'id': 1, 'primary_colour': colour},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return true;
    } catch (e) {
      print('Errore in setPrimaryColour: $e');
      return false;
    }
  }

  Future<bool> renameSubject(
      String oldSubjectName, String newSubjectName) async {
    final db = await database;
    final oldUpper = oldSubjectName.toUpperCase();
    final newUpper = newSubjectName.toUpperCase();

    if (oldUpper == newUpper) return true;

    try {
      await db.transaction((txn) async {
        await txn.update(
          'grades',
          {'subject_name': newUpper},
          where: 'subject_name = ?',
          whereArgs: [oldUpper],
        );
        await txn.update(
          'subject_list',
          {'subject': newUpper},
          where: 'subject = ?',
          whereArgs: [oldUpper],
        );
      });
      print("Materia rinominata");
      return true;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw 'duplicate subject';
      } else {
        print('Errore Database in renameSubject: $e');
        rethrow;
      }
    } catch (e) {
      print('Errore generico in renameSubject: $e');
      return false;
    }
  }

  Future<bool> setObjective(String subject, double objective) async {
    final db = await database;
    try {
      final count = await db.update(
        'subject_list',
        {'objective': objective},
        where: 'subject = ?',
        whereArgs: [subject.toUpperCase()],
      );
      return count > 0;
    } catch (e) {
      print('Errore in setObjective: $e');
      return false;
    }
  }

  Future<dynamic> setPeriod(
      String periodName, int startDate, int endDate) async {
    final db = await database;

    if (startDate > endDate) {
      return 'invalid dates';
    }

    try {
      if (periodName == 'second_period') {
        final firstPeriodData = await db
            .query('periods', where: 'name = ?', whereArgs: ['first_period']);
        if (firstPeriodData.isNotEmpty) {
          final firstPeriod = Period.fromMap(firstPeriodData.first);
          if (firstPeriod.endDate != null &&
              firstPeriod.endDate! >= startDate) {
            return 'invalid dates';
          }
        }
      } else if (periodName == 'first_period') {
        final secondPeriodData = await db
            .query('periods', where: 'name = ?', whereArgs: ['second_period']);
        if (secondPeriodData.isNotEmpty) {
          final secondPeriod = Period.fromMap(secondPeriodData.first);
          if (secondPeriod.startDate != null &&
              secondPeriod.startDate! <= endDate) {
            return 'invalid dates';
          }
        }
      }

      final count = await db.update(
        'periods',
        {'start_date': startDate, 'end_date': endDate},
        where: 'name = ?',
        whereArgs: [periodName],
      );
      return count > 0;
    } catch (e) {
      print('Errore in setPeriod: $e');
      return false;
    }
  }

  Future<bool> updateLesson(Lesson lesson) async {
    final db = await database;
    try {
      if (lesson.id == null) {
        print('Errore: ID della lezione non fornito per l\'aggiornamento.');
        return false;
      }
      final Map<String, dynamic> lessonMap = lesson.toMap();
      lessonMap['subject_name'] =
          (lessonMap['subject_name'] as String).toUpperCase();

      final count = await db.update(
        'timetable',
        lessonMap,
        where: 'id = ?',
        whereArgs: [lesson.id],
      );
      return count > 0;
    } catch (e) {
      print('Errore in updateLesson: $e');
      return false;
    }
  }

  Future<bool> updateCalendarEvent(CalendarEvent event) async {
    final db = await database;
    try {
      if (event.id == null) {
        print('Errore: ID dell\'evento non fornito per l\'aggiornamento.');
        return false;
      }
      final count = await db.update(
        'calendar_events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      return count > 0;
    } catch (e) {
      print('Errore in updateCalendarEvent: $e');
      return false;
    }
  }

  // ---------- REMOVE FUNCTIONS ----------

  Future<bool> deleteGrade(int id) async {
    final db = await database;
    try {
      final count = await db.delete(
        'grades',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Errore in deleteGrade: $e');
      return false;
    }
  }

  Future<bool> deleteSubject(String subject) async {
    final db = await database;
    final subjectUpper = subject.toUpperCase();
    try {
      await db.transaction((txn) async {
        await txn.delete(
          'grades',
          where: 'subject_name = ?',
          whereArgs: [subjectUpper],
        );
        await txn.delete(
          'subject_list',
          where: 'subject = ?',
          whereArgs: [subjectUpper],
        );
      });
      return true;
    } catch (e) {
      print('Errore in deleteSubject: $e');
      return false;
    }
  }

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

  Future<bool> deleteLesson(int id) async {
    final db = await database;
    try {
      final count = await db.delete(
        'timetable',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Errore in deleteLesson: $e');
      return false;
    }
  }

  Future<bool> deleteCalendarEvent(int id) async {
    final db = await database;
    try {
      final count = await db.delete(
        'calendar_events',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Errore in deleteCalendarEvent: $e');
      return false;
    }
  }

  // ---------- CREATE FUNCTIONS ----------

  Future<bool> addSubject(String subject, {int cfu = 6, String status = 'planned'}) async {
    final db = await database;
    try {
      await db.insert(
        'subject_list',
        {
          'subject': subject.toUpperCase(),
          'cfu': cfu,
          'status': status,
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw 'duplicate subject';
      } else {
        print('Errore Database in addSubject: $e');
        rethrow;
      }
    } catch (e) {
      print('Errore generico in addSubject: $e');
      return false;
    }
  }

  Future<bool> updateSubjectCfu(String subject, int cfu) async {
    final db = await database;
    try {
      await db.update(
        'subject_list',
        {'cfu': cfu},
        where: 'subject = ?',
        whereArgs: [subject.toUpperCase()],
      );
      return true;
    } catch (e) {
      print('Errore in updateSubjectCfu: $e');
      return false;
    }
  }

  Future<bool> updateSubjectStatus(String subject, String status) async {
    final db = await database;
    try {
      await db.update(
        'subject_list',
        {'status': status},
        where: 'subject = ?',
        whereArgs: [subject.toUpperCase()],
      );
      return true;
    } catch (e) {
      print('Errore in updateSubjectStatus: $e');
      return false;
    }
  }

  Future<List<Subject>> listSubjectsFull() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('subject_list');
      return maps.map((m) => Subject.fromMap(m)).toList();
    } catch (e) {
      print('Errore in listSubjectsFull: $e');
      return [];
    }
  }

  Future<Subject?> getSubjectDetails(String subjectName) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'subject_list',
        where: 'subject = ?',
        whereArgs: [subjectName.toUpperCase()],
      );
      if (maps.isNotEmpty) {
        return Subject.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Errore in getSubjectDetails: $e');
      return null;
    }
  }

  /// Calcola la Media Ponderata per l'Università (Voto * CFU / CFU totali superati)
  Future<String> returnWeightedAverage() async {
    final db = await database;
    try {
      final subjects = await listSubjectsFull();
      if (subjects.isEmpty) return 'N/A';

      double totalWeightedSum = 0.0;
      int totalCfuEvaluated = 0;

      for (var s in subjects) {
        final grades = await listGrades(s.subjectName);
        if (grades.isNotEmpty) {
          // Calcola la media dei voti della materia
          double subjectAvgSum = 0.0;
          double subjectWeightSum = 0.0;
          for (var g in grades) {
            if (g.weight > 0) {
              subjectAvgSum += g.grade * g.weight;
              subjectWeightSum += g.weight;
            }
          }
          if (subjectWeightSum > 0) {
            double subjectAverage = subjectAvgSum / subjectWeightSum;
            totalWeightedSum += subjectAverage * s.cfu;
            totalCfuEvaluated += s.cfu;
          }
        }
      }

      if (totalCfuEvaluated == 0) return 'N/A';
      double weightedAverage = totalWeightedSum / totalCfuEvaluated;
      return weightedAverage.toStringAsFixed(2);
    } catch (e) {
      print('Errore in returnWeightedAverage: $e');
      return 'N/A';
    }
  }

  /// Calcola il totale dei CFU conseguiti (materie che hanno almeno un voto di sufficienza >= 18)
  Future<int> returnAcquiredCfu() async {
    try {
      final subjects = await listSubjectsFull();
      int acquiredCfu = 0;

      for (var s in subjects) {
        final grades = await listGrades(s.subjectName);
        if (grades.any((g) => g.grade >= 18)) {
          acquiredCfu += s.cfu;
        }
      }
      return acquiredCfu;
    } catch (e) {
      print('Errore in returnAcquiredCfu: $e');
      return 0;
    }
  }

  /// Calcola la proiezione del voto di laurea (base 110)
  Future<String> returnDegreePrediction() async {
    final weightedAvgStr = await returnWeightedAverage();
    final double? weightedAvg = double.tryParse(weightedAvgStr);
    if (weightedAvg == null) return 'N/A';

    double degreeBase = (weightedAvg * 110) / 30;
    return degreeBase.toStringAsFixed(2);
  }

  Future<bool> addGrade(
      String subjectName, double grade, int date, double weight, String type,
      {String? note}) async {
    final db = await database;
    try {
      final gradeObj = Grade(
          subjectName: subjectName.toUpperCase(),
          grade: grade,
          date: date,
          weight: weight,
          type: type,
          note: note);
      await db.insert(
        'grades',
        gradeObj.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (e) {
      print('Errore in addGrade: $e');
      return false;
    }
  }

  Future<bool> addLesson(Lesson lesson) async {
    final db = await database;
    try {
      final Map<String, dynamic> lessonMap = lesson.toMap();
      lessonMap['subject_name'] =
          (lessonMap['subject_name'] as String).toUpperCase();

      await db.insert(
        'timetable',
        lessonMap..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      print('Errore in addLesson: $e');
      return false;
    }
  }

  Future<bool> addCalendarEvent(CalendarEvent event) async {
    final db = await database;
    try {
      await db.insert(
        'calendar_events',
        event.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      print('Errore in addCalendarEvent: $e');
      return false;
    }
  }

  // ---------- GRADE TYPE ANALYSIS FUNCTIONS ----------

  /// Restituisce la media per tipologia di voto (scritto/orale/pratico) per una materia
  Future<Map<String, double>> getAveragesByType(String subject) async {
    final db = await database;
    final subjectUpper = subject.toUpperCase();

    try {
      final result = await db.rawQuery('''
        SELECT type, SUM(grade * weight) / SUM(weight) AS average_grade
        FROM grades
        WHERE subject_name = ?
        GROUP BY type
      ''', [subjectUpper]);

      Map<String, double> averages = {};
      for (var row in result) {
        final type = row['type'] as String;
        final average = row['average_grade'] as double?;
        if (average != null) {
          averages[type] = average;
        }
      }
      return averages;
    } catch (e) {
      print('Errore in getAveragesByType: $e');
      return {};
    }
  }

  /// Restituisce la media per tipologia di voto per tutte le materie
  Future<Map<String, double>> getOverallAveragesByType() async {
    final db = await database;

    try {
      final result = await db.rawQuery('''
        SELECT type, SUM(grade * weight) / SUM(weight) AS average_grade
        FROM grades
        GROUP BY type
      ''');

      Map<String, double> averages = {};
      for (var row in result) {
        final type = row['type'] as String;
        final average = row['average_grade'] as double?;
        if (average != null) {
          averages[type] = average;
        }
      }
      return averages;
    } catch (e) {
      print('Errore in getOverallAveragesByType: $e');
      return {};
    }
  }

  /// Restituisce il conteggio di voti per tipologia
  Future<Map<String, int>> getGradeCountByType(String? subject) async {
    final db = await database;

    try {
      String query;
      List<dynamic> args;

      if (subject != null) {
        query = '''
          SELECT type, COUNT(*) as count
          FROM grades
          WHERE subject_name = ?
          GROUP BY type
        ''';
        args = [subject.toUpperCase()];
      } else {
        query = '''
          SELECT type, COUNT(*) as count
          FROM grades
          GROUP BY type
        ''';
        args = [];
      }

      final result = await db.rawQuery(query, args);

      Map<String, int> counts = {};
      for (var row in result) {
        final type = row['type'] as String;
        final count = row['count'] as int;
        counts[type] = count;
      }
      return counts;
    } catch (e) {
      print('Errore in getGradeCountByType: $e');
      return {};
    }
  }

  // ---------- ACHIEVEMENT FUNCTIONS ----------

  /// Restituisce gli achievement dell'utente
  Future<Map<String, dynamic>> getAchievements() async {
    final db = await database;
    Map<String, dynamic> achievements = {
      'total_grades': 0,
      'perfect_scores': 0, // Voti massimi (10 o max_grade)
      'above_eight': 0, // Voti >= 8
      'subjects_with_objective': 0, // Materie con obiettivo raggiunto
      'best_subject': null,
      'best_average': 0.0,
      'current_streak': 0, // Giorni consecutivi con voti
      'highest_improvement': null, // Materia con maggior miglioramento
    };

    try {
      // Carica max_grade dalle impostazioni
      final prefs = await SharedPreferences.getInstance();
      final maxGrade = prefs.getDouble('max_grade') ?? 10.0;

      // Totale voti
      final totalResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM grades');
      achievements['total_grades'] = totalResult.first['count'] as int;

      // Voti perfetti
      final perfectResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM grades WHERE grade >= ?', [maxGrade]);
      achievements['perfect_scores'] = perfectResult.first['count'] as int;

      // Voti sopra 8
      final aboveEightResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM grades WHERE grade >= 8.0');
      achievements['above_eight'] = aboveEightResult.first['count'] as int;

      // Materie con obiettivo raggiunto
      final objectivesResult = await objectiveAchievementByPeriod();
      final reachedCount = (objectivesResult.$2['completely reached'] ?? 0) +
          (objectivesResult.$2['reached'] ?? 0);
      achievements['subjects_with_objective'] = reachedCount;

      // Materia migliore
      final bestSubjectResult = await db.rawQuery('''
        SELECT subject_name, SUM(grade * weight) / SUM(weight) AS average_grade
        FROM grades
        GROUP BY subject_name
        ORDER BY average_grade DESC
        LIMIT 1
      ''');
      if (bestSubjectResult.isNotEmpty &&
          bestSubjectResult.first['average_grade'] != null) {
        achievements['best_subject'] =
            bestSubjectResult.first['subject_name'] as String;
        achievements['best_average'] =
            bestSubjectResult.first['average_grade'] as double;
      }

      // Calcola streak (giorni consecutivi con almeno un voto)
      final streakResult = await _calculateStreak();
      achievements['current_streak'] = streakResult;

      return achievements;
    } catch (e) {
      print('Errore in getAchievements: $e');
      return achievements;
    }
  }

  /// Calcola lo streak di giorni consecutivi con voti
  Future<int> _calculateStreak() async {
    final db = await database;

    try {
      final result = await db.rawQuery('''
        SELECT DISTINCT date
        FROM grades
        ORDER BY date DESC
      ''');

      if (result.isEmpty) return 0;

      int streak = 0;
      DateTime? lastDate;

      for (var row in result) {
        final dateInt = row['date'] as int;
        final dateStr = dateInt.toString();
        if (dateStr.length == 8) {
          final date = DateTime.parse(
              '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}');

          if (lastDate == null) {
            // Primo giorno
            final today = DateTime.now();
            final diff = today.difference(date).inDays;
            if (diff > 1)
              break; // Lo streak è rotto se l'ultimo voto non è oggi o ieri
            streak = 1;
            lastDate = date;
          } else {
            // Controlla se è consecutivo
            final diff = lastDate.difference(date).inDays;
            if (diff == 1) {
              streak++;
              lastDate = date;
            } else {
              break; // Lo streak è rotto
            }
          }
        }
      }

      return streak;
    } catch (e) {
      print('Errore in _calculateStreak: $e');
      return 0;
    }
  }

  // ---------- CALENDAR FUNCTIONS ----------

  /// Restituisce tutti i voti con le loro date per il calendario
  Future<List<Grade>> getGradesForCalendar(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    try {
      String query = 'SELECT * FROM grades';
      List<dynamic> args = [];

      if (startDate != null && endDate != null) {
        final startInt = int.parse(DateFormat('yyyyMMdd').format(startDate));
        final endInt = int.parse(DateFormat('yyyyMMdd').format(endDate));
        query += ' WHERE date BETWEEN ? AND ?';
        args = [startInt, endInt];
      }

      query += ' ORDER BY date DESC';

      final result = await db.rawQuery(query, args);
      return result.map((map) => Grade.fromMap(map)).toList();
    } catch (e) {
      print('Errore in getGradesForCalendar: $e');
      return [];
    }
  }

  /// Restituisce i voti per una specifica data
  Future<List<Grade>> getGradesForDate(DateTime date) async {
    final db = await database;
    final dateInt = int.parse(DateFormat('yyyyMMdd').format(date));

    try {
      final result = await db.query(
        'grades',
        where: 'date = ?',
        whereArgs: [dateInt],
        orderBy: 'subject_name ASC',
      );
      return result.map((map) => Grade.fromMap(map)).toList();
    } catch (e) {
      print('Errore in getGradesForDate: $e');
      return [];
    }
  }

  /// Restituisce un riepilogo mensile dei voti
  Future<Map<int, List<Grade>>> getGradesByMonth(int year, int month) async {
    final db = await database;

    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0); // Ultimo giorno del mese

      final startInt = int.parse(DateFormat('yyyyMMdd').format(startDate));
      final endInt = int.parse(DateFormat('yyyyMMdd').format(endDate));

      final result = await db.query(
        'grades',
        where: 'date BETWEEN ? AND ?',
        whereArgs: [startInt, endInt],
        orderBy: 'date ASC',
      );

      Map<int, List<Grade>> gradesByDay = {};
      for (var map in result) {
        final grade = Grade.fromMap(map);
        final day = grade.dateTime.day;
        if (!gradesByDay.containsKey(day)) {
          gradesByDay[day] = [];
        }
        gradesByDay[day]!.add(grade);
      }

      return gradesByDay;
    } catch (e) {
      print('Errore in getGradesByMonth: $e');
      return {};
    }
  }

  // ---------- UTILITY AND ACHIEVEMENT FUNCTIONS ----------

  int roundCustom(double n) {
    return (n + 0.5).floor();
  }

  Future<String> objectiveAchievementSubjectByPeriod(String subject) async {
    final db = await database;
    final subjectUpper = subject.toUpperCase();

    try {
      final objectiveData = await db.query('subject_list',
          columns: ['objective'],
          where: 'subject = ?',
          whereArgs: [subjectUpper]);
      if (objectiveData.isEmpty || objectiveData.first['objective'] == null) {
        return "not enough data";
      }
      final objective = objectiveData.first['objective'] as double;

      final averageString = await returnAverageByPeriodBis(subjectUpper);
      if (averageString == 'N/A') {
        return "not enough data";
      }
      final average = double.parse(averageString);

      if (average >= objective) {
        return "completely reached";
      }
      if (roundCustom(average) >= objective) {
        return "reached";
      }
      if (average >= objective - 1) {
        return "almost reached";
      }
      return "not reached";
    } catch (e) {
      print("Errore in objectiveAchievementSubjectByPeriod: $e");
      return "error";
    }
  }

  Future<(Map<String, String>, Map<String, int>, int)>
      objectiveAchievementByPeriod() async {
    Map<String, String> resultsBySubject = {};
    Map<String, int> countResult = {
      'completely reached': 0,
      'reached': 0,
      'almost reached': 0,
      'not reached': 0,
      'not enough data': 0,
      'error': 0,
    };

    try {
      final allSubjectsList = await listSubjects();
      final subjectNames = allSubjectsList.map((s) => s.$1).toList();
      final subjectNumber = subjectNames.length;

      for (String subjectName in subjectNames) {
        final status = await objectiveAchievementSubjectByPeriod(subjectName);
        resultsBySubject[subjectName] = status;
        countResult[status] = (countResult[status] ?? 0) + 1;
      }

      return (resultsBySubject, countResult, subjectNumber);
    } catch (e) {
      print("Errore generale in objectiveAchievementByPeriod: $e");
      return (
        <String, String>{},
        countResult..update('error', (v) => v + 1),
        0
      );
    }
  }

  // ---------- INTERNAL HELPERS ----------

  Future<Period?> _getCurrentPeriodDates() async {
    final db = await database;
    try {
      final todayInt = int.parse(DateFormat('yyyyMMdd').format(DateTime.now()));

      final periodsData = await db.query('periods', orderBy: 'name');
      if (periodsData.length < 2) return null;

      final firstPeriod = Period.fromMap(periodsData[0]);
      final secondPeriod = Period.fromMap(periodsData[1]);

      if (firstPeriod.startDate != null &&
          firstPeriod.endDate != null &&
          todayInt >= firstPeriod.startDate! &&
          todayInt <= firstPeriod.endDate!) {
        return firstPeriod;
      }
      if (secondPeriod.startDate != null &&
          secondPeriod.endDate != null &&
          todayInt >= secondPeriod.startDate! &&
          todayInt <= secondPeriod.endDate!) {
        if (firstPeriod.endDate == null ||
            secondPeriod.startDate! > firstPeriod.endDate!) {
          return secondPeriod;
        }
      }

      if (secondPeriod.startDate != null && secondPeriod.endDate != null) {
        return secondPeriod;
      } else if (firstPeriod.startDate != null && firstPeriod.endDate != null) {
        return secondPeriod;
      }

      return null;
    } catch (e) {
      print("Errore nel determinare il periodo corrente: $e");
      return null;
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    print("Database chiuso.");
  }

  Future<String> archiveAndStartNewYear() async {
    final db = await database;
    try {
      // 1. Esporta il database corrente come backup
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupName = 'grades_archive_$timestamp.sqlite3';

      // Usa la logica interna di exportDatabase ma con nome custom se possibile,
      // oppure usa exportDatabase standard e rinomina o lascia così.
      // Per semplicità, usiamo exportDatabase che chiede all'utente dove salvare.
      // Se vogliamo automatizzare, dovremmo copiare il file DB internamente.

      // Copia interna automatica per preservare lo storico
      final dbFolder = await getApplicationDocumentsDirectory();
      final currentDbPath = join(dbFolder.path, _dbName);
      final archiveFolder = Directory(join(dbFolder.path, 'archives'));
      if (!await archiveFolder.exists()) {
        await archiveFolder.create(recursive: true);
      }
      final backupPath = join(archiveFolder.path, backupName);
      await File(currentDbPath).copy(backupPath);

      // 2. Cancella i dati dell'anno corrente
      await db.transaction((txn) async {
        await txn.delete('grades');
        await txn.delete('timetable'); // Orario scolastico

        // Verifica se esiste tabella calendar_events
        try {
          await txn.delete('calendar_events');
        } catch (e) {
          // Tabella potrebbe non esistere
        }

        // Resetta i periodi (opzionale, o li imposta a null)
        await txn.update('periods', {'start_date': null, 'end_date': null});

        // NON cancellare subject_list (materie)
      });

      // Resetta anche i periodi in SharedPreferences se necessario
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('first_period_start');
      await prefs.remove('first_period_end');
      await prefs.remove('second_period_start');
      await prefs.remove('second_period_end');

      return 'Anno archiviato con successo! Backup salvato in: $backupName';
    } catch (e) {
      print('Errore durante l\'archiviazione: $e');
      return 'Errore durante l\'archiviazione: $e';
    }
  }

  Future<bool> clearAllData() async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete('grades');
        await txn.delete('subject_list');
        await txn.delete('periods');
        // Reinserisci i periodi vuoti
        await txn.execute('''
        INSERT INTO periods (name, start_date, end_date)
        VALUES 
        ('first_period', NULL, NULL),
        ('second_period', NULL, NULL)
      ''');
      });
      return true;
    } catch (e) {
      print('Errore in clearAllData: $e');
      return false;
    }
  }
}
