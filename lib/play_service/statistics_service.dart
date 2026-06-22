import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:flutter/foundation.dart';

/// 单次播放记录
class PlayRecord {
  final String path;
  final DateTime playedAt;

  /// 本次实际听了多少秒
  final int listenedSeconds;

  PlayRecord({
    required this.path,
    required this.playedAt,
    this.listenedSeconds = 0,
  });

  Map<String, dynamic> toMap() => {
        "path": path,
        "played_at": playedAt.millisecondsSinceEpoch ~/ 1000,
        "listened_secs": listenedSeconds,
      };

  factory PlayRecord.fromMap(Map map) => PlayRecord(
        path: map["path"],
        playedAt:
            DateTime.fromMillisecondsSinceEpoch((map["played_at"] as int) * 1000),
        listenedSeconds: map["listened_secs"] ?? 0,
      );
}

/// 每首歌曲的统计汇总
class AudioStatistics {
  int playCount;

  /// secs since UNIX EPOCH, 上次播放时间
  int? lastPlayed;

  /// 累计听歌时长（秒）
  int totalListeningTime;

  /// 所有播放记录（含时间戳），按时间升序
  List<PlayRecord> playHistory;

  AudioStatistics({
    this.playCount = 0,
    this.lastPlayed,
    this.totalListeningTime = 0,
    List<PlayRecord>? playHistory,
  }) : playHistory = playHistory ?? [];

  Map<String, dynamic> toMap() => {
        "play_count": playCount,
        "last_played": lastPlayed,
        "total_listening_time": totalListeningTime,
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
      totalListeningTime: map["total_listening_time"] ?? 0,
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

  /// 所有播放记录（按时间降序）
  List<PlayRecord> get allRecords {
    final list = <PlayRecord>[];
    for (var stat in _stats.values) {
      list.addAll(stat.playHistory);
    }
    list.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return list;
  }

  /// 按播放次数降序
  List<MapEntry<String, AudioStatistics>> get sortedByPlayCount =>
      _stats.entries.toList()
        ..sort((a, b) => b.value.playCount.compareTo(a.value.playCount));

  /// 按累计听歌时长降序
  List<MapEntry<String, AudioStatistics>> get sortedByListeningTime =>
      _stats.entries.toList()
        ..sort(
            (a, b) => b.value.totalListeningTime.compareTo(a.value.totalListeningTime));

  /// 按最后播放时间降序
  List<MapEntry<String, AudioStatistics>> get sortedByLastPlayed =>
      _stats.entries.toList()
        ..sort((a, b) {
          if (a.value.lastPlayed == null && b.value.lastPlayed == null) return 0;
          if (a.value.lastPlayed == null) return 1;
          if (b.value.lastPlayed == null) return -1;
          return b.value.lastPlayed!.compareTo(a.value.lastPlayed!);
        });

  AudioStatistics? operator [](String path) => _stats[path];
  int getPlayCount(String path) => _stats[path]?.playCount ?? 0;
  int getListeningTime(String path) => _stats[path]?.totalListeningTime ?? 0;

  /// 增加播放次数并记录
  void incrementPlayCount(String path, {int listenedSeconds = 0}) {
    final now = DateTime.now();
    final stat = _stats.putIfAbsent(path, () => AudioStatistics());

    stat.playCount++;
    if (listenedSeconds > 0) {
      stat.totalListeningTime += listenedSeconds;
      stat.lastPlayed = now.millisecondsSinceEpoch ~/ 1000;
      stat.playHistory.add(PlayRecord(
        path: path,
        playedAt: now,
        listenedSeconds: listenedSeconds,
      ));
    }

    if (stat.playHistory.length > 200) {
      stat.playHistory =
          stat.playHistory.sublist(stat.playHistory.length - 200);
    }

    notifyListeners();
    _save();
  }

  /// 记录一次未达半程的部分收听（只增时长，不增播放次数）
  void recordPartialListen(String path, {int listenedSeconds = 0}) {
    if (listenedSeconds <= 0) return;
    final now = DateTime.now();
    final stat = _stats.putIfAbsent(path, () => AudioStatistics());

    stat.totalListeningTime += listenedSeconds;
    stat.lastPlayed = now.millisecondsSinceEpoch ~/ 1000;
    stat.playHistory.add(PlayRecord(
      path: path,
      playedAt: now,
      listenedSeconds: listenedSeconds,
    ));

    if (stat.playHistory.length > 200) {
      stat.playHistory =
          stat.playHistory.sublist(stat.playHistory.length - 200);
    }

    notifyListeners();
    _save();
  }

  // ─── 日期范围查询 ───────────────────────────────────────

  List<PlayRecord> queryByDateRange(DateTime start, DateTime end) {
    return allRecords.where((r) {
      return r.playedAt.isAfter(start) && !r.playedAt.isAfter(end);
    }).toList();
  }

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
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <String, List<PlayRecord>>{};
    for (var key in sortedKeys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  /// 获取指定日期范围内的播放次数统计
  Map<String, int> getCountByDateRange(DateTime start, DateTime end) {
    final map = <String, int>{};
    for (var record in queryByDateRange(start, end)) {
      map[record.path] = (map[record.path] ?? 0) + 1;
    }
    return map;
  }

  /// 获取指定日期范围内的听歌时长统计（秒）
  Map<String, int> getListeningTimeByDateRange(DateTime start, DateTime end) {
    final map = <String, int>{};
    for (var record in queryByDateRange(start, end)) {
      map[record.path] = (map[record.path] ?? 0) + record.listenedSeconds;
    }
    return map;
  }

  /// 获取指定日期范围内的总听歌时长（秒）
  int getTotalListeningTime(DateTime start, DateTime end) {
    var total = 0;
    for (var record in queryByDateRange(start, end)) {
      total += record.listenedSeconds;
    }
    return total;
  }

  static String _dateKey(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  static String formatDateKey(DateTime dt) => _dateKey(dt);

  static DateTime? parseDateKey(String key) {
    try {
      final parts = key.split("-");
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  // ─── 持久化 ───────────────────────────────────────────

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

  void _save() => _saveAsync();

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

  static Audio? findAudioByPath(String path) {
    for (var audio in AudioLibrary.instance.audioCollection) {
      if (audio.path == path) return audio;
    }
    return null;
  }

  /// 格式化时长（秒 → "X 小时 Y 分钟" 或 "X 分钟" 或 "X 秒"）
  static String formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return "${totalSeconds} 秒";
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return "${minutes} 分钟";
    final hours = minutes ~/ 60;
    final remainMin = minutes % 60;
    if (remainMin == 0) return "${hours} 小时";
    return "${hours} 小时 ${remainMin} 分钟";
  }
}
