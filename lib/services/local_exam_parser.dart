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
  static List<ParsedExamItem> parseText(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final List<ParsedExamItem> results = [];
    final Set<String> addedTitles = {};

    // Dividi per righe o punti elenco
    final lines = rawText.split(RegExp(r'[\r\n]+'));

    for (var line in lines) {
      final cleanedLine = line.trim();
      if (cleanedLine.isEmpty || _isHeaderOrFooter(cleanedLine)) continue;

      // Cerca i CFU nella riga
      int cfu = _extractCfu(cleanedLine) ?? 6;

      // Cerca il nome dell'esame
      String? title = _extractTitle(cleanedLine);

      if (title != null && title.length >= 3 && !addedTitles.contains(title.toUpperCase())) {
        addedTitles.add(title.toUpperCase());
        results.add(ParsedExamItem(
          title: _formatTitle(title),
          cfu: cfu,
          isSelected: true,
        ));
      }
    }

    return results;
  }

  static bool _isHeaderOrFooter(String text) {
    final lower = text.toLowerCase();
    final ignoreKeywords = [
      'cookie', 'privacy', 'copyright', 'menu', 'navigazione', 'home', 'contatti',
      'cerca', 'login', 'area riservata', 'anno accademico', 'piano di studi',
      'corso di laurea', 'dipartimento', 'università', 'universita', 'orario lezioni',
      'ricevimento', 'segreteria', 'tutti i diritti riservati', 'pagina'
    ];
    for (var kw in ignoreKeywords) {
      if (lower == kw || lower.startsWith('$kw ') || lower.endsWith(' $kw')) {
        return true;
      }
    }
    return false;
  }

  static int? _extractCfu(String text) {
    // 1. Pattern: "9 CFU", "6 cfu", "12 crediti", "6 C.F.U."
    final RegExp pattern1 = RegExp(r'(\d{1,2})\s*(?:cfu|c\.f\.u\.|crediti|credito|ects)', caseSensitive: false);
    final match1 = pattern1.firstMatch(text);
    if (match1 != null) {
      final val = int.tryParse(match1.group(1)!);
      if (val != null && val > 0 && val <= 60) return val;
    }

    // 2. Pattern: "CFU: 9", "Crediti: 12"
    final RegExp pattern2 = RegExp(r'(?:cfu|crediti|ects)\s*[:=\-]\s*(\d{1,2})', caseSensitive: false);
    final match2 = pattern2.firstMatch(text);
    if (match2 != null) {
      final val = int.tryParse(match2.group(1)!);
      if (val != null && val > 0 && val <= 60) return val;
    }

    // 3. Pattern: "(6)" o "[9]" alla fine della riga
    final RegExp pattern3 = RegExp(r'[\(\[\{]\s*(\d{1,2})\s*[\)\]\}]\s*$');
    final match3 = pattern3.firstMatch(text);
    if (match3 != null) {
      final val = int.tryParse(match3.group(1)!);
      if (val != null && val > 0 && val <= 30) return val;
    }

    return null;
  }

  static String? _extractTitle(String text) {
    String cleaned = text;

    // Rimuovi codici insegnamento all'inizio (es. "01ABC - ", "MAT/05 - ", "ING-INF/05 ")
    cleaned = cleaned.replaceAll(RegExp(r'^(?:[A-Z0-9]{4,10}|[A-Z]{2,4}\/[0-9]{2})\s*[\:\-\–\—\s]\s*'), '');

    // Rimuovi espressioni dei CFU dal titolo
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}\s*(?:cfu|c\.f\.u\.|crediti|credito|ects)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'(?:cfu|crediti|ects)\s*[:=\-]\s*\d{1,2}', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[\{]\s*\d{1,2}\s*[\)\]\}]'), '');

    // Rimuovi note tra parentesi irrilevanti (es. "(obbligatorio)", "(SSD MAT/05)", "(anno 1)")
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*(?:ssd|anno|semestre|obbligatorio|opzionale|propedeutico)[^\)\]\}]*[\)\]\}]', caseSensitive: false), '');

    // Rimuovi parole chiave di disturbo
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:SSD|MAT\/\d+|INF\/\d+|ING\-INF\/\d+|GEO\/\d+|FIS\/\d+|BIO\/\d+)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:anno\s*\d|primo\s*anno|secondo\s*anno|terzo\s*anno|semestre\s*\d)\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:obbligatorio|opzionale|corso|insegnamento)\b', caseSensitive: false), '');

    // Pulizia punteggiatura residua ai bordi
    cleaned = cleaned.replaceAll(RegExp(r'^[\s\:\-\–\—\,\.\;\*]+|[\s\:\-\–\—\,\.\;\*]+$'), '').trim();

    if (cleaned.length < 3) return null;
    return cleaned;
  }

  static String _formatTitle(String title) {
    if (title.isEmpty) return title;
    // Trasforma in Title Case / Maiuscole corrette per titoli di materie
    final words = title.split(' ');
    final formatted = words.map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      // Mantiene numeri romani (I, II, III, IV) o sigle (IA, DB, OS) in maiuscolo
      if (RegExp(r'^(?:[IVXLCDM]+|IA|DB|OS|AI|IT|ICT)$').hasMatch(w.toUpperCase())) {
        return w.toUpperCase();
      }
      if (['e', 'ed', 'di', 'del', 'della', 'degli', 'delle', 'per', 'a', 'in'].contains(lower)) {
        return lower;
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    return formatted[0].toUpperCase() + formatted.substring(1);
  }
}
