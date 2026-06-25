import 'package:coriander_player/lyric/lyric.dart';

class Qrc extends Lyric {
  Qrc(super.lines, [super.source = LrcSource.web]);

  static Qrc fromQrcText(String qrc, [String? transRawStr, LrcSource source = LrcSource.web]) {
    final List<QrcLine> lines = [];
    final splited = qrc.split("\n");
    for (final item in splited) {
      final qrcLine = QrcLine.fromLine(item);

      if (qrcLine == null) continue;

      lines.add(qrcLine);
    }

    if (transRawStr != null) {
      Duration? parseTimeStr(String timeStr) {
        final parts = timeStr.split(":");
        if (parts.length < 2) return null;
        final minute = int.tryParse(parts[0]);
        final second = double.tryParse(parts[1]);
        if (minute == null || second == null) return null;
        return Duration(milliseconds: ((minute * 60 + second) * 1000).toInt());
      }

      final splitedTrans = transRawStr.split("\n");
      for (var transLine in splitedTrans) {
        final left = transLine.indexOf("[");
        final right = transLine.indexOf("]");
        if (left == -1 || right == -1 || left >= right) continue;

        final timeStr = transLine.substring(left + 1, right);
        final transTime = parseTimeStr(timeStr);
        if (transTime == null) continue;

        final t = transLine.replaceAll(RegExp(r"\[\d{2}:\d{2}(?:\.\d+)?\]"), "").trim();
        if (t.isEmpty) continue;

        QrcLine? closestLine;
        int minDiff = 100000000;
        for (final line in lines) {
          final diff = (line.start.inMilliseconds - transTime.inMilliseconds).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestLine = line;
          }
        }

        if (closestLine != null && minDiff <= 1000) {
          closestLine.translation = t;
        }
      }
    }

    // 添加空白
    final List<QrcLine> fommatedLines = [];
    final firstLine = lines.firstOrNull;
    if (firstLine != null && firstLine.start > const Duration(seconds: 5)) {
      fommatedLines.add(QrcLine(Duration.zero, firstLine.start, []));
    }
    for (int i = 0; i < lines.length - 1; ++i) {
      fommatedLines.add(lines[i]);
      final transitionStart = lines[i].start + lines[i].length;
      final transitionLength = lines[i + 1].start - transitionStart;
      if (transitionLength > const Duration(seconds: 5)) {
        fommatedLines.add(QrcLine(transitionStart, transitionLength, []));
      }
    }
    final lastLine = lines.lastOrNull;
    if (lastLine != null) {
      fommatedLines.add(lastLine);
    }

    return Qrc(fommatedLines, source);
  }

  @override
  String toString() {
    return (lines as List<SyncLyricLine>).toString();
  }
}

class QrcLine extends SyncLyricLine {
  QrcLine(super.start, super.length, super.words, [super.translation]);

  static QrcLine? fromLine(String line, [String? translation]) {
    final splitedLine = line.split("]");
    if (splitedLine.length < 2) return null;
    final from = splitedLine[0].indexOf("[") + 1;
    final splitedTime = splitedLine[0].substring(from).split(",");

    if (splitedTime.length != 2) return null;

    final Duration start = Duration(
      milliseconds: int.tryParse(splitedTime[0]) ?? 0,
    );
    final Duration length = Duration(
      milliseconds: int.tryParse(splitedTime[1]) ?? 0,
    );

    final splitedContent = splitedLine[1].split(")");
    final List<QrcWord> words = [];
    for (final item in splitedContent) {
      final qrcWord = QrcWord.fromWord(item);

      if (qrcWord == null) continue;

      words.add(qrcWord);
    }

    return QrcLine(start, length, words, translation);
  }
}

class QrcWord extends SyncLyricWord {
  QrcWord(super.start, super.length, super.content);

  static QrcWord? fromWord(String word) {
    final splitedWord = word.split("(");
    if (splitedWord.length != 2) return null;

    final splitedTime = splitedWord[1].split(",");

    if (splitedTime.length != 2) return null;

    final Duration start = Duration(
      milliseconds: int.tryParse(splitedTime[0]) ?? 0,
    );
    final Duration length = Duration(
      milliseconds: int.tryParse(splitedTime[1]) ?? 0,
    );

    return QrcWord(start, length, splitedWord[0]);
  }
}
