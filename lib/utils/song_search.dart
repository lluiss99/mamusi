import '../models/audio_item.dart';

/// Mini lenguaje de búsqueda sobre título y artista:
/// - `&&` combina términos en AND  (ej. "Travis && Rodeo")
/// - `||` combina términos en OR   (ej. "Travis || Tyler")
/// - `&&` tiene más prioridad que `||`, igual que en código.
bool matchesSearchQuery(AudioItem audio, String rawQuery) {
  final query = rawQuery.trim();
  if (query.isEmpty) return true;

  final haystack = _searchableText(audio);
  final orGroups = query.split('||');

  for (final group in orGroups) {
    final andTerms = group
        .split('&&')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    if (andTerms.isEmpty) continue;
    if (andTerms.every(haystack.contains)) return true;
  }
  return false;
}

String _searchableText(AudioItem audio) =>
    '${audio.name} ${audio.artist ?? ''}'.toLowerCase();
