import 'package:flutter/material.dart';
import 'package:flutter_application_23/BottomBoardScreen.dart';
import 'package:flutter_application_23/DashboardScreen.dart';
import 'package:flutter_application_23/DefaultPackagesScreen.dart';
import 'package:flutter_application_23/DemoUsersScreen.dart';
import 'package:flutter_application_23/PartnerPackagesScreen.dart';
import 'package:flutter_application_23/PartnersScreen.dart';
import 'package:flutter_application_23/ScrollingScreen.dart';
import 'package:flutter_application_23/StatesScreen.dart';
import 'package:google_fonts/google_fonts.dart';

class MenuScreen extends StatefulWidget {
  final String? username;
  const MenuScreen({this.username, super.key});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const Color primaryColor = Color(0xFF00897B);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);

  late Widget _currentScreen;
  bool isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _currentScreen = DashboardScreen(username: widget.username); // Default to DashboardScreen
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial sidebar state based on screen width
    isSidebarOpen = MediaQuery.of(context).size.width >= 600;
  }

  void _updateScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
  }

  List<Map<String, dynamic>> get menuItems => [
        {"title": "Dashboard", "screen": DashboardScreen(username: widget.username)},
        {"title": "States", "screen": StatesScreen(username: widget.username)},
        {"title": "Default Packages", "screen": DefaultPackagesScreen(username: widget.username)},
        {"title": "Partners", "screen": PartnersScreen(username: widget.username)},
        {"title": "Partner Packages", "screen": PartnerPackagesScreen(username: widget.username)},
        {"title": "Demo Users", "screen": DemoUsersScreen(username: widget.username)},
        {"title": "Bottom Board", "screen": BottomBoardScreen(username: widget.username)},
        {"title": "Scrolling", "screen": ScrollingScreen(username: widget.username)},
        {"title": "Logout", "screen": null},
      ];

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Dashboard':
        return Icons.dashboard;
      case 'States':
        return Icons.location_on;
      case 'Default Packages':
        return Icons.local_shipping;
      case 'Partner Packages':
        return Icons.handshake;
      case 'Partners':
        return Icons.group;
      case 'Demo Users':
        return Icons.person_outline;
      case 'Bottom Board':
        return Icons.dashboard;
      case 'Scrolling':
        return Icons.text_rotation_none;
      case 'Logout':
        return Icons.logout;
      default:
        return Icons.menu;
    }
  }

  Widget _buildSidebar(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final double sidebarWidth = isMobile ? 200 : 250;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isSidebarOpen ? sidebarWidth : 0,
      color: drawerColor,
      child: isSidebarOpen
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  height: isMobile ? 120 : 140, // Increased height to avoid overflow
                  decoration: const BoxDecoration(
                    color: primaryColor,
                  ),
                  padding: EdgeInsets.all(isMobile ? 8 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 25 : 30, // Slightly smaller on mobile
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: isMobile ? 35 : 40, color: drawerColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.username ?? 'Admin',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ...menuItems.map((item) => ListTile(
                      leading: Icon(
                        _getIconForTitle(item["title"]),
                        color: Colors.cyan[300],
                        size: isMobile ? 20 : 24,
                      ),
                      title: Text(
                        item["title"],
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          isSidebarOpen = false;
                          if (item["title"] == "Logout") {
                            Navigator.pushReplacementNamed(context, '/');
                          } else {
                            _updateScreen(item["screen"]);
                          }
                        });
                      },
                    )),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: null,
      endDrawer: null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final bool isMobile = screenWidth < 600;
          final double padding = isMobile ? 8.0 : 16.0;

          return Row(
            children: [
              _buildSidebar(screenWidth),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: padding,
                        right: padding,
                        top: padding,
                        bottom: padding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isSidebarOpen ? Icons.close : Icons.menu,
                                  color: primaryColor,
                                  size: isMobile ? 24 : 28,
                                ),
                                onPressed: () {
                                  setState(() => isSidebarOpen = !isSidebarOpen);
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _currentScreen),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}