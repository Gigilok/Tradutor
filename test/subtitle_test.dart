import 'package:flutter_test/flutter_test.dart';
import 'package:ponte_app/models.dart';
import 'package:ponte_app/services/subtitles.dart';

void main() {
  test('Faz parse de um arquivo .srt simples', () {
    const srt = '''
1
00:00:01,000 --> 00:00:03,500
Hello there!

2
00:00:04,000 --> 00:00:06,000
How are you?
I hope you are fine.
''';
    final cues = SubtitleService.parse(srt);
    expect(cues.length, 2);
    expect(cues[0].start, const Duration(seconds: 1));
    expect(cues[0].end, const Duration(milliseconds: 3500));
    expect(cues[0].text, 'Hello there!');
    expect(cues[1].text, 'How are you?\nI hope you are fine.');
  });

  test('Faz parse de um arquivo .vtt (WEBVTT)', () {
    const vtt = '''
WEBVTT

00:00:05.000 --> 00:00:07.000
Hola, ¿cómo estás?
''';
    final cues = SubtitleService.parse(vtt);
    expect(cues.length, 1);
    expect(cues[0].text, 'Hola, ¿cómo estás?');
    expect(cues[0].start, const Duration(seconds: 5));
  });

  test('cueAt encontra a fala correta', () {
    final cues = [
      SubtitleCue(
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 3),
        text: 'Um',
      ),
      SubtitleCue(
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 8),
        text: 'Dois',
      ),
    ];
    expect(
      SubtitleService.cueAt(cues, const Duration(seconds: 2))!.text,
      'Um',
    );
    expect(
      SubtitleService.cueAt(cues, const Duration(seconds: 4)),
      isNull,
    );
    expect(
      SubtitleService.cueAt(cues, const Duration(seconds: 6))!.text,
      'Dois',
    );
  });

  test('Legenda vazia ou inválida gera lista vazia', () {
    expect(SubtitleService.parse(''), isEmpty);
    expect(SubtitleService.parse('isso não é uma legenda'), isEmpty);
  });
}
