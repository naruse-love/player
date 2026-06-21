import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/page/page_scaffold.dart';
import 'package:coriander_player/play_service/statistics_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
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

  @override
  Widget build(BuildContext context) {
    final stats = StatisticsService.instance;
    final topByCount = stats.sortedByPlayCount;
    final recentByLastPlayed = stats.sortedByLastPlayed;

    return PageScaffold(
      title: "统计",
      actions: [],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // 最多播放
          const _SectionHeader(title: "最多播放"),
          if (topByCount.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: Text(
                  "还没有播放记录",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...topByCount.take(50).map((entry) => _StatTile(
                  path: entry.key,
                  statistics: entry.value,
                  rank: topByCount.indexOf(entry) + 1,
                )),

          const SizedBox(height: 24),

          // 最近播放
          const _SectionHeader(title: "最近播放"),
          if (recentByLastPlayed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Center(
                child: Text(
                  "还没有播放记录",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...recentByLastPlayed.take(50).map((entry) => _StatTile(
                  path: entry.key,
                  statistics: entry.value,
                  showRank: false,
                )),
        ],
      ),
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

class _StatTile extends StatelessWidget {
  final String path;
  final AudioStatistics statistics;
  final int? rank;
  final bool showRank;

  const _StatTile({
    required this.path,
    required this.statistics,
    this.rank,
    this.showRank = true,
  });

  @override
  Widget build(BuildContext context) {
    final audio = StatisticsService.findAudioByPath(path);
    final scheme = Theme.of(context).colorScheme;

    final lastPlayedStr = statistics.lastPlayed != null
        ? _formatDate(statistics.lastPlayed!)
        : null;

    return ListTile(
      leading: showRank && rank != null
          ? SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rank! <= 3 ? scheme.primary : null,
                  ),
                ),
              ),
            )
          : null,
      title: Text(
        audio?.title ?? path.split("\\").last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (audio != null) audio.artist,
          "播放 ${statistics.playCount} 次",
          if (lastPlayedStr != null) "上次 $lastPlayedStr",
        ].join(" · "),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: audio != null
          ? () => context.push(
                "${app_paths.AUDIOS_PAGE}/detail",
                extra: audio,
              )
          : null,
    );
  }

  String _formatDate(int secs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "刚刚";
    if (diff.inHours < 1) return "${diff.inMinutes} 分钟前";
    if (diff.inDays < 1) return "${diff.inHours} 小时前";
    if (diff.inDays < 7) return "${diff.inDays} 天前";
    return "${dt.month}/${dt.day}";
  }
}
