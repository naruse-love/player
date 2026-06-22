import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/page/page_scaffold.dart';
import 'package:coriander_player/play_service/statistics_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 日期范围选项
enum DateRangePreset {
  today("今天"),
  thisWeek("本周"),
  thisMonth("本月"),
  lastMonth("上月"),
  allTime("全部"),
  custom("自定义");

  final String label;
  const DateRangePreset(this.label);
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateRangePreset _selectedPreset = DateRangePreset.thisMonth;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    StatisticsService.instance.addListener(_onStatsChanged);
  }

  @override
  void dispose() {
    StatisticsService.instance.removeListener(_onStatsChanged);
    super.dispose();
  }

  void _onStatsChanged() => setState(() {});

  DateTime get _rangeStart {
    final now = DateTime.now();
    switch (_selectedPreset) {
      case DateRangePreset.today:
        return DateTime(now.year, now.month, now.day);
      case DateRangePreset.thisWeek:
        return now.subtract(Duration(days: now.weekday - 1));
      case DateRangePreset.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DateRangePreset.lastMonth:
        final firstOfThis = DateTime(now.year, now.month, 1);
        return DateTime(firstOfThis.year, firstOfThis.month - 1, 1);
      case DateRangePreset.allTime:
        return DateTime(2000);
      case DateRangePreset.custom:
        return _customStart ?? DateTime(now.year, now.month, 1);
    }
  }

  DateTime get _rangeEnd {
    final now = DateTime.now();
    switch (_selectedPreset) {
      case DateRangePreset.today:
        return now.add(const Duration(days: 1));
      case DateRangePreset.lastMonth:
        final firstOfThis = DateTime(now.year, now.month, 1);
        return firstOfThis;
      case DateRangePreset.custom:
        return (_customEnd ?? now).add(const Duration(days: 1));
      default:
        return now.add(const Duration(days: 1));
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _customStart ?? DateTime(now.year, now.month, 1),
      end: _customEnd ?? now,
    );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale("zh"),
    );
    if (picked != null) {
      setState(() {
        _selectedPreset = DateRangePreset.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = StatisticsService.instance;
    final records = stats.queryByDateRange(_rangeStart, _rangeEnd);
    final grouped = stats.getGroupedByDay();
    final topSongs = stats.getCountByDateRange(_rangeStart, _rangeEnd);

    // 统计摘要
    final totalPlays = records.length;
    final uniqueSongs = topSongs.length;
    final top5 = topSongs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PageScaffold(
      title: "统计",
      actions: [
        _buildDateSelector(context),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // 日期选择器
          _buildDateChips(context),

          // 摘要卡片
          _buildSummaryCards(context, totalPlays, uniqueSongs),

          // 时间段内 Top 歌曲
          if (top5.isNotEmpty) ...[
            const _SectionHeader(title: "本时段热门"),
            ...top5.take(10).map((entry) => _StatTile(
                  path: entry.key,
                  playCount: entry.value,
                  rank: top5.indexOf(entry) + 1,
                )),
          ],

          const SizedBox(height: 16),

          // 每日详情
          const _SectionHeader(title: "每日播放详情"),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: Text("该时段没有播放记录",
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...grouped.entries.take(60).map((dayEntry) {
              // 只显示在选中范围内的天数
              final day = dayEntry.key;
              final dayRecords = dayEntry.value.where((r) {
                return r.playedAt.isAfter(_rangeStart) &&
                    r.playedAt.isBefore(_rangeEnd);
              }).toList();
              if (dayRecords.isEmpty) return const SizedBox.shrink();

              return _DayGroup(
                dateKey: day,
                records: dayRecords,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return PopupMenuButton<DateRangePreset>(
      icon: const Icon(Icons.date_range),
      tooltip: "选择时间范围",
      onSelected: (preset) {
        setState(() {
          _selectedPreset = preset;
          if (preset != DateRangePreset.custom) {
            _customStart = null;
            _customEnd = null;
          }
        });
      },
      itemBuilder: (_) => [
        ...DateRangePreset.values.where((p) => p != DateRangePreset.custom).map(
              (p) => PopupMenuItem(
                value: p,
                child: Row(
                  children: [
                    if (_selectedPreset == p)
                      Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(p.label),
                  ],
                ),
              ),
            ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: DateRangePreset.custom,
          child: Row(
            children: [
              Icon(Icons.edit_calendar, size: 18),
              SizedBox(width: 8),
              Text("自定义..."),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String dateLabel;
    if (_selectedPreset == DateRangePreset.custom) {
      dateLabel =
          "${_customStart!.month}/${_customStart!.day} - ${_customEnd!.month}/${_customEnd!.day}";
    } else {
      dateLabel = _selectedPreset.label;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text("自定义"),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
      BuildContext context, int totalPlays, int uniqueSongs) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.play_circle_outline,
              label: "播放次数",
              value: "$totalPlays",
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              icon: Icons.music_note_outlined,
              label: "听过歌曲",
              value: "$uniqueSongs",
              color: scheme.tertiary,
            ),
          ),
          if (_selectedPreset == DateRangePreset.allTime ||
              _selectedPreset == DateRangePreset.lastMonth ||
              _selectedPreset == DateRangePreset.custom) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.trending_up,
                label: "日均",
                value: _calcDailyAvg(totalPlays),
                color: scheme.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calcDailyAvg(int total) {
    final days = _rangeEnd.difference(_rangeStart).inDays;
    if (days <= 0) return "$total";
    final avg = total / days;
    return avg.toStringAsFixed(1);
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 每日播放分组
class _DayGroup extends StatelessWidget {
  final String dateKey;
  final List<PlayRecord> records;

  const _DayGroup({
    required this.dateKey,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dt = StatisticsService.parseDateKey(dateKey);
    final now = DateTime.now();
    final isToday = dt != null &&
        dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;

    // 统计当天每首歌的播放次数
    final songCounts = <String, int>{};
    for (var r in records) {
      songCounts[r.path] = (songCounts[r.path] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              Text(
                isToday ? "今天" : dateKey,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isToday ? scheme.primary : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${records.length} 次 · ${songCounts.length} 首",
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        // 每首歌在当天的播放记录
        ...songCounts.entries.map((entry) {
          // 获取该歌曲当天的具体播放时间列表
          final times = records
              .where((r) => r.path == entry.key)
              .map((r) =>
                  "${r.playedAt.hour.toString().padLeft(2, '0')}:${r.playedAt.minute.toString().padLeft(2, '0')}")
              .toList();

          return _DailySongTile(
            path: entry.key,
            count: entry.value,
            times: times,
          );
        }),
      ],
    );
  }
}

/// 每日歌曲条目
class _DailySongTile extends StatelessWidget {
  final String path;
  final int count;
  final List<String> times;

  const _DailySongTile({
    required this.path,
    required this.count,
    required this.times,
  });

  @override
  Widget build(BuildContext context) {
    final audio = StatisticsService.findAudioByPath(path);
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 28,
        child: Center(
          child: Text(
            "$count",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
              fontSize: 13,
            ),
          ),
        ),
      ),
      title: Text(
        audio?.title ?? path.split("\\").last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Row(
        children: [
          if (audio != null)
            Text(
              audio.artist,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          if (audio != null && times.isNotEmpty) const SizedBox(width: 8),
          Expanded(
            child: Text(
              times.join(" "),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: audio != null
          ? () => context.push(
                "${app_paths.AUDIOS_PAGE}/detail",
                extra: audio,
              )
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// 通用统计条目（带排名）
class _StatTile extends StatelessWidget {
  final String path;
  final int playCount;
  final int? rank;

  const _StatTile({
    required this.path,
    required this.playCount,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final audio = StatisticsService.findAudioByPath(path);
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: rank != null
          ? SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rank! <= 3 ? scheme.primary : null,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : null,
      title: Text(
        audio?.title ?? path.split("\\").last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        [
          if (audio != null) audio.artist,
          "${playCount} 次",
        ].join(" · "),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: Text(
        "$playCount",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.primary,
          fontSize: 16,
        ),
      ),
      onTap: audio != null
          ? () => context.push(
                "${app_paths.AUDIOS_PAGE}/detail",
                extra: audio,
              )
          : null,
    );
  }
}
