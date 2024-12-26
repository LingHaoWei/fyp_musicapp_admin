// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, avoid_print

import 'package:amplify_api/amplify_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp_musicapp_admin/manager/song_upload_manager.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_admin/models/ModelProvider.dart';

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

String formatDuration(int seconds) {
  int minutes = seconds ~/ 60;
  int remainingSeconds = seconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

enum SortField {
  title('Title'),
  date('Date Added');

  final String label;
  const SortField(this.label);
}

class SongsView extends StatefulWidget {
  const SongsView({super.key});

  @override
  _SongsDataView createState() => _SongsDataView();
}

class _SongsDataView extends State<SongsView> {
  final TextEditingController _searchController = TextEditingController();
  List<Songs?> _allSongs = [];
  List<Songs?> _filteredSongs = [];
  SortField _currentSortField = SortField.title;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    _allSongs = await listSongs();
    _filteredSongs = _allSongs;
    setState(() {});
  }

  Future<List<Songs?>> listSongs() async {
    try {
      final request = ModelQueries.list(Songs.classType);
      final response = await Amplify.API.query(request: request).response;
      safePrint('Raw Response: ${response.toString()}');
      final items = response.data?.items;
      if (items == null) {
        debugPrint('errors: ${response.errors}');
        return <Songs?>[];
      }
      return items;
    } on ApiException catch (e) {
      debugPrint('Query failed: $e');
    }
    return <Songs?>[];
  }

  Future<void> deleteSongs(Songs modelToDelete) async {
    try {
      final request = ModelMutations.delete(modelToDelete);
      final response = await Amplify.API.mutate(request: request).response;
      print('Response: $response');

      if (response.errors.isNotEmpty) {
        throw Exception(response.errors.first.message);
      }
    } catch (e) {
      print('Error deleting song: $e');
      rethrow;
    }
  }

  Future<void> deleteFilePublic(String fileName) async {
    try {
      Amplify.Storage.remove(path: StoragePath.fromString(fileName));
      print('Deleted file: $fileName');
    } on StorageException catch (e) {
      print('Error deleting file: $e');
    }
  }

  void _onSearchChanged(String value) {
    final searchTerm = value.toLowerCase();
    setState(() {
      _filteredSongs = _allSongs
          .where((song) =>
              song != null &&
              ((song.title?.toLowerCase() ?? '').contains(searchTerm) ||
                  (song.artist?.toLowerCase() ?? '').contains(searchTerm) ||
                  (song.album?.toLowerCase() ?? '').contains(searchTerm) ||
                  (song.genre?.toLowerCase() ?? '').contains(searchTerm)))
          .toList();
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
          const SizedBox(
            child: Text(
              'Song',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xffF9F9F9),
              border: Border.all(
                color: const Color(0xffC5C5C5),
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(6.0),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildBar();
              },
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Expanded(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xffF9F9F9),
                    border: Border.all(
                      color: const Color(0xffC5C5C5),
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(6.0),
                    ),
                  ),
                  child: Theme(
                      data: Theme.of(context).copyWith(
                        cardTheme: CardTheme(
                          elevation: 0,
                          color: const Color(0xffF9F9F9),
                          margin: const EdgeInsets.all(0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                        ),
                      ),
                      child: Center(
                          child: SizedBox(
                        child: FutureBuilder<List<Songs?>>(
                          future: Future.value(_filteredSongs),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                  child: Text('Error: ${snapshot.error}'));
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                  child: Text('No songs found'));
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                margin: const EdgeInsets.all(10),
                                child: PaginatedDataTable(
                                  rowsPerPage: 8,
                                  availableRowsPerPage: const [8, 16, 24],
                                  horizontalMargin: 10,
                                  columns: const [
                                    DataColumn(label: Text('Title')),
                                    DataColumn(label: Text('Artist')),
                                    DataColumn(label: Text('Album')),
                                    DataColumn(label: Text('Genre')),
                                    DataColumn(label: Text('Duration')),
                                    DataColumn(label: Text('File Type')),
                                    DataColumn(
                                      label: Text('Actions'),
                                    ),
                                  ],
                                  source: SongsDataSource(
                                    snapshot.data!,
                                    context: context,
                                    onDelete: (song) async {
                                      final currentContext = context;
                                      try {
                                        final fileName =
                                            "public/songs/${song.fileType}/${song.title}";
                                        await deleteFilePublic(fileName);
                                        await deleteSongs(song);
                                        await _loadSongs();

                                        if (currentContext.mounted) {
                                          ScaffoldMessenger.of(currentContext)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Song deleted successfully'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (currentContext.mounted) {
                                          ScaffoldMessenger.of(currentContext)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error deleting song: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    onUpdate: (song) async {
                                      final currentContext = context;
                                      try {
                                        final request =
                                            ModelMutations.update(song);
                                        final response = await Amplify.API
                                            .mutate(request: request)
                                            .response;

                                        if (response.errors.isNotEmpty) {
                                          throw Exception(
                                              response.errors.first.message);
                                        }

                                        await _loadSongs();
                                        setState(() {});

                                        if (currentContext.mounted) {
                                          ScaffoldMessenger.of(currentContext)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Song updated successfully'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (currentContext.mounted) {
                                          ScaffoldMessenger.of(currentContext)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error updating song: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ))),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Song List',
          style: TextStyle(fontSize: 15),
        ),
        Row(
          children: [
            // Combined sort dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<(SortField, bool)>(
                value: (_currentSortField, _isAscending),
                underline: const SizedBox(),
                items: [
                  for (var field in SortField.values) ...[
                    DropdownMenuItem(
                      value: (field, true),
                      child: Row(
                        children: [
                          Text('Sort by ${field.label} '),
                          const Icon(Icons.arrow_upward, size: 16),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: (field, false),
                      child: Row(
                        children: [
                          Text('Sort by ${field.label} '),
                          const Icon(Icons.arrow_downward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ],
                onChanged: ((SortField, bool)? value) async {
                  if (value != null) {
                    setState(() {
                      _currentSortField = value.$1;
                      _isAscending = value.$2;
                    });
                    await _sortSongs();
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            // Add Button
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SongUploadManager()));
              },
            ),
            const SizedBox(width: 16),
            // Search field
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

  Future<void> _sortSongs() async {
    final songs = await listSongs();
    setState(() {
      _allSongs = songs
        ..sort((a, b) {
          if (a == null || b == null) return 0;
          switch (_currentSortField) {
            case SortField.title:
              return _isAscending
                  ? (a.title ?? '').compareTo(b.title ?? '')
                  : (b.title ?? '').compareTo(a.title ?? '');
            case SortField.date:
              return _isAscending
                  ? a.createdAt!.compareTo(b.createdAt!)
                  : b.createdAt!.compareTo(a.createdAt!);
          }
        });
      _filteredSongs = _allSongs;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class SongsDataSource extends DataTableSource {
  final List<Songs?> _songs;
  final Function(Songs) onDelete;
  final Function(Songs) onUpdate;
  final BuildContext context;

  SongsDataSource(
    this._songs, {
    required this.onDelete,
    required this.onUpdate,
    required this.context,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= _songs.length) return null;
    final song = _songs[index];
    return DataRow(cells: [
      DataCell(Text(song?.title ?? 'No title')),
      DataCell(Text(song?.artist ?? 'Unknown artist')),
      DataCell(Text(song?.album ?? 'No album')),
      DataCell(Text(song?.genre ?? 'No genre')),
      DataCell(Text(formatDuration(song?.duration ?? 0))),
      DataCell(Text(song?.fileType ?? 'No file')),
      DataCell(
        SizedBox(
          width: 250,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: song == null ? null : () => _showEditDialog(song),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: song == null ? null : () => _showDeleteDialog(song),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _showDeleteDialog(Songs song) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "${song.title}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onDelete(song);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(Songs song) async {
    final formKey = GlobalKey<FormState>();
    final artistController = TextEditingController(text: song.artist ?? '');
    final albumController = TextEditingController(text: song.album ?? '');
    final genreController = TextEditingController(text: song.genre ?? '');
    final durationController =
        TextEditingController(text: formatDuration(song.duration ?? 0));
    int currentDuration = song.duration ?? 0;

    void showEditDialogWithDuration(int newDuration) {
      currentDuration = newDuration;
      _showEditDialog(song.copyWith(duration: newDuration));
    }

    try {
      return await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Edit "${song.title}"'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: artistController,
                      decoration: const InputDecoration(labelText: 'Artist'),
                    ),
                    TextFormField(
                      controller: albumController,
                      decoration: const InputDecoration(labelText: 'Album'),
                    ),
                    DropdownButtonFormField<String>(
                      value: genreController.text.isEmpty
                          ? 'Pop'
                          : genreController.text,
                      decoration: const InputDecoration(labelText: 'Genre'),
                      items: musicGenres.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          genreController.text = newValue;
                        }
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationController,
                            decoration:
                                const InputDecoration(labelText: 'Duration'),
                            readOnly: true,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final newDuration =
                                await _showDurationPicker(currentDuration);
                            if (newDuration != null) {
                              showEditDialogWithDuration(newDuration);
                            } else {
                              _showEditDialog(song);
                            }
                          },
                          tooltip: 'Pick duration',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Save'),
                onPressed: () async {
                  final updatedSong = song.copyWith(
                    artist: artistController.text,
                    album: albumController.text,
                    genre: genreController.text,
                    duration: currentDuration,
                  );
                  Navigator.of(context).pop();
                  await _updateSong(updatedSong);
                },
              ),
            ],
          );
        },
      );
    } finally {
      artistController.dispose();
      albumController.dispose();
      genreController.dispose();
      durationController.dispose();
    }
  }

  Future<void> _updateSong(Songs updatedSong) async {
    final currentContext = context;
    try {
      final request = ModelMutations.update(updatedSong);
      final response = await Amplify.API.mutate(request: request).response;

      if (response.errors.isNotEmpty) {
        throw Exception(response.errors.first.message);
      }

      onUpdate(updatedSong);
      notifyListeners();

      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('Song updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Error updating song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<int?> _showDurationPicker(int currentDuration) async {
    int minutes = currentDuration ~/ 60;
    int seconds = currentDuration % 60;
    int? result;

    await showDialog(
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
                              controller: TextEditingController(
                                  text: minutes.toString()),
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
                              controller: TextEditingController(
                                  text: seconds.toString()),
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
                result = (minutes * 60) + seconds;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return result;
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _songs.length;

  @override
  int get selectedRowCount => 0;
}
