// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, avoid_print

import 'package:amplify_api/amplify_api.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_admin/manager/song_upload_manager.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:fyp_musicapp_admin/models/ModelProvider.dart';

class SongsView extends StatefulWidget {
  const SongsView({super.key});

  @override
  _SongsDataView createState() => _SongsDataView();
}

class _SongsDataView extends State<SongsView> {
  @override
  void initState() {
    super.initState();
  }

  /// Fetches a list of songs from the data store using Amplify API.
  Future<List<Songs?>> listSongs() async {
    try {
      final request = ModelQueries.list(Songs.classType);
      final response = await Amplify.API.query(request: request).response;

      final items = response.data?.items;
      if (items == null) {
        print('errors: ${response.errors}');
        return <Songs?>[];
      }
      return items;
    } on ApiException catch (e) {
      print('Query failed: $e');
    }
    return <Songs?>[];
  }

  Future<void> deleteSongs(Songs modelToDelete) async {
    final request = ModelMutations.delete(modelToDelete);
    final response = await Amplify.API.mutate(request: request).response;
    print('Response: $response');
  }

  Future<void> deleteFilePublic(String fileName) async {
    try {
      Amplify.Storage.remove(path: StoragePath.fromString(fileName));
      print('Deleted file: $fileName');
    } on StorageException catch (e) {
      print('Error deleting file: $e');
    }
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
                          future: listSongs(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                ),
                              );
                            }
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
                                    //DataColumn(label: Text('Album')),
                                    //DataColumn(label: Text('Genre')),
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
                                      try {
                                        // Extract filename from audio URL/path
                                        final fileName = "public/${song.title}";
                                        await deleteFilePublic(fileName);

                                        // Then delete from database
                                        await deleteSongs(song);
                                        setState(() {}); // Refresh the list

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Song deleted successfully'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
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
          style: TextStyle(
            fontSize: 15,
          ),
        ),
        Row(
          children: [
            // Sort Button
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                // Implement sorting functionality
              },
              child: const Icon(Icons.sort),
            ),
            // Add Button
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SongUploadManager()));
              },
              child: const Icon(Icons.add),
            ),
            // Search field
            SizedBox(
              width: 180,
              child: TextField(
                controller: null,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SongsDataSource extends DataTableSource {
  final List<Songs?> _songs;
  final Function(Songs) onDelete;
  final BuildContext context;

  SongsDataSource(this._songs, {required this.onDelete, required this.context});

  @override
  DataRow? getRow(int index) {
    if (index >= _songs.length) return null;
    final song = _songs[index];
    return DataRow(cells: [
      DataCell(Text(song?.title ?? 'No title')),
      DataCell(Text(song?.artist ?? 'Unknown artist')),
      //DataCell(Text(song?.album ?? 'No album')),
      //DataCell(Text(song?.genre ?? 'No genre')),
      DataCell(Text(song?.duration?.toString() ?? '0:00')),
      DataCell(Text(song?.fileType ?? 'No file')),
      DataCell(
        SizedBox(
          width: 250,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Edit functionality
                },
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

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _songs.length;

  @override
  int get selectedRowCount => 0;
}
