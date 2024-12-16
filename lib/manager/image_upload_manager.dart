import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fyp_musicapp_admin/pages/home_page.dart';

class ImageUpload {
  final PlatformFile platformFile;
  final String name;
  final int size;
  String uploadStatus;
  double progress;
  String? errorMessage;

  ImageUpload({
    required this.platformFile,
    required this.name,
    required this.size,
    this.uploadStatus = 'pending',
    this.progress = 0,
    this.errorMessage,
  });
}

class ImageUploadManager extends StatefulWidget {
  const ImageUploadManager({super.key});

  @override
  State<ImageUploadManager> createState() => _ImageUploadManagerState();
}

class _ImageUploadManagerState extends State<ImageUploadManager> {
  List<ImageUpload> images = [];
  bool uploading = false;

  Future<void> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        allowMultiple: true,
        withData: false,
        withReadStream: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newImages = result.files.where((file) {
          if (!file.name.toLowerCase().endsWith('.png')) {
            _showErrorSnackBar('Only PNG files are allowed: ${file.name}');
            return false;
          }
          if (file.readStream == null) {
            _showErrorSnackBar('Cannot read file: ${file.name}');
            return false;
          }
          return true;
        }).map((file) {
          return ImageUpload(
            platformFile: file,
            name: file.name,
            size: file.size,
          );
        }).toList();

        setState(() {
          images.addAll(newImages);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking files: $e');
    }
  }

  Future<void> uploadImage(ImageUpload image) async {
    try {
      setState(() {
        image.uploadStatus = 'uploading';
        image.errorMessage = null;
      });

      final stream = image.platformFile.readStream;
      if (stream == null) throw Exception('Cannot read file stream');

      final s3Key = 'public/images/${image.name}';
      final contentType = _getContentType(image.name);

      await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromStream(
          stream,
          size: image.platformFile.size,
        ),
        path: StoragePath.fromString(s3Key),
        onProgress: (progress) {
          setState(() {
            image.progress = progress.fractionCompleted * 100;
          });
        },
        options: StorageUploadFileOptions(
          metadata: {
            'Content-Type': contentType,
          },
          pluginOptions: const S3UploadFilePluginOptions(
            getProperties: true,
          ),
        ),
      ).result;

      setState(() {
        image.uploadStatus = 'success';
      });
      _showSuccessSnackBar('${image.name} uploaded successfully!');
    } catch (e) {
      setState(() {
        image.uploadStatus = 'error';
        image.errorMessage = e.toString();
      });
      _showErrorSnackBar('Upload failed: $e');
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    if (extension != 'png') {
      throw Exception('Only PNG files are allowed');
    }
    return 'image/png';
  }

  Future<void> uploadAll() async {
    setState(() {
      uploading = true;
    });

    try {
      final pendingImages =
          images.where((image) => image.uploadStatus == 'pending');
      for (var image in pendingImages) {
        await uploadImage(image);
      }
      setState(() {
        images.removeWhere((image) => image.uploadStatus == 'success');
      });
      _showSuccessSnackBar('All images uploaded successfully!');
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
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
        title: const Text('Upload Images'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              alignment: WrapAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: pickFiles,
                  icon: const Icon(Icons.image),
                  label: const Text('Select Images'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: images.isEmpty || uploading ? null : uploadAll,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload All'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xffC5C5C5)),
                ),
                child: images.isEmpty
                    ? Center(
                        child: Text(
                          'No images selected',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final image = images[index];
                          return ListTile(
                            leading: const Icon(Icons.image),
                            title: Text(image.name),
                            subtitle: Text(_formatFileSize(image.size)),
                            trailing: SizedBox(
                              width: 100,
                              child: image.uploadStatus == 'uploading'
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        LinearProgressIndicator(
                                          value: image.progress / 100,
                                        ),
                                        Text(
                                            '${image.progress.toStringAsFixed(1)}%'),
                                      ],
                                    )
                                  : Text(image.uploadStatus),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
