import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/library/audio_library.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

const String _baseUrl = 'https://api.naruse.tech';

/// 在线音乐分类
class OnlineCategory {
  final String name;
  final int count;
  final int pages;

  OnlineCategory({
    required this.name,
    required this.count,
    required this.pages,
  });
}

/// 分页的在线曲目列表
class OnlineTrackPage {
  final List<Audio> tracks;
  final int page;
  final int pages;
  final int total;

  OnlineTrackPage({
    required this.tracks,
    required this.page,
    required this.pages,
    required this.total,
  });
}

/// 在线音乐 API 客户端及数据存储（单例，基于 ChangeNotifier 更新 UI）
class OnlineMusicService extends ChangeNotifier {
  OnlineMusicService._();
  static final OnlineMusicService instance = OnlineMusicService._();

  List<Audio> _allTracks = [];
  List<Audio> get allTracks => _allTracks;

  bool isReady = false;

  /// 初始化：先读本地缓存秒开，再发起网络请求拉取全量最新列表比对
  Future<void> init() async {
    await _loadFromLocal();
    _fetchAndCompare(); // 后台拉取
  }

  Future<File> get _cacheFile async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'coriander_player'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'online_list.json'));
  }

  Future<void> _loadFromLocal() async {
    try {
      final file = await _cacheFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        _parseAndSetTracks(content);
      }
    } catch (e) {
      // ignore
    }
  }

  void _parseAndSetTracks(String jsonStr) {
    try {
      final List data = json.decode(jsonStr);
      _allTracks = data.map((e) => Audio.fromRemoteMap(e)).toList();
      isReady = true;
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchAndCompare() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/list.json'));
      // 加入 User-Agent，避免被 Cloudflare 拦截
      request.headers.set(HttpHeaders.userAgentHeader, 'CorianderPlayer/1.0');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception("Status code ${response.statusCode}");
      }
      final body = await response.transform(utf8.decoder).join();
      
      final file = await _cacheFile;
      String? localBody;
      if (await file.exists()) {
        localBody = await file.readAsString();
      }

      // 如果有变化或者本地没有文件，则写入并刷新
      if (body != localBody) {
        await file.writeAsString(body);
        _parseAndSetTracks(body);
      } else if (!isReady) {
        isReady = true;
        notifyListeners();
      }
    } catch (e) {
      // 网络错误时，如果还未 ready，则置为 ready (但列表为空)
      if (!isReady) {
        isReady = true;
        notifyListeners();
      }
    } finally {
      client.close();
    }
  }

  Future<String> _getProxy(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'CorianderPlayer/1.0');
      final response = await request.close();
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  /// 获取所有分类 (本地过滤)
  List<OnlineCategory> getCategories() {
    final Map<String, int> counts = {};
    for (var track in _allTracks) {
      final c = track.category ?? '未分类';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    
    final list = counts.entries.map((e) {
      final pages = (e.value / 20).ceil();
      return OnlineCategory(name: e.key, count: e.value, pages: pages);
    }).toList();
    
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  /// 获取指定分类的曲目列表（本地分页）
  OnlineTrackPage getCategoryTracks(String category, int page) {
    List<Audio> filtered;
    if (category == '全部' || category.isEmpty) {
      filtered = _allTracks;
    } else {
      filtered = _allTracks.where((t) => t.category == category).toList();
    }

    final total = filtered.length;
    final pages = (total / 20).ceil();
    final start = (page - 1) * 20;
    final end = start + 20;

    List<Audio> tracks = [];
    if (start < total) {
      tracks = filtered.sublist(start, end > total ? total : end);
    }

    return OnlineTrackPage(
      tracks: tracks,
      page: page,
      pages: pages > 0 ? pages : 1,
      total: total,
    );
  }

  /// 搜索曲目（本地匹配）
  List<Audio> search(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    
    final result = _allTracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
             t.artist.toLowerCase().contains(q) ||
             t.album.toLowerCase().contains(q);
    }).toList();

    return result.take(50).toList();
  }

  /// 静态辅助方法：通过代理获取歌词内容
  static Future<String?> getLyricsContent(String lyricsUrl) async {
    try {
      final encodedUrl = Uri.encodeComponent(lyricsUrl);
      return await instance._getProxy('$_baseUrl/proxy?url=$encodedUrl');
    } catch (e) {
      return null;
    }
  }
}
