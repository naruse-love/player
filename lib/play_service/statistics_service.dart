import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:flutter/foundation.dart';

class AudioStatistics {
  int playCount;
  int? lastPlayed; // secs since UNIX EPOCH, null if never played

  AudioStatistics({this.playCount = 0, this.lastPlayed});

  Map<String, dynamic> toMap() => {
        "play_count": playCount,
        "last_played": lastPlayed,
      };

  factory AudioStatistics.fromMap(Map map) => AudioStatistics(
        playCount: map["play_count"] ?? 0,
        lastPlayed: map["last_played"],
      );
}

class StatisticsService extends ChangeNotifier {
  StatisticsService._();

  static StatisticsService? _instance;
  static StatisticsService get instance {
    _instance ??= StatisticsService._();
    return _instance!;
  }

  /// path -> AudioStatistics
  final Map<String, AudioStatistics> _stats = {};

  /// 按播放次数降序排列的统计列表
  List<MapEntry<String, AudioStatistics>> get sortedByPlayCount =>
      _stats.entries.toList()
        ..sort((a, b) => b.value.playCount.compareTo(a.value.playCount));

  /// 按最后播放时间降序排列的统计列表
  List<MapEntry<String, AudioStatistics>> get sortedByLastPlayed =>
      _stats.entries.toList()
        ..sort((a, b) {
          if (a.value.lastPlayed == null && b.value.lastPlayed == null) return 0;
          if (a.value.lastPlayed == null) return 1;
          if (b.value.lastPlayed == null) return -1;
          return b.value.lastPlayed!.compareTo(a.value.lastPlayed!);
        });

  /// 获取某首歌曲的统计
  AudioStatistics? getStat(String path) => _stats[path];

  /// 获取某首歌曲的播放次数
  int getPlayCount(String path) => _stats[path]?.playCount ?? 0;

  /// 增加播放次数并记录最后播放时间
  void incrementPlayCount(String path) {
    final stat = _stats.putIfAbsent(path, () => AudioStatistics());
    stat.playCount++;
    stat.lastPlayed = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    notifyListeners();
    _save();
  }

  /// 从 supportPath/statistics.json 加载
  Future<void> load() async {
    final supportPath = (await getAppDataDir()).path;
    final file = File("$supportPath\\statistics.json");
    if (!await file.exists()) return;

    try {
      final jsonStr = await file.readAsString();
      final Map data = json.decode(jsonStr);
      for (var entry in data.entries) {
        _stats[entry.key] = AudioStatistics.fromMap(entry.value);
      }
    } catch (err) {
      // ignore corrupted file
    }
  }

  /// 保存到 supportPath/statistics.json
  Future<void> _save() async {
    final supportPath = (await getAppDataDir()).path;
    final file = File("$supportPath\\statistics.json");
    final Map<String, dynamic> data = {};
    for (var entry in _stats.entries) {
      data[entry.key] = entry.value.toMap();
    }
    await file.writeAsString(json.encode(data));
  }

  /// 获取某首歌曲对应的 Audio（通过 AudioLibrary 查找）
  static Audio? findAudioByPath(String path) {
    for (var audio in AudioLibrary.instance.audioCollection) {
      if (audio.path == path) return audio;
    }
    return null;
  }
}
