import 'dart:ui';
import 'package:audio_app/config/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../services/player_service.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends StatelessWidget {
  final PlayerService player;
  final bool enableNavigation;
  const MiniPlayer(
      {super.key, required this.player, this.enableNavigation = true});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: player.handler.mediaItem,
      builder: (context, snap) {
        final media = snap.data;
        if (media == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: player.playbackStateStream,
          builder: (context, stateSnap) {
            final playing = stateSnap.data?.playing ?? false;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: GestureDetector(
                    onTap: enableNavigation
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PlayerScreen(player: player)),
                            )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 8, 0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    color: AppColors.purpleMid,
                                    child: const Icon(Icons.music_note,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    media.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.skip_previous, size: 20),
                                  onPressed: player.previous,
                                  color: Colors.white,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                ),
                                IconButton(
                                  icon: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  onPressed: player.togglePlay,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next, size: 20),
                                  onPressed: player.next,
                                  color: Colors.white,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<Duration>(
                            stream: player.positionStream,
                            builder: (context, posSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final dur = player.duration ?? Duration.zero;
                              final progress = dur.inMilliseconds > 0
                                  ? (pos.inMilliseconds / dur.inMilliseconds)
                                      .clamp(0.0, 1.0)
                                  : 0.0;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbColor: Colors.white,
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor:
                                        Colors.white.withValues(alpha: 0.25),
                                    overlayColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12),
                                  ),
                                  child: SizedBox(
                                    height: 24,
                                    child: Slider(
                                      value: progress,
                                      onChanged: dur.inMilliseconds > 0
                                          ? (v) => player.seek(dur * v)
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
