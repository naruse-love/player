import 'dart:convert';
import 'dart:io';

import 'package:coriander_player/library/audio_library.dart';

const String _baseUrl = 'https://naruse.tech';

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

  factory OnlineCategory.fromMap(Map map) => OnlineCategory(
        name: map['name'] ?? '',
        count: map['count'] ?? 0,
        pages: map['pages'] ?? 1,
      );
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

/// 在线音乐 API 客户端（静态方法）
class OnlineMusicService {
  OnlineMusicService._();

  /// 通用 GET 请求，返回响应体字符串
  static Future<String> _get(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  /// 获取所有分类
  static Future<List<OnlineCategory>> getCategories() async {
    try {
      final body = await _get('$_baseUrl/api/categories.json');
      final Map data = json.decode(body);
      final List list = data['categories'] ?? [];
      return list.map((e) => OnlineCategory.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取指定分类的曲目列表（分页）
  static Future<OnlineTrackPage> getCategoryTracks(
    String category,
    int page,
  ) async {
    try {
      final encodedCategory = Uri.encodeComponent(category);
      final body = await _get(
        '$_baseUrl/api/category_tracks.json?category=$encodedCategory&page=$page',
      );
      final Map data = json.decode(body);
      final List tracksJson = data['tracks'] ?? [];
      final tracks = tracksJson.map((e) => Audio.fromRemoteMap(e)).toList();
      return OnlineTrackPage(
        tracks: tracks,
        page: data['page'] ?? page,
        pages: data['pages'] ?? 1,
        total: data['total'] ?? tracks.length,
      );
    } catch (e) {
      return OnlineTrackPage(tracks: [], page: page, pages: 1, total: 0);
    }
  }

  /// 搜索曲目（最多 50 条）
  static Future<List<Audio>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final body = await _get('$_baseUrl/api/search.json?q=$encodedQuery');
      final List data = json.decode(body);
      return data.map((e) => Audio.fromRemoteMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 通过代理获取歌词内容
  static Future<String?> getLyricsContent(String lyricsUrl) async {
    try {
      final encodedUrl = Uri.encodeComponent(lyricsUrl);
      final body = await _get('$_baseUrl/proxy?url=$encodedUrl');
      return body;
    } catch (e) {
      return null;
    }
  }
}
