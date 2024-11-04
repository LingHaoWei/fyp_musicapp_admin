import 'package:flutter/material.dart';

class SongsView extends StatefulWidget {
  const SongsView({super.key});

  @override
  _SongsDataView createState() => _SongsDataView();
}

class _SongsDataView extends State<SongsView> {
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
              'Songs Page',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24,),

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
                    child: const Text('Songs Here')
                  ),
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
            fontWeight: FontWeight.w500,
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
                // Implement file picker and AWS upload functionality
              },
              child: const Icon(Icons.add),
            ),
            // Search field
            SizedBox(
              width: 200,
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