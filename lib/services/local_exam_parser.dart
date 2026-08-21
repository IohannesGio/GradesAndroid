class ParsedExamItem {
  String title;
  int cfu;
  bool isSelected;

  ParsedExamItem({
    required this.title,
    this.cfu = 6,
    this.isSelected = true,
  });
}

class LocalExamParser {
  /// Analizza il testo copiato da una pagina web universitaria ed estrae la lista degli esami e i relativi CFU.
  /// Supporta formati tabulari (es. Sapienza, Esse3, Gomp, Cineca), elenchi monolinea e multilinea con lookahead.
  static List<ParsedExamItem> parseText(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final List<ParsedExamItem> results = [];
    final Set<String> addedTitles = {};

    final rawLines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      if (_isHeaderOrFooter(line)) continue;

      // 1. Parsing riga singola (tabulare o con CFU sulla stessa riga)
      ParsedExamItem? item = _parseTabularLine(line);
      item ??= _parseStandardLine(line);

      // 2. Se l'esame è valido ma ha il CFU di default o non trovato, effettua lookahead sulle righe adiacenti
      if (item != null) {
        final cfuOnLine = _extractCfu(line);
        if (cfuOnLine == null) {
          int? lookaheadCfu = _findCfuInSubsequentLines(rawLines, i);
          if (lookaheadCfu != null) {
            item.cfu = lookaheadCfu;
          }
        }
      }

      if (item != null &&
          item.title.length >= 3 &&
          !addedTitles.contains(item.title.toUpperCase())) {
        addedTitles.add(item.title.toUpperCase());
        results.add(item);
      }
    }

