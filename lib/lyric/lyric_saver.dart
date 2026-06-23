import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/lyric/lyric.dart';

/// 将 Lyric 对象保存为 .lrc 文件
Future<bool> saveLyricToLrcFile(String audioPath, Lyric lyric) async {
  try {
    final lrcPath = audioPath.replaceFirst(RegExp(r'\.[^.]*$'), '.lrc');
    final file = File(lrcPath);
    final buffer = StringBuffer();

    for (final line in lyric.lines) {
      if (line is UnsyncLyricLine) {
        final minutes = line.start.inMinutes;
        final seconds = (line.start.inSeconds % 60);
        final millis = (line.start.inMilliseconds % 1000) ~/ 10;
        final timeStr =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
        buffer.writeln('[$timeStr]${line.content}');
      } else if (line is SyncLyricLine) {
        // 逐字歌词转成标准 LRC 行（取整句内容）
        final minutes = line.start.inMinutes;
        final seconds = (line.start.inSeconds % 60);
        final millis = (line.start.inMilliseconds % 1000) ~/ 10;
        final timeStr =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}';
        buffer.writeln('[$timeStr]${line.content}');
      }
    }

    await file.writeAsString(buffer.toString(), encoding: utf8);
    return true;
  } catch (_) {
    return false;
  }
}
