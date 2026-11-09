/// Un audio importado en la biblioteca local.
///
/// El fichero se copia dentro del directorio privado de la app al importarlo,
/// así que [filePath] siempre apunta a almacenamiento local del dispositivo.
class AudioItem {
  final String id;
  final String name;
  final String? artist;
  final String filePath;
  final DateTime createdAt;

  AudioItem({
    required this.id,
    required this.name,
    this.artist,
    required this.filePath,
    required this.createdAt,
  });

  factory AudioItem.fromRow(Map<String, Object?> row) {
    return AudioItem(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      artist: row['artist'] as String?,
      filePath: row['file_path'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int? ?? 0),
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'file_path': filePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
