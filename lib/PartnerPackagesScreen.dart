import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_23/BottomBoardScreen.dart';
import 'package:flutter_application_23/DefaultPackagesScreen.dart';
import 'package:flutter_application_23/DemoUsersScreen.dart';
import 'package:flutter_application_23/PartnersScreen.dart';
import 'package:flutter_application_23/ScrollingScreen.dart';
import 'package:flutter_application_23/StatesScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PartnersScreen extends StatefulWidget {
  final String? username;
  const PartnersScreen({this.username, super.key});

  @override
  _PartnersScreenState createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> partners = [];
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> displayedPartners = []; // For displaying partners in the table
  TextEditingController newNameController = TextEditingController();
  TextEditingController newCodeController = TextEditingController();
  TextEditingController newSelectStateController = TextEditingController();
  TextEditingController searchController = TextEditingController(); // Controller for search field
  List<PlatformFile?> partnerFiles = [null, null, null];
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;
  bool isSidebarOpen = false;
  int? highlightedIndex; // To track the highlighted row

  static const Color primaryColor = Color(0xFF00897B);
  static const Color secondaryColor = Color(0xFFFFCA28);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);
  static const Color cardColor = Color(0xFF455A64);

  static const String apiGetPartners = "https://sms.mydreamplaytv.com/get-partners.php";
  static const String apiAddPartner = "https://sms.mydreamplaytv.com/add_partner.php";
  static const String apiUpdatePartner = "https://sms.mydreamplaytv.com/update-partner.php";
  static const String apiDeletePartner = "https://sms.mydreamplaytv.com/delete-partner.php";
  static const String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchPartners();
    fetchStates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newNameController.dispose();
    newCodeController.dispose();
    newSelectStateController.dispose();
    searchController.dispose();
    super.dispose();
  }

  String extractJson(String response) {
    final int jsonStartIndex = response.indexOf('{');
    return jsonStartIndex != -1 ? response.substring(jsonStartIndex) : "";
  }

  Future<void> fetchPartners() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetPartners));
      print("Response status: ${response.statusCode}, Body: ${response.body}");
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        print("Extracted JSON: $jsonResponse");
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          print("Decoded data: $data");
          if (data["success"]) {
            setState(() {
              partners = List<Map<String, dynamic>>.from(data["partners"]);
              displayedPartners = List.from(partners); // Initialize displayed partners
            });
          }
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching partners: $e", Colors.red);
    }
    setState(() => isLoading = false);
    print("Partners after fetch: $partners");
  }

  Future<void> fetchStates() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-states.php"));
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          if (data["success"]) setState(() => states = List<Map<String, dynamic>>.from(data["states"]));
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching states: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<Map<String, String>?> uploadFile(PlatformFile file, String type) async {
    var request = http.MultipartRequest("POST", Uri.parse(apiUploadFile));
    request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
    request.fields['type'] = type;
    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final String jsonResponse = extractJson(responseData);
      final jsonData = jsonDecode(jsonResponse);
      if (jsonData["success"]) {
        return {
          "file_name": jsonData["file_name"],
          "url": jsonData["url"] ?? "$apiUploadFile?file_name=${jsonData["file_name"]}"
        };
      }
      return null;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  Future<void> addPartner() async {
    if (newNameController.text.isEmpty || newCodeController.text.isEmpty || newSelectStateController.text.isEmpty || partnerFiles.any((f) => f == null)) {
      _showSnackBar("Please fill all fields and upload files", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    List<Map<String, String>?> fileData = [];
    for (int i = 0; i < partnerFiles.length; i++) {
      if (partnerFiles[i] != null) {
        Map<String, String>? data = await uploadFile(partnerFiles[i]!, "partner");
        if (data == null) {
          setState(() => isLoading = false);
          _showSnackBar("Failed to upload file", Colors.red);
          return;
        }
        fileData.add(data);
      }
    }
    try {
      var state = states.firstWhere((s) => s["state_name"] == newSelectStateController.text);
      var payload = {
        "partner_name": newNameController.text.trim(),
        "partner_code": newCodeController.text.trim(),
        "state_id": state["id"].toString(),
        "splash_screen": fileData[0]!["file_name"],
        "logos": fileData[1]!["file_name"],
        "board": fileData[2]!["file_name"],
        "splash_screen_url": fileData[0]!["url"],
        "logos_url": fileData[1]!["url"],
        "board_url": fileData[2]!["url"],
      };
      var response = await http.post(
        Uri.parse(apiAddPartner),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      String jsonResponse = extractJson(response.body);
      var data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) {
        newNameController.clear();
        newCodeController.clear();
        newSelectStateController.clear();
        setState(() => partnerFiles = [null, null, null]);
        await fetchPartners();
      }
    } catch (e) {
      _showSnackBar("Error adding partner: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> updatePartner(Entity entity, String newName, String newCode, String newState, List<PlatformFile?> newFiles) async {
    setState(() => isLoading = true);
    List<String?> fileNames = [
      entity.splashUrl != 'N/A' ? Uri.parse(entity.splashUrl).queryParameters['file_name'] : null,
      entity.logosUrl != 'N/A' ? Uri.parse(entity.logosUrl).queryParameters['file_name'] : null,
      entity.boardUrl != 'N/A' ? Uri.parse(entity.boardUrl).queryParameters['file_name'] : null,
    ];
    List<String?> fileUrls = [
      entity.splashUrl != 'N/A' ? entity.splashUrl : null,
      entity.logosUrl != 'N/A' ? entity.logosUrl : null,
      entity.boardUrl != 'N/A' ? entity.boardUrl : null,
    ];
    for (int i = 0; i < newFiles.length; i++) {
      if (newFiles[i] != null) {
        Map<String, String>? data = await uploadFile(newFiles[i]!, "partner");
        if (data == null) {
          setState(() => isLoading = false);
          _showSnackBar("Failed to upload new file", Colors.red);
          return;
        }
        fileNames[i] = data["file_name"];
        fileUrls[i] = data["url"];
      }
    }
    try {
      var state = states.firstWhere((s) => s["state_name"] == newState);
      var payload = {
        "id": entity.id,
        "partner_name": newName,
        "partner_code": newCode,
        "state_id": state["id"].toString(),
        "splash_screen": fileNames[0] ?? '',
        "logos": fileNames[1] ?? '',
        "board": fileNames[2] ?? '',
        "splash_screen_url": fileUrls[0] ?? '',
        "logos_url": fileUrls[1] ?? '',
        "board_url": fileUrls[2] ?? '',
      };
      var response = await http.post(
        Uri.parse(apiUpdatePartner),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      String jsonResponse = extractJson(response.body);
      var data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchPartners();
    } catch (e) {
      _showSnackBar("Error updating partner: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> deletePartner(String id) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(apiDeletePartner),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      final String jsonResponse = extractJson(response.body);
      final data = jsonDecode(jsonResponse);
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchPartners();
    } catch (e) {
      _showSnackBar("Error deleting partner: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => partnerFiles[index] = result.files.first);
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
    final TextEditingController codeController = TextEditingController(text: entity.code);
    final TextEditingController stateController = TextEditingController(text: entity.state);
    List<PlatformFile?> updatedFiles = [null, null, null];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Edit Partner',
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
              TextField(
                controller: codeController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Code',
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
              _buildFileInput("Splash Screen", 0, updatedFiles, entity.splashUrl),
              const SizedBox(height: 12),
              _buildFileInput("Logos", 1, updatedFiles, entity.logosUrl),
              const SizedBox(height: 12),
              _buildFileInput("Board", 2, updatedFiles, entity.boardUrl),
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
              updatePartner(entity, nameController.text, codeController.text, stateController.text, updatedFiles);
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
          'Are you sure you want to delete partner "${entity.name}"?',
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
              deletePartner(entity.id);
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

  Widget _buildFileInput(String label, int index, List<PlatformFile?> files, String currentUrl) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(text: files[index]?.name ?? (currentUrl != 'N/A' ? currentUrl.split('/').last : '')),
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: label,
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
          onPressed: () => pickFileForEdit(index, files),
        ),
      ],
    );
  }

  void pickFileForEdit(int index, List<PlatformFile?> files) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() => files[index] = result.files.first);
    }
  }

  void _showImagesDialog(List<String> imageUrls) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Partner Images",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (imageUrls[0] != 'N/A') ...[
                            Text(
                              "Splash Screen",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.network(
                              imageUrls[0],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 200,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print("Error loading Splash Screen image: $error");
                                print("URL: ${imageUrls[0]}");
                                print("StackTrace: $stackTrace");
                                return Text(
                                  "Failed to load image",
                                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (imageUrls[1] != 'N/A') ...[
                            Text(
                              "Logos",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.network(
                              imageUrls[1],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 200,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print("Error loading Logos image: $error");
                                print("URL: ${imageUrls[1]}");
                                print("StackTrace: $stackTrace");
                                return Text(
                                  "Failed to load image",
                                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (imageUrls[2] != 'N/A') ...[
                            Text(
                              "Board",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Image.network(
                              imageUrls[2],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 200,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print("Error loading Board image: $error");
                                print("URL: ${imageUrls[2]}");
                                print("StackTrace: $stackTrace");
                                return Text(
                                  "Failed to load image",
                                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddSection() {
    return Container(
      width: double.infinity,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6), // Reduced border radius
          side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
        elevation: 1, // Reduced elevation
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add New Partner",
                style: GoogleFonts.poppins(
                  fontSize: 10, // Reduced font size
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 3), // Reduced spacing
              // Search Field
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search by Partner Name",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(width: 1)),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.black, size: 16), // Reduced icon size
                    onPressed: () => _searchPartner(searchController.text),
                  ),
                ),
                style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                onSubmitted: (value) => _searchPartner(value), // Trigger search on Enter
              ),
              const SizedBox(height: 3), // Reduced spacing
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newNameController,
                      decoration: InputDecoration(
                        hintText: "Enter Name",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4), // Reduced border radius
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                      ),
                      style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                    ),
                  ),
                  const SizedBox(width: 3), // Reduced spacing
                  Expanded(
                    child: TextField(
                      controller: newCodeController,
                      decoration: InputDecoration(
                        hintText: "Enter Code",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4), // Reduced border radius
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                      ),
                      style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                    ),
                  ),
                  const SizedBox(width: 3), // Reduced spacing
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: newSelectStateController.text.isEmpty ? null : newSelectStateController.text,
                      hint: Text(
                        "Select State",
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                      ),
                      items: states.map((state) => DropdownMenuItem<String>(
                        value: state["state_name"] as String,
                        child: Text(
                          state["state_name"] as String,
                          style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => newSelectStateController.text = value!),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4), // Reduced border radius
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                      ),
                      dropdownColor: Colors.white,
                      style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                    ),
                  ),
                  const SizedBox(width: 3), // Reduced spacing
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: partnerFiles[0]?.name ?? ""),
                            decoration: InputDecoration(
                              hintText: "Upload Splash",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4), // Reduced border radius
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                            ),
                            style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 2), // Reduced spacing
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.black, size: 16), // Reduced icon size
                          onPressed: () => pickFile(0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3), // Reduced spacing
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: partnerFiles[1]?.name ?? ""),
                            decoration: InputDecoration(
                              hintText: "Upload Logos",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4), // Reduced border radius
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                            ),
                            style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 2), // Reduced spacing
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.black, size: 16), // Reduced icon size
                          onPressed: () => pickFile(1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3), // Reduced spacing
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: partnerFiles[2]?.name ?? ""),
                            decoration: InputDecoration(
                              hintText: "Upload Board",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), // Reduced font size
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4), // Reduced border radius
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Reduced padding
                            ),
                            style: GoogleFonts.poppins(color: Colors.black, fontSize: 10), // Reduced font size
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 2), // Reduced spacing
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.black, size: 16), // Reduced icon size
                          onPressed: () => pickFile(2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3), // Reduced spacing
                  FloatingActionButton(
                    onPressed: addPartner,
                    backgroundColor: const Color(0xFF4CAF50),
                    mini: true,
                    child: const Icon(Icons.add, color: Colors.white, size: 16), // Reduced icon size
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchPartner(String query) {
    if (query.isEmpty) {
      setState(() {
        displayedPartners = List.from(partners);
        highlightedIndex = null;
      });
      return;
    }

    setState(() {
      // Reset the list to the original order
      displayedPartners = List.from(partners);
      highlightedIndex = null;

      // Find the first partner that matches the partner name
      final matchingIndex = displayedPartners.indexWhere((partner) {
        final partnerName = partner['partner_name'].toString().toLowerCase();
        return partnerName.contains(query.toLowerCase());
      });

      if (matchingIndex != -1) {
        // Move the matching partner to the top
        final matchingPartner = displayedPartners[matchingIndex];
        displayedPartners.removeAt(matchingIndex);
        displayedPartners.insert(0, matchingPartner);
        highlightedIndex = 0; // Highlight the first row (index 0 after moving)
      } else {
        _showSnackBar("No matching partner found", Colors.red);
      }
    });
  }

  Widget _buildPaginatedDataSection() {
    final int totalPages = (displayedPartners.length / itemsPerPage).ceil();

    List<Entity> partnerEntities = displayedPartners.map((partner) {
      String splashUrl = partner['splash_screen_url'] ?? 'N/A';
      String logosUrl = partner['logos_url'] ?? 'N/A';
      String boardUrl = partner['board_url'] ?? 'N/A';

      return Entity(
        type: 'Partner',
        name: partner['partner_name'] ?? 'N/A',
        code: partner['partner_code'] ?? 'N/A',
        state: states.firstWhere(
          (s) => s['id'].toString() == partner['state_id'].toString(),
          orElse: () => {'state_name': 'N/A'},
        )['state_name'],
        partner: partner['partner_name'] ?? 'N/A',
        file: [splashUrl, logosUrl, boardUrl].where((f) => f != 'N/A').join(', '),
        package: '',
        id: partner['id'].toString(),
        splashUrl: splashUrl,
        logosUrl: logosUrl,
        boardUrl: boardUrl,
      );
    }).toList();

    final List<Entity> paginatedEntities = partnerEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, partnerEntities.length),
    );

    return Container(
      decoration: BoxDecoration(
        color: drawerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            columnSpacing: 0,
                            headingRowColor: MaterialStateColor.resolveWith((states) => cardColor),
                            dataRowColor: MaterialStateColor.resolveWith((states) => drawerColor),
                            dataRowHeight: 56,
                            dividerThickness: 0.5,
                            border: TableBorder(
                              horizontalInside: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
                            ),
                            columns: [
                              DataColumn(
                                label: Container(
                                  width: 50,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: 150,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'State',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: 200,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Name',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: 150,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Code',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: 200,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Files',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: 80,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'View',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: 120,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Actions',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: paginatedEntities.asMap().entries.map((entry) {
                              int index = entry.key + 1 + (currentPage - 1) * itemsPerPage;
                              final entity = entry.value;
                              final actualIndex = (currentPage - 1) * itemsPerPage + entry.key; // Calculate the actual index in displayedPartners
                              final isHighlighted = actualIndex == highlightedIndex;

                              return DataRow(
                                color: MaterialStateColor.resolveWith((states) => isHighlighted
                                    ? primaryColor.withOpacity(0.2)
                                    : drawerColor), // Highlight background
                                cells: [
                                  DataCell(
                                    Container(
                                      width: 50,
                                      alignment: Alignment.center,
                                      decoration: isHighlighted
                                          ? BoxDecoration(
                                              border: Border(
                                                left: BorderSide(color: primaryColor, width: 2),
                                              ),
                                            )
                                          : null,
                                      child: Text(
                                        '$index',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 150,
                                      alignment: Alignment.center,
                                      child: Text(
                                        entity.state,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 200,
                                      alignment: Alignment.center,
                                      child: Text(
                                        entity.name,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 150,
                                      alignment: Alignment.center,
                                      child: Text(
                                        entity.code,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 200,
                                      alignment: Alignment.center,
                                      child: Text(
                                        entity.file.split(', ').length.toString() + ' files',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 80,
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.visibility,
                                          color: Colors.cyan[300],
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          List<String> imageUrls = [
                                            entity.splashUrl,
                                            entity.logosUrl,
                                            entity.boardUrl,
                                          ];
                                          _showImagesDialog(imageUrls);
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: 120,
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
                                            icon: Icon(
                                              Icons.edit,
                                              color: Colors.cyan[300],
                                              size: 20,
                                            ),
                                            onPressed: () => _showEditDialog(context, entity),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.red[300],
                                              size: 20,
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
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                  ),
                  Text(
                    'Page $currentPage of $totalPages',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                  ),
                  const SizedBox(width: 10),
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
                      fontSize: 14,
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

  IconData _getIconForTitle(String title) {
    switch (title) {
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

  List<Map<String, dynamic>> get menuItems => [
        {"title": "States", "screen": StatesScreen(username: widget.username)},
        {"title": "Default Packages", "screen": DefaultPackagesScreen(username: widget.username)},
        {"title": "Partners", "screen": PartnersScreen(username: widget.username)},
        {"title": "Partner Packages", "screen": PartnerPackagesScreen(username: widget.username)},
        {"title": "Demo Users", "screen": DemoUsersScreen(username: widget.username)},
        {"title": "Bottom Board", "screen": BottomBoardScreen(username: widget.username)},
        {"title": "Scrolling", "screen": ScrollingScreen(username: widget.username)},
        {"title": "Logout", "screen": null},
      ];

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isSidebarOpen ? 250 : 0,
      color: drawerColor,
      child: isSidebarOpen
          ? ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 30),
                      const SizedBox(height: 8),
                      Text(
                        widget.username ?? 'Super Admin',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
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
                        size: 24,
                      ),
                      title: Text(
                        item["title"],
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        setState(() => isSidebarOpen = false);
                        if (item["title"] == "Logout") {
                          Navigator.pushReplacementNamed(context, '/');
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => item["screen"]),
                          );
                        }
                      },
                    )),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: Icon(
                    Icons.close,
                    color: Colors.cyan[300],
                    size: 24,
                  ),
                  title: Text(
                    "Close",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    setState(() => isSidebarOpen = false);
                  },
                ),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: isSidebarOpen ? 8.0 : 16.0,
                    right: 16.0,
                    top: 8.0, // Reduced top padding
                    bottom: 8.0, // Reduced bottom padding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: primaryColor,
                              size: 28,
                            ),
                            onPressed: () {
                              fetchPartners();
                              fetchStates();
                            },
                            tooltip: "Refresh Data",
                          ),
                        ],
                      ),
                      const SizedBox(height: 6), // Reduced spacing
                      _buildAddSection(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSidebarOpen ? 8.0 : 16.0),
                    child: _buildPaginatedDataSection(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Entity {
  final String type, name, code, state, partner, file, package, id, splashUrl, logosUrl, boardUrl;
  const Entity({
    required this.type,
    required this.name,
    required this.code,
    required this.state,
    required this.partner,
    required this.file,
    required this.package,
    required this.id,
    required this.splashUrl,
    required this.logosUrl,
    required this.boardUrl,
  });
}