import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/library_service.dart';
import '../config/app_colors.dart';

class _PendingAudio {
  File audioFile;
  String name;
  String artist;
  bool saving;
  bool done;
  String? error;

  _PendingAudio({
    required this.audioFile,
    required this.name,
    this.artist = '',
    this.saving = false,
    this.done = false,
    this.error,
  });
}

class AddAudioScreen extends StatefulWidget {
  const AddAudioScreen({super.key});

  @override
  State<AddAudioScreen> createState() => _AddAudioScreenState();
}

class _AddAudioScreenState extends State<AddAudioScreen> {
  final _service = LibraryService();
  final List<_PendingAudio> _pending = [];
  bool _savingAll = false;

  Future<void> _pickAudios() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return;

    setState(() {
      for (final f in result.files) {
        if (f.path == null) continue;
        final base = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        // Si el fichero se llama "Artista - Título", rellena ambos campos.
        final sep = base.indexOf(' - ');
        _pending.add(_PendingAudio(
          audioFile: File(f.path!),
          name: sep == -1 ? base : base.substring(sep + 3).trim(),
          artist: sep == -1 ? '' : base.substring(0, sep).trim(),
        ));
      }
    });
  }

  void _removePending(int index) {
    setState(() => _pending.removeAt(index));
  }

  void _cancelAll() {
    setState(() => _pending.clear());
  }

  Future<void> _saveAll() async {
    if (_pending.isEmpty) return;
    final toUpload = _pending.where((p) => !p.done).toList();
    if (toUpload.isEmpty) return;

    setState(() => _savingAll = true);

    for (final audio in toUpload) {
      if (audio.name.trim().isEmpty) {
        setState(() => audio.error = 'Ponle un nombre');
        continue;
      }
      setState(() {
        audio.saving = true;
        audio.error = null;
      });
      try {
        await _service.importAudio(
          source: audio.audioFile,
          name: audio.name.trim(),
          artist: audio.artist,
        );
        setState(() {
          audio.saving = false;
          audio.done = true;
        });
      } catch (e) {
        setState(() {
          audio.saving = false;
          audio.error = 'Error al importar';
        });
      }
    }

    setState(() => _savingAll = false);

    // Remove completed ones after a moment
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _pending.removeWhere((p) => p.done));
      if (_pending.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Audios añadidos a la biblioteca')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir audio'),
        actions: [
          if (_pending.isNotEmpty)
            TextButton.icon(
              onPressed: _savingAll ? null : _cancelAll,
              icon: const Icon(Icons.close, color: Colors.white),
              label:
                  const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _pending.isEmpty
          ? Center(
              child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.purpleMid,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.audio_file_outlined,
                      size: 72, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('Selecciona uno o varios audios',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _pickAudios,
                    icon: const Icon(Icons.add),
                    label: const Text('Seleccionar archivos'),
                    style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black),
                  ),
                ],
              ),
            ))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pending.length,
                    itemBuilder: (context, i) {
                      final audio = _pending[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TextField(
                                          controller: TextEditingController(
                                              text: audio.name)
                                            ..selection =
                                                TextSelection.collapsed(
                                                    offset: audio.name.length),
                                          decoration: InputDecoration(
                                            labelText: 'Nombre',
                                            border: const OutlineInputBorder(),
                                            errorText: audio.error,
                                            isDense: true,
                                          ),
                                          enabled:
                                              !audio.saving && !audio.done,
                                          onChanged: (v) => audio.name = v,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: TextEditingController(
                                              text: audio.artist)
                                            ..selection =
                                                TextSelection.collapsed(
                                                    offset:
                                                        audio.artist.length),
                                          decoration: const InputDecoration(
                                            labelText: 'Artista (opcional)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          enabled:
                                              !audio.saving && !audio.done,
                                          onChanged: (v) => audio.artist = v,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (audio.done)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green)
                                  else if (audio.saving)
                                    const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => _removePending(i),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                              if (!audio.done && !audio.saving) ...[
                                const SizedBox(height: 6),
                                Text(
                                  audio.audioFile.path.split('/').last,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16,
                      16 + 60 + MediaQuery.of(context).padding.bottom),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _savingAll ? null : _pickAudios,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Añadir más',
                            style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _savingAll ? null : _saveAll,
                          icon: _savingAll
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_done, color: Colors.white),
                          label: Text(
                              _savingAll ? 'Guardando...' : 'Guardar todo',
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
