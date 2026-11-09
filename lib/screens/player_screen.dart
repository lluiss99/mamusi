import 'package:audio_app/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../services/player_service.dart';

class PlayerScreen extends StatelessWidget {
  final PlayerService player;
  const PlayerScreen({super.key, required this.player});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: player.handler.mediaItem,
      builder: (context, mediaSnap) {
        final media = mediaSnap.data;
        if (media == null) {
          return const Scaffold(
              body: Center(child: Text('No hay audio seleccionado')));
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Reproduciendo'), centerTitle: true),
          body: Container(
            color: AppColors.purpleMid,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.music_note,
                      size: 80, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Text(
                  media.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (media.artist != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    media.artist!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7)),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 32),

                // Progress
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = player.duration ?? Duration.zero;
                    final loading = dur.inMilliseconds == 0;
                    final progress = (!loading && dur.inMilliseconds > 0)
                        ? (pos.inMilliseconds / dur.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                          ),
                          child: Slider(
                            value: progress,
                            activeColor: Colors.white,
                            onChanged: (v) => player.seek(dur * v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(pos),
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text(_formatDuration(dur),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Controls
                StreamBuilder<PlaybackState>(
                  stream: player.playbackStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    final loading = snap.data?.processingState ==
                            AudioProcessingState.loading ||
                        snap.data?.processingState ==
                            AudioProcessingState.buffering;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          color: Colors.white,
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 40,
                          onPressed: player.previous,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: loading
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : IconButton(
                                  icon: Icon(
                                      playing ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32),
                                  onPressed: player.togglePlay,
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          iconSize: 40,
                          color: Colors.white,
                          onPressed: player.next,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
