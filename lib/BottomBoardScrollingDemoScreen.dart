import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BottomBoardScrollingDemoScreen extends StatefulWidget {
  @override
  _BottomBoardScrollingDemoScreenState createState() => _BottomBoardScrollingDemoScreenState();
}

class _BottomBoardScrollingDemoScreenState extends State<BottomBoardScrollingDemoScreen> with SingleTickerProviderStateMixin {
  // Controllers
  TextEditingController boardNameController = TextEditingController();
  TextEditingController timeScheduleController = TextEditingController();
  TextEditingController scrollingNameController = TextEditingController();
  TextEditingController scriptController = TextEditingController();
  TextEditingController mobileNumberController = TextEditingController();

  // Variables
  html.File? selectedBoardFile;
  List<Map<String, dynamic>> bottomBoards = [];
  List<Map<String, dynamic>> scrollingMessages = [];
  List<Map<String, dynamic>> states = [];
  Map<String, dynamic>? selectedState;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  final ScrollController _scrollController = ScrollController();

  // API Endpoints
  final String apiCheckUser = "https://sms.mydreamplaytv.com/check-user.php";
  final String apiGetStates = "https://sms.mydreamplaytv.com/get-states.php";
  final String apiGetBottomBoards = "https://sms.mydreamplaytv.com/get-bottom-boards.php";
  final String apiAddBottomBoard = "https://sms.mydreamplaytv.com/add-bottom-board.php";
  final String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";
  final String apiGetScrollingMessages = "https://sms.mydreamplaytv.com/get-scrolling-messages.php";
  final String apiAddScrollingMessage = "https://sms.mydreamplaytv.com/add_scrolling_message.php";
  final String apiEditScrollingMessage = "https://sms.mydreamplaytv.com/edit-scrolling-message.php";
  final String apiDeleteScrollingMessage = "https://sms.mydreamplaytv.com/delete-scrolling-message.php";

  @override
  void initState() {
    super.initState();
    fetchBottomBoards();
    fetchScrollingMessages();
    fetchStates();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    boardNameController.dispose();
    timeScheduleController.dispose();
    scrollingNameController.dispose();
    scriptController.dispose();
    mobileNumberController.dispose();
    super.dispose();
  }

  String extractJson(String response) {
    int jsonStartIndex = response.indexOf('{');
    return jsonStartIndex != -1 ? response.substring(jsonStartIndex) : response;
  }

