// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, avoid_print

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_admin/manager/image_upload_manager.dart';

class ImagesView extends StatefulWidget {
  const ImagesView({super.key});

  @override
  _ImagesDataView createState() => _ImagesDataView();
}

class _ImagesDataView extends State<ImagesView> {
  final TextEditingController _searchController = TextEditingController();
  List<StorageItem> _allImages = [];
  List<StorageItem> _filteredImages = [];
  bool _isLoading = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final images = await listImagesFromS3();
      if (_isDisposed) return;

      setState(() {
        _allImages = images;
        _filteredImages = images;
        _isLoading = false;
      });
    } catch (e) {
      if (_isDisposed) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading images: $e');
    }
  }

  Future<List<StorageItem>> listImagesFromS3() async {
    List<StorageItem> allItems = [];
    try {
      String? nextToken;
      bool hasNextPage;
      do {
        final result = await Amplify.Storage.list(
          path: const StoragePath.fromString('public/images/'),
          options: StorageListOptions(
            pageSize: 50,
            nextToken: nextToken,
            pluginOptions: const S3ListPluginOptions(
              excludeSubPaths: true,
              delimiter: '/',
            ),
          ),
        ).result;

        allItems.addAll(result.items);
        nextToken = result.nextToken;
        hasNextPage = result.hasNextPage;
      } while (hasNextPage);

      return allItems;
    } on StorageException catch (e) {
      safePrint(e.message);
      return [];
    }
  }

  Future<void> deleteFilePublic(String fileName) async {
    final currentContext = context;
    try {
      debugPrint('Attempting to delete file: $fileName');
      await Amplify.Storage.remove(
        path: StoragePath.fromString(fileName),
      ).result;
      debugPrint('Deleted file: $fileName');
      if (!_isDisposed) {
        await _loadImages();
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
              content: Text('Image deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on StorageException catch (e) {
      debugPrint('Error deleting file: $e');
      if (!_isDisposed && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Error deleting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      if (!_isDisposed && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    final searchTerm = value.toLowerCase();
    setState(() {
      _filteredImages = _allImages.where((image) {
        final fileName = image.path.split('/').last.toLowerCase();
        return fileName.contains(searchTerm);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cover Images',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xffF9F9F9),
              border: Border.all(color: const Color(0xffC5C5C5)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _buildBar(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffF9F9F9),
                border: Border.all(color: const Color(0xffC5C5C5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildImagesList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Cover Images List',
          style: TextStyle(fontSize: 15),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImageUploadManager(),
                  ),
                ).then((_) => _loadImages());
              },
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagesList() {
    if (_filteredImages.isEmpty) {
      return const Center(child: Text('No images found'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.858,
        margin: const EdgeInsets.all(2),
        child: Theme(
          data: Theme.of(context).copyWith(
            cardTheme: CardTheme(
              elevation: 0,
              color: const Color(0xffF9F9F9),
              margin: EdgeInsets.zero,
            ),
            dataTableTheme: DataTableThemeData(
              headingRowColor: WidgetStateProperty.all(const Color(0xffF9F9F9)),
              dataRowColor: WidgetStateProperty.all(const Color(0xffF9F9F9)),
            ),
          ),
          child: PaginatedDataTable(
            rowsPerPage: 12,
            availableRowsPerPage: const [8, 16, 24],
            horizontalMargin: 10,
            showFirstLastButtons: true,
            arrowHeadColor: Colors.black,
            header: null,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Size')),
              DataColumn(label: Text('Actions')),
            ],
            source: S3ImagesDataSource(
              _filteredImages,
              context: context,
              deleteFilePublic: deleteFilePublic,
              onDelete: (item) async {
                final currentContext = context;
                try {
                  await deleteFilePublic(item.path);
                  if (!_isDisposed) {
                    await _loadImages();
                  }

                  if (currentContext.mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Image deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (currentContext.mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting image: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(StorageItem item) {
    final fileName = item.path.split('/').last;
    final currentContext = context;
    showDialog(
      context: currentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to delete this image?'),
              const SizedBox(height: 16),
              Text(fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xff202020))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await deleteFilePublic(item.path);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    super.dispose();
  }
}

class S3ImagesDataSource extends DataTableSource {
  final List<StorageItem> _items;
  final Function(StorageItem) onDelete;
  final BuildContext context;
  final Function(String) deleteFilePublic;

  S3ImagesDataSource(this._items,
      {required this.onDelete,
      required this.context,
      required this.deleteFilePublic});

  @override
  DataRow? getRow(int index) {
    if (index >= _items.length) return null;
    final item = _items[index];

    final fileName = item.path.split('/').last;

    return DataRow(cells: [
      DataCell(
        Row(
          children: [
            FutureBuilder<StorageGetUrlResult>(
              future: Amplify.Storage.getUrl(
                path: StoragePath.fromString(item.path),
                options: const StorageGetUrlOptions(
                  pluginOptions: S3GetUrlPluginOptions(
                    validateObjectExistence: true,
                    expiresIn: Duration(minutes: 5),
                  ),
                ),
              ).result,
              builder: (context, urlSnapshot) {
                if (urlSnapshot.hasData) {
                  return Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Image.network(
                      urlSnapshot.data!.url.toString(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  );
                }
                return Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.image, size: 20),
                );
              },
            ),
            Text(fileName),
          ],
        ),
      ),
      DataCell(Text(_formatFileSize(item.size ?? 0))),
      DataCell(
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteDialog(item),
            ),
          ],
        ),
      ),
    ]);
  }

  void _showDeleteDialog(StorageItem item) {
    final fileName = item.path.split('/').last;
    final currentContext = context;
    showDialog(
      context: currentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to delete this image?'),
              const SizedBox(height: 16),
              Text(fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xff202020))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await deleteFilePublic(item.path);
              },
            ),
          ],
        );
      },
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
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _items.length;

  @override
  int get selectedRowCount => 0;
}
