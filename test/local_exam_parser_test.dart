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
Gruppo opzionale: Altre attività formative: tirocini e altre conoscenze utili per l'inserimento nel mondo del lavoro - Nel caso in cui lo studente intenda inserire nel proprio percorso formativo il corso "LE SCIENZE DELLA SOSTENIBILITA' IN FARMACIA E MEDICINA", si precisa che esso può essere inserito tra le attività formative "CFU a scelta dello studente" esclusivamente nel caso in cui vengano, altresì, inseriti, sempre tra i "CFU a scelta dello studente", anche il corso "LE SCIENZE DELLA SOSTENIBILITA' IN SAPIENZA" - 2 CFU e un ulteriore corso scelto tra quelli delle "LE SCIENZE DELLA SOSTENIBILITA' IN ....." 2 CFU offerti da altri CdS.	 	 	 
 1023908 | BIOCHIMICA E BIOTECNOLOGIE BIOCHIMICHE [BIO/10] [ITA]	2º	1º	12
 1036628 | CHIMICA ANALITICA ED ELEMENTI DI CHIMICA FISICA [CHIM/02, CHIM/01] [ITA]	2º	1º	6
 1038017 | ANATOMIA E FISIOLOGIA GENERALE [BIO/09, BIO/16] [ITA]	2º	1º	6
 1041708 | BIOLOGIA MOLECOLARE [BIO/11] [ITA]	2º	1º	12
 1038018 | FISIOLOGIA UMANA E FISIOLOGIA VEGETALE [BIO/04, BIO/09] [ITA]	2º	2º	6
1041679 | MICROBIOLOGIA INDUSTRIALE E TECNOLOGIE AMBIENTALI [CHIM/11] [ITA]	2º	2º	6
 1041756 | BIOINFORMATICA E FARMACOLOGIA [BIO/14, BIO/10] [ITA]	3º	1º	12
 1051487 | IMMUNOLOGIA [MED/04, MED/46] [ITA]	3º	1º	6
 1023914 | CHIMICA FARMACEUTICA E TECNOLOGIE FARMACEUTICHE [CHIM/08, CHIM/09] [ITA]	3º	1º	9
A SCELTA DELLO STUDENTE [N/D] [ITA]	3º	2º	12
AAF1044 | TIROCINIO [N/D] [ITA]	3º	2º	6
 1041682 | PATOLOGIA GENERALE CON MODELLI DI MALATTIA BIOETICA ED ASPETTI ECONOMICI E LEGISLATIVI [MED/02, MED/04] [ITA]	3º	2º	10
AAF1004 | PROVA FINALE [N/D] [ITA]	3º	2º	6
''';

      final results = LocalExamParser.parseText(sampleText);

      expect(results.isNotEmpty, true);
      expect(results.any((e) => e.title.contains('Lingua Inglese') && e.cfu == 4), true);
      expect(results.any((e) => e.title.contains('Chimica Generale e Inorganica') && e.cfu == 6), true);
      expect(results.any((e) => e.title.contains('Biologia Cellulare') && e.cfu == 9), true);
      expect(results.any((e) => e.title.contains('Microbiologia Generale') && e.cfu == 12), true);
    });

    test('Parse browser pasted text without tabs (spaces instead)', () {
      const spacePastedText = '''
AAF1102 | LINGUA INGLESE [N/D] [ITA] 1º 1º 4
100938 | CHIMICA GENERALE E INORGANICA [CHIM/03] [ITA] 1º 1º 6
1038524 | BIOLOGIA CELLULARE [BIO/13] [ITA] 1º 1º 9
''';

      final results = LocalExamParser.parseText(spacePastedText);

      expect(results.length, 3);
      expect(results[0].title, 'Lingua Inglese');
      expect(results[0].cfu, 4);
      expect(results[1].title, 'Chimica Generale e Inorganica');
      expect(results[1].cfu, 6);
      expect(results[2].title, 'Biologia Cellulare');
      expect(results[2].cfu, 9);
    });

    test('Parse multi-line cell-stacked pasted text', () {
      const multiLineText = '''
AAF1102 | LINGUA INGLESE [N/D] [ITA]
1º
1º
4
100938 | CHIMICA GENERALE E INORGANICA [CHIM/03] [ITA]
1º
1º
6
''';

      final results = LocalExamParser.parseText(multiLineText);

      expect(results.length, 2);
      expect(results[0].title, 'Lingua Inglese');
      expect(results[0].cfu, 4);
      expect(results[1].title, 'Chimica Generale e Inorganica');
      expect(results[1].cfu, 6);
    });
  });
}
