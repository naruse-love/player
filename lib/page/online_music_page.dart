import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/online_music_service.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/component/scroll_aware_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:coriander_player/utils.dart';

class OnlineMusicPage extends StatefulWidget {
  const OnlineMusicPage({super.key});

  @override
  State<OnlineMusicPage> createState() => _OnlineMusicPageState();
}

class _OnlineMusicPageState extends State<OnlineMusicPage> {
  List<OnlineCategory> categories = [];
  List<Audio> tracks = [];
  String selectedCategory = '全部';
  int currentPage = 1;
  int totalPages = 1;
  bool isLoading = false;
  bool isSearching = false;
  final searchController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    OnlineMusicService.instance.addListener(_onServiceUpdate);
    OnlineMusicService.instance.init();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    OnlineMusicService.instance.removeListener(_onServiceUpdate);
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted && OnlineMusicService.instance.isReady) {
      _loadCategories();
      _loadTracks(page: currentPage, force: true);
    }
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      if (!isLoading && currentPage < totalPages && !isSearching) {
        _loadTracks(page: currentPage + 1);
      }
    }
  }

  void _loadCategories() {
    final fetched = OnlineMusicService.instance.getCategories();
    if (mounted) {
      setState(() {
        categories = fetched;
      });
    }
  }

  void _loadTracks({int page = 1, bool force = false}) {
    if (!OnlineMusicService.instance.isReady) return;
    if (isLoading && !force) return;
    setState(() {
      isLoading = true;
    });

    final result = OnlineMusicService.instance.getCategoryTracks(selectedCategory, page);

    if (mounted) {
      setState(() {
        if (page == 1) {
          tracks = result.tracks;
        } else {
          // If not force, and we are appending, we need to make sure we don't append duplicates if data changed
          // For simplicity, just append if it's a real pagination
          if (force && page > 1) {
             // In force mode, it's a background update. We probably should just reload page 1 to be safe.
             tracks = result.tracks;
             page = 1;
          } else {
             tracks.addAll(result.tracks);
          }
        }
        currentPage = result.page;
        totalPages = result.pages;
        isLoading = false;
        isSearching = false;
      });
    }
  }

  void _search() {
    if (!OnlineMusicService.instance.isReady) return;
    
    final query = searchController.text.trim();
    if (query.isEmpty) {
      _loadTracks();
      return;
    }

    setState(() {
      isLoading = true;
      isSearching = true;
      selectedCategory = ''; // unselect category
    });

    final result = OnlineMusicService.instance.search(query);

    if (mounted) {
      setState(() {
        tracks = result;
        currentPage = 1;
        totalPages = 1;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text("在线音乐"),
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: 250,
              height: 40,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "搜索歌曲...",
                  prefixIcon: const Icon(Symbols.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          if (categories.isNotEmpty && !isSearching)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildCategoryChip("全部", selectedCategory == "全部"),
                  const SizedBox(width: 8),
                  ...categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildCategoryChip(c.name, selectedCategory == c.name),
                      )),
                ],
              ),
            ),
          Expanded(
            child: tracks.isEmpty && isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 80.0),
                    itemCount: tracks.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == tracks.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _RemoteAudioTile(
                        audioIndex: index,
                        playlist: tracks,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String name, bool selected) {
    return FilterChip(
      label: Text(name),
      selected: selected,
      onSelected: (_) {
        setState(() {
          selectedCategory = name;
          searchController.clear();
          isSearching = false;
        });
        _loadTracks(page: 1);
      },
    );
  }
}

class _RemoteAudioTile extends StatelessWidget {
  const _RemoteAudioTile({
    required this.audioIndex,
    required this.playlist,
  });

  final int audioIndex;
  final List<Audio> playlist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final audio = playlist[audioIndex];
    final placeholder = Icon(
      Symbols.music_note,
      size: 48.0,
      color: scheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: () {
        PlayService.instance.playbackService.play(audioIndex, playlist);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            ScrollAwareFutureBuilder(
              future: () => audio.cover,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
                  return placeholder;
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image(
                    image: snapshot.data!,
                    width: 48.0,
                    height: 48.0,
                    errorBuilder: (_, __, ___) => placeholder,
                  ),
                );
              },
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title,
                    style: TextStyle(color: scheme.onSurface, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "${audio.artist} - ${audio.album}",
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
