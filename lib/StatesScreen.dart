
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class StatesScreen extends StatefulWidget {
  final String? username;
  const StatesScreen({this.username, super.key});

  @override
  _StatesScreenState createState() => _StatesScreenState();
}

class _StatesScreenState extends State<StatesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> states = [];
  TextEditingController newNameController = TextEditingController();
  PlatformFile? splashScreenFile;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;

  static const Color primaryColor = Color(0xFF00897B);
  static const Color secondaryColor = Color(0xFFFFCA28);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);
  static const Color cardColor = Color(0xFF455A64);

  static const String apiGetStates = "https://sms.mydreamplaytv.com/get-states.php";
  static const String apiAddState = "https://sms.mydreamplaytv.com/add-state.php";
  static const String apiUpdateState = "https://sms.mydreamplaytv.com/update-state.php";
  static const String apiDeleteState = "https://sms.mydreamplaytv.com/delete-state.php";
  static const String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";
  static const String baseImageUrl = "https://sms.mydreamplaytv.com/uploads/"; // Aligned with backend

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchStates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newNameController.dispose();
    super.dispose();
  }

  String extractJson(String response) {
    response = response.trim();
    if (response.isEmpty) return "{}";
    if (!response.startsWith('{') && !response.startsWith('[')) {
      print("Invalid JSON response: $response");
      return "{}";
    }
    return response;
  }

  Future<void> fetchStates() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetStates));
      print("API Response: ${response.body}");
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty && jsonResponse != "{}") {
          final data = jsonDecode(jsonResponse);
          if (data["success"] == true) {
            setState(() => states = List<Map<String, dynamic>>.from(data["states"] ?? []));
          } else {
            _showSnackBar("No states found", Colors.orange);
          }
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error fetching states: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<Map<String, String>?> uploadFile(PlatformFile file) async {
    var request = http.MultipartRequest("POST", Uri.parse(apiUploadFile));
    request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
    request.fields['type'] = 'state';
    try {
      print("Uploading file: ${file.name}");
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      print("Upload response: $responseData");
      final String jsonResponse = extractJson(responseData);
      final jsonData = jsonDecode(jsonResponse);
      if (jsonData["success"]) {
        final fileName = jsonData["file_name"];
        final url = "$baseImageUrl$fileName";
        print("Uploaded file: $fileName, URL: $url");
        return {
          "file_name": fileName,
          "url": url,
        };
      }
      _showSnackBar("Upload failed: ${jsonData["message"] ?? "Unknown error"}", Colors.red);
      return null;
    } catch (e) {
      print("Upload error: $e");
      _showSnackBar("Error uploading file: $e", Colors.red);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFileAsBase64(String fileUrl, String fileExtension) async {
    try {
      print("Original file URL: $fileUrl");
      final fileName = fileUrl.split('/').last;
      final fetchUrl = "$apiUploadFile?file_name=$fileName";
      print("Fetching file from URL: $fetchUrl");
      final response = await http.get(Uri.parse(fetchUrl));
      print("Fetch response status: ${response.statusCode}");
      if (response.statusCode == 200) {
        return {'data': base64Encode(response.bodyBytes)};
      }
      return {'error': 'Failed to fetch file (status: ${response.statusCode})'};
    } catch (e) {
      print("Fetch error: $e");
      return {'error': e.toString()};
    }
  }

  Future<void> addState() async {
    if (newNameController.text.isEmpty) {
      _showSnackBar("Please enter a state name", Colors.red);
      return;
    }
    if (splashScreenFile == null) {
      _showSnackBar("Please select a splash screen", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      Map<String, String>? fileData = await uploadFile(splashScreenFile!);
      if (fileData == null) {
        _showSnackBar("Failed to upload splash screen", Colors.red);
        setState(() => isLoading = false);
        return;
      }
      String splashScreenName = fileData["file_name"]!;

      final response = await http.post(
        Uri.parse(apiAddState),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "state_name": newNameController.text.trim(),
          "splash_screen": splashScreenName,
        }),
      );
      final String jsonResponse = extractJson(response.body);
      if (jsonResponse.isEmpty || jsonResponse == "{}") {
        _showSnackBar("Invalid response from server", Colors.red);
        return;
      }
      final data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"] ?? "State added", data["success"] == true ? Colors.green : Colors.red);
      if (data["success"] == true) {
        newNameController.clear();
        setState(() => splashScreenFile = null);
        await fetchStates();
      }
    } catch (e) {
      _showSnackBar("Error adding state: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> updateState(String id, String newName, PlatformFile? newSplashFile) async {
    if (newName.isEmpty) {
      _showSnackBar("Please enter a state name", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      String? splashScreenName;
      if (newSplashFile != null) {
        Map<String, String>? fileData = await uploadFile(newSplashFile);
        if (fileData == null) {
          _showSnackBar("Failed to upload splash screen", Colors.red);
          setState(() => isLoading = false);
          return;
        }
        splashScreenName = fileData["file_name"];
      }

      final response = await http.post(
        Uri.parse(apiUpdateState),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": id,
          "state_name": newName.trim(),
          "splash_screen": splashScreenName ?? '',
        }),
      );
      final String jsonResponse = extractJson(response.body);
      if (jsonResponse.isEmpty || jsonResponse == "{}") {
        _showSnackBar("Invalid response from server", Colors.red);
        return;
      }
      final data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"] ?? "State updated", data["success"] == true ? Colors.green : Colors.red);
      if (data["success"] == true) await fetchStates();
    } catch (e) {
      _showSnackBar("Error updating state: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteState(String id) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(apiDeleteState),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      print("Delete response: ${response.body}");
      final String jsonResponse = extractJson(response.body);
      if (jsonResponse.isEmpty || jsonResponse == "{}") {
        _showSnackBar("Failed to delete state: Invalid response from server", Colors.red);
        return;
      }
      final data = jsonDecode(jsonResponse);
      if (data["success"] == true) {
        _showSnackBar(data["message"] ?? "State deleted successfully", Colors.green);
        await fetchStates();
      } else {
        _showSnackBar(data["message"] ?? "Failed to delete state", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error deleting state: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> pickSplashFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => splashScreenFile = result.files.first);
    }
  }

  void _showFileDialog(BuildContext context, {PlatformFile? file, String? fileUrl, String? fileName, bool isMobile = false}) {
    if (file == null && (fileUrl == null || fileUrl.isEmpty)) {
      _showSnackBar("No splash screen available", Colors.red);
      return;
    }

    String displayFileName = file != null ? file.name : fileName ?? 'Unknown';
    String fileExtension = displayFileName.split('.').last.toLowerCase();
    bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileExtension);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('View File: $displayFileName', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isMobile ? 16 : 18)),
        content: SingleChildScrollView(
          child: file != null
              ? isImage
                  ? Image.memory(
                      file.bytes!,
                      width: isMobile ? 300 : 500,
                      height: isMobile ? 200 : 300,
                      fit: BoxFit.contain,
                    )
                  : Text(
                      'Cannot preview: $fileExtension',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14),
                    )
              : FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchFileAsBase64(fileUrl!, fileExtension),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {
                      return Column(children: [
                        Text('Error: ${snapshot.data?['error'] ?? 'Unknown'}', style: GoogleFonts.poppins(color: Colors.red, fontSize: isMobile ? 12 : 14)),
                        ElevatedButton.icon(
                          onPressed: () => _downloadFile(fileUrl),
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ]);
                    }
                    final base64Data = snapshot.data!['data'] as String;
                    if (isImage) {
                      return Image.memory(
                        base64Decode(base64Data),
                        width: isMobile ? 300 : 500,
                        height: isMobile ? 200 : 300,
                        fit: BoxFit.contain,
                      );
                    }
                    return Column(children: [
                      Text('Cannot preview: $fileExtension', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                      ElevatedButton.icon(
                        onPressed: () => _downloadFile(fileUrl),
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ]);
                  },
                ),
        ),
        actions: [
          if (fileUrl != null)
            ElevatedButton.icon(
              onPressed: () => _downloadFile(fileUrl),
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
          ),
        ],
      ),
    );
  }

  void _downloadFile(String url) {
    print("Downloading file from: $url");
    // Implement download logic if needed
  }

  void _showEditDialog(Entity entity) {
    final TextEditingController editNameController = TextEditingController(text: entity.name);
    PlatformFile? newSplashFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: drawerColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Edit State",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editNameController,
                  decoration: InputDecoration(
                    hintText: "Enter State Name",
                    hintStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: cardColor,
                  ),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        newSplashFile != null
                            ? newSplashFile!.name
                            : entity.file.isNotEmpty
                                ? entity.file
                                : "No splash screen",
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.upload_file, color: primaryColor, size: 20),
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (result != null && result.files.isNotEmpty) {
                          setState(() => newSplashFile = result.files.first);
                        }
                      },
                    ),
                    if (newSplashFile != null || entity.file.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.visibility, color: Colors.green[300], size: 20),
                        onPressed: () => _showFileDialog(
                          context,
                          file: newSplashFile,
                          fileUrl: entity.file.isNotEmpty ? "$baseImageUrl${entity.file}" : null,
                          fileName: newSplashFile != null ? newSplashFile!.name : entity.file,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                updateState(entity.id, editNameController.text, newSplashFile);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                "Save",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          "Delete State",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this state?",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              deleteState(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedDataSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final int totalPages = (states.length / itemsPerPage).ceil();
    List<Entity> stateEntities = states.map((state) => Entity(
          type: 'State',
          name: state['state_name'] ?? 'N/A',
          code: '',
          state: state['state_name'] ?? 'N/A',
          partner: '',
          file: state['splash_screen'] ?? '',
          package: '',
          id: state['id']?.toString() ?? '0',
        )).toList();

    if (stateEntities.isEmpty) {
      return Center(
        child: Text(
          "No states available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    List<Entity> paginatedEntities = stateEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, stateEntities.length),
    );

    return Container(
      decoration: BoxDecoration(
        color: drawerColor,
        borderRadius: BorderRadius.circular(8),
      ),
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
                        child: DataTable(
                          columnSpacing: 0,
                          headingRowColor: MaterialStateColor.resolveWith((states) => cardColor),
                          dataRowColor: MaterialStateColor.resolveWith((states) => drawerColor),
                          dataRowHeight: isMobile ? 48 : 56,
                          dividerThickness: 0.5,
                          border: TableBorder(
                            horizontalInside: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
                          ),
                          columns: [
                            DataColumn(
                              label: Container(
                                width: isMobile ? 40 : 50,
                                alignment: Alignment.center,
                                child: Text(
                                  '#',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 150 : 200,
                                alignment: Alignment.center,
                                child: Text(
                                  'Name',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 150 : 200,
                                alignment: Alignment.center,
                                child: Text(
                                  'Splash Screen',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 60 : 80,
                                alignment: Alignment.center,
                                child: Text(
                                  'Update',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 60 : 80,
                                alignment: Alignment.center,
                                child: Text(
                                  'Delete',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: paginatedEntities.asMap().entries.map((entry) {
                            int index = entry.key + 1 + (currentPage - 1) * itemsPerPage;
                            final entity = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    width: isMobile ? 40 : 50,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$index',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: isMobile ? 12 : 14,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: isMobile ? 150 : 200,
                                    alignment: Alignment.center,
                                    child: Text(
                                      entity.name,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: isMobile ? 12 : 14,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: isMobile ? 150 : 200,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entity.file.isEmpty ? 'None' : entity.file,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: isMobile ? 12 : 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (entity.file.isNotEmpty)
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility,
                                              color: Colors.green[300],
                                              size: isMobile ? 18 : 20,
                                            ),
                                            onPressed: () => _showFileDialog(
                                              context,
                                              fileUrl: "$baseImageUrl${entity.file}",
                                              fileName: entity.file,
                                              isMobile: isMobile,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: isMobile ? 60 : 80,
                                    alignment: Alignment.center,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.cyan[300],
                                        size: isMobile ? 18 : 20,
                                      ),
                                      onPressed: () => _showEditDialog(entity),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: isMobile ? 60 : 80,
                                    alignment: Alignment.center,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                        size: isMobile ? 18 : 20,
                                      ),
                                      onPressed: () => _showDeleteDialog(entity.id),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: isMobile ? 8 : 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 18 : 20),
                    onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                  ),
                  Text(
                    'Page $currentPage of $totalPages',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward, color: Colors.white, size: isMobile ? 18 : 20),
                    onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  DropdownButton<int>(
                    value: itemsPerPage,
                    items: const [50, 100, 200, 500]
                        .map((value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value', style: TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => itemsPerPage = value!),
                    dropdownColor: drawerColor,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isMobile = screenWidth < 600;
        final double padding = isMobile ? 8.0 : 16.0;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: padding,
                right: padding,
                top: padding,
                bottom: padding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "",
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: primaryColor,
                          size: isMobile ? 24 : 28,
                        ),
                        onPressed: fetchStates,
                        tooltip: "Refresh Data",
                      ),
                    ],
                  ),
                  SizedBox(height: padding),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Add New State",
                            style: GoogleFonts.poppins(
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: padding / 2),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: newNameController,
                                  decoration: InputDecoration(
                                    hintText: "Enter State Name",
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(width: 1),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: isMobile ? 8 : 10,
                                      horizontal: 12,
                                    ),
                                  ),
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ),
                              SizedBox(width: padding / 2),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        splashScreenFile != null ? splashScreenFile!.name : "No splash screen",
                                        style: GoogleFonts.poppins(
                                          fontSize: isMobile ? 12 : 14,
                                          color: splashScreenFile != null ? Colors.black : Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.upload_file,
                                        color: primaryColor,
                                        size: isMobile ? 18 : 20,
                                      ),
                                      onPressed: pickSplashFile,
                                    ),
                                    if (splashScreenFile != null)
                                      IconButton(
                                        icon: Icon(
                                          Icons.visibility,
                                          color: Colors.green[300],
                                          size: isMobile ? 18 : 20,
                                        ),
                                        onPressed: () => _showFileDialog(
                                          context,
                                          file: splashScreenFile,
                                          fileName: splashScreenFile!.name,
                                          isMobile: isMobile,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: padding / 2),
                              FloatingActionButton(
                                onPressed: addState,
                                backgroundColor: primaryColor,
                                mini: isMobile,
                                child: Icon(Icons.add, color: Colors.white, size: isMobile ? 18 : 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: padding),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: _buildPaginatedDataSection(screenWidth),
              ),
            ),
          ],
        );
      },
    );
  }
}

class Entity {
  final String type;
  final String name;
  final String code;
  final String state;
  final String partner;
  final String file;
  final String package;
  final String id;

  const Entity({
    required this.type,
    required this.name,
    required this.code,
    required this.state,
    required this.partner,
    required this.file,
    required this.package,
    required this.id,
  });
}