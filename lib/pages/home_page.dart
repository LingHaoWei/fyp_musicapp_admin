// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously, avoid_print

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fyp_musicapp_admin/main.dart';
import 'package:fyp_musicapp_admin/theme/app_color.dart';
import 'package:fyp_musicapp_admin/views/songs_view.dart';
import 'package:fyp_musicapp_admin/views/users_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiMU Admin Panel',
      theme: _buildAppTheme(),
      home: AdminHomePage(),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      inputDecorationTheme: const InputDecorationTheme(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Color(0xFFEEEEEE),
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: AppColor.primaryColor,
        backgroundColor: const Color(0xFFEEEEEE),
      ),
    );
  }
}

// Admin Home Page ui
class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    SongsView(),
    UsersView(),
  ];

  Future<void> _signOut(BuildContext context) async {
    try {
      await Amplify.Auth.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MyApp()),
      );
    } catch (e) {
      print('Sign out failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            //padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xffC5C5C5)),
              ),
            ),

            child: NavigationRail(
              extended: MediaQuery.of(context).size.width > 600,
              minExtendedWidth: 210,
              groupAlignment: -1.0,
              backgroundColor: Color(0xFFEEEEEE),

              // Brands
              leading: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                child: Row(
                  children: [
                    SizedBox(height: 10),
                    Image.asset('images/logo.png', width: 50),
                    SizedBox(width: 10),
                    Text('LiMU'),
                  ],
                ),
              ),

              // Navigation
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.people),
                  label: Text('Song'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.music_note),
                  label: Text('User'),
                ),
              ],
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },

              // Sign out
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0, left: 8.0),
                    child: IconButton(
                      icon: Icon(Icons.logout),
                      onPressed: () => _signOut(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          VerticalDivider(thickness: 1, width: 1),

          // Page Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