    return results;
  }

  /// Cerca i CFU nelle 4 righe immediatamente successive quando il testo è incollato in colonne multilinea
  static int? _findCfuInSubsequentLines(List<String> lines, int currentIndex) {
    for (int offset = 1; offset <= 4; offset++) {
      if (currentIndex + offset >= lines.length) break;
      final nextLine = lines[currentIndex + offset];

      // Se la riga successiva è un nuovo inizio esame (es. codice o pipe "|"), stop
      if (nextLine.contains('|') || _isHeaderOrFooter(nextLine)) break;

      final cfu = _extractCfu(nextLine);
      if (cfu != null) return cfu;
    }
    return null;
  }

  /// Parser specifico per tabelle universitarie (es. Sapienza, Esse3, Gomp)
  static ParsedExamItem? _parseTabularLine(String line) {
    final parts = line.split('\t').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (parts.length >= 2 || line.contains('|')) {
      final firstCol = parts.first;

      String? title = _extractTitle(firstCol);
      if (title == null || title.length < 3 || _isHeaderOrFooter(title)) return null;

      int? cfu;
      if (parts.length >= 2) {
        final lastCol = parts.last;
        final cfuMatch = RegExp(r'^\d{1,2}$').firstMatch(lastCol);
        if (cfuMatch != null) {
          cfu = int.tryParse(cfuMatch.group(0)!);
        }
      }

      cfu ??= _extractCfu(line) ?? 6;

      return ParsedExamItem(
        title: _formatTitle(title),
        cfu: cfu,
        isSelected: true,
      );
    }
    return null;
  }

  /// Parser per righe di testo standard o elenchi
  static ParsedExamItem? _parseStandardLine(String line) {
    int cfu = _extractCfu(line) ?? 6;
    String? title = _extractTitle(line);

    if (title != null && title.length >= 3) {
      return ParsedExamItem(
        title: _formatTitle(title),
        cfu: cfu,
        isSelected: true,
      );
    }
    return null;
  }

  static bool _isHeaderOrFooter(String text) {
    final lower = text.toLowerCase();
    final ignoreKeywords = [
      'insegnamento', 'ssd', 'lingua', 'anno', 'semestre', 'cfu', 'cookie', 'privacy',
      'copyright', 'menu', 'navigazione', 'home', 'contatti', 'cerca', 'login',
      'area riservata', 'anno accademico', 'piano di studi', 'corso di laurea',
      'dipartimento', 'università', 'universita', 'orario lezioni', 'ricevimento',
      'segreteria', 'tutti i diritti riservati', 'pagina', 'gruppo opzionale:',
      'altre attività formative:', 'nel caso in cui lo studente'
    ];
    for (var kw in ignoreKeywords) {
      if (lower == kw || lower.startsWith(kw)) {
        return true;
      }
    }
    return false;
  }

  static String _cleanTitleFromCodeAndBracket(String text) {
    String cleaned = text;

    // 1. Rimuovi codice prima del pipe (es. "100938 | " o "AAF1102 | ")
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z0-9_\-]{2,15}\s*\|\s*'), '');

    // 2. Rimuovi tutto ciò che c'è tra parentesi quadre [CHIM/03], [ITA], [N/D], [BIO/13, BIO/18]
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');

    // 3. Rimuovi codici insegnamento che contengono almeno una cifra (es. "01ABC - ", "MAT/05 - ", "1047699 - ")
    cleaned = cleaned.replaceAll(RegExp(r'^(?:(?=.*\d)[A-Z0-9]{4,12}|[A-Z]{2,4}\/[0-9]{2})\s*[\:\-\–\—]\s*'), '');

    // 4. Rimuovi punteggiatura residua
    cleaned = cleaned.replaceAll(RegExp(r'^[\s\:\-\–\—\,\.\;\*\|]+|[\s\:\-\–\—\,\.\;\*\|]+$'), '').trim();

    return cleaned;
  }

  static int? _extractCfu(String text) {
    // 1. Pattern: Standalone CFU alla fine della riga tabulata (es. "\t6", "\t12")
    final RegExp tabEndPattern = RegExp(r'\t\s*(\d{1,2})\s*$');
    final tabMatch = tabEndPattern.firstMatch(text);
    if (tabMatch != null) {
      final val = int.tryParse(tabMatch.group(1)!);
      if (val != null && val > 0 && val <= 60) return val;
    }

    // 2. Pattern: "9 CFU", "6 cfu", "12 crediti", "6 C.F.U."
    final RegExp pattern1 = RegExp(r'(\d{1,2})\s*(?:cfu|c\.f\.u\.|crediti|credito|ects)', caseSensitive: false);
    final match1 = pattern1.firstMatch(text);
    if (match1 != null) {
      final val = int.tryParse(match1.group(1)!);
      if (val != null && val > 0 && val <= 60) return val;
    }

    // 3. Pattern: "CFU: 9", "Crediti: 12"
    final RegExp pattern2 = RegExp(r'(?:cfu|crediti|ects)\s*[:=\-]\s*(\d{1,2})', caseSensitive: false);
    final match2 = pattern2.firstMatch(text);
    if (match2 != null) {
      final val = int.tryParse(match2.group(1)!);
      if (val != null && val > 0 && val <= 60) return val;
    }

    // 4. Pattern: "(6)" o "[9]" alla fine della riga
    final RegExp pattern3 = RegExp(r'[\(\[\{]\s*(\d{1,2})\s*[\)\]\}]\s*$');
    final match3 = pattern3.firstMatch(text);
    if (match3 != null) {
      final val = int.tryParse(match3.group(1)!);
      if (val != null && val > 0 && val <= 30) return val;
    }

    // 5. Se la riga termina con indicazione anno/semestre/CFU (es. "... 1º 1º 6")
    final RegExp trailingNumPattern = RegExp(r'\b(\d{1,2})\s*$');
    final trailingMatch = trailingNumPattern.firstMatch(text);
    if (trailingMatch != null) {
      final val = int.tryParse(trailingMatch.group(1)!);
      if (val != null && val > 0 && val <= 30) return val;
    }

    return null;
  }

  static String? _extractTitle(String text) {
    String cleaned = _cleanTitleFromCodeAndBracket(text);

    // Rimuovi espressioni dei CFU dal titolo
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}\s*(?:cfu|c\.f\.u\.|crediti|credito|ects)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'(?:cfu|crediti|ects)\s*[:=\-]\s*\d{1,2}', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[\{]\s*\d{1,2}\s*[\)\]\}]'), '');

    // Rimuovi note tra parentesi irrilevanti
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*(?:ssd|anno|semestre|obbligatorio|opzionale|propedeutico)[^\)\]\}]*[\)\]\}]', caseSensitive: false), '');

    // Rimuovi indicazioni di anno/semestre come "1º 1º 6" o "1° 2° 12"
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:\d[º°]\s*)+', caseSensitive: false), '');

    // Rimuovi parole chiave di disturbo ed SSD
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:SSD|MAT\/\d+|INF\/\d+|ING\-INF\/\d+|GEO\/\d+|FIS\/\d+|BIO\/\d+|MED\/\d+|CHIM\/\d+)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:anno\s*\d|primo\s*anno|secondo\s*anno|terzo\s*anno|semestre\s*\d)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:obbligatorio|opzionale|corso|insegnamento)\b', caseSensitive: false), '');

    // Rimuovi sequenze di numeri isolati alla fine della riga (che erano anno/semestre/cfu)
    cleaned = cleaned.replaceAll(RegExp(r'(?:\s+\d{1,2})+\s*$'), '');

    // Pulizia punteggiatura residua ai bordi
    cleaned = cleaned.replaceAll(RegExp(r'^[\s\:\-\–\—\,\.\;\*\|]+|[\s\:\-\–\—\,\.\;\*\|]+$'), '').trim();

    if (cleaned.length < 3) return null;
    return cleaned;
  }

  static String _formatTitle(String title) {
    if (title.isEmpty) return title;
    final words = title.split(RegExp(r'\s+'));
    final formatted = words.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      if (RegExp(r'^(?:[IVXLCDM]+|IA|DB|OS|AI|IT|ICT)$').hasMatch(w.toUpperCase())) {
        return w.toUpperCase();
      }
      if (['e', 'ed', 'di', 'del', 'della', 'degli', 'delle', 'per', 'a', 'in', 'con'].contains(lower)) {
        return lower;
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    return formatted[0].toUpperCase() + formatted.substring(1);
  }
}
