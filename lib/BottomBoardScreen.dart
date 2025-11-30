import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_23/DefaultPackagesScreen.dart';
import 'package:flutter_application_23/DemoUsersScreen.dart';
import 'package:flutter_application_23/PartnerPackagesScreen.dart';
import 'package:flutter_application_23/PartnersScreen.dart';
import 'package:flutter_application_23/ScrollingScreen.dart';
import 'package:flutter_application_23/StatesScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.length > 8) newText = newText.substring(0, 8);
    String formattedText = '';
    for (int i = 0; i < newText.length; i++) {
      if (i == 4 || i == 6) formattedText += '-';
      formattedText += newText[i];
    }
    return TextEditingValue(text: formattedText, selection: TextSelection.collapsed(offset: formattedText.length));
  }
}

class BottomBoardScreen extends StatefulWidget {
  final String? username;
  const BottomBoardScreen({this.username, super.key});

  @override
  _BottomBoardScreenState createState() => _BottomBoardScreenState();
}

class _BottomBoardScreenState extends State<BottomBoardScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> bottomBoards = [];
  TextEditingController boardNameController = TextEditingController();
  TextEditingController timeScheduleController = TextEditingController();
  html.File? boardFile;
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;
  bool isBoardView = false;

  DateTime? startDate;
  DateTime? endDate;
  List<String> selectedDays = [];
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int duration = 5;
  String? timeSlotIncrementUnit;
  int timeSlotIncrementValue = 15;
  List<String> generatedTimeSlots = [];

  static const Color primaryColor = Color(0xFF00897B);
  static const Color secondaryColor = Color(0xFFFFCA28);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color drawerColor = Color(0xFF2E3B4E);
  static const Color cardColor = Color(0xFF455A64);

  static const String apiGetBottomBoards = "https://sms.mydreamplaytv.com/get-bottom-boards.php";
  static const String apiAddBottomBoard = "https://sms.mydreamplaytv.com/add-bottom-board.php";
  static const String apiUpdateBottomBoard = "https://sms.mydreamplaytv.com/update-bottom-board.php";
  static const String apiUploadFile = "https://sms.mydreamplaytv.com/upload-file.php";
  static const String apiDeleteBottomBoard = "https://sms.mydreamplaytv.com/delete-bottom-board.php";
  static const String baseImageUrl = "https://sms.mydreamplaytv.com/public_html/uploads/";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchBottomBoards();
  }

  @override
  void dispose() {
    _animationController.dispose();
    boardNameController.dispose();
    timeScheduleController.dispose();
    super.dispose();
  }

  String _extractJson(String response) => response.substring(response.indexOf('{') != -1 ? response.indexOf('{') : 0);

  Future<String?> uploadFile(html.File file, String type) async {
    var request = http.MultipartRequest("POST", Uri.parse(apiUploadFile));
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final fileBytes = reader.result as List<int>;
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: file.name));
    request.fields['type'] = type;
    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(_extractJson(responseData));
      return jsonData["success"] ? jsonData["file_name"] : null;
    } catch (e) {
      _showSnackBar("Error uploading file: $e", Colors.red);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFileAsBase64(String fileUrl, String fileExtension) async {
    try {
      final fileName = fileUrl.split('/').last;
      final response = await http.get(Uri.parse("$apiUploadFile?file_name=$fileName"));
      if (response.statusCode == 200) return {'data': base64Encode(response.bodyBytes)};
      return {'error': 'Failed to fetch file (status: ${response.statusCode})'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  int _timeToSeconds(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]) * 3600) + (int.parse(parts[1]) * 60);
  }

  bool _hasOverlaps(List<String> newTimeSlots, DateTime newStartDate, DateTime newEndDate, int newDuration, {String? excludeBoardId}) {
    for (var board in bottomBoards) {
      if (excludeBoardId != null && board['id'] == excludeBoardId) continue;
      final start = DateTime.tryParse(board['start_date']) ?? DateTime(1970);
      final end = DateTime.tryParse(board['end_date']) ?? DateTime(9999);
      final slots = List<String>.from(jsonDecode(board['time_schedule']));
      final dur = board['duration'] as int;
      if (!newStartDate.isAfter(end) && !newEndDate.isBefore(start)) {
        for (var slot in newTimeSlots) {
          final slotSec = _timeToSeconds(slot);
          final slotEndSec = slotSec + newDuration;
          for (var existingSlot in slots) {
            final existingSec = _timeToSeconds(existingSlot);
            final existingEndSec = existingSec + dur;
            if (slotSec < existingEndSec && slotEndSec > existingSec) return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> addBottomBoard() async {
    if (boardNameController.text.isEmpty || generatedTimeSlots.isEmpty || boardFile == null || startDate == null || endDate == null) {
      _showSnackBar("Please fill all fields", Colors.red);
      return;
    }
    if (_hasOverlaps(generatedTimeSlots, startDate!, endDate!, duration)) {
      _showSnackBar("Time slots overlap with existing boards", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    String? fileName = await uploadFile(boardFile!, "bottom_board");
    if (fileName == null) {
      setState(() => isLoading = false);
      return;
    }
    try {
      var response = await http.post(
        Uri.parse(apiAddBottomBoard),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "board_name": boardNameController.text.trim(),
          "time_schedule": jsonEncode(generatedTimeSlots),
          "file_name": fileName,
          "duration": duration,
          "start_date": "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}",
          "end_date": "${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}",
        }),
      );
      var data = jsonDecode(_extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) {
        boardNameController.clear();
        timeScheduleController.clear();
        setState(() {
          boardFile = null;
          generatedTimeSlots.clear();
          startDate = null;
          endDate = null;
          selectedDays.clear();
          startTime = null;
          endTime = null;
          duration = 5;
          timeSlotIncrementUnit = "minutes";
          timeSlotIncrementValue = 15;
        });
        await fetchBottomBoards();
      }
    } catch (e) {
      _showSnackBar("Error adding bottom board: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateBottomBoard(Entity entity, String newBoardName, html.File? newFile) async {
    setState(() => isLoading = true);
    String? fileName = newFile != null ? await uploadFile(newFile, "bottom_board") : entity.file;
    if (newFile != null && fileName == null) {
      setState(() => isLoading = false);
      return;
    }
    if (startDate == null || endDate == null || generatedTimeSlots.isEmpty) {
      _showSnackBar("Please select date range and time slots", Colors.red);
      setState(() => isLoading = false);
      return;
    }
    if (_hasOverlaps(generatedTimeSlots, startDate!, endDate!, duration, excludeBoardId: entity.id)) {
      _showSnackBar("Time slots overlap with other boards", Colors.red);
      setState(() => isLoading = false);
      return;
    }
    try {
      var response = await http.post(
        Uri.parse(apiUpdateBottomBoard),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": entity.id,
          "board_name": newBoardName,
          "time_schedule": jsonEncode(generatedTimeSlots),
          "file_name": fileName,
          "duration": duration,
          "start_date": "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}",
          "end_date": "${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}",
        }),
      );
      var data = jsonDecode(_extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchBottomBoards();
    } catch (e) {
      _showSnackBar("Error updating bottom board: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteBottomBoard(String id) async {
    setState(() => isLoading = true);
    try {
      var response = await http.post(
        Uri.parse(apiDeleteBottomBoard),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      var data = jsonDecode(_extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchBottomBoards();
    } catch (e) {
      _showSnackBar("Error deleting bottom board: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectTimeSchedule() async {
    final startDateController = TextEditingController(text: startDate?.toString().substring(0, 10) ?? "");
    final endDateController = TextEditingController(text: endDate?.toString().substring(0, 10) ?? "");
    List<String> tempSelectedDays = List.from(selectedDays);
    int? tempStartHour = startTime?.hour;
    int? tempStartMinute = startTime?.minute;
    int? tempEndHour = endTime?.hour;
    int? tempEndMinute = endTime?.minute;
    String tempTimeSlotIncrementUnit = timeSlotIncrementUnit ?? "minutes";
    int tempTimeSlotIncrementValue = timeSlotIncrementValue;
    int tempDuration = duration;

    DateTime? parsedStartDate;
    DateTime? parsedEndDate;
    bool isDateRangeValid = true;

    final daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    final hours = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minutes = ["00", "15", "30", "45"];
    final durations = [5, 10, 15, 30];
    final timeSlotIncrements = [
      {"unit": "seconds", "value": 5, "label": "Every 5 Seconds"},
      {"unit": "seconds", "value": 10, "label": "Every 10 Seconds"},
      {"unit": "minutes", "value": 15, "label": "Every 15 Minutes"},
      {"unit": "minutes", "value": 30, "label": "Every 30 Minutes"},
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void validateDates() {
            final dateFormatRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
            parsedStartDate = dateFormatRegExp.hasMatch(startDateController.text) ? DateTime.tryParse(startDateController.text) : null;
            parsedEndDate = dateFormatRegExp.hasMatch(endDateController.text) ? DateTime.tryParse(endDateController.text) : null;
            isDateRangeValid = parsedStartDate != null && parsedEndDate != null && !parsedEndDate!.isBefore(parsedStartDate!);
            setDialogState(() {});
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Time Slots", style: GoogleFonts.poppins(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text("Date Range", style: GoogleFonts.poppins(fontSize: 12)),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: startDateController,
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
                          border: OutlineInputBorder(),
                          errorText: !isDateRangeValid ? "Invalid range" : null,
                        ),
                        inputFormatters: [DateInputFormatter()],
                        onChanged: (value) => validateDates(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("to"),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endDateController,
                        decoration: InputDecoration(
                          hintText: "YYYY-MM-DD",
                          border: OutlineInputBorder(),
                          errorText: !isDateRangeValid ? "Invalid range" : null,
                        ),
                        inputFormatters: [DateInputFormatter()],
                        onChanged: (value) => validateDates(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text("Days", style: GoogleFonts.poppins(fontSize: 12)),
                  Wrap(
                    spacing: 8,
                    children: daysOfWeek.map((day) => ChoiceChip(
                      label: Text(day),
                      selected: tempSelectedDays.contains(day),
                      onSelected: (selected) => setDialogState(() => selected ? tempSelectedDays.add(day) : tempSelectedDays.remove(day)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text("Time Range", style: GoogleFonts.poppins(fontSize: 12)),
                  Row(children: [
                    DropdownButton<String>(
                      value: tempStartHour?.toString().padLeft(2, '0') ?? hours[0],
                      items: hours.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                      onChanged: (v) => setDialogState(() => tempStartHour = int.parse(v!)),
                    ),
                    const Text(":"),
                    DropdownButton<String>(
                      value: tempStartMinute?.toString().padLeft(2, '0') ?? minutes[0],
                      items: minutes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setDialogState(() => tempStartMinute = int.parse(v!)),
                    ),
                    const SizedBox(width: 8),
                    const Text("to"),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: tempEndHour?.toString().padLeft(2, '0') ?? hours[0],
                      items: hours.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                      onChanged: (v) => setDialogState(() => tempEndHour = int.parse(v!)),
                    ),
                    const Text(":"),
                    DropdownButton<String>(
                      value: tempEndMinute?.toString().padLeft(2, '0') ?? minutes[0],
                      items: minutes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setDialogState(() => tempEndMinute = int.parse(v!)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text("Increment", style: GoogleFonts.poppins(fontSize: 12)),
                  DropdownButton<Map<String, dynamic>>(
                    value: timeSlotIncrements.firstWhere((i) => i["unit"] == tempTimeSlotIncrementUnit && i["value"] == tempTimeSlotIncrementValue, orElse: () => timeSlotIncrements[2]),
                    items: timeSlotIncrements.map((i) => DropdownMenuItem(value: i, child: Text(i["label"] as String))).toList(),
                    onChanged: (v) => setDialogState(() {
                      tempTimeSlotIncrementUnit = v!["unit"];
                      tempTimeSlotIncrementValue = v["value"];
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text("Duration", style: GoogleFonts.poppins(fontSize: 12)),
                  DropdownButton<int>(
                    value: tempDuration,
                    items: durations.map((d) => DropdownMenuItem(value: d, child: Text("$d sec"))).toList(),
                    onChanged: (v) => setDialogState(() => tempDuration = v!),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: isDateRangeValid && parsedStartDate != null && parsedEndDate != null && tempSelectedDays.isNotEmpty && tempStartHour != null && tempEndHour != null
                          ? () {
                              setState(() {
                                startDate = parsedStartDate;
                                endDate = parsedEndDate;
                                selectedDays = tempSelectedDays;
                                startTime = TimeOfDay(hour: tempStartHour!, minute: tempStartMinute ?? 0);
                                endTime = TimeOfDay(hour: tempEndHour!, minute: tempEndMinute ?? 0);
                                timeSlotIncrementUnit = tempTimeSlotIncrementUnit;
                                timeSlotIncrementValue = tempTimeSlotIncrementValue;
                                duration = tempDuration;
                              });
                              _generateTimeSlots();
                              timeScheduleController.text = "${generatedTimeSlots.length} time slots selected";
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text("Generate Time Slots", style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> fetchBottomBoards() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetBottomBoards));
      if (response.statusCode == 200) {
        final data = jsonDecode(_extractJson(response.body));
        if (data["success"] && data["data"]["package_list"] != null) {
          setState(() => bottomBoards = List<Map<String, dynamic>>.from(data["data"]["package_list"].map((board) => {
                "id": board["boardId"].toString(),
                "board_name": board["boardName"],
                "time_schedule": jsonEncode(board["timeSlots"]),
                "file_name": board["imageUrl"].split('file_name=')[1],
                "duration": board["displayTime"] ?? 5,
                "start_date": board["startDate"] == "0000-00-00" || board["startDate"] == null ? "N/A" : board["startDate"],
                "end_date": board["endDate"] == "0000-00-00" || board["endDate"] == null ? "N/A" : board["endDate"],
              })));
        } else {
          setState(() => bottomBoards = []);
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching bottom boards: $e", Colors.red);
      setState(() => bottomBoards = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _generateTimeSlots() {
    if (startDate == null || endDate == null || startTime == null || endTime == null || selectedDays.isEmpty) return;
    generatedTimeSlots.clear();
    int startSeconds = (startTime!.hour * 3600) + (startTime!.minute * 60);
    int endSeconds = (endTime!.hour * 3600) + (endTime!.minute * 60);
    int increment = timeSlotIncrementUnit == "minutes" ? timeSlotIncrementValue * 60 : timeSlotIncrementValue;
    if (endSeconds <= startSeconds) {
      _showSnackBar("End time must be after start time", Colors.red);
      return;
    }
    for (int sec = startSeconds; sec <= endSeconds; sec += increment) {
      int hours = sec ~/ 3600;
      int minutes = (sec % 3600) ~/ 60;
      generatedTimeSlots.add("${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}");
    }
    setState(() {});
  }

  Future<void> pickFile() async {
    final uploadInput = html.FileUploadInputElement()..accept = '*/*';
    uploadInput.click();
    uploadInput.onChange.listen((event) => setState(() => boardFile = uploadInput.files?.first));
  }

  void _showFileDialog(BuildContext context, Entity entity) {
    String fileUrl = "$baseImageUrl${entity.file}";
    String fileName = entity.file;
    String fileExtension = fileName.split('.').last.toLowerCase();
    bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileExtension);
    bool isTextFile = ['txt', 'm3u', 'log', 'csv'].contains(fileExtension);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('View File: $fileName', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        content: SingleChildScrollView(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _fetchFileAsBase64(fileUrl, fileExtension),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.containsKey('error')) {
                return Column(children: [
                  Text('Error: ${snapshot.data?['error'] ?? 'Unknown'}', style: GoogleFonts.poppins(color: Colors.red, fontSize: 14)),
                  ElevatedButton.icon(
                    onPressed: () => html.window.open(fileUrl, '_blank'),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ]);
              }
              final base64Data = snapshot.data!['data'] as String;
              if (isImage) return Image.memory(base64Decode(base64Data), width: 300, height: 300, fit: BoxFit.contain);
              if (isTextFile) {
                return Container(
                  width: 300,
                  height: 300,
                  child: SingleChildScrollView(
                    child: Text(utf8.decode(base64Decode(base64Data)), style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                  ),
                );
              }
              return Column(children: [
                Text('Cannot preview: $fileExtension', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                ElevatedButton.icon(
                  onPressed: () => html.window.open(fileUrl, '_blank'),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ]);
            },
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => html.window.open(fileUrl, '_blank'),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
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

  void _showTimeSlotsDialog() {
    if (startDate == null || endDate == null) return;
    String dateRange =
        "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')} to ${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Generated Time Slots', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date Range: $dateRange", style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 8),
            Text("Time Slots (${generatedTimeSlots.length}):", style: GoogleFonts.poppins(fontSize: 14)),
            Container(
              height: 300,
              width: 300,
              child: ListView.builder(
                itemCount: generatedTimeSlots.length,
                itemBuilder: (context, index) => ListTile(title: Text(generatedTimeSlots[index], style: GoogleFonts.poppins(fontSize: 14))),
              ),
            ),
            const SizedBox(height: 8),
            Text("Duration: $duration sec", style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showTimeSlotsDialogForEntity(Entity entity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Time Slots for ${entity.name}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date Range: ${entity.startDate} to ${entity.endDate}", style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 8),
            Text("Time Slots (${entity.timeSlots.length}):", style: GoogleFonts.poppins(fontSize: 14)),
            Container(
              height: 300,
              width: 300,
              child: ListView.builder(
                itemCount: entity.timeSlots.length,
                itemBuilder: (context, index) => ListTile(title: Text(entity.timeSlots[index], style: GoogleFonts.poppins(fontSize: 14))),
              ),
            ),
            const SizedBox(height: 8),
            Text("Duration: ${entity.duration} sec", style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 14)),
          ),
        ],
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
          _buildSidebarItem(context, "Partners", PartnersScreen(username: widget.username), Icons.group),
          _buildSidebarItem(context, "Partner Packages", PartnerPackagesScreen(username: widget.username), Icons.handshake),
          _buildSidebarItem(context, "Demo Users", DemoUsersScreen(username: widget.username), Icons.person_outline),
          _buildSidebarItem(context, "Bottom Board", BottomBoardScreen(username: widget.username), Icons.dashboard, isSelected: true),
          _buildSidebarItem(context, "Scrolling", ScrollingScreen(username: widget.username), Icons.text_rotation_none),
          _buildSidebarItem(context, "Logout", null, Icons.logout, onTap: () {
            _showSnackBar("Logged out successfully", Colors.green);
            Navigator.pushReplacementNamed(context, '/'); // Replace with your login screen route
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
    final double padding = isMobile ? 8.0 : 16.0;
    final double fontSize = isMobile ? 12 : 14;
    final double iconSize = isMobile ? 18 : 20;
    final double fieldWidth = isMobile ? 120 : double.infinity;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Add New Bottom Board",
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
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: boardNameController,
                            decoration: InputDecoration(
                              hintText: "Enter Board Name",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                          ),
                        ),
                        SizedBox(width: padding),
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: timeScheduleController,
                            decoration: InputDecoration(
                              hintText: "Select Time Schedule",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                            readOnly: true,
                            onTap: _selectTimeSchedule,
                          ),
                        ),
                        SizedBox(width: padding),
                        Container(
                          width: fieldWidth,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(text: boardFile?.name ?? ""),
                                  decoration: InputDecoration(
                                    hintText: "Upload File",
                                    hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: fontSize),
                                  readOnly: true,
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.attach_file, size: iconSize),
                                onPressed: pickFile,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: padding),
                        FloatingActionButton(
                          onPressed: addBottomBoard,
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
                          controller: boardNameController,
                          decoration: InputDecoration(
                            hintText: "Enter Board Name",
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                          ),
                          style: GoogleFonts.poppins(fontSize: fontSize),
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: TextField(
                          controller: timeScheduleController,
                          decoration: InputDecoration(
                            hintText: "Select Time Schedule",
                            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                          ),
                          style: GoogleFonts.poppins(fontSize: fontSize),
                          readOnly: true,
                          onTap: _selectTimeSchedule,
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: boardFile?.name ?? ""),
                                decoration: InputDecoration(
                                  hintText: "Upload File",
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                                ),
                                style: GoogleFonts.poppins(fontSize: fontSize),
                                readOnly: true,
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.attach_file, size: iconSize),
                              onPressed: pickFile,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: padding),
                      FloatingActionButton(
                        onPressed: addBottomBoard,
                        backgroundColor: primaryColor,
                        mini: false,
                        child: Icon(Icons.add, color: Colors.white, size: iconSize),
                      ),
                    ],
                  );
                }
              },
            ),
            if (generatedTimeSlots.isNotEmpty) ...[
              SizedBox(height: padding),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${generatedTimeSlots.length} time slots selected",
                    style: GoogleFonts.poppins(fontSize: fontSize, color: Colors.black54),
                  ),
                  TextButton(
                    onPressed: _showTimeSlotsDialog,
                    child: Text(
                      "View Time Slots",
                      style: GoogleFonts.poppins(fontSize: fontSize, color: primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableView(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final int totalPages = (bottomBoards.length / itemsPerPage).ceil();

    List<Entity> boardEntities = bottomBoards.map((board) => Entity(
          type: 'Bottom Board',
          name: board['board_name'] ?? 'N/A',
          code: '',
          state: '',
          partner: '',
          file: board['file_name'] ?? 'N/A',
          timeSlots: List<String>.from(jsonDecode(board['time_schedule'])),
          id: board['id'].toString(),
          duration: board['duration'],
          startDate: board['start_date'],
          endDate: board['end_date'],
        )).toList();

    if (boardEntities.isEmpty) {
      return Center(
        child: Text(
          "No bottom boards available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    final paginatedEntities = boardEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, boardEntities.length),
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
                                child: Text('Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 120 : 150,
                                alignment: Alignment.center,
                                child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 150 : 200,
                                alignment: Alignment.center,
                                child: Text('Date Range', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 100 : 120,
                                alignment: Alignment.center,
                                child: Text('Time Slots', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 80 : 100,
                                alignment: Alignment.center,
                                child: Text('Duration', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
                              ),
                            ),
                            DataColumn(
                              label: Container(
                                width: isMobile ? 120 : 150,
                                alignment: Alignment.center,
                                child: Text('File', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
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
                            final int index = entry.key + 1 + (currentPage - 1) * itemsPerPage;
                            final entity = entry.value;
                            return DataRow(cells: [
                              DataCell(
                                Container(
                                  width: isMobile ? 40 : 50,
                                  alignment: Alignment.center,
                                  child: Text('$index', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 100 : 120,
                                  alignment: Alignment.center,
                                  child: Text(entity.type, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text(entity.name, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 150 : 200,
                                  alignment: Alignment.center,
                                  child: Text("${entity.startDate} to ${entity.endDate}", style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 100 : 120,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: () => _showTimeSlotsDialogForEntity(entity),
                                    child: Text("${entity.timeSlots.length} slots", style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 80 : 100,
                                  alignment: Alignment.center,
                                  child: Text("${entity.duration} sec", style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Text(entity.file.split('/').last, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: isMobile ? 120 : 150,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.visibility, color: Colors.green[300], size: isMobile ? 18 : 20),
                                        onPressed: () => _showFileDialog(context, entity),
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
                            ]);
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: isMobile ? 8 : 16),
              _buildPaginationControls(totalPages, isMobile),
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
        ],
      ),
    );
  }

  Widget _buildBoardView(double screenWidth) {
    final bool isMobile = screenWidth < 600;

    List<Entity> boardEntities = bottomBoards.map((board) => Entity(
          type: 'Bottom Board',
          name: board['board_name'] ?? 'N/A',
          code: '',
          state: '',
          partner: '',
          file: board['file_name'] ?? 'N/A',
          timeSlots: List<String>.from(jsonDecode(board['time_schedule'])),
          id: board['id'].toString(),
          duration: board['duration'],
          startDate: board['start_date'],
          endDate: board['end_date'],
        )).toList();

    if (boardEntities.isEmpty) {
      return Center(
        child: Text(
          "No bottom boards available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: drawerColor, borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: Stack(
        children: [
          GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isMobile ? 300 : 350,
              childAspectRatio: isMobile ? 2 / 3 : 3 / 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            padding: const EdgeInsets.all(8),
            itemCount: boardEntities.length,
            itemBuilder: (context, index) {
              final entity = boardEntities[index];
              return Card(
                color: cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entity.name,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: ${entity.startDate} to ${entity.endDate}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: isMobile ? 10 : 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showTimeSlotsDialogForEntity(entity),
                        child: Text(
                          'Time Slots: ${entity.timeSlots.length} slots',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: isMobile ? 10 : 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration: ${entity.duration} sec',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: isMobile ? 10 : 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'File: ${entity.file.split('/').last}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: isMobile ? 10 : 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.visibility, color: Colors.green[300], size: isMobile ? 18 : 20),
                            onPressed: () => _showFileDialog(context, entity),
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
                    ],
                  ),
                ),
              );
            },
          ),
          if (isLoading) const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: isMobile ? 18 : 20),
          onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
        ),
        Text('Page $currentPage of $totalPages', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
        IconButton(
          icon: Icon(Icons.arrow_forward, color: Colors.white, size: isMobile ? 18 : 20),
          onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
        ),
        const SizedBox(width: 10),
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
    );
  }

  void _showEditDialog(BuildContext context, Entity entity) {
    final nameController = TextEditingController(text: entity.name);
    html.File? updatedFile;

    setState(() {
      generatedTimeSlots = List.from(entity.timeSlots);
      startDate = DateTime.tryParse(entity.startDate) ?? DateTime.now();
      endDate = DateTime.tryParse(entity.endDate) ?? DateTime.now();
      duration = entity.duration;
      timeScheduleController.text = "${generatedTimeSlots.length} time slots selected";
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Bottom Board', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Board Name',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeScheduleController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Time Schedule',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                ),
                readOnly: true,
                onTap: _selectTimeSchedule,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) => Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: updatedFile?.name ?? entity.file),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white),
                      onPressed: () {
                        final uploadInput = html.FileUploadInputElement()..accept = '*/*';
                        uploadInput.click();
                        uploadInput.onChange.listen((event) {
                          final files = uploadInput.files;
                          if (files != null && files.isNotEmpty) setDialogState(() => updatedFile = files[0]);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              updateBottomBoard(entity, nameController.text, updatedFile);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
          ),
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
        content: Text('Are you sure you want to delete "${entity.name}"?', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
          ),
          ElevatedButton(
            onPressed: () {
              deleteBottomBoard(entity.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontSize: screenWidth > 600 ? 14 : 12)),
          ),
        ],
      ),
    );
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
              isBoardView ? Icons.table_chart : Icons.grid_view,
              color: primaryColor,
            ),
            onPressed: () => setState(() => isBoardView = !isBoardView),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: primaryColor,
            ),
            onPressed: fetchBottomBoards,
          ),
        ],
      ),
      drawer: _buildSidebar(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final bool isMobile = screenWidth < 600;
          final double padding = isMobile ? 8.0 : 16.0;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAddSection(screenWidth),
                    SizedBox(height: padding),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: isBoardView ? _buildBoardView(screenWidth) : _buildTableView(screenWidth),
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
  final List<String> timeSlots;
  final String id;
  final int duration;
  final String startDate;
  final String endDate;

  const Entity({
    required this.type,
    required this.name,
    required this.code,
    required this.state,
    required this.partner,
    required this.file,
    required this.timeSlots,
    required this.id,
    required this.duration,
    required this.startDate,
    required this.endDate,
  });
}