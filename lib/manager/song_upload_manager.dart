// ignore_for_file: prefer_const_constructors

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fyp_musicapp_admin/models/ModelProvider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:fyp_musicapp_admin/pages/home_page.dart';
import 'package:just_audio/just_audio.dart';

// Add this at the top of the file with other constants
const List<String> musicGenres = [
  'Pop',
  'Rock',
  'Hip Hop',
  'R&B',
  'Jazz',
  'Classical',
  'Electronic',
  'Country',
  'Blues',
  'Folk',
  'Metal',
  'Reggae',
  'Other'
];

// model class for song metadata
class SongMetadata {
  final String id;
  final String s3Key;
  final DateTime uploadedAt;

  SongMetadata({
    String? id,
    required this.s3Key,
    DateTime? uploadedAt,
  })  : id = id ?? const Uuid().v4(),
        uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
  String? artist;
  String? album;
  String? genre;
  String? fileType;
  int? duration;
  TextEditingController artistController = TextEditingController();
  TextEditingController albumController = TextEditingController();
  TextEditingController durationController = TextEditingController();

  SongUpload({
    required this.platformFile,
    required this.name,
    required this.size,
    required this.metadata,
    this.uploadStatus = 'pending',
    this.progress = 0,
    this.errorMessage,
    this.artist,
    this.album,
    this.genre = 'Pop',
    this.duration = 0,
    this.fileType,
  }) {
    artistController.text = artist ?? '';
    albumController.text = album ?? '';
    durationController.text = duration?.toString() ?? '0';
  }
}

class SongUploadManager extends StatefulWidget {
  const SongUploadManager({super.key});

  @override
  State<SongUploadManager> createState() => _SongUploadManagerState();
}

class _SongUploadManagerState extends State<SongUploadManager> {
  List<SongUpload> songs = [];
  bool uploading = false;

