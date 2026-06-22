import 'package:coriander_player/play_service/desktop_lyric_service.dart';
import 'package:coriander_player/play_service/lyric_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';

class PlayService {
  late final playbackService = PlaybackService(this);
  late final lyricService = LyricService(this);
  late final desktopLyricService = DesktopLyricService(this);

  PlayService._();

  static PlayService? _instance;
  static PlayService get instance {
    _instance ??= PlayService._();
    return _instance!;
  }

  void close() {
    desktopLyricService.killDesktopLyric();
    playbackService.close();
  }

  /// 启动时恢复上次的播放列表和进度
  Future<void> restorePlaylist() async {
    await playbackService.restorePlaylistState();
  }
}
