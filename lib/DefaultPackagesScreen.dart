import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class DefaultPackagesScreen extends StatefulWidget {
  final String? username;
  const DefaultPackagesScreen({this.username, super.key});

  @override
  _DefaultPackagesScreenState createState() => _DefaultPackagesScreenState();
}

class _DefaultPackagesScreenState extends State<DefaultPackagesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> defaultPackages = [];
  List<Map<String, dynamic>> states = [];
  TextEditingController newNameController = TextEditingController();
  TextEditingController newSelectStateController = TextEditingController();
  PlatformFile? newFile;
  Map<String, String> originalFileNames = {};
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;

  // Color scheme matching StatesScreen
  static const Color primaryColor = Color(0xFF00897B);
  static const Color secondaryColor = Color(0xFFFFCA28);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);
  static const Color cardColor = Color(0xFF455A64);

  static const String apiGetDefaultPackages = "https://sms.mydreamplaytv.com/get-default-packages.php";
  static const String apiAddDefaultPackage = "https://sms.mydreamplaytv.com/add-default-package.php";
  static const String apiUpdateDefaultPackage = "https://sms.mydreamplaytv.com/update-default-package.php";
  static const String apiDeleteDefaultPackage = "https://sms.mydreamplaytv.com/delete-default-package.php";
  static const String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";
  static const String baseImageUrl = "https://sms.mydreamplaytv.com/public_html/uploads/";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchDefaultPackages();
    fetchStates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newNameController.dispose();
    newSelectStateController.dispose();
    super.dispose();
  }

  String extractJson(String response) {
    final int jsonStartIndex = response.indexOf('{');
    return jsonStartIndex != -1 ? response.substring(jsonStartIndex) : "{}";
  }

  Future<void> fetchDefaultPackages() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetDefaultPackages));
      print("Response status: ${response.statusCode}, Body: ${response.body}");
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        print("Extracted JSON: $jsonResponse");
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          print("Decoded data: $data");
          if (data["success"]) {
            setState(() => defaultPackages = List<Map<String, dynamic>>.from(data["packages"]));
          } else {
            _showSnackBar("No default packages found", Colors.orange);
          }
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error fetching default packages: $e", Colors.red);
    }
    setState(() => isLoading = false);
    print("Default packages after fetch: $defaultPackages");
  }

  Future<void> fetchStates() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-states.php"));
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          if (data["success"]) {
            setState(() => states = List<Map<String, dynamic>>.from(data["states"]));
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

  Future<void> addDefaultPackage() async {
    if (newNameController.text.isEmpty || newSelectStateController.text.isEmpty || newFile == null) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    final String? fileName = await uploadFile(newFile!);
    if (fileName == null) {
      setState(() => isLoading = false);
      _showSnackBar("Failed to upload file", Colors.red);
      return;
    }
    try {
      final state = states.firstWhere((s) => s["state_name"] == newSelectStateController.text);
      final response = await http.post(
        Uri.parse(apiAddDefaultPackage),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "package_name": newNameController.text.trim(),
          "state_id": state["id"].toString(),
          "file_name": fileName,
        }),
      );
      final String jsonResponse = extractJson(response.body);
      final data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) {
        newNameController.clear();
        newSelectStateController.clear();
        setState(() => newFile = null);
        await fetchDefaultPackages();
      }
    } catch (e) {
      _showSnackBar("Error adding default package: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> updateDefaultPackage(Entity entity, String newName, String newState, PlatformFile? newFile) async {
    setState(() => isLoading = true);
    String? fileName = entity.file;
    if (newFile != null) {
      fileName = await uploadFile(newFile);
      if (fileName == null) {
        setState(() => isLoading = false);
        _showSnackBar("Failed to upload new file", Colors.red);
        return;
      }
    }
    try {
      final state = states.firstWhere((s) => s["state_name"] == newState);
      final response = await http.post(
        Uri.parse(apiUpdateDefaultPackage),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": entity.id,
          "package_name": newName,
          "state_id": state["id"].toString(),
          "file_name": fileName,
        }),
      );
      final String jsonResponse = extractJson(response.body);
      final data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchDefaultPackages();
    } catch (e) {
      _showSnackBar("Error updating default package: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> deleteDefaultPackage(String id) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(apiDeleteDefaultPackage),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      final String jsonResponse = extractJson(response.body);
      final data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchDefaultPackages();
    } catch (e) {
      _showSnackBar("Error deleting default package: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String?> uploadFile(PlatformFile file) async {
    final request = http.MultipartRequest("POST", Uri.parse(apiUploadFile));
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      file.bytes!,
      filename: file.name,
    );
    request.files.add(multipartFile);
    request.fields['type'] = "default_package";
    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final String jsonResponse = extractJson(responseData);
      final jsonData = jsonDecode(jsonResponse);
      if (jsonData["success"]) {
        setState(() => originalFileNames[jsonData["file_name"]] = file.name);
        return jsonData["file_name"];
      }
      return null;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => newFile = result.files.first);
      }
    } catch (e) {
      _showSnackBar("Error picking file: $e", Colors.red);
    }
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

  void _showEditDialog(BuildContext context, Entity entity) {
    final TextEditingController nameController = TextEditingController(text: entity.name);
    final TextEditingController stateController = TextEditingController(text: entity.state);
    PlatformFile? updatedFile;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Edit Default Package',
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
                controller: nameController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: stateController.text,
                items: states.map((state) => DropdownMenuItem<String>(
                  value: state['state_name'] as String,
                  child: Text(
                    state['state_name'] as String,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  ),
                )).toList(),
                onChanged: (value) => stateController.text = value!,
                decoration: InputDecoration(
                  labelText: 'State',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                ),
                dropdownColor: drawerColor,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: updatedFile?.name ?? cleanFileName(entity.file)),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'File',
                        labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: cardColor,
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        allowMultiple: false,
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        updatedFile = result.files.first;
                        setState(() {});
                      }
                    },
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
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              updateDefaultPackage(entity, nameController.text, stateController.text, updatedFile);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
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
          'Confirm Deletion',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Are you sure you want to delete default package "${entity.name}"?',
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
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              deleteDefaultPackage(entity.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
Future<Map<String, dynamic>?> _fetchFileAsBase64(String fileUrl, String fileExtension) async {
  try {
    // Use a proxy endpoint that can fetch the file for us
    final proxyUrl = "$apiUploadFile?file_name=${Uri.encodeComponent(fileUrl.split('/').last)}";
    print("Fetching file via proxy API: $proxyUrl");

    final response = await http.get(Uri.parse(proxyUrl));
    print("Proxy API response status: ${response.statusCode}");

    if (response.statusCode == 200) {
      final base64Data = base64Encode(response.bodyBytes);
      return {'data': base64Data};
    } else {
      print("Failed to fetch file via proxy, status: ${response.statusCode}");
      return {'error': 'Failed to fetch file (status: ${response.statusCode})'};
    }
  } catch (e) {
    print("Error fetching file via proxy: $e");
    return {'error': e.toString()};
  }
}

void _showFileDialog(BuildContext context, Entity entity) {
  if (entity.file == 'N/A') {
    _showSnackBar("No file available for this package", Colors.red);
    return;
  }

  // Get the raw file data from the package
  final package = defaultPackages.firstWhere(
    (pkg) => pkg['id'].toString() == entity.id,
    orElse: () => {'file_name': 'N/A'}
  );
  
  String fileName = package['file_name'] ?? 'N/A';
  String fileUrl = fileName.startsWith('http') 
      ? fileName.replaceAll('/public_html', '')
      : "$baseImageUrl$fileName";

  print("Constructed file URL: $fileUrl");

  String fileExtension = fileName.split('.').last.toLowerCase();
  bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileExtension);
  bool isTextFile = ['txt', 'm3u', 'log', 'csv'].contains(fileExtension);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: drawerColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'View File: ${cleanFileName(entity.file)}',
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
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchFileAsBase64(fileUrl, fileExtension),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {
                  String errorMessage = snapshot.data?['error'] ?? 'Unknown error';
                  return Column(
                    children: [
                      Text(
                        'Error loading file: $errorMessage',
                        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _downloadFile(fileUrl, cleanFileName(entity.file)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Download File',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                }

                final base64Data = snapshot.data!['data'] as String;
                
                if (isImage) {
                  return Image.memory(
                    base64Decode(base64Data),
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  );
                } else if (isTextFile) {
                  return Container(
                    width: 300,
                    height: 300,
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      child: Text(
                        utf8.decode(base64Decode(base64Data)),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  );
                } else {
                  return Column(
                    children: [
                      Text(
                        'File type not previewable ($fileExtension)',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _downloadFile(fileUrl, cleanFileName(entity.file)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Download File',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}Future<void> _downloadFile(String url, String fileName) async {
  try {
    // For web, we need to create an anchor tag and trigger click
    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
  } catch (e) {
    _showSnackBar("Error downloading file: $e", Colors.red);
  }
}
  String cleanFileName(String fileName) {
    final String baseName = fileName.split('/').last;
    String cleanedName = baseName.replaceFirst(RegExp(r'^[0-9a-f]{16}[-_]?'), '');
    cleanedName = cleanedName.replaceFirst(RegExp(r'^(splash_|logo_|board_|file_)'), '');
    return cleanedName.isEmpty ? baseName : cleanedName;
  }

  Widget _buildAddSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final double padding = isMobile ? 8.0 : 16.0;
    final double fontSize = isMobile ? 12 : 14;
    final double iconSize = isMobile ? 18 : 20;
    final double fieldWidth = isMobile ? 120 : double.infinity; // Fixed width on mobile, stretch on larger screens

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        width: double.infinity, // Ensure the Card spans the full width
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Add New Default Package",
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            SizedBox(height: padding),
            LayoutBuilder(
              builder: (context, constraints) {
                if (isMobile) {
                  // Mobile layout: Scrollable Row with fixed-width fields
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: newNameController,
                            decoration: InputDecoration(
                              hintText: "Enter Name",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
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
                            style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                          ),
                        ),
                        SizedBox(width: padding),
                        Container(
                          width: fieldWidth,
                          child: DropdownButtonFormField<String>(
                            value: newSelectStateController.text.isEmpty ? null : newSelectStateController.text,
                            hint: Text(
                              "Select State",
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                            ),
                            items: states.map((state) => DropdownMenuItem<String>(
                              value: state["state_name"] as String,
                              child: Text(
                                state["state_name"] as String,
                                style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                              ),
                            )).toList(),
                            onChanged: (value) => setState(() => newSelectStateController.text = value!),
                            decoration: InputDecoration(
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
                            dropdownColor: Colors.white,
                            style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                          ),
                        ),
                        SizedBox(width: padding),
                        Container(
                          width: fieldWidth,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(text: newFile?.name ?? ""),
                                  decoration: InputDecoration(
                                    hintText: "Upload File",
                                    hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
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
                                  style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                                  readOnly: true,
                                ),
                              ),
                              SizedBox(width: padding / 2),
                              IconButton(
                                icon: Icon(Icons.attach_file, color: Colors.black, size: iconSize),
                                onPressed: pickFile,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: padding),
                        FloatingActionButton(
                          onPressed: addDefaultPackage,
                          backgroundColor: primaryColor,
                          mini: isMobile,
                          child: Icon(Icons.add, color: Colors.white, size: iconSize),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Larger screens: Row with Expanded fields to stretch across the width
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newNameController,
                          decoration: InputDecoration(
                            hintText: "Enter Name",
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
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
                          style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: newSelectStateController.text.isEmpty ? null : newSelectStateController.text,
                          hint: Text(
                            "Select State",
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                          ),
                          items: states.map((state) => DropdownMenuItem<String>(
                            value: state["state_name"] as String,
                            child: Text(
                              state["state_name"] as String,
                              style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                            ),
                          )).toList(),
                          onChanged: (value) => setState(() => newSelectStateController.text = value!),
                          decoration: InputDecoration(
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
                          dropdownColor: Colors.white,
                          style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: newFile?.name ?? ""),
                                decoration: InputDecoration(
                                  hintText: "Upload File",
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
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
                                style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
                                readOnly: true,
                              ),
                            ),
                            SizedBox(width: padding / 2),
                            IconButton(
                              icon: Icon(Icons.attach_file, color: Colors.black, size: iconSize),
                              onPressed: pickFile,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: padding),
                      FloatingActionButton(
                        onPressed: addDefaultPackage,
                        backgroundColor: primaryColor,
                        mini: isMobile,
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

  Widget _buildPaginatedDataSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final int totalPages = (defaultPackages.length / itemsPerPage).ceil();
    final List<Entity> packageEntities = defaultPackages.map((pkg) {
      final state = states.firstWhere(
        (s) => s['id'].toString() == pkg['state_id'].toString(),
        orElse: () => {'state_name': 'N/A'},
      );
      final fileName = pkg['file_name'] ?? 'N/A';
      return Entity(
        type: 'Default Package',
        name: pkg['package_name'] ?? 'N/A',
        code: '',
        state: state['state_name'],
        partner: '',
        file: fileName,
        package: pkg['package_name'] ?? 'N/A',
        id: pkg['id'].toString(),
      );
    }).toList();

    if (packageEntities.isEmpty) {
      return Center(
        child: Text(
          "No default packages available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    final List<Entity> paginatedEntities = packageEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, packageEntities.length),
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
                                width: isMobile ? 120 : 150,
                                alignment: Alignment.center,
                                child: Text(
                                  'State',
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
                                  'File',
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
                                width: isMobile ? 150 : 180,
                                alignment: Alignment.center,
                                child: Text(
                                  'Actions',
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
                                    width: isMobile ? 120 : 150,
                                    alignment: Alignment.center,
                                    child: Text(
                                      entity.state,
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
                                    child: Text(
                                      cleanFileName(entity.file),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: isMobile ? 12 : 14,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    width: isMobile ? 150 : 180,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.visibility,
                                            color: Colors.green[300],
                                            size: isMobile ? 18 : 20,
                                          ),
                                          onPressed: () => _showFileDialog(context, entity),
                                          tooltip: 'View File',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            color: Colors.cyan[300],
                                            size: isMobile ? 18 : 20,
                                          ),
                                          onPressed: () => _showEditDialog(context, entity),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red[300],
                                            size: isMobile ? 18 : 20,
                                          ),
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
                        "Default Packages Management",
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
                        onPressed: () {
                          fetchDefaultPackages();
                          fetchStates();
                        },
                        tooltip: "Refresh Data",
                      ),
                    ],
                  ),
                  SizedBox(height: padding),
                  _buildAddSection(screenWidth),
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
  final String type, name, code, state, partner, file, package, id;
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