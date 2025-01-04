// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_admin/models/ModelProvider.dart';

enum SortField {
  username('Username'),
  email('Email');

  final String label;
  const SortField(this.label);
}

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  final TextEditingController _searchController = TextEditingController();
  List<Users?> _allUsers = [];
  List<Users?> _filteredUsers = [];
  SortField _currentSortField = SortField.username;
  bool _isAscending = true;
  bool _isLoading = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await listUsers();
      if (_isDisposed) return;

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (_isDisposed) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading users: $e');
    }
  }

  Future<List<Users?>> listUsers() async {
    try {
      final request = ModelQueries.list(Users.classType);
      final response = await Amplify.API.query(request: request).response;
      safePrint('Raw Response: ${response.toString()}');
      final items = response.data?.items;
      if (items == null) {
        debugPrint('errors: ${response.errors}');
        return <Users?>[];
      }
      return items;
    } on ApiException catch (e) {
      debugPrint('Query failed: $e');
    }
    return <Users?>[];
  }

  Future<void> deleteUser(Users modelToDelete) async {
    final request = ModelMutations.delete(modelToDelete);
    await Amplify.API.mutate(request: request).response;
    await _loadUsers();
  }

  void _onSearchChanged(String value) {
    final searchTerm = value.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers
          .where((user) =>
              user != null &&
              ((user.name?.toLowerCase() ?? '').contains(searchTerm) ||
                  (user.email?.toLowerCase() ?? '').contains(searchTerm)))
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
          const Text(
            'Users',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(10),
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
                  : _buildUsersList(),
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
          'User List',
          style: TextStyle(fontSize: 15),
        ),
        Row(
          children: [
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
                    await _sortUsers();
                  }
                },
              ),
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

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return const Center(child: Text('No users found'));
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
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Preferred File Type')),
              DataColumn(label: Text('Actions')),
            ],
            source: UsersDataSource(
              users: _filteredUsers,
              context: context,
              onDelete: (user) async {
                final currentContext = context;
                try {
                  await deleteUser(user);
                  await _loadUsers();

                  if (currentContext.mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text('User deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (currentContext.mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting user: $e'),
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

  Future<void> _sortUsers() async {
    if (_isDisposed) return;

    setState(() {
      _filteredUsers.sort((a, b) {
        if (a == null || b == null) return 0;
        switch (_currentSortField) {
          case SortField.username:
            return _isAscending
                ? (a.name ?? '').compareTo(b.name ?? '')
                : (b.name ?? '').compareTo(a.name ?? '');
          case SortField.email:
            return _isAscending
                ? (a.email ?? '').compareTo(b.email ?? '')
                : (b.email ?? '').compareTo(a.email ?? '');
        }
      });
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    super.dispose();
  }
}

class UsersDataSource extends DataTableSource {
  final List<Users?> users;
  final BuildContext context;
  final Function(Users) onDelete;

  UsersDataSource({
    required this.users,
    required this.context,
    required this.onDelete,
  });

  @override
  DataRow getRow(int index) {
    final user = users[index];
    if (user == null) {
      return DataRow(cells: [
        DataCell(Text('N/A')),
        DataCell(Text('N/A')),
        DataCell(Text('N/A')),
        DataCell(SizedBox()),
      ]);
    }

    return DataRow(cells: [
      DataCell(Text(user.name ?? 'N/A')),
      DataCell(Text(user.email ?? 'N/A')),
      DataCell(Text(user.preferFileType ?? 'Not specified')),
      DataCell(
        SizedBox(
          width: 250,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteDialog(user),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _showDeleteDialog(Users user) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "${user.name}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xff202020))),
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
                onDelete(user);
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
  int get rowCount => users.length;

  @override
  int get selectedRowCount => 0;
}
