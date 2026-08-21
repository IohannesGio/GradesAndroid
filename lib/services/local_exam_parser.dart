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
  /// Supporta formati tabulari (es. Sapienza, Esse3, Gomp, Cineca), elenchi ed espressioni formattate.
  static List<ParsedExamItem> parseText(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final List<ParsedExamItem> results = [];
    final Set<String> addedTitles = {};

    final lines = rawText.split(RegExp(r'[\r\n]+'));

    for (var line in lines) {
      final cleanedLine = line.trim();
      if (cleanedLine.isEmpty || _isHeaderOrFooter(cleanedLine)) continue;

      // Prova strategie di parsing in ordine di specificità:
      
      // 1. Tabular / Sapienza / Esse3 format (es. "100938 | CHIMICA GENERALE [CHIM/03] [ITA]\t1º\t1º\t6")
      ParsedExamItem? item = _parseTabularLine(cleanedLine);

      // 2. Fallback: Standard line parsing
      item ??= _parseStandardLine(cleanedLine);

      if (item != null && item.title.length >= 3 && !addedTitles.contains(item.title.toUpperCase())) {
        addedTitles.add(item.title.toUpperCase());
        results.add(item);
      }
    }

    return results;
  }

  /// Parser specifico per tabelle universitarie (es. Sapienza, Esse3, Gomp)
  static ParsedExamItem? _parseTabularLine(String line) {
    final parts = line.split('\t').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Se ci sono colonne (con tab) oppure c'è il pipe "|"
    if (parts.length >= 2 || line.contains('|')) {
      final firstCol = parts.first;

      // Estrai il nome dal primo campo
      String title = _cleanTitleFromCodeAndBracket(firstCol);
      if (title.length < 3 || _isHeaderOrFooter(title)) return null;

      // Trova CFU: controlla l'ultima colonna, poi la riga intera
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

  /// Pulisce codici insegnamento (es. "100938 | ", "AAF1102 | ") e staffe con SSD o Lingua (es. "[CHIM/03] [ITA]")
  static String _cleanTitleFromCodeAndBracket(String text) {
    String cleaned = text;

    // Rimuovi codice prima del pipe (es. "100938 | " o "AAF1102 | ")
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z0-9_]{3,12}\s*\|\s*'), '');

    // Rimuovi tutto ciò che c'è tra parentesi quadre [CHIM/03], [ITA], [N/D], [BIO/13, BIO/18]
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');

    // Rimuovi codici insegnamento senza pipe all'inizio
    cleaned = cleaned.replaceAll(RegExp(r'^(?:[A-Z0-9]{4,10}|[A-Z]{2,4}\/[0-9]{2})\s*[\:\-\–\—\s]\s*'), '');

    // Rimuovi punteggiatura residua
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

    // 5. Se la riga termina semplicemente con un numero di CFU isolato (es. "... 1º 1º 6")
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

    // Rimuovi parole chiave di disturbo
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:SSD|MAT\/\d+|INF\/\d+|ING\-INF\/\d+|GEO\/\d+|FIS\/\d+|BIO\/\d+|MED\/\d+|CHIM\/\d+)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:anno\s*\d|primo\s*anno|secondo\s*anno|terzo\s*anno|semestre\s*\d|\dº\s*|\d°\s*)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:obbligatorio|opzionale|corso|insegnamento)\b', caseSensitive: false), '');

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
