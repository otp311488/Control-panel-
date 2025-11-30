import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_application_23/BottomBoardScreen.dart';
import 'package:flutter_application_23/DefaultPackagesScreen.dart';
import 'package:flutter_application_23/DemoUsersScreen.dart';
import 'package:flutter_application_23/ScrollingScreen.dart';
import 'package:flutter_application_23/StatesScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class PartnerPackagesScreen extends StatefulWidget {
  final String? username;
  const PartnerPackagesScreen({this.username, super.key});

  @override
  _PartnerPackagesScreenState createState() => _PartnerPackagesScreenState();
}

class _PartnerPackagesScreenState extends State<PartnerPackagesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> partnerPackages = [];
  List<Map<String, dynamic>> partners = [];
  List<Map<String, dynamic>> displayedPackages = [];
  TextEditingController newNameController = TextEditingController();
  TextEditingController newPartnerController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  TextEditingController editNameController = TextEditingController();
  TextEditingController editPartnerController = TextEditingController();
  html.File? newFile;
  html.File? editFile;
  Map<String, String> originalFileNames = {};
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;
  String? editingPackageId;
  int? highlightedIndex;

  static const Color primaryColor = Color(0xFF00897B);
  static const Color secondaryColor = Color(0xFFFFCA28);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);
  static const Color cardColor = Color(0xFF455A64);

  static const String apiGetPartnerPackages = "https://sms.mydreamplaytv.com/get-partner-packages.php";
  static const String apiAddPartnerPackage = "https://sms.mydreamplaytv.com/add_partner_package.php";
  static const String apiUpdatePartnerPackage = "https://sms.mydreamplaytv.com/update-partner-package.php";
  static const String apiDeletePartnerPackage = "https://sms.mydreamplaytv.com/delete-partner-pack.php";
  static const String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";
  static const String baseImageUrl = "https://sms.mydreamplaytv.com/public_html/uploads/";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchPartnerPackages();
    fetchPartners();
  }

  @override
  void dispose() {
    _animationController.dispose();
    newNameController.dispose();
    newPartnerController.dispose();
    searchController.dispose();
    editNameController.dispose();
    editPartnerController.dispose();
    super.dispose();
  }

  String extractJson(String response) {
    final int jsonStartIndex = response.indexOf('{');
    return jsonStartIndex != -1 ? response.substring(jsonStartIndex) : "";
  }

  Future<void> fetchPartnerPackages() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetPartnerPackages));
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          if (data["success"]) {
            setState(() {
              partnerPackages = List<Map<String, dynamic>>.from(data["packages"]);
              displayedPackages = List.from(partnerPackages);
            });
          } else {
            _showSnackBar(data["message"] ?? "Failed to fetch partner packages", Colors.red);
          }
        } else {
          _showSnackBar("Invalid response from server", Colors.red);
        }
      } else {
        _showSnackBar("Failed to fetch partner packages: HTTP ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error fetching partner packages: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> fetchPartners() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-partners.php"));
      if (response.statusCode == 200) {
        final String jsonResponse = extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          if (data["success"]) {
            setState(() {
              partners = List<Map<String, dynamic>>.from(data["partners"]);
              print("Fetched partners: $partners");
            });
          } else {
            _showSnackBar(data["message"] ?? "Failed to fetch partners", Colors.red);
          }
        } else {
          _showSnackBar("Invalid response from server", Colors.red);
        }
      } else {
        _showSnackBar("Failed to fetch partners: HTTP ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error fetching partners: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> addPartnerPackage() async {
    if (newNameController.text.isEmpty || newPartnerController.text.isEmpty || newFile == null) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    final String? fileName = await uploadFile(newFile!, "partner_package");
    if (fileName == null) {
      setState(() => isLoading = false);
      _showSnackBar("Failed to upload file", Colors.red);
      return;
    }
    try {
      final partner = partners.firstWhere(
        (p) => p["partner_name"] == newPartnerController.text,
        orElse: () => {},
      );
      if (partner.isEmpty || partner["partner_code"] == null) {
        _showSnackBar("Selected partner not found or missing partner code", Colors.red);
        setState(() => isLoading = false);
        return;
      }
      print("Adding package with partner_code: ${partner["partner_code"]}");
      final requestBody = {
        "partner_code": partner["partner_code"],
        "package_name": newNameController.text.trim(),
        "partner_id": partner["id"].toString(),
        "file_name": fileName,
      };
      print("Add request body: $requestBody");
      final response = await http.post(
        Uri.parse(apiAddPartnerPackage),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );
      final String jsonResponse = extractJson(response.body);
      print("Add response: $jsonResponse");
      if (response.statusCode == 200) {
        final data = jsonDecode(jsonResponse);
        _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
        if (data["success"]) {
          newNameController.clear();
          newPartnerController.clear();
          setState(() => newFile = null);
          await fetchPartnerPackages();
        }
      } else {
        _showSnackBar("Failed to add partner package: HTTP ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error adding partner package: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  Future<void> deletePartnerPackage(String id) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(apiDeletePartnerPackage),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      final String jsonResponse = extractJson(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(jsonResponse);
        _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
        if (data["success"]) await fetchPartnerPackages();
      } else {
        _showSnackBar("Failed to delete partner package: HTTP ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error deleting partner package: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<String?> uploadFile(html.File file, String type) async {
    final request = http.MultipartRequest("POST", Uri.parse(apiUploadFile));
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final fileBytes = reader.result as List<int>;
    final multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: file.name);
    request.files.add(multipartFile);
    request.fields['type'] = type;
    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final String jsonResponse = extractJson(responseData);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(jsonResponse);
        if (jsonData["success"]) {
          setState(() => originalFileNames[jsonData["file_name"]] = file.name);
          return jsonData["file_name"];
        } else {
          _showSnackBar(jsonData["message"] ?? "Failed to upload file", Colors.red);
          return null;
        }
      } else {
        _showSnackBar("Failed to upload file: HTTP ${response.statusCode}", Colors.red);
        return null;
      }
    } catch (e) {
      print("Error uploading file: $e");
      _showSnackBar("Error uploading file: $e", Colors.red);
      return null;
    }
  }

  Future<void> pickFile() async {
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.multiple = false;
    uploadInput.accept = '.txt,.m3u,.csv,.jpg,.jpeg,.png,.pdf,*/*'; // Allow all desired file types
    uploadInput.click();
    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        setState(() => newFile = files[0]);
      }
    });
  }

  Future<Map<String, dynamic>?> _fetchFileAsBase64(String fileUrl, String fileExtension) async {
    try {
      final fileName = fileUrl.split('/').last;
      final proxyUrl = "$apiUploadFile?file_name=$fileName";
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) {
        final base64Data = base64Encode(response.bodyBytes);
        return {'data': base64Data};
      } else {
        return {'error': 'Failed to fetch file via proxy (status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  void _showFileDialog(BuildContext context, Entity entity) {
    if (entity.file == 'N/A') {
      _showSnackBar("No file available for this package", Colors.red);
      return;
    }

    String rawFileName = partnerPackages.firstWhere((pkg) => pkg['id'].toString() == entity.id)['file_name'];
    String fileName = rawFileName.startsWith('http') ? rawFileName.split('/').last : rawFileName;
    String fileUrl = rawFileName.startsWith('http') ? rawFileName.replaceAll('/public_html', '') : "$baseImageUrl$fileName";

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
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
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
                      child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {
                    String errorMessage = snapshot.data?['error'] ?? 'Unknown error';
                    return Column(
                      children: [
                        Text(
                          'Error loading file content: $errorMessage\nYou can download the file to view it.',
                          style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => html.window.open(fileUrl, '_blank'),
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: Text('Download File', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    );
                  }

                  final base64Data = snapshot.data!['data'] as String;
                  if (isImage) {
                    return Image.memory(base64Decode(base64Data), width: 300, height: 300, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
                      return Text('Error loading image: $error', style: GoogleFonts.poppins(color: Colors.red, fontSize: 14));
                    });
                  } else if (isTextFile) {
                    String textContent;
                    try {
                      textContent = utf8.decode(base64Decode(base64Data));
                    } catch (e) {
                      textContent = 'Error decoding file content';
                    }
                    return Container(
                      width: 300,
                      height: 300,
                      child: SingleChildScrollView(child: Text(textContent, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
                    );
                  } else {
                    return Column(
                      children: [
                        Text('File type: $fileExtension (Cannot preview)', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => html.window.open(fileUrl, '_blank'),
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: Text('Download File', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
          ElevatedButton.icon(
            onPressed: () => html.window.open(fileUrl, '_blank'),
            icon: const Icon(Icons.download, color: Colors.white),
            label: Text('Download', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
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

  void _showEditDialog(BuildContext context, Entity entity) {
    editNameController.text = entity.name;
    editPartnerController.text = entity.partner;
    editFile = null;
    editingPackageId = entity.id;

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: drawerColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Edit Partner Package', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: screenWidth > 600 ? 18 : 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editNameController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12),
                  decoration: InputDecoration(
                    labelText: 'Package Name',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: cardColor,
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: partners.firstWhere(
                    (p) => p["partner_name"] == editPartnerController.text,
                    orElse: () => {"id": ""},
                  )["id"].toString().isEmpty
                      ? null
                      : partners.firstWhere(
                          (p) => p["partner_name"] == editPartnerController.text,
                          orElse: () => {"id": ""},
                        )["id"].toString(),
                  items: partners.map((partner) => DropdownMenuItem<String>(
                        value: partner["id"].toString(),
                        child: Text(partner["partner_name"] as String, style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
                      )).toList(),
                  onChanged: (value) {
                    final selectedPartner = partners.firstWhere((p) => p["id"].toString() == value, orElse: () => {"partner_name": ""});
                    editPartnerController.text = selectedPartner["partner_name"];
                  },
                  decoration: InputDecoration(
                    labelText: 'Partner',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: cardColor,
                  ),
                  dropdownColor: drawerColor,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: editFile?.name ?? cleanFileName(entity.file)),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12),
                        decoration: InputDecoration(
                          labelText: 'File',
                          labelStyle: GoogleFonts.poppins(color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: cardColor,
                        ),
                        readOnly: true,
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.white, size: screenWidth > 600 ? 20 : 16),
                      onPressed: () async {
                        final uploadInput = html.FileUploadInputElement();
                        uploadInput.multiple = false;
                        uploadInput.accept = '.txt,.m3u,.csv,.jpg,.jpeg,.png,.pdf,*/*'; // Allow all desired file types
                        uploadInput.click();
                        uploadInput.onChange.listen((event) {
                          final files = uploadInput.files;
                          if (files != null && files.isNotEmpty) {
                            setState(() {
                              editFile = files[0];
                            });
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  editFile = null;
                  editingPackageId = null;
                });
                Navigator.pop(context);
              },
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePartnerPackage();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
            ),
          ],
        );
      },
    );
  }

Future<void> _updatePartnerPackage() async {
  if (editNameController.text.isEmpty || editPartnerController.text.isEmpty) {
    _showSnackBar("Please fill all required fields", Colors.red);
    return;
  }

  setState(() => isLoading = true);
  String? fileName;
  if (editFile != null) {
    fileName = await uploadFile(editFile!, "partner_package");
    if (fileName == null) {
      setState(() => isLoading = false);
      _showSnackBar("Failed to upload new file", Colors.red);
      return;
    }
  }

  try {
    final partner = partners.firstWhere((p) => p["partner_name"] == editPartnerController.text, orElse: () => {});
    if (partner.isEmpty || partner["partner_code"] == null) {
      _showSnackBar("Selected partner not found or missing partner code", Colors.red);
      setState(() => isLoading = false);
      return;
    }
    print("Updating package with partner_code: ${partner["partner_code"]}");

    final existingPackage = partnerPackages.firstWhere((pkg) => pkg['id'].toString() == editingPackageId, orElse: () => {'file_name': ''});
    final requestBody = {
      "id": editingPackageId,
      "partner_code": partner["partner_code"],
      "package_name": editNameController.text.trim(),
      "partner_id": partner["id"].toString(),
      "file_name": fileName ?? existingPackage['file_name'],
    };
    print("Update request body: $requestBody");

    final request = http.MultipartRequest("POST", Uri.parse(apiUpdatePartnerPackage));
    request.fields['data'] = jsonEncode(requestBody); // Send JSON as 'data' field
    if (editFile != null) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(editFile!);
      await reader.onLoad.first;
      final fileBytes = reader.result as List<int>;
      final multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: editFile!.name);
      request.files.add(multipartFile);
    }

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final String jsonResponse = extractJson(responseData);
    print("Update response: $jsonResponse");

    if (response.statusCode == 200) {
      final responseData = jsonDecode(jsonResponse);
      _showSnackBar(responseData["message"], responseData["success"] ? Colors.green : Colors.red);
      if (responseData["success"]) {
        await fetchPartnerPackages();
      }
    } else {
      _showSnackBar("Failed to update partner package: HTTP ${response.statusCode}", Colors.red);
    }
  } catch (e) {
    _showSnackBar("Error updating partner package: $e", Colors.red);
  } finally {
    setState(() {
      isLoading = false;
      editingPackageId = null;
      editFile = null;
      editNameController.clear();
      editPartnerController.clear();
    });
  }
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
                Text(
                  "Admin Panel",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: screenWidth > 600 ? 20 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          _buildSidebarItem(context, "States", StatesScreen(username: widget.username), Icons.location_on),
          _buildSidebarItem(context, "Default Packages", DefaultPackagesScreen(username: widget.username), Icons.local_shipping),
          _buildSidebarItem(context, "Partners", null, Icons.group),
          _buildSidebarItem(context, "Partner Packages", PartnerPackagesScreen(username: widget.username), Icons.handshake, isSelected: true),
          _buildSidebarItem(context, "Demo Users", DemoUsersScreen(username: widget.username), Icons.person_outline),
          _buildSidebarItem(context, "Bottom Board", BottomBoardScreen(username: widget.username), Icons.dashboard),
          _buildSidebarItem(context, "Scrolling", ScrollingScreen(username: widget.username), Icons.text_rotation_none),
          _buildSidebarItem(context, "Logout", null, Icons.logout, onTap: () {
            _showSnackBar("Logged out successfully", Colors.green);
            Navigator.pushReplacementNamed(context, '/');
          }),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, String title, Widget? page, IconData icon, {bool isSelected = false, VoidCallback? onTap}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: screenWidth > 600 ? 24 : 20),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: screenWidth > 600 ? 16 : 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? Colors.white.withOpacity(0.1) : null,
      onTap: onTap ?? (page != null
          ? () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
            }
          : null),
    );
  }

  Widget _buildAddSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final double padding = isMobile ? 4.0 : 8.0;
    final double fontSize = isMobile ? 10 : 12;
    final double iconSize = isMobile ? 16 : 18;
    final double fieldWidth = isMobile ? 100 : double.infinity;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Add New Partner Package",
              style: GoogleFonts.poppins(
                fontSize: fontSize + 2,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            SizedBox(height: padding / 2),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search by Package Name",
                hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(width: 1)),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 4 : 6, horizontal: 8),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: Colors.black, size: iconSize),
                  onPressed: () => _searchPartnerPackage(searchController.text),
                ),
              ),
              style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
              onSubmitted: (value) => _searchPartnerPackage(value),
            ),
            SizedBox(height: padding / 2),
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
                          child: _buildTextField(newNameController, "Package Name", fontSize),
                        ),
                        SizedBox(width: padding / 2),
                        Container(
                          width: fieldWidth,
                          child: _buildDropdown(newPartnerController, fontSize),
                        ),
                        SizedBox(width: padding / 2),
                        Container(
                          width: fieldWidth,
                          child: _buildFilePicker(fontSize, iconSize),
                        ),
                        SizedBox(width: padding / 2),
                        _buildAddButton(isMobile, iconSize),
                      ],
                    ),
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildTextField(newNameController, "Package Name", fontSize)),
                      SizedBox(width: padding / 2),
                      Expanded(child: _buildDropdown(newPartnerController, fontSize)),
                      SizedBox(width: padding / 2),
                      Expanded(child: _buildFilePicker(fontSize, iconSize)),
                      SizedBox(width: padding / 2),
                      _buildAddButton(isMobile, iconSize),
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

  Widget _buildTextField(TextEditingController controller, String hint, double fontSize) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(width: 1)),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 4 : 6, horizontal: 8),
      ),
      style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
    );
  }

  Widget _buildDropdown(TextEditingController controller, double fontSize) {
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty
          ? null
          : partners.firstWhere(
              (p) => p["partner_name"] == controller.text,
              orElse: () => {"id": ""},
            )["id"].toString(),
      hint: Text("Select Partner", style: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize)),
      items: partners.map((partner) => DropdownMenuItem<String>(
            value: partner["id"].toString(),
            child: Text(partner["partner_name"] as String, style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize)),
          )).toList(),
      onChanged: (value) {
        final selectedPartner = partners.firstWhere((p) => p["id"].toString() == value);
        setState(() {
          controller.text = selectedPartner["partner_name"];
        });
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(width: 1)),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 4 : 6, horizontal: 8),
      ),
      dropdownColor: Colors.white,
    );
  }

  Widget _buildFilePicker(double fontSize, double iconSize) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(text: newFile?.name ?? ""),
            decoration: InputDecoration(
              hintText: "Upload File",
              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(width: 1)),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 10 ? 4 : 6, horizontal: 8),
            ),
            style: GoogleFonts.poppins(color: Colors.black, fontSize: fontSize),
            readOnly: true,
          ),
        ),
        SizedBox(width: 2),
        IconButton(
          icon: Icon(Icons.attach_file, color: Colors.black, size: iconSize),
          onPressed: pickFile,
        ),
      ],
    );
  }

  Widget _buildAddButton(bool isMobile, double iconSize) {
    return FloatingActionButton(
      onPressed: addPartnerPackage,
      backgroundColor: primaryColor,
      mini: isMobile,
      child: Icon(Icons.add, color: Colors.white, size: iconSize),
    );
  }

  void _searchPartnerPackage(String query) {
    if (query.isEmpty) {
      setState(() {
        displayedPackages = List.from(partnerPackages);
        highlightedIndex = null;
      });
      return;
    }

    setState(() {
      displayedPackages = List.from(partnerPackages);
      highlightedIndex = null;

      final matchingIndex = displayedPackages.indexWhere((pkg) {
        final packageName = pkg['package_name'].toString().toLowerCase();
        return packageName.contains(query.toLowerCase());
      });

      if (matchingIndex != -1) {
        final matchingPackage = displayedPackages[matchingIndex];
        displayedPackages.removeAt(matchingIndex);
        displayedPackages.insert(0, matchingPackage);
        highlightedIndex = 0;
      } else {
        _showSnackBar("No matching package found", Colors.red);
      }
    });
  }

  Widget _buildPaginatedDataSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final double fontSize = isMobile ? 12 : 14;
    final int totalPages = (displayedPackages.length / itemsPerPage).ceil();

    List<Entity> packageEntities = displayedPackages.map((pkg) => Entity(
          type: 'Partner Package',
          name: pkg['package_name'] ?? 'N/A',
          code: partners.firstWhere((p) => p['id'].toString() == pkg['partner_id'].toString(), orElse: () => {'partner_code': 'N/A'})['partner_code'],
          state: '',
          partner: partners.firstWhere((p) => p['id'].toString() == pkg['partner_id'].toString(), orElse: () => {'partner_name': 'N/A'})['partner_name'],
          file: cleanFileName(originalFileNames[pkg['file_name']] ?? pkg['file_name'] ?? 'N/A'),
          package: pkg['package_name'] ?? 'N/A',
          id: pkg['id'].toString(),
        )).toList();

    if (packageEntities.isEmpty) {
      return Center(
        child: Text(
          "No partner packages available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    final paginatedEntities = packageEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, packageEntities.length),
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
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
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
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text('Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 150 : 200,
                                  alignment: Alignment.center,
                                  child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 100 : 150,
                                  alignment: Alignment.center,
                                  child: Text('Code', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text('Partner', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 120 : 200,
                                  alignment: Alignment.center,
                                  child: Text('File', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  width: isMobile ? 150 : 180,
                                  alignment: Alignment.center,
                                  child: Text('Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                            ],
                            rows: paginatedEntities.asMap().entries.map((entry) {
                              final index = entry.key + 1 + (currentPage - 1) * itemsPerPage;
                              final entity = entry.value;
                              final actualIndex = (currentPage - 1) * itemsPerPage + entry.key;
                              final isHighlighted = actualIndex == highlightedIndex;

                              return DataRow(
                                color: MaterialStateColor.resolveWith((states) => isHighlighted
                                    ? primaryColor.withOpacity(0.2)
                                    : drawerColor),
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
                                      width: isMobile ? 120 : 150,
                                      alignment: Alignment.center,
                                      child: Text(entity.type, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 150 : 200,
                                      alignment: Alignment.center,
                                      child: Text(entity.name, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 100 : 150,
                                      alignment: Alignment.center,
                                      child: Text(entity.code, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 120 : 150,
                                      alignment: Alignment.center,
                                      child: Text(entity.partner, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 120 : 200,
                                      alignment: Alignment.center,
                                      child: Text(entity.file, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      width: isMobile ? 150 : 180,
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
                                            icon: Icon(Icons.visibility, color: Colors.green[300], size: isMobile ? 18 : 20),
                                            onPressed: () => _showFileDialog(context, entity),
                                            tooltip: 'View File',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.edit, color: Colors.cyan[300], size: isMobile ? 18 : 20),
                                            onPressed: () => _showEditDialog(context, entity),
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
              SizedBox(height: isMobile ? 8 : 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 18 : 20),
                    onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                  ),
                  Text('Page $currentPage of $totalPages',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
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
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Entity entity) {
    final screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Deletion', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: screenWidth > 600 ? 18 : 16)),
        content: Text('Are you sure you want to delete partner package "${entity.name}"?',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
          ),
          ElevatedButton(
            onPressed: () {
              deletePartnerPackage(entity.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
          ),
        ],
      ),
    );
  }

  String cleanFileName(String fileName) {
    final String baseName = fileName.split('/').last;
    String cleanedName = baseName.replaceFirst(RegExp(r'^[0-9a-f]{16}[-_]?'), '');
    cleanedName = cleanedName.replaceFirst(RegExp(r'^(splash_|logo_|board_|file_)'), '');
    return cleanedName.isEmpty ? baseName : cleanedName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "",
          style: GoogleFonts.poppins(
            color: primaryColor,
            fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: primaryColor,
            ),
            onPressed: () {
              fetchPartnerPackages();
              fetchPartners();
            },
          ),
        ],
      ),
      drawer: _buildSidebar(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final bool isMobile = screenWidth < 600;
          final double padding = isMobile ? 4.0 : 8.0;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 4.0, padding, padding),
                child: _buildAddSection(screenWidth),
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