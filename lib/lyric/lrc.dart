import 'dart:math';

import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/lyric/qrc.dart';
import 'package:coriander_player/lyric/krc.dart';
import 'package:coriander_player/lyric/elrc.dart';
import 'package:coriander_player/src/rust/api/tag_reader.dart';


class LrcLine extends UnsyncLyricLine {
  bool isBlank;
  Duration length;

  LrcLine(super.start, super.content,
      {required this.isBlank, this.length = Duration.zero});

  static LrcLine defaultLine = LrcLine(
    Duration.zero,
    "无歌词",
    isBlank: false,
    length: Duration.zero,
  );

  @override
  String toString() {
    return {"time": start.toString(), "content": content}.toString();
  }

  /// line: [mm:ss.msmsms]content
  static LrcLine? fromLine(String line, [int? offset]) {
    if (line.trim().isEmpty) {
      return null;
    }

    final left = line.indexOf("[");
    final right = line.indexOf("]");

    if (left == -1 || right == -1 || left >= right) {
      return null;
    }

    var lrcTimeString = line.substring(left + 1, right);

    // replace [mm:ss.msms...] with ""
    var content = line
        .substring(right + 1)
        .trim()
        .replaceAll(RegExp(r"\[\d{2}:\d{2}(?:\.\d+)?\]"), "");

    var timeList = lrcTimeString.split(":");
    int? minute;
    double? second;
    if (timeList.length >= 2) {
      minute = int.tryParse(timeList[0]);
      second = double.tryParse(timeList[1]);
    }

    if (minute == null || second == null) {
      return null;
    }

    var inMilliseconds = ((minute * 60 + second) * 1000).toInt();

    return LrcLine(
      Duration(
        milliseconds: max(inMilliseconds - (offset ?? 0), 0),
      ),
      content,
      isBlank: content.isEmpty,
    );
  }
}

class Lrc extends Lyric {
  Lrc(super.lines, super.source);

  @override
  String toString() {
    return {"type": source, "lyric": lines}.toString();
  }

  /// 歌词一般是有序的
  /// 按照时间升序排序，保留原文和译文的顺序，需要使用稳定的排序算法
  /// 这里使用插入排序
  void _sort() {
    for (int i = 1; i < lines.length; i++) {
      var temp = lines[i];
      int j;
      for (j = i; j > 0 && lines[j - 1].start > temp.start; j--) {
        lines[j] = lines[j - 1];
      }
      lines[j] = temp;
    }
  }

  /// line_1 and line_2时间戳相同，合并成line_1[separator]line_2
  Lrc _combineLrcLine(String separator) {
    List<LrcLine> combinedLines = [];
    var buf = StringBuffer();
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].start != lines[i - 1].start) {
        buf.write((lines[i - 1] as UnsyncLyricLine).content);
        combinedLines.add(LrcLine(
          lines[i - 1].start,
          buf.toString(),
          isBlank: (lines[i - 1] as LrcLine).isBlank,
          length: (lines[i - 1] as LrcLine).length,
        ));
        buf.clear();
      } else {
        buf.write((lines[i - 1] as UnsyncLyricLine).content);
        buf.write(separator);
      }
    }
    if (lines.isNotEmpty) {
      buf.write((lines.last as UnsyncLyricLine).content);
      combinedLines.add(LrcLine(
        lines.last.start,
        buf.toString(),
        isBlank: (lines.last as LrcLine).isBlank,
        length: (lines.last as LrcLine).length,
      ));
    }

    return Lrc(combinedLines, source);
  }

  /// 如果separator为null，不合并歌词；否则，合并相同时间戳的歌词
  static Lrc? fromLrcText(String lrc, LrcSource source, {String? separator}) {
    var lrcLines = lrc.split("\n");

    int? offsetInMilliseconds;
    final offsetPattern = RegExp(r'\[\s*offset\s*:\s*([+-]?\d+)\s*\]');
    for (var line in lrcLines) {
      final matched = offsetPattern.firstMatch(line);
      if (matched == null) continue;
      offsetInMilliseconds = int.tryParse(matched.group(1) ?? "");
      break;
    }

    var lines = <LrcLine>[];
    for (int i = 0; i < lrcLines.length; i++) {
      var lyricLine = LrcLine.fromLine(lrcLines[i], offsetInMilliseconds);
      if (lyricLine == null) {
        continue;
      }
      lines.add(lyricLine);
    }

    if (lines.isEmpty) {
      return null;
    }

    for (var i = 0; i < lines.length - 1; i++) {
      lines[i].length = lines[i + 1].start - lines[i].start;
    }
    if (lines.isNotEmpty) {
      lines.last.length = Duration.zero;
    }

    final result = Lrc(lines, source);
    result._sort();

    if (separator == null) {
      return result;
    }

    return result._combineLrcLine(separator);
  }

  /// 只支持读取 ID3V2, VorbisComment, Mp4Ilst 存储的内嵌歌词
  /// 以及相同目录相同文件名的 .lrc 外挂歌词（utf-8 or utf-16）
  static Future<Lyric?> fromAudioPath(
    Audio belongTo, {
    String? separator = "┃",
  }) async {
    Lyric? lyric = await getLyricFromPath(path: belongTo.path).then((value) {
      if (value == null) {
        return null;
      }
      return parseLyricText(value, separator: separator);
    });

    return lyric;
  }
}

