import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/playlist.dart';
import '../services/library_service.dart';
import 'playlist_detail_screen.dart';
import '../config/app_colors.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final _service = LibraryService();
  late final Stream<List<Playlist>> _playlists = _service.getPlaylists();
  final _searchCtrl = TextEditingController();
  final _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva lista'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: Colors.white,
          decoration: const InputDecoration(
              hintText: 'Nombre de la lista',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              )),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child:
                  const Text('Crear', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _service.createPlaylist(name);
    }
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final ctrl = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar lista'),
        content: TextField(
          controller: ctrl,
          cursorColor: Colors.white,
          autofocus: true,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text(
                'Cancelar',
              )),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _service.renamePlaylist(playlist.id, name);
    }
  }

  Future<void> _pickPlaylistImage(Playlist playlist) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    try {
      await _service.updatePlaylistImage(playlist.id, File(path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar la foto')),
      );
    }
  }

  Future<void> _showPlaylistOptions(Playlist playlist) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(
                  playlist.imagePath == null ? 'Añadir foto' : 'Cambiar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPlaylistImage(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renombrar'),
              onTap: () {
                Navigator.pop(ctx);
                _renamePlaylist(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () {
                Navigator.pop(ctx);
                _deletePlaylist(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar "${playlist.name}"? Los audios no se borran.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Eliminar', style: TextStyle(color: Colors.red[400]))),
        ],
      ),
    );
    if (ok == true) await _service.deletePlaylist(playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Biblioteca'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createPlaylist,
            tooltip: 'Nueva lista',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(color: AppColors.purpleMid),
        child: StreamBuilder<List<Playlist>>(
          stream: _playlists,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data ?? [];
            final filtered = _search.isEmpty
                ? all
                : all
                    .where((p) => p.name.toLowerCase().contains(_search))
                    .toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.queue_music_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      all.isEmpty ? 'Sin listas todavía' : 'Sin resultados',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                bottom: 180,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final p = filtered[i];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: p.imagePath != null
                        ? Image.file(
                            File(p.imagePath!),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.white,
                            child: const Icon(Icons.queue_music,
                                color: AppColors.purpleMid),
                          ),
                  ),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.audioIds.length} ${p.audioIds.length != 1 ? 'Canciones' : 'Canción'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlist: p),
                    ),
                  ),
                  onLongPress: () => _showPlaylistOptions(p),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
