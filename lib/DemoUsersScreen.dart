import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.length > 8) newText = newText.substring(0, 8);

    String formattedText = '';
    for (int i = 0; i < newText.length; i++) {
      if (i == 2 || i == 4) formattedText += '/';
      formattedText += newText[i];
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class DemoUsersScreen extends StatefulWidget {
  final String? username;
  const DemoUsersScreen({this.username, super.key});

  @override
  _DemoUsersScreenState createState() => _DemoUsersScreenState();
}

class _DemoUsersScreenState extends State<DemoUsersScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> demoUsers = [];
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> displayedUsers = []; // For displaying users in the table
  TextEditingController newMobileNumberController = TextEditingController();
  TextEditingController newValidityController = TextEditingController();
  TextEditingController newDeviceIdController = TextEditingController();
  TextEditingController searchController = TextEditingController(); // Controller for search field
  TimeOfDay? selectedTime;
  String? selectedStateId;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;
  int? highlightedIndex; // To track the highlighted row

  static const Color primaryColor = Color(0xFF00897B);
  static const Color secondaryColor = Color(0xFFFFCA28);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);
  static const Color cardColor = Color(0xFF455A64);

  static const String apiGetDemoUsers = "https://sms.mydreamplaytv.com/get-demo-users.php";
  static const String apiAddDemoUser = "https://sms.mydreamplaytv.com/add-demo-user.php";
  static const String apiUpdateDemoUser = "https://sms.mydreamplaytv.com/update-demo-user.php";
  static const String apiGetStates = "https://sms.mydreamplaytv.com/get-states.php";
  static const String apiDeleteDemoUser = "https://sms.mydreamplaytv.com/delete-demo-user.php";
  static const String apiManageDemoUser = "https://sms.mydreamplaytv.com/manage-demo-user.php";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchDemoUsers();
    fetchStates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newMobileNumberController.dispose();
    newValidityController.dispose();
    newDeviceIdController.dispose();
    searchController.dispose();
    super.dispose();
  }

  String extractJson(String response) => response.indexOf('{') != -1 ? response.substring(response.indexOf('{')) : "";

  Future<void> fetchDemoUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetDemoUsers));
      if (response.statusCode == 200) {
        String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          var data = jsonDecode(jsonResponse);
          print("fetchDemoUsers response: $data");
          if (data["success"]) {
            setState(() {
              demoUsers = List<Map<String, dynamic>>.from(data["users"]);
              displayedUsers = List.from(demoUsers); // Initialize displayed users
              print("Users in table: ${demoUsers.map((user) => user['mobile_number']).toList()}");
            });
          } else {
            _showSnackBar("Failed to fetch demo users: ${data["message"]}", Colors.red);
          }
        } else {
          _showSnackBar("Empty response from server", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      print("Error fetching demo users: $e");
      _showSnackBar("Error fetching demo users: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStates() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetStates));
      if (response.statusCode == 200) {
        String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          var data = jsonDecode(jsonResponse);
          print("fetchStates response: $data");
          if (data["success"]) setState(() => states = List<Map<String, dynamic>>.from(data["states"]));
        }
      }
    } catch (e) {
      print("Error fetching states: $e");
      _showSnackBar("Error fetching states: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> addDemoUser() async {
    String mobileNumber = newMobileNumberController.text.trim();
    String validityDate = newValidityController.text.trim();
    String deviceId = newDeviceIdController.text.trim();
    if (mobileNumber.isEmpty || selectedStateId == null || validityDate.isEmpty || deviceId.isEmpty) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(mobileNumber)) {
      _showSnackBar("Mobile number must be 10 digits", Colors.red);
      return;
    }
    if (!isValidDate(validityDate)) {
      _showSnackBar("Please enter a valid future date", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      final parts = validityDate.split('/');
      final formattedValidityDate = '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')} 00:00:00';

      var response = await http.post(
        Uri.parse(apiAddDemoUser),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "mobile_number": mobileNumber,
          "state_id": selectedStateId,
        }),
      );
      print("addDemoUser request body: ${jsonEncode({
        "mobile_number": mobileNumber,
        "state_id": selectedStateId,
      })}");
      print("addDemoUser response: ${response.body}");
      var data = jsonDecode(extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);

      if (data["success"]) {
        var selectedState = states.firstWhere((state) => state["id"].toString() == selectedStateId, orElse: () => {"state_name": "Unknown"});
        final deviceUri = Uri.parse('$apiManageDemoUser?mobile_number=$mobileNumber&state_name=${Uri.encodeComponent(selectedState["state_name"])}&deviceid=$deviceId');
        var deviceResponse = await http.post(deviceUri, headers: {"Content-Type": "application/json"});
        var deviceData = jsonDecode(extractJson(deviceResponse.body));
        print("manageDemoUser (add) response: $deviceData");
        _showSnackBar(deviceData["message"], deviceData["success"] ? Colors.green : Colors.red);

        if (deviceData["success"]) {
          newMobileNumberController.clear();
          newValidityController.clear();
          newDeviceIdController.clear();
          setState(() {
            selectedStateId = null;
          });
          await fetchDemoUsers();
        }
      }
    } catch (e) {
      print("Error adding demo user: $e");
      _showSnackBar("Error adding demo user: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> checkUser() async {
    String mobileNumber = newMobileNumberController.text.trim();
    String deviceId = newDeviceIdController.text.trim();
    if (mobileNumber.isEmpty || selectedStateId == null || deviceId.isEmpty) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      var selectedState = states.firstWhere((state) => state["id"].toString() == selectedStateId, orElse: () => {"state_name": "Unknown"});
      final uri = Uri.parse('$apiManageDemoUser?mobile_number=$mobileNumber&state_name=${Uri.encodeComponent(selectedState["state_name"])}');
      var response = await http.get(uri);
      var data = jsonDecode(extractJson(response.body));
      print("manageDemoUser (check) response: $data");
      _showSnackBar(data["message"] ?? "No message", data["success"] ? Colors.green : Colors.red);
      if (data["success"] && data["data"] is Map) {
        if (data["data"]["status"] == "active") {
          _showSnackBar("User ${data["data"]["mobile_number"]} active until ${data["data"]["validity_date"]}", Colors.green);
        } else if (data["data"]["status"] == "expired") {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: drawerColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text("Account Expired", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
              content: Text("User ${data["data"]["mobile_number"]} expired on ${data["data"]["expired_on"]}. Do you want to update this user?", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("No", style: GoogleFonts.poppins(color: primaryColor, fontSize: 14)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    var selectedState = states.firstWhere((state) => state["id"].toString() == selectedStateId, orElse: () => {"state_name": "Unknown"});
                    final deviceUri = Uri.parse('$apiManageDemoUser?mobile_number=$mobileNumber&state_name=${Uri.encodeComponent(selectedState["state_name"])}&deviceid=$deviceId');
                    var deviceResponse = await http.put(deviceUri, headers: {"Content-Type": "application/json"});
                    var deviceData = jsonDecode(extractJson(deviceResponse.body));
                    print("manageDemoUser (update) response: $deviceData");
                    _showSnackBar(deviceData["message"], deviceData["success"] ? Colors.green : Colors.red);
                    if (deviceData["success"]) {
                      newMobileNumberController.clear();
                      newValidityController.clear();
                      newDeviceIdController.clear();
                      setState(() => selectedStateId = null);
                      await fetchDemoUsers();
                    }
                  },
                  child: Text("Yes", style: GoogleFonts.poppins(color: primaryColor, fontSize: 14)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print("Error checking user: $e");
      _showSnackBar("Error checking user: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateDemoUser(Entity entity, String newMobileNumber, String newStateId, String newValidityDate, TimeOfDay newTime) async {
    setState(() => isLoading = true);
    try {
      final parts = newValidityDate.split('/');
      final formattedValidityDate = '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')} ${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}:00';

      var response = await http.post(
        Uri.parse(apiUpdateDemoUser),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": entity.id,
          "mobile_number": newMobileNumber,
          "state_id": newStateId,
          "validity_date": formattedValidityDate,
        }),
      );
      var data = jsonDecode(extractJson(response.body));
      print("updateDemoUser response: $data");
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);

      if (data["success"]) await fetchDemoUsers();
    } catch (e) {
      print("Error updating demo user: $e");
      _showSnackBar("Error updating demo user: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteDemoUser(String id) async {
    setState(() => isLoading = true);
    try {
      var response = await http.post(
        Uri.parse(apiDeleteDemoUser),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      var data = jsonDecode(extractJson(response.body));
      print("deleteDemoUser response: $data");
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchDemoUsers();
    } catch (e) {
      print("Error deleting demo user: $e");
      _showSnackBar("Error deleting demo user: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Drawer _buildSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Drawer(
      backgroundColor: drawerColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(color: primaryColor),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  widget.username ?? "Admin",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: screenWidth > 600 ? 16 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final double padding = isMobile ? 4.0 : 8.0; // Reduced padding
    final double fontSize = isMobile ? 10 : 12; // Reduced font size
    final double iconSize = isMobile ? 16 : 18; // Reduced icon size
    final double fieldWidth = isMobile ? 100 : double.infinity; // Adjusted field width for mobile

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // Reduced border radius
      elevation: 2, // Reduced elevation
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Add New Demo User",
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 3), // Reduced spacing
            // Search Field
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search by Mobile Number",
                hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(width: 1)),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 6 : 8, horizontal: 8), // Reduced padding
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: Colors.black, size: iconSize),
                  onPressed: () => _searchUser(searchController.text),
                ),
              ),
              style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
              keyboardType: TextInputType.phone,
              onSubmitted: (value) => _searchUser(value), // Trigger search on Enter
            ),
            const SizedBox(height: 3), // Reduced spacing
            LayoutBuilder(
              builder: (context, constraints) {
                if (isMobile) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: newMobileNumberController,
                            decoration: InputDecoration(
                              hintText: "Enter Mobile Number",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 6 : 8, horizontal: 8), // Reduced padding
                              errorText: newMobileNumberController.text.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(newMobileNumberController.text.trim()) ? "Enter a valid 10-digit number" : null,
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                            keyboardType: TextInputType.phone,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 3), // Reduced spacing
                        Container(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String>(
                            value: selectedStateId,
                            hint: Text("Select State", style: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize)),
                            items: states.map((state) => DropdownMenuItem<String>(
                                  value: state["id"].toString(),
                                  child: Text(state["state_name"] as String, style: GoogleFonts.poppins(fontSize: fontSize)),
                                )).toList(),
                            onChanged: (value) => setState(() => selectedStateId = value),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 6 : 8, horizontal: 8), // Reduced padding
                            ),
                            dropdownColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 3), // Reduced spacing
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: newValidityController,
                            decoration: InputDecoration(
                              hintText: "Validity (MM/DD/YYYY)",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 6 : 8, horizontal: 8), // Reduced padding
                              errorText: newValidityController.text.isNotEmpty && !isValidDate(newValidityController.text) ? "Enter a valid future date" : null,
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                            keyboardType: TextInputType.number,
                            inputFormatters: [DateInputFormatter()],
                            maxLength: 10,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 3), // Reduced spacing
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: newDeviceIdController,
                            decoration: InputDecoration(
                              hintText: "Enter Device ID",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 6 : 8, horizontal: 8), // Reduced padding
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                            keyboardType: TextInputType.text,
                          ),
                        ),
                        const SizedBox(width: 3), // Reduced spacing
                        FloatingActionButton(
                          onPressed: checkUser,
                          backgroundColor: Colors.blue,
                          mini: true,
                          child: Icon(Icons.search, color: Colors.white, size: iconSize),
                        ),
                        const SizedBox(width: 3), // Reduced spacing
                        FloatingActionButton(
                          onPressed: addDemoUser,
                          backgroundColor: primaryColor,
                          mini: true,
                          child: Icon(Icons.add, color: Colors.white, size: iconSize),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newMobileNumberController,
                          decoration: InputDecoration(
                            hintText: "Enter Mobile Number",
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 8), // Reduced padding
                            errorText: newMobileNumberController.text.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(newMobileNumberController.text.trim()) ? "Enter a valid 10-digit number" : null,
                          ),
                          style: GoogleFonts.poppins(fontSize: fontSize),
                          keyboardType: TextInputType.phone,
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 3), // Reduced spacing
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedStateId,
                          hint: Text("Select State", style: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize)),
                          items: states.map((state) => DropdownMenuItem<String>(
                                value: state["id"].toString(),
                                child: Text(state["state_name"] as String, style: GoogleFonts.poppins(fontSize: fontSize)),
                              )).toList(),
                          onChanged: (value) => setState(() => selectedStateId = value),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 8), // Reduced padding
                          ),
                          dropdownColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3), // Reduced spacing
                      Expanded(
                        child: TextField(
                          controller: newValidityController,
                          decoration: InputDecoration(
                            hintText: "Validity (MM/DD/YYYY)",
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 8), // Reduced padding
                            errorText: newValidityController.text.isNotEmpty && !isValidDate(newValidityController.text) ? "Enter a valid future date" : null,
                          ),
                          style: GoogleFonts.poppins(fontSize: fontSize),
                          keyboardType: TextInputType.number,
                          inputFormatters: [DateInputFormatter()],
                          maxLength: 10,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 3), // Reduced spacing
                      Expanded(
                        child: TextField(
                          controller: newDeviceIdController,
                          decoration: InputDecoration(
                            hintText: "Enter Device ID",
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), // Reduced border radius
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 8), // Reduced padding
                          ),
                          style: GoogleFonts.poppins(fontSize: fontSize),
                          keyboardType: TextInputType.text,
                        ),
                      ),
                      const SizedBox(width: 3), // Reduced spacing
                      FloatingActionButton(
                        onPressed: checkUser,
                        backgroundColor: Colors.blue,
                        mini: false,
                        child: Icon(Icons.search, color: Colors.white, size: iconSize),
                      ),
                      const SizedBox(width: 3), // Reduced spacing
                      FloatingActionButton(
                        onPressed: addDemoUser,
                        backgroundColor: primaryColor,
                        mini: false,
                        child: Icon(Icons.add, color: Colors.white, size: iconSize),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _searchUser(String query) {
    if (query.isEmpty) {
      setState(() {
        displayedUsers = List.from(demoUsers);
        highlightedIndex = null;
      });
      return;
    }

    setState(() {
      // Reset the list to the original order
      displayedUsers = List.from(demoUsers);
      highlightedIndex = null;

      // Find the first user that matches the mobile number
      final matchingIndex = displayedUsers.indexWhere((user) {
        final mobileNumber = user['mobile_number'].toString().toLowerCase();
        return mobileNumber.contains(query.toLowerCase());
      });

      if (matchingIndex != -1) {
        // Move the matching user to the top
        final matchingUser = displayedUsers[matchingIndex];
        displayedUsers.removeAt(matchingIndex);
        displayedUsers.insert(0, matchingUser);
        highlightedIndex = 0; // Highlight the first row (index 0 after moving)
      } else {
        _showSnackBar("No matching user found", Colors.red);
      }
    });
  }

  Widget _buildPaginatedDataSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final int totalPages = (displayedUsers.length / itemsPerPage).ceil();

    List<Entity> userEntities = displayedUsers.map((user) {
      String stateName = states.firstWhere(
        (state) => state['id'].toString() == user['state_id'].toString(),
        orElse: () => {'state_name': 'Unknown'},
      )['state_name'];

      String createdAtStr = user['created_at'] ?? '';
      int validityHours = int.tryParse(user['validity'].toString()) ?? 0;
      String validityDateStr = '';
      String status = 'Expired';

      if (createdAtStr.isNotEmpty && validityHours > 0) {
        try {
          DateTime createdAt = DateTime.parse(createdAtStr);
          DateTime validityDate = createdAt.add(Duration(hours: validityHours));
          validityDateStr = validityDate.toString();
          status = DateTime.now().isBefore(validityDate) ? 'Active' : 'Expired';
        } catch (e) {
          validityDateStr = createdAtStr;
          status = 'Unknown';
        }
      } else {
        validityDateStr = createdAtStr;
        status = 'Unknown';
      }

      String deviceIds = user['device_ids']?.toString() ?? '';
      List<String> devices = deviceIds.split(',').where((String d) => d.trim().isNotEmpty).toList();

      return Entity(
        type: status,
        name: user['mobile_number'].toString(),
        code: '',
        state: stateName,
        partner: '',
        package: validityDateStr,
        id: user['id'].toString(),
        devices: devices,
      );
    }).toList();

    if (userEntities.isEmpty) {
      return Center(
        child: Text(
          "No demo users available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    final paginatedEntities = userEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, userEntities.length),
    );

    return Container(
      decoration: BoxDecoration(color: drawerColor, borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columnSpacing: 0,
                            headingRowColor: MaterialStateColor.resolveWith((states) => cardColor),
                            dataRowColor: MaterialStateColor.resolveWith((states) => drawerColor),
                            dataRowHeight: isMobile ? 48 : 56,
                            dividerThickness: 0.5,
                            border: TableBorder(horizontalInside: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5)),
                            columns: [
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 40 : 50,
                                  alignment: Alignment.center,
                                  child: Text('#', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 100 : 120,
                                  alignment: Alignment.center,
                                  child: Text('Status', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text('Mobile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text('State', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 150 : 200,
                                  alignment: Alignment.center,
                                  child: Text('Validity', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 150 : 200,
                                  alignment: Alignment.center,
                                  child: Text('Devices', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                            ],
                            rows: paginatedEntities.asMap().entries.map((entry) {
                              final index = entry.key + 1 + (currentPage - 1) * itemsPerPage;
                              final entity = entry.value;
                              final actualIndex = (currentPage - 1) * itemsPerPage + entry.key; // Calculate the actual index in displayedUsers
                              final isHighlighted = actualIndex == highlightedIndex;

                              return DataRow(
                                color: MaterialStateColor.resolveWith((states) => isHighlighted
                                    ? primaryColor.withOpacity(0.2)
                                    : drawerColor), // Highlight background
                                cells: [
                                  DataCell(
                                    Container(
                                      width: isMobile ? 40 : 50,
                                      alignment: Alignment.center,
                                      decoration: isHighlighted
                                          ? BoxDecoration(
                                              border: Border(
                                                left: BorderSide(color: primaryColor, width: 2),
                                              ),
                                            )
                                          : null,
                                      child: Text('$index', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 100 : 120,
                                      alignment: Alignment.center,
                                      child: Text(entity.type, style: GoogleFonts.poppins(color: entity.type == 'Active' ? Colors.green : Colors.red, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 120 : 150,
                                      alignment: Alignment.center,
                                      child: Text(entity.name, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 120 : 150,
                                      alignment: Alignment.center,
                                      child: Text(entity.state, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 150 : 200,
                                      alignment: Alignment.center,
                                      child: Text(entity.package, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 150 : 200,
                                      alignment: Alignment.center,
                                      child: Text(entity.devices.join(', ') == '' ? 'None' : entity.devices.join(', '), style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 120 : 150,
                                      alignment: Alignment.center,
                                      decoration: isHighlighted
                                          ? BoxDecoration(
                                              border: Border(
                                                right: BorderSide(color: primaryColor, width: 2),
                                              ),
                                            )
                                          : null,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit, color: Colors.cyan[300], size: isMobile ? 18 : 20),
                                            onPressed: () => _showEditDialog(context, entity, isMobile),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red[300], size: isMobile ? 18 : 20),
                                            onPressed: () => _showDeleteConfirmation(context, entity),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: isMobile ? 16 : 24),
              Container(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 18 : 20),
                      onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                    ),
                    Text(
                      'Page $currentPage of $totalPages',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward, color: Colors.white, size: isMobile ? 18 : 20),
                      onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                    ),
                    SizedBox(width: isMobile ? 8 : 10),
                    DropdownButton<int>(
                      value: itemsPerPage,
                      items: [50, 100, 200, 500].map((value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                          )).toList(),
                      onChanged: (value) => setState(() => itemsPerPage = value!),
                      dropdownColor: drawerColor,
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
        ],
      ),
    );
  }

  bool isValidDate(String date) {
    final RegExp apiDateRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$');
    if (apiDateRegExp.hasMatch(date)) {
      try {
        final parsedDate = DateTime.parse(date);
        return parsedDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }

    final RegExp dateRegExp = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegExp.hasMatch(date)) return false;
    try {
      final parts = date.split('/');
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final parsedDate = DateTime(year, month, day);
      return parsedDate.isAfter(DateTime.now().subtract(const Duration(days: 1))) &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31 &&
          year >= DateTime.now().year;
    } catch (e) {
      return false;
    }
  }

  String formatApiDateToInput(String apiDate) {
    try {
      final parsedDate = DateTime.parse(apiDate);
      return '${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.year}';
    } catch (e) {
      return apiDate;
    }
  }

  TimeOfDay parseApiTime(String apiDate) {
    try {
      final parsedDate = DateTime.parse(apiDate);
      return TimeOfDay(hour: parsedDate.hour, minute: parsedDate.minute);
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  void _showEditDialog(BuildContext context, Entity entity, bool isMobile) {
    TextEditingController mobileNumberController = TextEditingController(text: entity.name);
    TextEditingController validityController = TextEditingController(text: formatApiDateToInput(entity.package));
    TimeOfDay editTime = parseApiTime(entity.package);
    String? selectedEditStateId = states.firstWhere(
      (state) => state["state_name"] == entity.state,
      orElse: () => {"id": null},
    )["id"]?.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: drawerColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Edit Demo User',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 16 : 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mobileNumberController,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    errorText: mobileNumberController.text.isNotEmpty &&
                            !RegExp(r'^\d{10}$').hasMatch(mobileNumberController.text.trim())
                        ? "Enter a valid 10-digit number"
                        : null,
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) => setState(() {}),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedEditStateId,
                  hint: Text(
                    "Select State",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                  items: states
                      .map(
                        (state) => DropdownMenuItem<String>(
                          value: state["id"].toString(),
                          child: Text(
                            state["state_name"] as String,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedEditStateId = value),
                  decoration: InputDecoration(
                    labelText: 'State',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: cardColor,
                  ),
                  dropdownColor: drawerColor,
                ),
                SizedBox(height: 12),
                TextField(
                  controller: validityController,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Validity Date (MM/DD/YYYY)',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    errorText: validityController.text.isNotEmpty && !isValidDate(validityController.text)
                        ? "Enter a valid future date"
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [DateInputFormatter()],
                  maxLength: 10,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  onChanged: (value) => setState(() {}),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: editTime,
                    );
                    if (picked != null) {
                      setState(() => editTime = picked);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Select Time: ${editTime.hour.toString().padLeft(2, '0')}:${editTime.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (mobileNumberController.text.isEmpty ||
                    selectedEditStateId == null ||
                    validityController.text.isEmpty) {
                  _showSnackBar("Please fill all fields", Colors.red);
                  return;
                }
                if (!RegExp(r'^\d{10}$').hasMatch(mobileNumberController.text.trim())) {
                  _showSnackBar("Mobile number must be 10 digits", Colors.red);
                  return;
                }
                if (!isValidDate(validityController.text)) {
                  _showSnackBar("Please enter a valid future date", Colors.red);
                  return;
                }
                Navigator.pop(context);
                updateDemoUser(
                  entity,
                  mobileNumberController.text.trim(),
                  selectedEditStateId!,
                  validityController.text.trim(),
                  editTime,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Update',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Entity entity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Demo User',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Are you sure you want to delete user ${entity.name}?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: primaryColor,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteDemoUser(entity.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 4.0 : 8.0), // Reduced padding
        child: Column(
          children: [
            _buildAddSection(screenWidth),
            const SizedBox(height: 4), // Reduced spacing
            Expanded(child: _buildPaginatedDataSection(screenWidth)),
          ],
        ),
      ),
    );
  }
}

class Entity {
  final String type;
  final String name;
  final String code;
  final String state;
  final String partner;
  final String package;
  final String id;
  final List<String> devices;

  Entity({
    required this.type,
    required this.name,
    required this.code,
    required this.state,
    required this.partner,
    required this.package,
    required this.id,
    required this.devices,
  });
}