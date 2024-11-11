import 'dart:math';
// import 'dart:typed_data';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
// import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';

// model class for song metadata
class SongMetadata {
  final String id;
  final String title;
  final String artist;
  final int duration;
  final String bitrate;
  final String s3Key;
  final DateTime uploadedAt;

  SongMetadata({
    String? id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.bitrate,
    required this.s3Key,
    DateTime? uploadedAt,
  })  : this.id = id ?? const Uuid().v4(),
        this.uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'bitrate': bitrate,
      's3Key': s3Key,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

// Model class for song upload status
class SongUpload {
  final PlatformFile platformFile;
  final String name;
  final int size;
  final SongMetadata metadata;
  String uploadStatus;
  double progress;
  String? errorMessage;

  SongUpload({
    required this.platformFile,
    required this.name,
    required this.size,
    required this.metadata,
    this.uploadStatus = 'pending',
    this.progress = 0,
    this.errorMessage,
  });
}

class SongUploadManager extends StatefulWidget {
  const SongUploadManager({super.key});

  @override
  State<SongUploadManager> createState() => _SongUploadManagerState();
}

class _SongUploadManagerState extends State<SongUploadManager> {
  List<SongUpload> songs = [];
  bool uploading = false;
  int currentPage = 1;
  final int itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  // Configure Amplify
  Future<void> _configureAmplify() async {
    try {
      // Create Storage and API plugins instance
      final storagePlugin = AmplifyStorageS3();
      final apiPlugin = AmplifyAPI();

      // Add plugins to Amplify
      await Amplify.addPlugins([storagePlugin, apiPlugin]);

      // Configure Amplify
      // Note: You need to create an amplifyconfiguration.dart file with your AWS configuration
      // await Amplify.configure(amplifyconfig);
    } catch (e) {
      debugPrint('Error configuring Amplify: $e');
      _showErrorSnackBar('Error configuring AWS services');
    }
  }

  // Pick audio files
  Future<void> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        final newSongs = await Future.wait(
          result.files.map((file) async {
            final metadata = await _extractAudioMetadata(file);
            return SongUpload(
              platformFile: file,
              name: file.name,
              size: file.size,
              metadata: metadata,
            );
          }),
        );

        setState(() {
          songs.addAll(newSongs);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking files: $e');
    }
  }

  // Extract real audio metadata using just_audio
  Future<SongMetadata> _extractAudioMetadata(PlatformFile file) async {
    final player = AudioPlayer();

    try {
      final bytes = file.bytes!;
      // Create a temporary URL for the audio file
      final audioSource = AudioSource.uri(
        Uri.dataFromBytes(bytes, mimeType: 'audio/${file.extension}'),
      );

      await player.setAudioSource(audioSource);
      final duration = await player.duration;

      // Generate a unique S3 key for the file
      final s3Key = 'uploads/${const Uuid().v4()}/${file.name}';

      return SongMetadata(
        title: file.name,
        artist: 'Unknown Artist', // Could be extracted from ID3 tags
        duration: duration?.inSeconds ?? 0,
        bitrate: '320kbps', // Could be calculated from file size and duration
        s3Key: s3Key,
      );
    } catch (e) {
      debugPrint('Error extracting metadata: $e');
      rethrow;
    }
  }

  // Upload single song
  Future<void> uploadSong(SongUpload song) async {
    try {
      setState(() {
        song.uploadStatus = 'uploading';
        song.errorMessage = null;
      });

      // Upload to S3
      await _uploadToS3(song);

      // Store metadata in DynamoDB through AppSync
      await _storeMetadata(song.metadata);

      setState(() {
        song.uploadStatus = 'success';
      });
    } catch (e) {
      setState(() {
        song.uploadStatus = 'error';
        song.errorMessage = e.toString();
      });
      _showErrorSnackBar('Upload failed: $e');
    }
  }

  // Upload file to S3 using Amplify Storage
  Future<void> _uploadToS3(SongUpload song) async {}

  // Store metadata using AppSync/GraphQL API
  Future<void> _storeMetadata(SongMetadata metadata) async {
    try {
      const String mutationDocument = '''
        mutation CreateSong(\$input: CreateSongInput!) {
          createSong(input: \$input) {
            id
            title
            artist
            duration
            bitrate
            s3Key
            uploadedAt
          }
        }
      ''';

      final variables = {
        'input': metadata.toJson(),
      };

      final request = GraphQLRequest<String>(
        document: mutationDocument,
        variables: variables,
      );

      await Amplify.API.mutate(request: request).response;
    } catch (e) {
      debugPrint('API error: $e');
      rethrow;
    }
  }

  // Upload all pending songs
  Future<void> uploadAll() async {
    setState(() {
      uploading = true;
    });

    try {
      final pendingSongs =
          songs.where((song) => song.uploadStatus == 'pending');
      for (var song in pendingSongs) {
        await uploadSong(song);
      }
    } finally {
      setState(() {
        uploading = false;
      });
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Format file size
  String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  // Format duration
  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = min(startIndex + itemsPerPage, songs.length);
    final paginatedSongs = songs.sublist(startIndex, endIndex);
    final totalPages = (songs.length / itemsPerPage).ceil();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: pickFiles,
                  icon: const Icon(Icons.music_note),
                  label: const Text('Select Files'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: songs.isEmpty || uploading ? null : uploadAll,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Songs table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Artist')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: paginatedSongs.map((song) {
                      return DataRow(
                        cells: [
                          DataCell(Text(song.metadata.title)),
                          DataCell(Text(song.metadata.artist)),
                          DataCell(
                              Text(formatDuration(song.metadata.duration))),
                          DataCell(Text(formatFileSize(song.size))),
                          DataCell(_buildStatusCell(song)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Pagination
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: currentPage > 1
                        ? () => setState(() => currentPage--)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $currentPage of $totalPages'),
                  IconButton(
                    onPressed: currentPage < totalPages
                        ? () => setState(() => currentPage++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCell(SongUpload song) {
    switch (song.uploadStatus) {
      case 'pending':
        return const Text('Pending');
      case 'uploading':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('${song.progress.toInt()}%'),
          ],
        );
      case 'success':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'error':
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Text('Unknown');
    }
  }
}
