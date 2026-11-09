# Mamusi

Reproductor de audio para Android hecho con Flutter. Funciona sin conexión: los audios se importan desde el dispositivo, se guardan en el almacenamiento privado de la app y se organizan en listas de reproducción.

## Funcionalidades

- Importar varios audios a la vez desde el almacenamiento del móvil. Si el archivo se llama `Artista - Título`, el nombre y el artista se rellenan solos.
- Listas de reproducción: crear, renombrar, eliminar, reordenar arrastrando y poner foto.
- Reproducción en segundo plano con controles en la notificación y la pantalla de bloqueo.
- Modo aleatorio que se recuerda entre sesiones.
- Buscador con operadores: `&&` (y) y `||` (o), por ejemplo `Travis && Rodeo` o `Tyler || Kendrick`.
- Mini reproductor flotante y pantalla de reproducción completa.

## Stack

| Área | Paquetes |
|---|---|
| Audio | `just_audio`, `audio_service`, `audio_session` |
| Persistencia | `sqflite` (biblioteca y listas), `shared_preferences` (ajustes), `path_provider` |
| Importación | `file_picker` |

## Arquitectura

```
lib/
├── models/      AudioItem, Playlist
├── services/
│   ├── library_service.dart   SQLite + ficheros locales, expone streams reactivos
│   └── player_service.dart    cola de reproducción sobre audio_service
├── screens/     biblioteca, buscar, añadir, reproductor, detalle de lista
├── widgets/     mini reproductor
└── utils/       búsqueda con && / ||
```

`LibraryService` guarda los metadatos en tres tablas (`audios`, `playlists`, `playlist_audios` con la posición de cada canción) y emite de nuevo cada consulta cuando algo cambia. Así las pantallas se actualizan solas con `StreamBuilder`.

## Ejecutar

```bash
flutter pub get
flutter run
```

Al abrirla por primera vez la biblioteca está vacía: ve a **Añadir** e importa audios desde el móvil.
