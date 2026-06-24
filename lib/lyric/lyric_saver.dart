import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/lyric/qrc.dart';
import 'package:coriander_player/lyric/krc.dart';
import 'package:coriander_player/src/rust/api/tag_writer.dart';

String lyricToLrcString(Lyric lyric) {
  final buffer = StringBuffer();
  for (final line in lyric.lines) {
    String? content;
    if (line is UnsyncLyricLine) {
      content = line.content;
    } else if (line is SyncLyricLine) {
      content = line.content;
    }
    if (content != null) {
      final minutes = line.start.inMinutes;
      final seconds = (line.start.inSeconds % 60);
      final millis = (line.start.inMilliseconds % 1000) ~/ 10;
      final timeStr =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
      buffer.writeln('[$timeStr]$content');
    }
  }
  return buffer.toString();
}

String serializeQrc(Qrc qrc) {
  final qrcBuffer = StringBuffer();
  final transBuffer = StringBuffer();
  bool hasTrans = false;

  for (final line in qrc.lines) {
    if (line is QrcLine) {
      qrcBuffer.write('[${line.start.inMilliseconds},${line.length.inMilliseconds}]');
      for (final word in line.words) {
        qrcBuffer.write('${word.content}(${word.start.inMilliseconds},${word.length.inMilliseconds})');
      }
      qrcBuffer.writeln();
      
      if (line.translation != null && line.translation!.isNotEmpty) {
        hasTrans = true;
        final minutes = line.start.inMinutes;
        final seconds = (line.start.inSeconds % 60);
        final millis = (line.start.inMilliseconds % 1000) ~/ 10;
        final timeStr =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
        transBuffer.writeln('[$timeStr]${line.translation}');
      }
    }
  }

  if (hasTrans) {
    return qrcBuffer.toString().trim() + "\n//trans//\n" + transBuffer.toString().trim();
  }
  return qrcBuffer.toString().trim();
}

String serializeKrc(Krc krc) {
  final krcBuffer = StringBuffer();
  final transBuffer = StringBuffer();
  bool hasTrans = false;

  for (final line in krc.lines) {
    if (line is KrcLine) {
      krcBuffer.write('[${line.start.inMilliseconds},${line.length.inMilliseconds}]');
      for (final word in line.words) {
        final relativeStart = word.start.inMilliseconds - line.start.inMilliseconds;
        krcBuffer.write('<$relativeStart,${word.length.inMilliseconds}>${word.content}');
      }
      krcBuffer.writeln();
      
      if (line.translation != null && line.translation!.isNotEmpty) {
        hasTrans = true;
        final minutes = line.start.inMinutes;
        final seconds = (line.start.inSeconds % 60);
        final millis = (line.start.inMilliseconds % 1000) ~/ 10;
        final timeStr =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
        transBuffer.writeln('[$timeStr]${line.translation}');
      }
    }
  }

  if (hasTrans) {
    return krcBuffer.toString().trim() + "\n//trans//\n" + transBuffer.toString().trim();
  }
  return krcBuffer.toString().trim();
}

String lyricToString(Lyric lyric) {
  if (lyric is Qrc) {
    return serializeQrc(lyric);
  } else if (lyric is Krc) {
    return serializeKrc(lyric);
  } else {
    return lyricToLrcString(lyric);
  }
}

/// 将 Lyric 对象保存为 .lrc 文件
Future<bool> saveLyricToLrcFile(String audioPath, Lyric lyric) async {
  try {
    final dotIndex = audioPath.lastIndexOf('.');
    final slashIndex = audioPath.lastIndexOf(Platform.pathSeparator);
    final lrcPath = (dotIndex > slashIndex)
        ? '${audioPath.substring(0, dotIndex)}.lrc'
        : '$audioPath.lrc';
    final file = File(lrcPath);
    final lyricString = lyricToString(lyric);
    await file.writeAsString(lyricString, encoding: utf8);
    return true;
  } catch (_) {
    return false;
  }
}

/// 将 Lyric 写入音频文件的标签中
Future<bool> saveLyricToTag(String audioPath, Lyric lyric) async {
  try {
    final lyricString = lyricToString(lyric);
    await setLyricToPath(path: audioPath, lyric: lyricString);
    return true;
  } catch (_) {
    return false;
  }
}
