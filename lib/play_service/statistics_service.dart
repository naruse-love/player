import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:flutter/foundation.dart';

/// 单次播放记录
class PlayRecord {
  final String path;
  final DateTime playedAt;

  PlayRecord({required this.path, required this.playedAt});

  Map<String, dynamic> toMap() => {
        "path": path,
        "played_at": playedAt.millisecondsSinceEpoch ~/ 1000,
      };

  factory PlayRecord.fromMap(Map map) => PlayRecord(
        path: map["path"],
        playedAt:
            DateTime.fromMillisecondsSinceEpoch((map["played_at"] as int) * 1000),
      );
}

/// 每首歌曲的统计汇总
class AudioStatistics {
  int playCount;

  /// secs since UNIX EPOCH, 上次播放时间
  int? lastPlayed;

  /// 所有播放记录（含时间戳），按时间升序
  List<PlayRecord> playHistory;

  AudioStatistics({
    this.playCount = 0,
    this.lastPlayed,
    List<PlayRecord>? playHistory,
  }) : playHistory = playHistory ?? [];

  Map<String, dynamic> toMap() => {
        "play_count": playCount,
        "last_played": lastPlayed,
        "play_history": playHistory.map((r) => r.toMap()).toList(),
      };

  factory AudioStatistics.fromMap(Map map) {
    final history = (map["play_history"] as List?)
            ?.map((e) => PlayRecord.fromMap(e))
            .toList() ??
        [];
    return AudioStatistics(
      playCount: map["play_count"] ?? 0,
      lastPlayed: map["last_played"],
      playHistory: history,
    );
  }
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

  /// 所有播放记录（按时间降序），方便按日期范围查询
  List<PlayRecord> get allRecords {
    final list = <PlayRecord>[];
    for (var stat in _stats.values) {
      list.addAll(stat.playHistory);
    }
    list.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return list;
  }

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
  AudioStatistics? operator [](String path) => _stats[path];

  /// 获取某首歌曲的播放次数
  int getPlayCount(String path) => _stats[path]?.playCount ?? 0;

  /// 增加播放次数并记录
  void incrementPlayCount(String path) {
    final now = DateTime.now();
    final stat = _stats.putIfAbsent(path, () => AudioStatistics());

    stat.playCount++;
    stat.lastPlayed = now.millisecondsSinceEpoch ~/ 1000;
    stat.playHistory.add(PlayRecord(path: path, playedAt: now));

    // 限制历史记录数，防止文件过大（保留最近 200 条）
    if (stat.playHistory.length > 200) {
      stat.playHistory = stat.playHistory
          .sublist(stat.playHistory.length - 200);
    }

    notifyListeners();
    _save();
  }

  // ─── 日期范围查询 ───────────────────────────────────────

  /// 获取指定日期范围内的所有播放记录（按时间降序）
  List<PlayRecord> queryByDateRange(DateTime start, DateTime end) {
    return allRecords.where((r) {
      return r.playedAt.isAfter(start) && r.playedAt.isBefore(end);
    }).toList();
  }

  /// 获取某一天的所有播放记录
  List<PlayRecord> queryByDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return queryByDateRange(dayStart, dayEnd);
  }

  /// 获取按天分组的播放记录（日期降序）
  Map<String, List<PlayRecord>> getGroupedByDay() {
    final map = <String, List<PlayRecord>>{};
    for (var record in allRecords) {
      final key = _dateKey(record.playedAt);
      map.putIfAbsent(key, () => []).add(record);
    }
    // 按日期降序排列
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <String, List<PlayRecord>>{};
    for (var key in sortedKeys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  /// 获取指定日期范围内的播放统计（歌曲路径 -> 播放次数）
  Map<String, int> getCountByDateRange(DateTime start, DateTime end) {
    final map = <String, int>{};
    for (var record in queryByDateRange(start, end)) {
      map[record.path] = (map[record.path] ?? 0) + 1;
    }
    return map;
  }

  /// 日期字符串 "yyyy-MM-dd"
  static String _dateKey(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  static String formatDateKey(DateTime dt) => _dateKey(dt);

  /// 解析日期字符串
  static DateTime? parseDateKey(String key) {
    try {
      final parts = key.split("-");
      return DateTime(int.parse(parts[0]), int.parse(parts[1]),
          int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  // ─── 持久化 ───────────────────────────────────────────

  /// 从 supportPath/statistics.json 加载
  Future<void> load() async {
    final supportPath = (await getAppDataDir()).path;
    final file = File("$supportPath\\statistics.json");
    if (!await file.exists()) return;

    try {
      final jsonStr = await file.readAsString();
      final Map data = json.decode(jsonStr);
      _stats.clear();
      for (var entry in data.entries) {
        _stats[entry.key] = AudioStatistics.fromMap(entry.value);
      }
    } catch (err) {
      // ignore corrupted file
    }
  }

  /// 保存到 supportPath/statistics.json
  void _save() {
    // 异步保存，不阻塞 UI
    _saveAsync();
  }

  Future<void> _saveAsync() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final file = File("$supportPath\\statistics.json");
      final Map<String, dynamic> data = {};
      for (var entry in _stats.entries) {
        data[entry.key] = entry.value.toMap();
      }
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  // ─── 工具 ─────────────────────────────────────────────

  /// 获取某首歌曲对应的 Audio（通过 AudioLibrary 查找）
  static Audio? findAudioByPath(String path) {
    for (var audio in AudioLibrary.instance.audioCollection) {
      if (audio.path == path) return audio;
    }
    return null;
  }
}
