import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/src/rust/api/tag_writer.dart';

String lyricToLrcString(Lyric lyric) {
  final buffer = StringBuffer();
  for (final line in lyric.lines) {
    if (line is UnsyncLyricLine || line is SyncLyricLine) {
      final minutes = line.start.inMinutes;
      final seconds = (line.start.inSeconds % 60);
      final millis = (line.start.inMilliseconds % 1000) ~/ 10;
      final timeStr =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
      buffer.writeln('[$timeStr]${line.content}');
    }
  }
  return buffer.toString();
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
    final lrcString = lyricToLrcString(lyric);
    await file.writeAsString(lrcString, encoding: utf8);
    return true;
  } catch (_) {
    return false;
  }
}

/// 将 Lyric 写入音频文件的标签中
Future<bool> saveLyricToTag(String audioPath, Lyric lyric) async {
  try {
    final lrcString = lyricToLrcString(lyric);
    await setLyricToPath(path: audioPath, lyric: lrcString);
    return true;
  } catch (_) {
    return false;
  }
}
