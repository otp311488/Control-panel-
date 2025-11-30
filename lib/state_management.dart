import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_23/BottomBoardScrollingDemoScreen.dart'; // Add this
import 'package:flutter_application_23/PartnersScreen.dart';
import 'package:http/http.dart' as http;

class StateManagementScreen extends StatefulWidget {
  final String username;

  const StateManagementScreen({Key? key, required this.username}) : super(key: key);

  @override
  _StateManagementScreenState createState() => _StateManagementScreenState();
}

class _StateManagementScreenState extends State<StateManagementScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> states = [];
  TextEditingController stateController = TextEditingController();
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  bool _showWelcomeCard = true;

  // API Endpoints
  static const String apiGetStates = "https://sms.mydreamplaytv.com/get-states.php";
  static const String apiAddState = "https://sms.mydreamplaytv.com/add-state.php";
  static const String apiDeleteState = "https://sms.mydreamplaytv.com/delete-state.php";
  static const String apiCheckUser = "https://sms.mydreamplaytv.com/check-user.php";
  static const String apiGetDemoUsers = "https://sms.mydreamplaytv.com/get-demo-users.php";
  static const String apiGetBottomBoards = "https://sms.mydreamplaytv.com/get-bottom-boards.php";
  static const String apiAddBottomBoard = "https://sms.mydreamplaytv.com/add-bottom-board.php";
  static const String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";
  static const String apiGetScrollingMessages = "https://sms.mydreamplaytv.com/get-scrolling-messages.php";
  static const String apiAddScrollingMessage = "https://sms.mydreamplaytv.com/add-scrolling-message.php";
  static const String apiEditScrollingMessage = "https://sms.mydreamplaytv.com/edit-scrolling-message.php";
  static const String apiDeleteScrollingMessage = "https://sms.mydreamplaytv.com/delete-scrolling-message.php";
  static const String apiGetPackages = "https://sms.mydreamplaytv.com/get-packages.php";
  static const String apiAddPackage = "https://sms.mydreamplaytv.com/add-package.php";
  static const String apiEditPackage = "https://sms.mydreamplaytv.com/edit-package.php";
  static const String apiDeletePackage = "https://sms.mydreamplaytv.com/delete-package.php";
  static const String apiGetChannels = "https://sms.mydreamplaytv.com/get-channels.php";
  static const String apiAddChannel = "https://sms.mydreamplaytv.com/add-channel.php";
  static const String apiEditChannel = "https://sms.mydreamplaytv.com/edit-channel.php";
  static const String apiDeleteChannel = "https://sms.mydreamplaytv.com/delete-channel.php";
  static const String apiGetUsers = "https://sms.mydreamplaytv.com/get-users.php";
  static const String apiUserLogin = "https://sms.mydreamplaytv.com/user-login.php";

  @override
  void initState() {
    super.initState();
    fetchStates();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showWelcomeCard = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    stateController.dispose();
    super.dispose();
  }

  Future<void> fetchStates() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetStates));
      print("Raw Response: ${response.body}");

      if (response.statusCode == 200) {
        String jsonString = _extractJson(response.body);
        var data = jsonDecode(jsonString);

        if (data["success"]) {
          setState(() {
            states = List<Map<String, dynamic>>.from(data["states"]);
          });
        } else {
          _showSnackBar(data["message"] ?? "Failed to load states", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      print("Error: $e");
      _showSnackBar("Error fetching states", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> addState() async {
    if (stateController.text.isEmpty) {
      _showSnackBar("Please enter a state name", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      var response = await http.post(
        Uri.parse(apiAddState),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"state_name": stateController.text.trim()}),
      );

      print("Raw Response: ${response.body}");
      String jsonString = _extractJson(response.body);
      var data = jsonDecode(jsonString);

      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) {
        stateController.clear();
        fetchStates();
      }
    } catch (e) {
      print("Error: $e");
      _showSnackBar("Error adding state", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteState(String id) async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Confirm Delete", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this state?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[700])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    setState(() => isLoading = true);
    try {
      var response = await http.post(
        Uri.parse(apiDeleteState),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": int.parse(id)}),
      );

      print("Raw Response: ${response.body}");
      String jsonString = _extractJson(response.body);
      var data = jsonDecode(jsonString);

      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) {
        fetchStates();
      }
    } catch (e) {
      print("Error: $e");
      _showSnackBar("Error deleting state", Colors.red);
    }
    setState(() => isLoading = false);
  }

  String _extractJson(String response) {
    int jsonStart = response.indexOf('{');
    return jsonStart != -1 ? response.substring(jsonStart) : response;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue[900]!,
              Colors.blue[600]!,
              Colors.blue[300]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Builder(
                builder: (BuildContext context) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.menu, color: Colors.white, size: 28),
                                onPressed: () {
                                  Scaffold.of(context).openDrawer();
                                },
                                tooltip: "Open Menu",
                              ),
                              SizedBox(width: 8),
                              Text(
                                "State Management",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(1, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.white, size: 28),
                            onPressed: fetchStates,
                            tooltip: "Refresh States",
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildSectionCard(),
                      SizedBox(height: 16),
                      Expanded(
                        child: isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : states.isEmpty
                                ? Center(
                                    child: Text(
                                      "No states available.",
                                      style: TextStyle(fontSize: 14, color: Colors.white70),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: states.length,
                                    itemBuilder: (context, index) {
                                      return _buildStateCard(states[index]);
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_showWelcomeCard)
              Center(
                child: AnimatedOpacity(
                  opacity: _showWelcomeCard ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 500),
                  child: Container(
                    width: 280,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[800]!,
                          Colors.blue[400]!,
                          Colors.white,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.7, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Welcome',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.username,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue[900]!,
              Colors.blue[600]!,
              Colors.blue[300]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 160,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[800]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  SizedBox(height: 12),
                  Text(
                    widget.username,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.local_shipping,
              title: 'Package Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PartnerPackagesScreen()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.slideshow,
              title: 'Bottom Board Demo',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BottomBoardScrollingDemoScreen()),
                );
              },
            ),
            Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context); // Back to LoginScreen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.1),
      tileColor: Colors.transparent,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildSectionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add New State",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
            SizedBox(height: 8),
            _buildTextField(),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedBuilder(
                animation: _buttonAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonAnimation.value,
                    child: _buildAddButton(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: stateController,
      style: TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: "State Name",
        labelStyle: TextStyle(color: Colors.blue[700], fontSize: 12),
        prefixIcon: Icon(Icons.location_city, color: Colors.blue[700], size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                  addState();
                });
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          "Add",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(Map<String, dynamic> state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.symmetric(vertical: 2), // Reduced from 4
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
          leading: CircleAvatar(
            radius: 14, // Reduced from 16
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.location_city, color: Colors.blue[700], size: 16), // Reduced from 18
          ),
          title: Text(
            state["state_name"],
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[900]), // Reduced from 14
          ),
          subtitle: Text(
            "ID: ${state["id"]}",
            style: TextStyle(fontSize: 10, color: Colors.grey[700]), // Reduced from 12
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.red[600], size: 18), // Reduced from 20
            onPressed: () => deleteState(state["id"].toString()),
            tooltip: "Delete State",
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}