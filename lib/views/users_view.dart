// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  // text controller
  final TextEditingController _searchController = TextEditingController();

  //int _rowsPerpage = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            child: Text(
              'User',
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
          /*Expanded(
            child: StreamBuilder<>(
              stream: firestoreService.getUsersStream(),
              builder: (context, snapshot) {
                // check if we have data
                if (snapshot.hasData) {
                  final userDocs = snapshot.data!.docs;
                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: SingleChildScrollView(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(0xffC5C5C5),
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(6),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            cardTheme: CardTheme(
                              elevation: 0,
                              color: Color(0xffF9F9F9),
                              margin: EdgeInsets.all(0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          child: PaginatedDataTable(
                            rowsPerPage: _rowsPerpage,
                            availableRowsPerPage: const [5, 10, 15, 20],
                            onRowsPerPageChanged: (value) {
                              setState(() {
                                _rowsPerpage = value!;
                              });
                            },
                            columns: [
                              DataColumn(
                                label: Text(
                                  'Username',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Email',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Prefer File Type',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Action',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            source: (userDocs),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading users data'),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ),*/
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
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/*class UserDataSource extends DataTableSource {
  final List<DocumentSnapshot> _userData;

  UserDataSource(this._userData);

  @override
  DataRow? getRow(int index) {
    if (index >= _userData.length) return null;

    final DocumentSnapshot document = _userData[index];
    final data = document.data() as Map<String, dynamic>;

    return DataRow(
      cells: [
        DataCell(Text(data['username'] ?? 'N/A')),
        DataCell(Text(data['email'] ?? 'N/A')),
        DataCell(Text(data['preferfile'] ?? 'N/A')),
        DataCell(
          IconButton(
            icon: Icon(
              Icons.edit,
              color: Color(0xff151515),
            ),
            onPressed: () => ([]),
          ),
        )
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _userData.length;

  @override
  int get selectedRowCount => 0;
}*/