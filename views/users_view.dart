import 'package:flutter/material.dart';

class UsersView extends StatefulWidget {
  const UsersView({super.key});

  @override
  _UsersDataView createState() => _UsersDataView();
}

class _UsersDataView extends State<UsersView>{
  final TextEditingController _searchController = TextEditingController();
  List<bool> selected = List.generate(20, (index) => false);
  String _sortColumn = 'name';
  bool _sortAscending = true;
  int _rowsPerPage = 10;
  //int _currentPage = 0;

  // Sample data
  final List<Map<String, dynamic>> _data = List.generate(
    10,
    (index) => {
      'id': index + 1,
      'name': 'Item ${index + 1}',
      'email': 'userEmail${index + 1}@gmail.com',
      'password': '********',
      'prefile': index % 3 == 0 ? '.flac' : '.mp3',
    },
  );

  List<Map<String, dynamic>> get filteredData {
    return _data.where((item) {
      final searchTerm = _searchController.text.toLowerCase();
      return item['name'].toLowerCase().contains(searchTerm) ||
          item['email'].toLowerCase().contains(searchTerm);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(30),
      //padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            //padding: const EdgeInsets.all(20),
            child: Text(
              'Users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24,),
      
          // Bar with controls
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
      
          const SizedBox(height: 16,),

          Expanded(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
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
                    child: PaginatedDataTable(
                      
                      header: null,
                      rowsPerPage: _rowsPerPage,
                      onRowsPerPageChanged: (value) {
                        setState(() {
                          _rowsPerPage = value!;
                        });
                      },
                      sortColumnIndex: _sortColumn == 'name' ? 1 : null,
                      sortAscending: _sortAscending,
                      columns: [
                        DataColumn(
                          label: const Text('ID'),
                          onSort: (_, __) => _onSort('id'),
                        ),
                        DataColumn(
                          label: const Text('Name'),
                          onSort: (_, __) => _onSort('name'),
                        ),
                        const DataColumn(
                          label: Text('Email'),
                        ),
                        const DataColumn(
                          label: Text('Password'),
                        ),
                        DataColumn(
                          label: const Text('File Type'),
                          onSort: (_, __) => _onSort('prefile'),
                        ),
                        const DataColumn(label: Text('Options')),
                      ], 
                      source: _DataTableSource(
                        data: filteredData,
                        onSelectChanged: (index, value) {
                          setState((){
                            selected[index] = value!;
                          });
                        },
                        selectedRows: selected,
                        onEdit: _onEditItem,
                      ),
                      ),
                  ),
                ),
              ),
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
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            // Search field
            SizedBox(
              width: 200,
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

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }

      filteredData.sort((a, b) {
        final aValue = a[column];
        final bValue = b[column];
        return _sortAscending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

  void _onEditItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User'),
          content: Text('Edit user: ${item['name']}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Perform edit action here
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _DataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final Function(int, bool?) onSelectChanged;
  final List<bool> selectedRows;
  final Function(Map<String, dynamic>) onEdit;

  _DataTableSource({
    required this.data,
    required this.onSelectChanged,
    required this.selectedRows,
    required this.onEdit,
  });

  @override
  DataRow getRow(int index) {
    return DataRow(
      selected: selectedRows[index],
      onSelectChanged: (value) => onSelectChanged(index, value),
      cells: [
        DataCell(Text(data[index]['id'].toString())),
        DataCell(Text(data[index]['name'])),
        DataCell(Text(data[index]['email'])),
        DataCell(Text(data[index]['password'])),
        DataCell(Text(data[index]['prefile'])),
        DataCell(
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => onEdit(data[index]),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => selectedRows.where((selected) => selected).length;
}