import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import 'player_screen.dart';

import '../config/app_colors.dart';
import '../utils/song_search.dart';

class AllAudiosScreen extends StatefulWidget {
  const AllAudiosScreen({super.key});

  @override
  State<AllAudiosScreen> createState() => _AllAudiosScreenState();
}

class _AllAudiosScreenState extends State<AllAudiosScreen> {
  final _service = LibraryService();
  final _player = PlayerService();
  // Se crea una sola vez: si se pidiera en build(), cada tecla en el buscador
  // abriría un stream nuevo y mostraría el spinner de carga.
  late final Stream<List<AudioItem>> _audios = _service.getAudios();
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addToPlaylist(AudioItem audio) async {
    final playlists = await _service.getPlaylists().first;
    if (!mounted) return;

    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay listas creadas todavía')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Añadir a lista',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          ...playlists.map((p) => ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name),
                trailing: p.audioIds.contains(audio.id)
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (p.audioIds.contains(audio.id)) {
                    await _service.removeAudioFromPlaylist(p.id, audio.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Eliminado de "${p.name}"')),
                      );
                    }
                  } else {
                    await _service.addAudioToPlaylist(p.id, audio.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Añadido a "${p.name}"')),
                      );
                    }
                  }
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _deleteAudio(AudioItem audio) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar audio'),
        content:
            Text('¿Eliminar "${audio.name}"? Se borrará de todas las listas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Eliminar', style: TextStyle(color: Colors.red[400]))),
        ],
      ),
    );
    if (ok == true) await _service.deleteAudio(audio.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audios'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.purpleMid,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SearchBar(
              backgroundColor: const WidgetStatePropertyAll(Colors.black),
              controller: _searchCtrl,
              hintText: 'Buscar audios...',
              textStyle:
                  const WidgetStatePropertyAll(TextStyle(color: Colors.white)),
              leading: const Icon(Icons.search, size: 20),
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
          Expanded(
            child: ColoredBox(
              color: AppColors.purpleMid,
              child: StreamBuilder<List<AudioItem>>(
                stream: _audios,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? [];

                  final filtered = _search.isEmpty
                      ? all
                      : (all
                          .where((a) => matchesSearchQuery(a, _search))
                          .toList()
                        // Agrupa por artista al buscar.
                        ..sort((a, b) => (a.artist ?? '')
                            .compareTo(b.artist ?? '')));

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_off_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            all.isEmpty
                                ? 'Sin audios todavía'
                                : 'Sin resultados',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 180),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final audio = filtered[i];
                      final artist = audio.artist;
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.5),
                            child: Icon(Icons.music_note,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(audio.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: artist != null
                            ? Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        onTap: () {
                          _player.playQueue(filtered, startIndex: i);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(player: _player)),
                          );
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'playlist') _addToPlaylist(audio);
                            if (v == 'delete') _deleteAudio(audio);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'playlist',
                                child: Text('Añadir a lista')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
