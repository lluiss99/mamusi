/// Una lista de reproducción. El orden de [audioIds] es el orden de la lista.
class Playlist {
  final String id;
  final String name;
  final List<String> audioIds;
  final String? imagePath;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.audioIds,
    this.imagePath,
    required this.createdAt,
  });

  factory Playlist.fromRow(Map<String, Object?> row, List<String> audioIds) {
    return Playlist(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      audioIds: audioIds,
      imagePath: row['image_path'] as String?,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int? ?? 0),
    );
  }
}