  Future<void> fetchStates() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetStates));
      if (response.statusCode == 200) {
        String jsonResponse = extractJson(response.body);
        var data = jsonDecode(jsonResponse);
        if (data["success"]) {
          setState(() {
            states = List<Map<String, dynamic>>.from(data["states"]);
          });
        }
      }
    } catch (e) {
      print("Error fetching states: $e");
      _showSnackBar("Failed to fetch states", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> checkUser() async {
    if (mobileNumberController.text.isEmpty || selectedState == null) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse('$apiCheckUser?mobile_number=${mobileNumberController.text.trim()}&state_name=${selectedState!["state_name"]}');
      var response = await http.get(uri);

      if (response.statusCode == 200) {
        String jsonResponse = extractJson(response.body);
        var data = jsonDecode(jsonResponse);
        _showSnackBar(data["message"] ?? "No message provided", data["success"] ? Colors.green : Colors.red);

        if (data["success"] == true && data["data"] is Map) {
          if (data["data"]["status"] == "active") {
            String validUntil = data["data"]["validity_date"] ?? "Unknown";
            _showSnackBar("User ${data["data"]["mobile_number"]} is active until $validUntil", Colors.green);
          } else {
            mobileNumberController.clear();
            setState(() => selectedState = null);
            String packageName = data["data"]["default_pack"] ?? "Unknown";
            List channels = data["data"]["package_list"] ?? [];
            String validUntil = data["data"]["validity_date"] ?? "Unknown";
            _showSnackBar("Registered: Package: $packageName, Channels: ${channels.length}, Until: $validUntil", Colors.green);
          }
        } else if (data["data"] != null && data["data"]["status"] == "expired") {
          String expiredOn = data["data"]["expired_on"] ?? "Unknown";
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text("Account Expired", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
              content: Text("User ${data["data"]["mobile_number"]} account expired on $expiredOn."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK", style: TextStyle(color: Colors.blue[700])),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print("Error checking user: $e");
      _showSnackBar("Error processing request: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<String?> uploadFile(html.File file, String type) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUploadFile));
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final fileBytes = reader.result as List<int>;
      final multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: file.name);
      request.files.add(multipartFile);
      request.fields['type'] = type;
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        String jsonResponse = extractJson(responseData);
        var data = jsonDecode(jsonResponse);
        if (data["success"]) return data["file_name"];
      }
      return null;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  Future<void> fetchBottomBoards() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetBottomBoards));
      if (response.statusCode == 200) {
        String jsonResponse = extractJson(response.body);
        var data = jsonDecode(jsonResponse);
        if (data["success"]) {
          setState(() {
            bottomBoards = List<Map<String, dynamic>>.from(data["boards"]);
          });
        }
      }
    } catch (e) {
      print("Error fetching bottom boards: $e");
      _showSnackBar("Failed to fetch bottom boards", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> addBottomBoard() async {
    if (boardNameController.text.isEmpty || timeScheduleController.text.isEmpty || selectedBoardFile == null) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }

    setState(() => isLoading = true);
    String? fileName = await uploadFile(selectedBoardFile!, "board");
    if (fileName == null) {
      setState(() => isLoading = false);
      _showSnackBar("Failed to upload file", Colors.red);
      return;
    }

    try {
      var response = await http.post(
        Uri.parse(apiAddBottomBoard),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "board_name": boardNameController.text.trim(),
          "time_schedule": timeScheduleController.text.trim(),
          "file_name": fileName,
        }),
      );

      String jsonResponse = extractJson(response.body);
      var data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);

      if (data["success"]) {
        boardNameController.clear();
        timeScheduleController.clear();
        selectedBoardFile = null;
        fetchBottomBoards();
      }
    } catch (e) {
      print("Error adding bottom board: $e");
      _showSnackBar("Error adding bottom board", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> fetchScrollingMessages() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetScrollingMessages));
      if (response.statusCode == 200) {
        String jsonResponse = extractJson(response.body);
        var data = jsonDecode(jsonResponse);
        if (data["success"]) {
          setState(() {
            scrollingMessages = List<Map<String, dynamic>>.from(data["messages"]);
          });
        }
      }
    } catch (e) {
      print("Error fetching scrolling messages: $e");
      _showSnackBar("Failed to fetch scrolling messages", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> addScrollingMessage() async {
    if (scrollingNameController.text.isEmpty || scriptController.text.isEmpty || timeScheduleController.text.isEmpty) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      var response = await http.post(
        Uri.parse(apiAddScrollingMessage),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "scrolling_name": scrollingNameController.text.trim(),
          "script": scriptController.text.trim(),
          "time_schedule": timeScheduleController.text.trim(),
        }),
      );

      String jsonResponse = extractJson(response.body);
      var data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);

      if (data["success"]) {
        scrollingNameController.clear();
        scriptController.clear();
        timeScheduleController.clear();
        fetchScrollingMessages();
      }
    } catch (e) {
      print("Error adding scrolling message: $e");
      _showSnackBar("Error adding scrolling message", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          timeScheduleController.text = "${fullDateTime.toLocal()}".split('.')[0];
        });
      }
    }
  }

  Future<void> pickFile(String type) async {
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.multiple = false;
    uploadInput.accept = '*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        setState(() {
          if (type == "board") selectedBoardFile = file;
        });
      }
    });
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

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[900]!, Colors.blue[600]!, Colors.blue[300]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Control Panel",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 4)],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.white, size: 28),
                            onPressed: () {
                              fetchBottomBoards();
                              fetchScrollingMessages();
                              fetchStates();
                            },
                            tooltip: "Refresh All",
                          ),
                          IconButton(
                            icon: Icon(Icons.arrow_downward, color: Colors.white, size: 28),
                            onPressed: _scrollToBottom,
                            tooltip: "Scroll Down",
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildUnifiedManagementCard(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bottom Boards",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      isLoading
                          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : bottomBoards.isEmpty
                              ? Center(child: Text("No bottom boards available.", style: TextStyle(color: Colors.white70)))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: bottomBoards.length,
                                  itemBuilder: (context, index) {
                                    var board = bottomBoards[index];
                                    return _buildListCard(board["board_name"], "Schedule: ${board["time_schedule"]}");
                                  },
                                ),
                      SizedBox(height: 16),
                      Text(
                        "Scrolling Messages",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      isLoading
                          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : scrollingMessages.isEmpty
                              ? Text("No scrolling messages available.", style: TextStyle(color: Colors.white70))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: scrollingMessages.length,
                                  itemBuilder: (context, index) {
                                    var message = scrollingMessages[index];
                                    return _buildListCard(message["scrolling_name"], "Script: ${message["script"]}");
                                  },
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

  Widget _buildUnifiedManagementCard() {
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
              "Manage Bottom Boards & Messages",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
            SizedBox(height: 12),
            ExpansionTile(
              title: Text("Add Bottom Board", style: TextStyle(fontSize: 14, color: Colors.blue[700])),
              children: [
                _buildTextField(boardNameController, "Board Name"),
                SizedBox(height: 8),
                _buildDateTimeField(),
                SizedBox(height: 8),
                _buildFilePickerButton("board", selectedBoardFile, "Board File"),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActionButton("Add Board", addBottomBoard),
                ),
              ],
            ),
            Divider(color: Colors.grey[300], thickness: 1),
            ExpansionTile(
              title: Text("Add Scrolling Message", style: TextStyle(fontSize: 14, color: Colors.blue[700])),
              children: [
                _buildTextField(scrollingNameController, "Scrolling Name"),
                SizedBox(height: 8),
                _buildTextField(scriptController, "Script", maxLines: 3),
                SizedBox(height: 8),
                _buildDateTimeField(),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActionButton("Add Message", addScrollingMessage),
                ),
              ],
            ),
            Divider(color: Colors.grey[300], thickness: 1),
            ExpansionTile(
              title: Text("Check/Register Demo User", style: TextStyle(fontSize: 14, color: Colors.blue[700])),
              children: [
                _buildTextField(mobileNumberController, "Mobile Number"),
                SizedBox(height: 8),
                _buildDropdown(),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActionButton("Check/Register", checkUser),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blue[700], fontSize: 12),
        prefixIcon: Icon(Icons.edit, color: Colors.blue[700], size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }

  Widget _buildDateTimeField() {
    return InkWell(
      onTap: () => _selectDateTime(context),
      child: IgnorePointer(
        child: TextField(
          controller: timeScheduleController,
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: "Date and Time",
            labelStyle: TextStyle(color: Colors.blue[700], fontSize: 12),
            prefixIcon: Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: selectedState,
      hint: Text("Select State", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      onChanged: (val) => setState(() => selectedState = val),
      items: states.map((state) => DropdownMenuItem(value: state, child: Text(state["state_name"], style: TextStyle(fontSize: 12)))).toList(),
      decoration: InputDecoration(
        labelText: "State",
        labelStyle: TextStyle(color: Colors.blue[700], fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }

  Widget _buildFilePickerButton(String type, html.File? file, String label) {
    return AnimatedBuilder(
      animation: _buttonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue[600]!, Colors.blue[400]!]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
            ),
            child: ElevatedButton(
              onPressed: () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                  pickFile(type);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                file != null ? file.name : label,
                style: TextStyle(fontSize: 12, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return AnimatedBuilder(
      animation: _buttonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green[700]!, Colors.green[500]!]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
            ),
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      _animationController.forward().then((_) {
                        _animationController.reverse();
                        onPressed();
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListCard(String title, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          title: Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue[900]),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}