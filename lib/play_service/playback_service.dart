import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/play_service/statistics_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/src/rust/api/smtc_flutter.dart';
import 'package:coriander_player/theme_provider.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/lyric/lyric_saver.dart';

enum PlayMode {
  /// 顺序播放到播放列表结尾
  forward,

  /// 循环整个播放列表
  loop,

  /// 循环播放单曲
  singleLoop;

  static PlayMode? fromString(String playMode) {
    for (var value in PlayMode.values) {
      if (value.name == playMode) return value;
    }
    return null;
  }
}

/// 只通知 now playing 变更
class PlaybackService extends ChangeNotifier {
  final PlayService playService;

  late StreamSubscription _playerStateStreamSub;
  late StreamSubscription _smtcEventStreamSub;

  PlaybackService(this.playService) {
    _playerStateStreamSub = playerStateStream.listen((event) {
      if (event == PlayerState.completed) {
        _autoNextAudio();
      }
    });

    _smtcEventStreamSub = _smtc.subscribeToControlEvents().listen((event) {
      switch (event) {
        case SMTCControlEvent.play:
          start();
          break;
        case SMTCControlEvent.pause:
          pause();
          break;
        case SMTCControlEvent.previous:
          lastAudio();
          break;
        case SMTCControlEvent.next:
          nextAudio();
          break;
        case SMTCControlEvent.unknown:
      }
    });

    positionStream.listen((progress) {
      _smtc.updateTimeProperties(progress: (progress * 1000).floor());

      if (nowPlaying == null) return;

      // 连续跟踪实际收听时长（逐帧累加位置增量）
      if (progress > _maxTrackedPosition) {
        _listenedThisSession += progress - _maxTrackedPosition;
        _maxTrackedPosition = progress;
      }

      // 播放进度过半时标记：基于实际收听时长而非进度位置，
      // 避免用户拖动进度条跳过内容后被误判为"播放过半"
      if (_player.length > 0 &&
          _listenedThisSession >= _player.length / 2 &&
          !_hasIncrementedForCurrentSong) {
        _hasIncrementedForCurrentSong = true;
      }
    });
  }

  final _player = BassPlayer();
  final _smtc = SmtcFlutter();
  final _pref = AppPreference.instance.playbackPref;

  late final _wasapiExclusive = ValueNotifier(_player.wasapiExclusive);
  ValueNotifier<bool> get wasapiExclusive => _wasapiExclusive;

  /// 防止同一首歌重复增加播放次数
  bool _hasIncrementedForCurrentSong = false;

  /// 连续听歌时长跟踪
  /// 当前会话中到达的最大进度位置（秒）
  double _maxTrackedPosition = 0;
  /// 当前歌曲已积累的收听秒数（浮点精确）
  double _listenedThisSession = 0;

  /// 结束当前播放会话，将实际收听时长写入统计
  /// [incrementCount] 是否同时增加播放次数
  void _finalizePlaySession({bool incrementCount = false}) {
    if (nowPlaying == null || _listenedThisSession < 1) return;
    final secs = _listenedThisSession.round();
    if (incrementCount) {
      StatisticsService.instance
          .incrementPlayCount(nowPlaying!.path, listenedSeconds: secs);
    } else {
      // 未达半程但确实听了，单独记录收听时长
      StatisticsService.instance
          .recordPartialListen(nowPlaying!.path, listenedSeconds: secs);
    }
  }

  /// 独占模式
  void useExclusiveMode(bool exclusive) {
    if (_player.useExclusiveMode(exclusive)) {
      _wasapiExclusive.value = exclusive;
    }
  }

  Audio? nowPlaying;

  int? _playlistIndex;
  int get playlistIndex => _playlistIndex ?? 0;

  final ValueNotifier<List<Audio>> playlist = ValueNotifier([]);
  List<Audio> _playlistBackup = [];

  late final _playMode = ValueNotifier(_pref.playMode);
  ValueNotifier<PlayMode> get playMode => _playMode;

  void setPlayMode(PlayMode playMode) {
    this.playMode.value = playMode;
    _pref.playMode = playMode;
  }

  late final _shuffle = ValueNotifier(false);
  ValueNotifier<bool> get shuffle => _shuffle;

  double get length => _player.length;

  double get position => _player.position;

  PlayerState get playerState => _player.playerState;

  double get volumeDsp => _player.volumeDsp;

  /// 修改解码时的音量（不影响 Windows 系统音量）
  void setVolumeDsp(double volume) {
    _player.setVolumeDsp(volume);
    _pref.volumeDsp = volume;
  }

