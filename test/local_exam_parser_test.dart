import 'package:flutter_test/flutter_test.dart';
import 'package:grades/services/local_exam_parser.dart';

void main() {
  group('LocalExamParser Tests', () {
    test('Parse Sapienza sample text with tabs and spaces', () {
      const sampleText = '''
Insegnamento [SSD] [Lingua]	Anno	Semestre	CFU
AAF1102 | LINGUA INGLESE [N/D] [ITA]	1º	1º	4
100938 | CHIMICA GENERALE E INORGANICA [CHIM/03] [ITA]	1º	1º	6
1038524 | BIOLOGIA CELLULARE [BIO/13] [ITA]	1º	1º	9
 1047699 | MATEMATICA [MAT/07, MAT/05] [ITA]	1º	1º	6
 1036586 | CHIMICA ORGANICA [CHIM/06] [ITA]	1º	1º	9
97597 | FISICA [FIS/01] [ITA]	1º	2º	6
 1023907 | MICROBIOLOGIA GENERALE, BIOTECNOLOGIE MICROBICHE ED ELEMENTI DI MICROBIOLOGIA MEDICA [MED/07, BIO/19] [ITA]	1º	2º	12
 1044806 | ISTOLOGIA ED EMBRIOLOGIA [BIO/06, BIO/17] [ITA]	1º	2º	6
 1051488 | GENETICA [BIO/13, BIO/18] [ITA]	1º	2º	9
''';

      final results = LocalExamParser.parseText(sampleText);

      expect(results.isNotEmpty, true);
      expect(results.any((e) => e.title.contains('Lingua Inglese') && e.cfu == 4), true);
      expect(results.any((e) => e.title.contains('Chimica Generale e Inorganica') && e.cfu == 6), true);
      expect(results.any((e) => e.title.contains('Biologia Cellulare') && e.cfu == 9), true);
      expect(results.any((e) => e.title.contains('Microbiologia Generale') && e.cfu == 12), true);
    });

    test('Parse Polimi (Politecnico di Milano) format', () {
      const polimiText = '''
089201 - ANALISI MATEMATICA I (10 CFU)
089202 - GEOMETRIA E ALGEBRA LINEARE (8 ECTS)
089203 - FISICA SPERIMENTALE (12 CFU)
''';

      final results = LocalExamParser.parseText(polimiText);

      expect(results.length, 3);
      expect(results[0].title, 'Analisi Matematica I');
      expect(results[0].cfu, 10);
      expect(results[1].title, 'Geometria e Algebra Lineare');
      expect(results[1].cfu, 8);
      expect(results[2].title, 'Fisica Sperimentale');
      expect(results[2].cfu, 12);
    });

    test('Parse UniBo (Università di Bologna) format', () {
      const uniboText = '''
72819 - PROGRAMMAZIONE (CFU 9)
72820 - SISTEMI OPERATIVI (CFU 12)
72821 - BASI DI DATI (CFU 6)
''';

      final results = LocalExamParser.parseText(uniboText);

      expect(results.length, 3);
      expect(results[0].title, 'Programmazione');
      expect(results[0].cfu, 9);
      expect(results[1].title, 'Sistemi Operativi');
      expect(results[1].cfu, 12);
    });

    test('Parse PoliTo (Politecnico di Torino) & UniPd format', () {
      const politoText = '''
01QZWPM - FISICA I (8.00 crediti)
IN01112233 INFORMATICA GENERALE 6.00 CFU
''';

      final results = LocalExamParser.parseText(politoText);

      expect(results.length, 2);
      expect(results[0].title, 'Fisica I');
      expect(results[0].cfu, 8);
      expect(results[1].title, 'Informatica Generale');
      expect(results[1].cfu, 6);
    });

    test('Parse UniNa & UniGe format', () {
      const uninaText = '''
12345 - ECONOMIA AZIENDALE [9 CFU]
SISTEMI OPERATIVI - 9 CFU - SSD ING-INF/05
''';

      final results = LocalExamParser.parseText(uninaText);

      expect(results.length, 2);
      expect(results[0].title, 'Economia Aziendale');
      expect(results[0].cfu, 9);
      expect(results[1].title, 'Sistemi Operativi');
      expect(results[1].cfu, 9);
    });
  });
}
