import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_item.dart';
import '../models/playlist.dart';

/// Biblioteca 100 % local: los audios se copian al directorio privado de la
/// app y los metadatos (audios, listas y su orden) viven en SQLite.
///
/// Expone streams que se re-emiten cada vez que cambia algo, para que las
/// pantallas puedan usar `StreamBuilder` y refrescarse solas.
class LibraryService {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  final _uuid = const Uuid();
  final _changes = StreamController<void>.broadcast();

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db {
    if (_db != null) return Future.value(_db!);
    return _opening ??= _open().then((database) => _db = database);
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'mamusi.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE audios (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            artist TEXT,
            file_path TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            image_path TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_audios (
            playlist_id TEXT NOT NULL
              REFERENCES playlists(id) ON DELETE CASCADE,
            audio_id TEXT NOT NULL
              REFERENCES audios(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            PRIMARY KEY (playlist_id, audio_id)
          )
        ''');
      },
    );
  }

  void _notify() => _changes.add(null);

  /// Ejecuta [query] al suscribirse y de nuevo tras cada cambio.
  Stream<T> _watch<T>(Future<T> Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<void>? sub;

    Future<void> emit() async {
      try {
        final value = await query();
        if (!controller.isClosed) controller.add(value);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  Future<Directory> _subDir(String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  // ─── AUDIOS ───────────────────────────────────────────

  Stream<List<AudioItem>> getAudios() => _watch(_queryAudios);

  Future<List<AudioItem>> _queryAudios() async {
    final rows = await (await db).query('audios', orderBy: 'created_at DESC');
    return rows.map(AudioItem.fromRow).toList();
  }

  /// Copia [source] a la biblioteca de la app y lo registra.
  Future<AudioItem> importAudio({
    required File source,
    required String name,
    String? artist,
  }) async {
    final id = _uuid.v4();
    final ext = p.extension(source.path);
    final dir = await _subDir('audios');
    final dest = p.join(dir.path, '$id${ext.isEmpty ? '.audio' : ext}');
    await source.copy(dest);

    final trimmedArtist = artist?.trim();
    final item = AudioItem(
      id: id,
      name: name,
      artist:
          (trimmedArtist == null || trimmedArtist.isEmpty) ? null : trimmedArtist,
      filePath: dest,
      createdAt: DateTime.now(),
    );
    await (await db).insert('audios', item.toRow());
    _notify();
    return item;
  }

  /// Borra el audio, su fichero y su presencia en todas las listas.
  Future<void> deleteAudio(String id) async {
    final database = await db;
    final rows = await database.query('audios',
        columns: ['file_path'], where: 'id = ?', whereArgs: [id]);
    await database.delete('audios', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _deleteFileIfExists(rows.first['file_path'] as String?);
    }
    _notify();
  }

  // ─── PLAYLISTS ────────────────────────────────────────

  Stream<List<Playlist>> getPlaylists() => _watch(_queryPlaylists);

  Future<List<Playlist>> _queryPlaylists() async {
    final database = await db;
    final rows = await database.query('playlists', orderBy: 'created_at ASC');
    final links = await database.query('playlist_audios',
        orderBy: 'playlist_id, position ASC');

    final idsByPlaylist = <String, List<String>>{};
    for (final link in links) {
      idsByPlaylist
          .putIfAbsent(link['playlist_id'] as String, () => [])
          .add(link['audio_id'] as String);
    }
    return rows
        .map((r) => Playlist.fromRow(r, idsByPlaylist[r['id']] ?? []))
        .toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      audioIds: [],
      createdAt: DateTime.now(),
    );
    await (await db).insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'image_path': null,
      'created_at': playlist.createdAt.millisecondsSinceEpoch,
    });
    _notify();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await (await db).update('playlists', {'name': newName},
        where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<void> deletePlaylist(String id) async {
    final database = await db;
    final rows = await database.query('playlists',
        columns: ['image_path'], where: 'id = ?', whereArgs: [id]);
    await database.delete('playlists', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _deleteFileIfExists(rows.first['image_path'] as String?);
    }
    _notify();
  }

  /// Copia la imagen elegida como foto de la lista y devuelve su ruta local.
  Future<String> updatePlaylistImage(String id, File imageFile) async {
    final database = await db;
    final rows = await database.query('playlists',
        columns: ['image_path'], where: 'id = ?', whereArgs: [id]);
    final oldPath =
        rows.isNotEmpty ? rows.first['image_path'] as String? : null;

    final dir = await _subDir('playlist_images');
    final ext = p.extension(imageFile.path);
    // Nombre único en cada cambio: Image.file cachea por ruta y, si se
    // reutilizase el mismo nombre, seguiría mostrando la foto anterior.
    final dest = p.join(dir.path,
        '${id}_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}');
    await imageFile.copy(dest);

    await database.update('playlists', {'image_path': dest},
        where: 'id = ?', whereArgs: [id]);
    await _deleteFileIfExists(oldPath);
    _notify();
    return dest;
  }

  Future<void> addAudioToPlaylist(String playlistId, String audioId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next '
      'FROM playlist_audios WHERE playlist_id = ?',
      [playlistId],
    );
    final next = result.first['next'] as int? ?? 0;
    await database.insert(
      'playlist_audios',
      {'playlist_id': playlistId, 'audio_id': audioId, 'position': next},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify();
  }

  Future<void> removeAudioFromPlaylist(
      String playlistId, String audioId) async {
    await (await db).delete('playlist_audios',
        where: 'playlist_id = ? AND audio_id = ?',
        whereArgs: [playlistId, audioId]);
    _notify();
  }

  Future<void> reorderPlaylistAudios(
      String playlistId, List<String> audioIds) async {
    await (await db).transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < audioIds.length; i++) {
        batch.update('playlist_audios', {'position': i},
            where: 'playlist_id = ? AND audio_id = ?',
            whereArgs: [playlistId, audioIds[i]]);
      }
      await batch.commit(noResult: true);
    });
    _notify();
  }

  Future<List<AudioItem>> getAudiosForPlaylist(String playlistId) async {
    final rows = await (await db).rawQuery('''
      SELECT a.* FROM audios a
      JOIN playlist_audios pa ON pa.audio_id = a.id
      WHERE pa.playlist_id = ?
      ORDER BY pa.position ASC
    ''', [playlistId]);
    return rows.map(AudioItem.fromRow).toList();
  }
}