  Stream<double> get positionStream => _player.positionStream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// 1. 更新 [_playlistIndex] 为 [audioIndex]
  /// 2. 更新 [nowPlaying] 为 playlist[_nowPlayingIndex]
  /// 3. _bassPlayer.setSource
  /// 4. 设置解码音量
  /// 4. 获取歌词 **将 [_nextLyricLine] 置为0**
  /// 5. 播放
  /// 6. 通知并更新主题色
  void _loadAndPlay(int audioIndex, List<Audio> playlist) {
    try {
      // 切歌前先把之前的收听会话结束（传递是否过半标记）
      _finalizePlaySession(incrementCount: _hasIncrementedForCurrentSong);

      _playlistIndex = audioIndex;
      nowPlaying = playlist[audioIndex];
      _hasIncrementedForCurrentSong = false;
      _maxTrackedPosition = 0;
      _listenedThisSession = 0;
      _player.setSource(nowPlaying!.path);
      setVolumeDsp(AppPreference.instance.playbackPref.volumeDsp);

      playService.lyricService.updateLyric();

      _player.start();
      notifyListeners();
      ThemeProvider.instance.applyThemeFromAudio(nowPlaying!);

      _smtc.updateState(state: SMTCState.playing);
      _smtc.updateDisplay(
        title: nowPlaying!.title,
        artist: nowPlaying!.artist,
        album: nowPlaying!.album,
        duration: (length * 1000).floor(),
        path: nowPlaying!.path,
      );

      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;

        playService.desktopLyricService
            .sendPlayerStateMessage(playerState == PlayerState.playing);
        playService.desktopLyricService.sendNowPlayingMessage(nowPlaying!);
      });
    } catch (err) {
      LOGGER.e("[load and play] $err");
      showTextOnSnackBar(err.toString());
    }
  }

  /// 播放当前播放列表的第几项，只能用在播放列表界面
  void playIndexOfPlaylist(int audioIndex) {
    _loadAndPlay(audioIndex, playlist.value);
  }

  /// 播放playlist[audioIndex]并设置播放列表为playlist
  void play(int audioIndex, List<Audio> playlist) {
    if (shuffle.value) {
      this.playlist.value = List.from(playlist);
      final willPlay = this.playlist.value.removeAt(audioIndex);
      this.playlist.value.shuffle();
      this.playlist.value.insert(0, willPlay);
      _playlistBackup = List.from(playlist);
      _loadAndPlay(0, this.playlist.value);
    } else {
      _loadAndPlay(audioIndex, playlist);
      this.playlist.value = List.from(playlist);
      _playlistBackup = List.from(playlist);
    }
  }

  void shuffleAndPlay(List<Audio> audios) {
    playlist.value = List.from(audios);
    playlist.value.shuffle();
    _playlistBackup = List.from(audios);

    shuffle.value = true;

    _loadAndPlay(0, playlist.value);
  }

  /// 下一首播放
  void addToNext(Audio audio) {
    if (_playlistIndex != null) {
      playlist.value.insert(_playlistIndex! + 1, audio);
      _playlistBackup = List.from(playlist.value);
    }
  }

  void useShuffle(bool flag) {
    if (nowPlaying == null) return;
    if (flag == shuffle.value) return;

    if (flag) {
      playlist.value.shuffle();
      playlist.value.remove(nowPlaying!);
      playlist.value.insert(0, nowPlaying!);
      _playlistIndex = 0;
      shuffle.value = true;
    } else {
      playlist.value = List.from(_playlistBackup);
      _playlistIndex = playlist.value.indexOf(nowPlaying!);
      shuffle.value = false;
    }
  }

  void _nextAudio_forward() {
    if (_playlistIndex == null) return;

    if (_playlistIndex! < playlist.value.length - 1) {
      _loadAndPlay(_playlistIndex! + 1, playlist.value);
    } else {
      // 到达播放列表末尾，结算最后一首歌的收听数据
      _finalizePlaySession(incrementCount: _hasIncrementedForCurrentSong);
      _hasIncrementedForCurrentSong = false;
      _listenedThisSession = 0;
      _maxTrackedPosition = 0;
    }
  }

  void _nextAudio_loop() {
    if (_playlistIndex == null) return;

    int newIndex = _playlistIndex! + 1;
    if (newIndex >= playlist.value.length) {
      newIndex = 0;
    }

    _loadAndPlay(newIndex, playlist.value);
  }

  void _nextAudio_singleLoop() {
    if (_playlistIndex == null) return;

    _loadAndPlay(_playlistIndex!, playlist.value);
  }

  void _autoNextAudio() {
    switch (playMode.value) {
      case PlayMode.forward:
        _nextAudio_forward();
        break;
      case PlayMode.loop:
        _nextAudio_loop();
        break;
      case PlayMode.singleLoop:
        _nextAudio_singleLoop();
        break;
    }
  }

  /// 手动下一曲时默认循环播放列表
  void nextAudio() => _nextAudio_loop();

  /// 手动上一曲时默认循环播放列表
  void lastAudio() {
    if (_playlistIndex == null) return;

    int newIndex = _playlistIndex! - 1;
    if (newIndex < 0) {
      newIndex = playlist.value.length - 1;
    }

    _loadAndPlay(newIndex, playlist.value);
  }

  /// 暂停
  void pause() {
    try {
      _player.pause();
      _smtc.updateState(state: SMTCState.paused);
      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;

        playService.desktopLyricService.sendPlayerStateMessage(false);
      });
    } catch (err) {
      LOGGER.e("[pause] $err");
      showTextOnSnackBar(err.toString());
    }
  }

  /// 恢复播放
  void start() {
    try {
      _player.start();
      _smtc.updateState(state: SMTCState.playing);
      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;

        playService.desktopLyricService.sendPlayerStateMessage(true);
      });
    } catch (err) {
      LOGGER.e("[start]: $err");
      showTextOnSnackBar(err.toString());
    }
  }

  /// 再次播放。在顺序播放完最后一曲时再次按播放时使用。
  /// 与 [start] 的差别在于它会通知重绘组件
  void playAgain() => _nextAudio_singleLoop();

  void seek(double position) {
    // 向前拖动时，跳过的区间不应计入收听时长
    if (position > _maxTrackedPosition) {
      _maxTrackedPosition = position;
    }
    _player.seek(position);
    playService.lyricService.findCurrLyricLine();
  }

  void close() {
    _finalizePlaySession(incrementCount: _hasIncrementedForCurrentSong);
    _savePlaylistState();
    _playerStateStreamSub.cancel();
    _smtcEventStreamSub.cancel();
    _player.free();
    _smtc.close();
  }

  // ─── 播放列表持久化 ──────────────────────────────────

  /// 保存当前播放列表和正在播放的歌曲到文件
  void _savePlaylistState() {
    if (playlist.value.isEmpty) return;
    try {
      _savePlaylistStateAsync();
    } catch (_) {}
  }

  Future<void> _savePlaylistStateAsync() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final file = File("$supportPath\\playlist_state.json");
      final data = {
        "playlist": playlist.value.map((a) => a.path).toList(),
        "current_index": _playlistIndex ?? 0,
        "shuffle": _shuffle.value,
        "play_mode": _playMode.value.name,
        "current_position": _player.position,
      };
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  /// 从文件恢复播放列表和正在播放的歌曲
  /// 返回是否恢复成功（可继续播放）
  Future<bool> restorePlaylistState() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final file = File("$supportPath\\playlist_state.json");
      if (!await file.exists()) return false;

      final jsonStr = await file.readAsString();
      final Map data = json.decode(jsonStr);
      final paths = (data["playlist"] as List).cast<String>();
      final savedIndex = data["current_index"] as int? ?? 0;
      final savedShuffle = data["shuffle"] as bool? ?? false;
      final savedPlayMode = data["play_mode"] as String?;
      final savedPosition = data["current_position"] as num? ?? 0.0;

      if (paths.isEmpty) return false;

      // 将路径还原为 Audio 对象
      final restored = <Audio>[];
      for (var p in paths) {
        final audio = StatisticsService.findAudioByPath(p);
        if (audio != null) restored.add(audio);
      }
      if (restored.isEmpty) return false;

      playlist.value = List.from(restored);
      _playlistBackup = List.from(restored);
      _shuffle.value = savedShuffle;

      if (savedPlayMode != null) {
        final mode = PlayMode.fromString(savedPlayMode);
        if (mode != null) _playMode.value = mode;
      }

      // 恢复播放
      final index = savedIndex.clamp(0, restored.length - 1);
      _loadAndPlay(index, restored);
      // 恢复到上次的进度位置
      if (savedPosition > 0) {
        _player.seek(savedPosition.toDouble());
        _maxTrackedPosition = savedPosition.toDouble();
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 写入歌词到歌曲的标签中。如果歌曲当前正在播放，则需要临时释放文件锁。
  Future<bool> writeLyricToTag(Audio audio, Lyric lyric) async {
    final isPlaying = nowPlaying?.path == audio.path;
    final double? currentPosition = isPlaying ? _player.position : null;
    final bool? wasPlaying = isPlaying ? (_player.playerState == PlayerState.playing) : null;

    if (isPlaying) {
      _player.freeFStream();
    }

    final ok = await saveLyricToTag(audio.path, lyric);

    if (isPlaying) {
      _player.setSource(audio.path);
      setVolumeDsp(AppPreference.instance.playbackPref.volumeDsp);
      if (currentPosition != null) {
        _player.seek(currentPosition);
      }
      if (wasPlaying == true) {
        _player.start();
      }
    }

    return ok;
  }
}
