import 'package:coriander_player/lyric/lyric.dart';

class Elrc extends Lyric {
  Elrc(super.lines, [super.source = LrcSource.web]);

  static Elrc fromLrcText(String lrcText, [LrcSource source = LrcSource.web]) {
    final timestampRegex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d+))?\]');
    final lines = lrcText.split('\n');

    int? offsetInMilliseconds;
    final offsetPattern = RegExp(r'\[\s*offset\s*:\s*([+-]?\d+)\s*\]');
    for (var line in lines) {
      final matched = offsetPattern.firstMatch(line);
      if (matched == null) continue;
      offsetInMilliseconds = int.tryParse(matched.group(1) ?? "");
      break;
    }
    final offset = Duration(milliseconds: offsetInMilliseconds ?? 0);

    final List<ElrcLine> syncedLines = [];
    final List<({Duration start, Duration length, String content})> unsyncedLines = [];

    Duration parseTimestampMatch(RegExpMatch match) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final msStr = match.group(3) ?? '0';
      final milliseconds = int.tryParse(msStr.padRight(3, '0').substring(0, 3)) ?? 0;
      
      var duration = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
      if (offset.inMilliseconds != 0) {
        duration -= offset;
        if (duration.isNegative) {
          duration = Duration.zero;
        }
      }
      return duration;
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip metadata tags
      if (trimmed.startsWith('[ti:') ||
          trimmed.startsWith('[ar:') ||
          trimmed.startsWith('[al:') ||
          trimmed.startsWith('[by:') ||
          trimmed.startsWith('[offset:') ||
          trimmed.startsWith('[tool:')) {
        continue;
      }

      final matches = timestampRegex.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      final List<Duration> durations = matches.map(parseTimestampMatch).toList();

      if (matches.length >= 3) {
        // Synced line (at least 3 timestamps: start, word boundaries, end)
        final List<ElrcWord> words = [];
        for (int i = 0; i < matches.length - 1; i++) {
          final wordStart = durations[i];
          var wordLength = durations[i + 1] - durations[i];
          if (wordLength.isNegative) {
            wordLength = Duration.zero;
          }
          final wordContent = trimmed.substring(matches[i].end, matches[i + 1].start);
          words.add(ElrcWord(wordStart, wordLength, wordContent));
        }

        final lineStart = durations.first;
        var lineLength = durations.last - durations.first;
        if (lineLength.isNegative) {
          lineLength = Duration.zero;
        }

        syncedLines.add(ElrcLine(lineStart, lineLength, words));
      } else {
        // Unsynced line (1 or 2 timestamps, e.g. translation or plain text)
        final lineStart = durations.first;
        var lineLength = durations.length > 1 ? (durations.last - durations.first) : Duration.zero;
        if (lineLength.isNegative) {
          lineLength = Duration.zero;
        }

        // Remove all timestamps from content
        final content = trimmed.replaceAll(timestampRegex, '').trim();
        unsyncedLines.add((start: lineStart, length: lineLength, content: content));
      }
    }

    // Associate translations and unmatched unsynced lines
    for (final unsynced in unsyncedLines) {
      bool matched = false;
      ElrcLine? closestLine;
      int minDiff = 100000000;
      for (final synced in syncedLines) {
        final diff = (synced.start.inMilliseconds - unsynced.start.inMilliseconds).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestLine = synced;
        }
      }

      if (closestLine != null && minDiff <= 1000) {
        closestLine.translation = unsynced.content;
        matched = true;
      }

      if (!matched && unsynced.content.isNotEmpty) {
        // Unmatched unsynced line becomes a synced line with a single word
        final word = ElrcWord(unsynced.start, unsynced.length, unsynced.content);
        syncedLines.add(ElrcLine(unsynced.start, unsynced.length, [word]));
      }
    }

    // Sort lines by start time
    syncedLines.sort((a, b) => a.start.compareTo(b.start));

    // Fill in lengths for lines that have zero length (e.g. from unmatched unsynced lines)
    for (int i = 0; i < syncedLines.length - 1; i++) {
      if (syncedLines[i].length == Duration.zero) {
        final newLength = syncedLines[i + 1].start - syncedLines[i].start;
        syncedLines[i].length = newLength;
        if (syncedLines[i].words.length == 1) {
          syncedLines[i].words[0].length = newLength;
        }
      }
    }

    return Elrc(syncedLines, source);
  }

  @override
  String toString() {
    return lines.toString();
  }
}

class ElrcLine extends SyncLyricLine {
  ElrcLine(super.start, super.length, super.words, [super.translation]);
}

class ElrcWord extends SyncLyricWord {
  ElrcWord(super.start, super.length, super.content);
}