Lyric? parseLyricText(String text, {String? separator = "┃"}) {
  final lines = text.split("\n");

  bool isQrc = false;
  bool isKrc = false;
  bool isElrc = false;

  final timestampRegex = RegExp(r'\[\d{2}:\d{2}(?:\.\d+)?\]');

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // Qrc pattern check: starts with [digits,digits] and has word(digits,digits)
    if (trimmed.startsWith(RegExp(r'^\[\d+,\d+\]')) &&
        trimmed.contains(RegExp(r'\(\d+,\d+\)'))) {
      isQrc = true;
      break;
    }

    // Krc pattern check: starts with [digits,digits] and has <digits,digits>
    if (trimmed.startsWith(RegExp(r'^\[\d+,\d+\]')) &&
        trimmed.contains(RegExp(r'<\d+,\d+>'))) {
      isKrc = true;
      break;
    }

    // Elrc pattern check: skip metadata tags, look for >= 3 timestamps on a single line with content in between
    if (trimmed.startsWith('[ti:') ||
        trimmed.startsWith('[ar:') ||
        trimmed.startsWith('[al:') ||
        trimmed.startsWith('[by:') ||
        trimmed.startsWith('[offset:') ||
        trimmed.startsWith('[tool:')) {
      continue;
    }
    final matches = timestampRegex.allMatches(trimmed).toList();
    if (matches.length >= 3) {
      bool hasWordContent = false;
      for (int i = 0; i < matches.length - 1; i++) {
        final gap = trimmed.substring(matches[i].end, matches[i + 1].start).trim();
        if (gap.isNotEmpty) {
          hasWordContent = true;
          break;
        }
      }
      if (hasWordContent) {
        isElrc = true;
        break;
      }
    }
  }

  if (isQrc) {
    if (text.contains("//trans//")) {
      final parts = text.split("//trans//");
      return Qrc.fromQrcText(parts[0].trim(), parts[1].trim(), LrcSource.local);
    }
    return Qrc.fromQrcText(text, null, LrcSource.local);
  } else if (isKrc) {
    if (text.contains("//trans//")) {
      final parts = text.split("//trans//");
      return Krc.fromKrcText(parts[0].trim(), parts[1].trim(), LrcSource.local);
    }
    return Krc.fromKrcText(text, null, LrcSource.local);
  } else if (isElrc) {
    return Elrc.fromLrcText(text, LrcSource.local);
  } else {
    return Lrc.fromLrcText(text, LrcSource.local, separator: separator);
  }
}