  // Add these constants at the class level
  static const int chunkSize = 10 * 1024 * 1024; // 10MB chunks
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
  }

  // Modify pickFiles to check for configuration
  Future<void> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac'],
        allowMultiple: true,
        withData: false,
        withReadStream: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          // Add validation for file stream
          if (file.readStream == null) {
            _showErrorSnackBar('Cannot read file: ${file.name}');
            continue;
          }

          // Get file extension and validate
          final extension = file.name.split('.').last.toLowerCase();
          if (!['mp3', 'flac'].contains(extension)) {
            _showErrorSnackBar('Invalid file type: ${file.name}');
            continue;
          }

          // Create s3Key with extension-based folder structure
          final s3Key = 'public/songs/$extension/${file.name}';

          final songUpload = SongUpload(
            platformFile: file,
            name: file.name,
            size: file.size,
            metadata: SongMetadata(s3Key: s3Key),
            fileType: extension,
          );

          if (kIsWeb) {
            // For web, leave duration empty for manual input
            songUpload.durationController.text = '';
            debugPrint(
                'Web platform: Duration will need to be entered manually');
          } else {
            // For desktop/mobile, try to read duration
            try {
              final player = AudioPlayer();
              await player.setFilePath(file.path!);
              await player.load();
              final audioDuration = player.duration;
              final duration = audioDuration?.inSeconds ?? 0;
              songUpload.duration = duration;
              songUpload.durationController.text = formatDuration(duration);
              await player.dispose();
            } catch (e) {
              debugPrint('Error reading duration for ${file.name}: $e');
            }
          }

          setState(() {
            songs.add(songUpload);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking files: $e');
    }
  }

  // Update the validation method to exclude duration
  bool _validateSongFields(SongUpload song) {
    if (song.artistController.text.trim().isEmpty) {
      _showErrorSnackBar('Artist name is required for "${song.name}"');
      return false;
    }
    if (song.albumController.text.trim().isEmpty) {
      _showErrorSnackBar('Album name is required for "${song.name}"');
      return false;
    }
    return true;
  }

  // Modify uploadSong method to include validation
  Future<void> uploadSong(SongUpload song) async {
    if (!_validateSongFields(song)) {
      return;
    }

    try {
      setState(() {
        song.uploadStatus = 'uploading';
        song.errorMessage = null;
      });

      await _uploadToS3(song);
      await createSongs(song);

      setState(() {
        song.uploadStatus = 'success';
      });
      _showSuccessSnackBar('${song.name} uploaded successfully!');
    } catch (e) {
      setState(() {
        song.uploadStatus = 'error';
        song.errorMessage = e.toString();
      });
      _showErrorSnackBar('Upload failed: $e');
    }
  }

  // Modified _uploadToS3 method to handle chunked uploads
  Future<void> _uploadToS3(SongUpload song) async {
    Stream<List<int>>? fileStream;
    try {
      fileStream = song.platformFile.readStream;
      if (fileStream == null) {
        throw Exception('Cannot read file stream');
      }

      debugPrint(
          'Starting chunked upload for ${song.name} (${_formatFileSize(song.size)})');

      if (song.size > chunkSize) {
        await _uploadInChunks(song, fileStream);
      } else {
        // For small files, use regular upload
        await _uploadSingleFile(song, fileStream);
      }

      debugPrint('Successfully uploaded file: ${song.metadata.s3Key}');
    } catch (e, stackTrace) {
      debugPrint('Upload error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to upload file: $e');
    }
  }

  // New method for chunked upload
  Future<void> _uploadInChunks(
      SongUpload song, Stream<List<int>> fileStream) async {
    final int totalChunks = (song.size / chunkSize).ceil();
    final chunks = _splitStreamIntoChunks(fileStream, chunkSize);
    final contentType = _getContentType(song.name);
    int uploadedChunks = 0;
    int totalBytesUploaded = 0;

    await for (final chunk in chunks) {
      final chunkNumber = uploadedChunks + 1;
      final String chunkKey = '${song.metadata.s3Key}.part$chunkNumber';

      bool uploaded = false;
      int retryCount = 0;

      while (!uploaded && retryCount < maxRetries) {
        try {
          await Amplify.Storage.uploadFile(
            localFile: AWSFile.fromData(chunk),
            path: StoragePath.fromString(chunkKey),
            options: StorageUploadFileOptions(
              metadata: {
                'Content-Type': contentType,
                'chunkNumber': '$chunkNumber',
                'totalChunks': '$totalChunks',
                'originalKey': song.metadata.s3Key,
              },
            ),
          ).result;

          totalBytesUploaded += chunk.length;
          uploadedChunks++;

          // Update progress
          final progress = (totalBytesUploaded / song.size) * 100;
          setState(() {
            song.progress = progress;
          });

          debugPrint('Uploaded chunk $chunkNumber/$totalChunks - '
              '${_formatFileSize(totalBytesUploaded)}/${_formatFileSize(song.size)}');

          uploaded = true;
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            throw Exception(
                'Failed to upload chunk after $maxRetries attempts');
          }
          debugPrint('Retrying chunk $chunkNumber (attempt $retryCount)');
          await Future.delayed(
              Duration(seconds: retryCount * 2)); // Exponential backoff
        }
      }
    }

    // After all chunks are uploaded, trigger the merge operation
    await _mergeChunks(song, totalChunks);
  }

  // Helper method to split stream into chunks
  Stream<List<int>> _splitStreamIntoChunks(
      Stream<List<int>> source, int chunkSize) async* {
    List<int> currentChunk = [];

    await for (final List<int> data in source) {
      currentChunk.addAll(data);

      while (currentChunk.length >= chunkSize) {
        yield currentChunk.sublist(0, chunkSize);
        currentChunk = currentChunk.sublist(chunkSize);
      }
    }

    if (currentChunk.isNotEmpty) {
      yield currentChunk;
    }
  }

  // Add this helper function at the class level
  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg'; // default fallback
    }
  }

  // Helper method for regular single-file upload
  Future<void> _uploadSingleFile(
      SongUpload song, Stream<List<int>> fileStream) async {
    final contentType = _getContentType(song.name);

    await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromStream(
        fileStream,
        size: song.platformFile.size,
      ),
      path: StoragePath.fromString(song.metadata.s3Key),
      onProgress: (progress) {
        setState(() {
          song.progress = progress.fractionCompleted * 100;
        });
      },
      options: StorageUploadFileOptions(
        metadata: {
          'Content-Type': contentType,
        },
        pluginOptions: S3UploadFilePluginOptions(
          getProperties: true,
        ),
      ),
    ).result;
  }

  // Helper method to merge chunks (this would typically be handled by a backend service)
  Future<void> _mergeChunks(SongUpload song, int totalChunks) async {
    debugPrint('Merging $totalChunks chunks for ${song.metadata.s3Key}');

    try {
      // Create a list of all chunk keys
      List<String> chunkKeys = List.generate(
          totalChunks, (i) => '${song.metadata.s3Key}.part${i + 1}');

      // Download and combine all chunks
      List<int> completeFile = [];
      for (String chunkKey in chunkKeys) {
        final result = await Amplify.Storage.downloadData(
          path: StoragePath.fromString(chunkKey),
        ).result;
        completeFile.addAll(result.bytes);
      }

      // Upload the complete file with proper content type
      final contentType = _getContentType(song.name);

      await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromData(completeFile),
        path: StoragePath.fromString(song.metadata.s3Key),
        options: StorageUploadFileOptions(
          metadata: {
            'Content-Type': contentType,
          },
          pluginOptions: S3UploadFilePluginOptions(
            getProperties: true,
          ),
        ),
      ).result;

      // Clean up chunk files
      for (String chunkKey in chunkKeys) {
        await Amplify.Storage.remove(
          path: StoragePath.fromString(chunkKey),
        ).result;
      }
    } catch (e) {
      debugPrint('Error merging chunks: $e');
      throw Exception('Failed to merge chunks: $e');
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
      // Only remove successful uploads from the list
      setState(() {
        songs.removeWhere((song) => song.uploadStatus == 'success');
      });
      // Show success message after all uploads complete
      _showSuccessSnackBar('All songs uploaded successfully!');

      // Remove the auto-navigation code
      // The user will need to press the back button to return
    } finally {
      setState(() {
        uploading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> createSongs(SongUpload song) async {
    try {
      final model = Songs(
        title: song.name,
        artist: song.artistController.text.isNotEmpty
            ? song.artistController.text
            : "Unknown Artist",
        album: song.albumController.text.isNotEmpty
            ? song.albumController.text
            : "Unknown Album",
        duration: parseDurationToSeconds(song.durationController.text),
        fileType: song.fileType,
        genre: song.genre ?? "Pop",
      );

      final request = ModelMutations.create(model);
      final response = await Amplify.API.mutate(request: request).response;

      final createdSong = response.data;
      if (createdSong == null) {
        safePrint('errors: ${response.errors}');
        throw Exception('Failed to create song record');
      }
      safePrint('Mutation result: ${createdSong.id}');

      // Add a small delay to ensure the data is properly synchronized
      await Future.delayed(const Duration(seconds: 1));
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          ),
        ),
        title: const Text('Upload Songs'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Buttons Row
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              alignment: WrapAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: pickFiles,
                  icon: const Icon(Icons.music_note),
                  label: const Text('Select Files'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: songs.isEmpty || uploading ? null : uploadAll,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload All'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table Header
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Upload Queue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            // Table Content
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Color(0xffC5C5C5)),
                ),
                child: songs.isEmpty
                    ? Center(
                        child: Text(
                          'No files selected',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 24,
                            horizontalMargin: 16,
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Size')),
                              DataColumn(label: Text('Artist')),
                              DataColumn(label: Text('Album')),
                              DataColumn(label: Text('Genre')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Progress')),
                              DataColumn(label: Text('Duration (sec)')),
                            ],
                            rows: songs.map((song) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 200),
                                      child: Text(
                                        song.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_formatFileSize(song.size))),
                                  DataCell(
                                    TextField(
                                      controller: song.artistController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter artist name',
                                        border: InputBorder.none,
                                        errorText: song.artistController.text
                                                .trim()
                                                .isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          song.artist = value;
                                        });
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    TextField(
                                      controller: song.albumController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter album name',
                                        border: InputBorder.none,
                                        errorText: song.albumController.text
                                                .trim()
                                                .isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          song.album = value;
                                        });
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButton<String>(
                                      value: song.genre ?? 'Pop',
                                      isExpanded: true,
                                      underline:
                                          Container(), // Removes the default underline
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          song.genre = newValue;
                                        });
                                      },
                                      items: musicGenres
                                          .map<DropdownMenuItem<String>>(
                                              (String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  DataCell(_buildStatusCell(song)),
                                  DataCell(_buildProgressIndicator(song)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: song.durationController,
                                            decoration: const InputDecoration(
                                              hintText: 'MM:SS',
                                              border: InputBorder.none,
                                            ),
                                            readOnly: true,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.access_time),
                                          onPressed: () =>
                                              _showDurationPicker(song),
                                          tooltip: 'Pick duration',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper method for formatting file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildStatusCell(SongUpload song) {
    Color color;
    IconData icon;

    switch (song.uploadStatus) {
      case 'success':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'error':
        color = Colors.red;
        icon = Icons.error;
        break;
      case 'uploading':
        color = Colors.blue;
        icon = Icons.upload;
        break;
      default:
        color = Colors.grey;
        icon = Icons.hourglass_empty;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(song.uploadStatus),
      ],
    );
  }

  Widget _buildProgressIndicator(SongUpload song) {
    if (song.uploadStatus == 'uploading') {
      return Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: song.progress / 100,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${song.progress.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Add these helper functions
  String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int parseDurationToSeconds(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return (minutes * 60) + seconds;
      }
    } catch (e) {
      debugPrint('Error parsing duration: $e');
    }
    return 0;
  }

  void _showDurationPicker(SongUpload song) {
    int minutes = 0;
    int seconds = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Duration'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Minutes'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              onChanged: (value) {
                                minutes = int.tryParse(value) ?? 0;
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(':', style: TextStyle(fontSize: 20)),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Seconds'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              onChanged: (value) {
                                seconds = int.tryParse(value) ?? 0;
                                if (seconds > 59) {
                                  seconds = 59;
                                }
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Set'),
              onPressed: () {
                final totalSeconds = (minutes * 60) + seconds;
                setState(() {
                  song.duration = totalSeconds;
                  song.durationController.text = formatDuration(totalSeconds);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class StorageConfig {
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int chunkSize = 10 * 1024 * 1024; // 10MB
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}

// Add this class at the bottom of the file
class BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
