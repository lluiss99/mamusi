import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import '../models/audio_item.dart';
import '../models/playlist.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../widgets/mini_player.dart';
import '../config/app_colors.dart';
import '../utils/song_search.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _service = LibraryService();
  final _player = PlayerService();
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _shuffle = false;
  List<AudioItem> _audios = [];
  bool _loading = true;

  static const _prefKey = 'playlist_shuffle_mode';

  @override
  void initState() {
    super.initState();
    _loadShufflePref();
    _loadAudios();
  }

  Future<void> _loadShufflePref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _shuffle = prefs.getBool(_prefKey) ?? false);
  }

  Future<void> _toggleShuffle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _shuffle = !_shuffle);
    await prefs.setBool(_prefKey, _shuffle);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAudios() async {
    setState(() => _loading = true);
    final audios = await _service.getAudiosForPlaylist(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _audios = audios;
      _loading = false;
    });
  }

  List<AudioItem> get _visualList {
    if (_search.isEmpty) return List.from(_audios);
    final matches =
        _audios.where((a) => matchesSearchQuery(a, _search)).toList();
    // Agrupa por artista al buscar.
    matches.sort((a, b) => (a.artist ?? '').compareTo(b.artist ?? ''));
    return matches;
  }

  List<AudioItem> _buildPlayQueue(List<AudioItem> visual,
      {int startIndex = 0}) {
    if (!_shuffle) return visual;
    // En modo aleatorio: el audio seleccionado va primero, el resto shuffleado
    final selected = visual[startIndex];
    final rest = List<AudioItem>.from(visual)..removeAt(startIndex);
    rest.shuffle();
    return [selected, ...rest];
  }

  Future<void> _removeFromPlaylist(AudioItem audio) async {
    await _service.removeAudioFromPlaylist(widget.playlist.id, audio.id);
    await _loadAudios();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _audios.removeAt(oldIndex);
      _audios.insert(newIndex, item);
    });
    await _service.reorderPlaylistAudios(
        widget.playlist.id, _audios.map((a) => a.id).toList());
  }

  Future<void> _showSongOptions(AudioItem audio) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Añadir a otra lista'),
              onTap: () {
                Navigator.pop(ctx);
                _addToAnotherPlaylist(audio);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Quitar de esta lista'),
              onTap: () {
                Navigator.pop(ctx);
                _removeFromPlaylist(audio);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToAnotherPlaylist(AudioItem audio) async {
    final playlists = await _service.getPlaylists().first;
    final others = playlists.where((p) => p.id != widget.playlist.id).toList();
    if (!mounted) return;

    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay otras listas creadas')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Añadir a lista',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ...others.map((p) => ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(p.name),
                  trailing: p.audioIds.contains(audio.id)
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (p.audioIds.contains(audio.id)) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ya está en "${p.name}"')),
                        );
                      }
                      return;
                    }
                    await _service.addAudioToPlaylist(p.id, audio.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Añadido a "${p.name}"')),
                      );
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _playAll() {
    final visual = _visualList;
    if (visual.isEmpty) return;
    final startIndex = _shuffle ? Random().nextInt(visual.length) : 0;
    final queue = _buildPlayQueue(visual, startIndex: startIndex);
    _player.playQueue(queue);
  }

  Widget _buildAudioTile(List<AudioItem> visual, int i) {
    final audio = visual[i];
    final artist = audio.artist;
    return StreamBuilder<MediaItem?>(
      key: ValueKey(audio.id),
      stream: _player.handler.mediaItem,
      builder: (context, mediaSnap) {
        final playingId = mediaSnap.data?.extras?['id'] as String?;
        final isPlaying = playingId == audio.id;
        return Container(
          color: isPlaying ? const Color(0xFF440073) : null,
          child: ListTile(
            leading: GestureDetector(
              onTap: () {
                final queue = _buildPlayQueue(visual, startIndex: i);
                _player.playQueue(queue, startIndex: _shuffle ? 0 : i);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Colors.white,
                      child: const Icon(Icons.music_note,
                          color: AppColors.purpleMid),
                    ),
                  ),
                  if (isPlaying)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.equalizer,
                        color: Color(0xFFD9A9FF),
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
              audio.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying ? const Color(0xFFD9A9FF) : null,
                fontWeight: isPlaying ? FontWeight.w700 : null,
              ),
            ),
            subtitle: artist != null
                ? Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying
                          ? const Color(0xFFD9A9FF).withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  )
                : null,
            onTap: () {
              final queue = _buildPlayQueue(visual, startIndex: i);
              _player.playQueue(queue, startIndex: _shuffle ? 0 : i);
            },
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () => _showSongOptions(audio),
              tooltip: 'Opciones',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visualList;

    return Scaffold(
      backgroundColor: AppColors.purpleMid,
      extendBody: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.playlist.name),
      ),
      body: Column(
        children: [
          // Barra superior con búsqueda y botones
          Container(
            color: AppColors.purpleMid,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    backgroundColor: const WidgetStatePropertyAll(Colors.black),
                    controller: _searchCtrl,
                    hintText: 'Buscar en la lista ...',
                    leading: const Icon(Icons.search, size: 20),
                    textStyle: const WidgetStatePropertyAll(
                        TextStyle(color: Colors.white)),
                    trailing: [
                      if (_search.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        ),
                    ],
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                //Botones play y orden
                Tooltip(
                  decoration: const BoxDecoration(color: Colors.black),
                  textStyle: const TextStyle(color: Colors.white),
                  message: _shuffle
                      ? 'Orden aleatorio activo'
                      : 'Orden predefinido activo',
                  child: _SquareIconButton(
                    icon: _shuffle ? Icons.casino : Icons.sort,
                    onPressed: _toggleShuffle,
                  ),
                ),
                const SizedBox(width: 12),
                _SquareIconButton(
                  icon: Icons.play_arrow,
                  onPressed: visual.isEmpty ? null : _playAll,
                ),
              ],
            ),
          ),

          // Lista de audios
          Expanded(
            child: ColoredBox(
              color: AppColors.purpleMid,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visual.isEmpty
                      ? SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.music_off,
                                  size: 64, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(
                                _audios.isEmpty
                                    ? 'Lista vacía'
                                    : 'Sin resultados',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      // LISTA DE AUDIOS
                      : _search.isEmpty
                          ? ReorderableListView.builder(
                              padding: const EdgeInsets.only(bottom: 110),
                              itemCount: visual.length,
                              onReorder: _onReorder,
                              itemBuilder: (context, i) =>
                                  _buildAudioTile(visual, i),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 110),
                              itemCount: visual.length,
                              itemBuilder: (context, i) =>
                                  _buildAudioTile(visual, i),
                            ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: MiniPlayer(player: _player, enableNavigation: false),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SquareIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.black : Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white38,
          size: 22,
        ),
      ),
    );
  }
}
