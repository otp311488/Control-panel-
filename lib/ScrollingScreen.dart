import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ScrollingScreen extends StatefulWidget {
  final String? username;
  const ScrollingScreen({this.username, super.key});

  @override
  _ScrollingScreenState createState() => _ScrollingScreenState();
}

class _ScrollingScreenState extends State<ScrollingScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> scrollItems = [];
  TextEditingController scrollingNameController = TextEditingController();
  TextEditingController scriptController = TextEditingController();
  TextEditingController timeScheduleController = TextEditingController();
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  int itemsPerPage = 50;
  int currentPage = 1;
  bool isBoardView = false;
  bool _isAddButtonEnabled = true;

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

  static const String apiGetScrollItems = "https://sms.mydreamplaytv.com/get-scrolling-messages.php";
  static const String apiAddScrollItem = "https://sms.mydreamplaytv.com/add_scrolling_message.php";
  static const String apiUpdateScrollItem = "https://sms.mydreamplaytv.com/update-scrolling-message.php";
  static const String apiDeleteScrollItem = "https://sms.mydreamplaytv.com/delete-scrolling-message.php";

  static const List<String> daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    fetchScrollItems();
  }

  @override
  void dispose() {
    _animationController.dispose();
    scrollingNameController.dispose();
    scriptController.dispose();
    timeScheduleController.dispose();
    super.dispose();
  }

  String _extractJson(String response) => response.indexOf('{') != -1 ? response.substring(response.indexOf('{')) : "";

  Future<void> fetchScrollItems() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiGetScrollItems));
      if (response.statusCode == 200) {
        final jsonResponse = _extractJson(response.body);
        if (jsonResponse.isNotEmpty) {
          final data = jsonDecode(jsonResponse);
          if (data["success"]) {
            setState(() => scrollItems = List<Map<String, dynamic>>.from(data["messages"]));
          } else {
            setState(() => scrollItems = []);
          }
        }
      } else {
        _showSnackBar("Failed to fetch scroll items: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error fetching scroll items: $e", Colors.red);
      setState(() => scrollItems = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  bool _hasOverlappingTimeSlots(List<String> newTimeSlots, {String? excludeItemId}) {
  for (var item in scrollItems) {
    if (excludeItemId != null && item['id'].toString() == excludeItemId) continue;
    try {
      dynamic timeSchedule = item['time_schedule'];
      // Ensure the timeSchedule is converted to List<String>
      List<String> existingSlots;
      if (timeSchedule is String) {
        // Decode the JSON string and map each element to a string
        final decoded = jsonDecode(timeSchedule);
        existingSlots = (decoded as List<dynamic>).map((e) => e.toString()).toList();
      } else if (timeSchedule is List) {
        // If it's already a list, map each element to a string
        existingSlots = timeSchedule.map((e) => e.toString()).toList();
      } else {
        // Handle unexpected format
        _showSnackBar("Invalid time schedule format for item ${item['scrolling_name']}", Colors.red);
        continue;
      }

      DateTime existingStart = DateTime.parse(item['start_date']);
      DateTime existingEnd = DateTime.parse(item['end_date']);
      if (!(endDate!.isBefore(existingStart) || startDate!.isAfter(existingEnd))) {
        for (var newSlot in newTimeSlots) {
          if (existingSlots.contains(newSlot)) return true;
        }
      }
    } catch (e) {
      _showSnackBar("Error parsing time slots for item ${item['scrolling_name']}: $e", Colors.red);
    }
  }
  return false;
}
  Future<void> addScrollItem() async {
    if (scrollingNameController.text.isEmpty || scriptController.text.isEmpty || generatedTimeSlots.isEmpty || startDate == null || endDate == null) {
      _showSnackBar("Please fill all fields and set a date range", Colors.red);
      return;
    }
    if (_hasOverlappingTimeSlots(generatedTimeSlots)) {
      _showSnackBar("Selected time slots overlap with existing items.", Colors.red);
      return;
    }
    setState(() {
      isLoading = true;
      _isAddButtonEnabled = false;
    });
    try {
      final response = await http.post(
        Uri.parse(apiAddScrollItem),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "scrolling_name": scrollingNameController.text.trim(),
          "script": scriptController.text.trim(),
          "time_schedule": jsonEncode(generatedTimeSlots),
          "duration": duration,
          "start_date": "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}",
          "end_date": "${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}",
        }),
      );
      final data = jsonDecode(_extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) {
        scrollingNameController.clear();
        scriptController.clear();
        timeScheduleController.clear();
        setState(() {
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
        await fetchScrollItems();
      }
    } catch (e) {
      _showSnackBar("Error adding scroll item: $e", Colors.red);
    } finally {
      setState(() {
        isLoading = false;
        _isAddButtonEnabled = true;
      });
    }
  }

  Future<void> updateScrollItem(Entity entity, String newScrollingName, String newScript) async {
    if (_hasOverlappingTimeSlots(generatedTimeSlots, excludeItemId: entity.id)) {
      _showSnackBar("Selected time slots overlap with existing items.", Colors.red);
      return;
    }
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(apiUpdateScrollItem),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": entity.id,
          "scrolling_name": newScrollingName,
          "script": newScript,
          "time_schedule": jsonEncode(generatedTimeSlots),
          "duration": duration,
          "start_date": "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}",
          "end_date": "${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}",
        }),
      );
      final data = jsonDecode(_extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchScrollItems();
    } catch (e) {
      _showSnackBar("Error updating scroll item: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteScrollItem(String id) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(apiDeleteScrollItem),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      final data = jsonDecode(_extractJson(response.body));
      _showSnackBar(data["message"], data["success"] ? Colors.green : Colors.red);
      if (data["success"]) await fetchScrollItems();
    } catch (e) {
      _showSnackBar("Error deleting scroll item: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectTimeSchedule() async {
    final currentDate = DateTime.now();
    DateTime? tempStartDate = startDate;
    DateTime? tempEndDate = endDate;
    List<String> tempSelectedDays = List.from(selectedDays);
    int? tempStartHour = startTime?.hour;
    int? tempStartMinute = startTime?.minute;
    int? tempEndHour = endTime?.hour;
    int? tempEndMinute = endTime?.minute;
    String tempTimeSlotIncrementUnit = timeSlotIncrementUnit ?? "minutes";
    int tempTimeSlotIncrementValue = timeSlotIncrementValue;
    int tempDuration = duration;

    bool isDateRangeValid = true;

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
            isDateRangeValid = tempStartDate != null &&
                tempEndDate != null &&
                !tempEndDate!.isBefore(tempStartDate!) &&
                !tempStartDate!.isAfter(currentDate) &&
                !tempEndDate!.isAfter(currentDate);
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
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: tempStartDate ?? currentDate,
                              firstDate: DateTime(2000),
                              lastDate: currentDate,
                            );
                            if (selectedDate != null) {
                              setDialogState(() => tempStartDate = selectedDate);
                              validateDates();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tempStartDate != null
                                  ? "${tempStartDate!.year}-${tempStartDate!.month.toString().padLeft(2, '0')}-${tempStartDate!.day.toString().padLeft(2, '0')}"
                                  : "Select Start Date",
                              style: GoogleFonts.poppins(fontSize: 12, color: tempStartDate == null ? Colors.grey : Colors.black),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("to"),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: tempEndDate ?? currentDate,
                              firstDate: DateTime(2000),
                              lastDate: currentDate,
                            );
                            if (selectedDate != null) {
                              setDialogState(() => tempEndDate = selectedDate);
                              validateDates();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tempEndDate != null
                                  ? "${tempEndDate!.year}-${tempEndDate!.month.toString().padLeft(2, '0')}-${tempEndDate!.day.toString().padLeft(2, '0')}"
                                  : "Select End Date",
                              style: GoogleFonts.poppins(fontSize: 12, color: tempEndDate == null ? Colors.grey : Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isDateRangeValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Invalid date range or future dates not allowed",
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                      ),
                    ),
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
                  Row(
                    children: [
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
                    ],
                  ),
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
                      onPressed: isDateRangeValid &&
                              tempStartDate != null &&
                              tempEndDate != null &&
                              tempSelectedDays.isNotEmpty &&
                              tempStartHour != null &&
                              tempEndHour != null
                          ? () {
                              setState(() {
                                startDate = tempStartDate;
                                endDate = tempEndDate;
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

  void _generateTimeSlots() {
    if (startDate == null || endDate == null || startTime == null || endTime == null || selectedDays.isEmpty) return;
    generatedTimeSlots.clear();

    int startSeconds = (startTime!.hour * 3600) + (startTime!.minute * 60);
    int endSeconds = (endTime!.hour * 3600) + (endTime!.minute * 60);
    int incrementInSeconds = timeSlotIncrementUnit == "minutes" ? timeSlotIncrementValue * 60 : timeSlotIncrementValue;

    if (endSeconds <= startSeconds) {
      _showSnackBar("End time must be after start time", Colors.red);
      return;
    }

    final dayIndices = {
      "Sun": 0,
      "Mon": 1,
      "Tue": 2,
      "Wed": 3,
      "Thu": 4,
      "Fri": 5,
      "Sat": 6,
    };

    DateTime currentDate = startDate!;
    while (!currentDate.isAfter(endDate!)) {
      int dayOfWeek = currentDate.weekday % 7;
      String dayName = daysOfWeek[dayOfWeek];
      if (selectedDays.contains(dayName)) {
        for (int currentSeconds = startSeconds; currentSeconds <= endSeconds; currentSeconds += incrementInSeconds) {
          int hours = currentSeconds ~/ 3600;
          int minutes = (currentSeconds % 3600) ~/ 60;
          String timeSlot = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
          generatedTimeSlots.add(timeSlot);
        }
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    setState(() {});
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
              "Add New Scroll Item",
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
                            controller: scrollingNameController,
                            decoration: InputDecoration(
                              hintText: "Enter Name",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: padding),
                        Container(
                          width: fieldWidth,
                          child: TextField(
                            controller: scriptController,
                            decoration: InputDecoration(
                              hintText: "Enter Script",
                              hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: fontSize),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(vertical: fontSize == 12 ? 8 : 10, horizontal: 12),
                            ),
                            style: GoogleFonts.poppins(fontSize: fontSize),
                            maxLines: 1,
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
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: padding),
                        FloatingActionButton(
                          onPressed: (_isAddButtonEnabled && !isLoading) ? addScrollItem : null,
                          backgroundColor: (_isAddButtonEnabled && !isLoading) ? primaryColor : Colors.grey,
                          mini: true,
                          child: isLoading
                              ? SizedBox(width: iconSize, height: iconSize, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(Icons.add, color: Colors.white, size: iconSize),
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
                          controller: scrollingNameController,
                          decoration: InputDecoration(
                            hintText: "Enter Name",
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
                          controller: scriptController,
                          decoration: InputDecoration(
                            hintText: "Enter Script",
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
                      FloatingActionButton(
                        onPressed: (_isAddButtonEnabled && !isLoading) ? addScrollItem : null,
                        backgroundColor: (_isAddButtonEnabled && !isLoading) ? primaryColor : Colors.grey,
                        mini: false,
                        child: isLoading
                            ? SizedBox(width: iconSize, height: iconSize, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(Icons.add, color: Colors.white, size: iconSize),
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

  Widget _buildPaginatedDataSection(double screenWidth) {
    final bool isMobile = screenWidth < 600;
    final int totalPages = (scrollItems.length / itemsPerPage).ceil();

    List<Entity> itemEntities = scrollItems.map((item) => Entity(
          type: 'Scroll Item',
          name: item['scrolling_name'] ?? 'N/A',
          code: item['script'] ?? 'N/A',
          state: '',
          partner: '',
          file: '',
          timeSlots: List<String>.from(jsonDecode(item['time_schedule'])),
          id: item['id'].toString(),
          duration: int.tryParse(item['duration'].toString()) ?? 5,
          startDate: item['start_date'] ?? 'N/A',
          endDate: item['end_date'] ?? 'N/A',
        )).toList();

    if (itemEntities.isEmpty) {
      return Center(
        child: Text(
          "No scroll items available",
          style: GoogleFonts.poppins(fontSize: isMobile ? 14 : 16, color: Colors.black),
        ),
      );
    }

    final paginatedEntities = itemEntities.sublist(
      (currentPage - 1) * itemsPerPage,
      (currentPage * itemsPerPage).clamp(0, itemEntities.length),
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
                                child: Text('Script', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: isMobile ? 12 : 14)),
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
                                  child: Text(entity.code, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14), overflow: TextOverflow.ellipsis),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.cyan[300], size: isMobile ? 18 : 20),
                                        onPressed: () => _showEditDialog(context, entity, isMobile),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red[300], size: isMobile ? 18 : 20),
                                        onPressed: () => _showDeleteConfirmation(context, entity, isMobile),
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
          isLoading ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))) : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildBoardView(double screenWidth) {
    final bool isMobile = screenWidth < 600;

    List<Entity> itemEntities = scrollItems.map((item) => Entity(
          type: 'Scroll Item',
          name: item['scrolling_name'] ?? 'N/A',
          code: item['script'] ?? 'N/A',
          state: '',
          partner: '',
          file: '',
          timeSlots: List<String>.from(jsonDecode(item['time_schedule'])),
          id: item['id'].toString(),
          duration: int.tryParse(item['duration'].toString()) ?? 5,
          startDate: item['start_date'] ?? 'N/A',
          endDate: item['end_date'] ?? 'N/A',
        )).toList();

    if (itemEntities.isEmpty) {
      return Center(
        child: Text(
          "No scroll items available",
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
            itemCount: itemEntities.length,
            itemBuilder: (context, index) {
              final entity = itemEntities[index];
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
                        'Script: ${entity.code}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: isMobile ? 10 : 12),
                        maxLines: 2,
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
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.cyan[300], size: isMobile ? 18 : 20),
                            onPressed: () => _showEditDialog(context, entity, isMobile),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red[300], size: isMobile ? 18 : 20),
                            onPressed: () => _showDeleteConfirmation(context, entity, isMobile),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          isLoading ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor))) : const SizedBox.shrink(),
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

  void _showEditDialog(BuildContext context, Entity entity, bool isMobile) {
    final nameController = TextEditingController(text: entity.name);
    final scriptController = TextEditingController(text: entity.code);
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
        title: Text('Edit Scroll Item', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isMobile ? 16 : 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14),
                decoration: InputDecoration(
                  labelText: 'Scrolling Name',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                  contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10, horizontal: 12),
                ),
              ),
              SizedBox(height: isMobile ? 8 : 12),
              TextField(
                controller: scriptController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14),
                decoration: InputDecoration(
                  labelText: 'Script',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                  contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10, horizontal: 12),
                ),
              ),
              SizedBox(height: isMobile ? 8 : 12),
              TextField(
                controller: timeScheduleController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14),
                decoration: InputDecoration(
                  labelText: 'Time Schedule',
                  labelStyle: GoogleFonts.poppins(color: Colors.white70),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: cardColor,
                  contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10, horizontal: 12),
                ),
                readOnly: true,
                onTap: _selectTimeSchedule,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
          ),
          ElevatedButton(
            onPressed: () {
              updateScrollItem(entity, nameController.text, scriptController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Entity entity, bool isMobile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: drawerColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Deletion', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isMobile ? 16 : 18)),
        content: Text('Are you sure you want to delete scrolling message "${entity.name}"?', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
          ),
          ElevatedButton(
            onPressed: () {
              deleteScrollItem(entity.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 12 : 14)),
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
            onPressed: fetchScrollItems,
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
                  child: isBoardView ? _buildBoardView(screenWidth) : _buildPaginatedDataSection(screenWidth),
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