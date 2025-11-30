import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  final String? username;
  const DashboardScreen({this.username, super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color primaryColor = Color(0xFF00897B);
  static const Color backgroundColor = Color(0xFFECEFF1);
  static const Color cardColor = Color(0xFF455A64);
  static const Color chartColor = Colors.purple;

  List<Map<String, dynamic>> partners = [];
  List<Map<String, dynamic>> demoUsers = [];
  List<Map<String, dynamic>> scrollingMessages = [];
  List<Map<String, dynamic>> bottomBoards = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchPartners(),
      fetchDemoUsers(),
      fetchScrollingMessages(),
      fetchBottomBoards(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> fetchPartners() async {
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-partners.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"]) {
          setState(() => partners = List<Map<String, dynamic>>.from(data["partners"]));
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching partners: $e", Colors.red);
    }
  }

  Future<void> fetchDemoUsers() async {
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-demo-users.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"]) {
          setState(() {
            demoUsers = List<Map<String, dynamic>>.from(data["users"]);
            // Debug print to verify data
            demoUsers.forEach((user) {
              debugPrint('Demo User: ${user['id']}, added: ${user['added_at']}, validity: ${user['validity']}');
            });
          });
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching demo users: $e", Colors.red);
    }
  }

  Future<void> fetchScrollingMessages() async {
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-scrolling-messages.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"]) {
          setState(() => scrollingMessages = List<Map<String, dynamic>>.from(data["messages"]));
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching scrolling messages: $e", Colors.red);
    }
  }

  Future<void> fetchBottomBoards() async {
    try {
      final response = await http.get(Uri.parse("https://sms.mydreamplaytv.com/get-bottom-boards.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"]) {
          setState(() => bottomBoards = List<Map<String, dynamic>>.from(data["data"]["package_list"]));
        }
      }
    } catch (e) {
      _showSnackBar("Error fetching bottom boards: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int countByDay(List<Map<String, dynamic>> items, String dateField, DateTime day) {
    return items.where((item) {
      final dateStr = item[dateField];
      if (dateStr == null) return false;
      try {
        final itemDate = DateTime.parse(dateStr);
        return itemDate.year == day.year && itemDate.month == day.month && itemDate.day == day.day;
      } catch (e) {
        return false;
      }
    }).length;
  }

  int countActive(List<Map<String, dynamic>> items, String startField, String endField) {
    final now = DateTime.now();
    return items.where((item) {
      final startDateStr = item[startField];
      final endDateStr = item[endField];
      if (startDateStr == null || endDateStr == null) return false;
      try {
        final startDate = DateTime.parse(startDateStr);
        final endDate = DateTime.parse(endDateStr);
        return now.isAfter(startDate) && now.isBefore(endDate);
      } catch (e) {
        return false;
      }
    }).length;
  }
bool isDemoUserActive(Map<String, dynamic> user) {
  final addedAtStr = user['added_at'] ?? user['created_at'];
  final validityDays = int.tryParse(user['validity']?.toString() ?? '0') ?? 0;
  
  if (addedAtStr == null || validityDays <= 0) return false;
  
  try {
    // Parse only the date part (ignore time)
    final addedAt = DateTime.parse(addedAtStr.toString().split(' ')[0]);
    final expiryDate = addedAt.add(Duration(days: validityDays));
    final now = DateTime.now();
    
    debugPrint('User ${user['id']}: Added $addedAt, Expires $expiryDate, Now $now, Active: ${now.isBefore(expiryDate)}');
    
    // User is active if current date is before expiry date
    return now.isBefore(expiryDate);
  } catch (e) {
    debugPrint('Error parsing dates for user ${user['id']}: $e');
    return false;
  }
}
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 900;
        final crossAxisCount = isMobile ? 2 : isTablet ? 3 : 6;

        final padding = screenWidth < 600 ? 8.0 : screenWidth < 900 ? 12.0 : 16.0;
        final fontScale = screenWidth < 600 ? 0.8 : screenWidth < 900 ? 0.9 : 1.0;

        // Calculate counts
        final totalPartners = partners.length;
        final totalDemoUsers = demoUsers.length;
        final activeDemoUsers = demoUsers.where((user) => isDemoUserActive(user)).length;
        final expiredDemoUsers = totalDemoUsers - activeDemoUsers;
        final activeScrollingMessages = countActive(scrollingMessages, 'start_date', 'end_date');
        final activeBottomBoards = countActive(bottomBoards, 'startDate', 'endDate');

        return isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)))
            : SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dashboard",
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 24 * fontScale : 28 * fontScale,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: padding),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: padding,
                      crossAxisSpacing: padding,
                      childAspectRatio: 3.0,
                      children: [
                        _buildSummaryCard("Total Partners", totalPartners, Colors.blue, fontScale),
                        _buildSummaryCard("Total Demo Users", totalDemoUsers, Colors.green, fontScale),
                        _buildSummaryCard("Active Demo Users", activeDemoUsers, Colors.teal, fontScale),
                        _buildSummaryCard("Expired Demo Users", expiredDemoUsers, Colors.redAccent, fontScale),
                        _buildSummaryCard("Active Scrolling Messages", activeScrollingMessages, Colors.orange, fontScale),
                        _buildSummaryCard("Active Bottom Boards", activeBottomBoards, Colors.red, fontScale),
                      ],
                    ),
                    SizedBox(height: padding),
                    _buildStatisticsCards(isMobile, padding, fontScale),
                    SizedBox(height: padding),
                    _buildCharts(isMobile, padding, fontScale, screenWidth),
                  ],
                ),
              );
      },
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color, double fontScale) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 10 * fontScale, color: Colors.black54),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14 * fontScale,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(bool isMobile, double padding, double fontScale) {
    final children = [
      _buildStatsCard("Partner Statistics", _buildPartnerStats(fontScale), fontScale),
      _buildStatsCard("Demo User Statistics", _buildDemoUserStats(fontScale), fontScale),
      _buildStatsCard("Scrolling Message Stats", _buildScrollingStats(fontScale), fontScale),
      _buildStatsCard("Bottom Board Stats", _buildBottomBoardStats(fontScale), fontScale),
    ];

    return isMobile
        ? Column(
            children: children.map((child) => Padding(
                  padding: EdgeInsets.only(bottom: padding),
                  child: child,
                )).toList(),
          )
        : GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: padding,
            crossAxisSpacing: padding,
            childAspectRatio: 3.0,
            children: children,
          );
  }

  Widget _buildStatsCard(String title, Widget content, double fontScale) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12 * fontScale,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerStats(double fontScale) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final thisMonthStart = DateTime(today.year, today.month, 1);
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = DateTime(today.year, today.month, 0);

    final registeredThisMonth = partners.where((p) {
      final dateStr = p['registration_date'];
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr);
        return date.isAfter(thisMonthStart) || date.isAtSameMomentAs(thisMonthStart);
      } catch (e) {
        return false;
      }
    }).length;

    final registeredLastMonth = partners.where((p) {
      final dateStr = p['registration_date'];
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr);
        return date.isAfter(lastMonthStart) && date.isBefore(lastMonthEnd);
      } catch (e) {
        return false;
      }
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow("Registered Today", countByDay(partners, 'registration_date', today), fontScale),
        _buildStatRow("Registered Yesterday", countByDay(partners, 'registration_date', yesterday), fontScale),
        _buildStatRow("Registered This Month", registeredThisMonth, fontScale),
        _buildStatRow("Registered Last Month", registeredLastMonth, fontScale),
      ],
    );
  }

  Widget _buildDemoUserStats(double fontScale) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final thisMonthStart = DateTime(today.year, today.month, 1);
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = DateTime(today.year, today.month, 0);

    final registeredThisMonth = demoUsers.where((u) {
      final dateStr = u['added_at'] ?? u['created_at'];
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr.split(' ')[0]);
        return date.isAfter(thisMonthStart) || date.isAtSameMomentAs(thisMonthStart);
      } catch (e) {
        return false;
      }
    }).length;

    final registeredLastMonth = demoUsers.where((u) {
      final dateStr = u['added_at'] ?? u['created_at'];
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr.split(' ')[0]);
        return date.isAfter(lastMonthStart) && date.isBefore(lastMonthEnd);
      } catch (e) {
        return false;
      }
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow("Registered Today", countByDay(demoUsers, 'added_at', today), fontScale),
        _buildStatRow("Registered Yesterday", countByDay(demoUsers, 'added_at', yesterday), fontScale),
        _buildStatRow("Registered This Month", registeredThisMonth, fontScale),
        _buildStatRow("Registered Last Month", registeredLastMonth, fontScale),
      ],
    );
  }

  Widget _buildScrollingStats(double fontScale) {
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow("Active Today", countActive(scrollingMessages, 'start_date', 'end_date'), fontScale),
        _buildStatRow("Starting Today", countByDay(scrollingMessages, 'start_date', today), fontScale),
        _buildStatRow("Ending Today", countByDay(scrollingMessages, 'end_date', today), fontScale),
        _buildStatRow("Total Messages", scrollingMessages.length, fontScale),
      ],
    );
  }

  Widget _buildBottomBoardStats(double fontScale) {
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow("Active Today", countActive(bottomBoards, 'startDate', 'endDate'), fontScale),
        _buildStatRow("Starting Today", countByDay(bottomBoards, 'startDate', today), fontScale),
        _buildStatRow("Ending Today", countByDay(bottomBoards, 'endDate', today), fontScale),
        _buildStatRow("Total Boards", bottomBoards.length, fontScale),
      ],
    );
  }

  Widget _buildStatRow(String label, int value, double fontScale) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10 * fontScale, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(fontSize: 10 * fontScale, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCharts(bool isMobile, double padding, double fontScale, double screenWidth) {
    final children = [
      _buildChart("Partners Over Time", partners, 'registration_date', fontScale, screenWidth),
      _buildChart("Demo Users Over Time", demoUsers, 'added_at', fontScale, screenWidth),
      _buildChart("Scrolling Messages Over Time", scrollingMessages, 'created_at', fontScale, screenWidth),
      _buildChart("Bottom Boards Over Time", bottomBoards, 'createdAt', fontScale, screenWidth),
    ];

    return isMobile
        ? Column(
            children: children.map((child) => Padding(
                  padding: EdgeInsets.only(bottom: padding),
                  child: child,
                )).toList(),
          )
        : GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: padding,
            crossAxisSpacing: padding,
            childAspectRatio: 3.0,
            children: children,
          );
  }

  Widget _buildChart(String title, List<Map<String, dynamic>> items, String dateField, double fontScale, double screenWidth) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final spots = days.asMap().entries.map((e) => FlSpot(e.key.toDouble(), countByDay(items, dateField, e.value).toDouble())).toList();

    final chartHeight = screenWidth < 600 ? 75.0 : screenWidth < 900 ? 100.0 : 125.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12 * fontScale,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: chartHeight,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(fontSize: 12 * fontScale, color: Colors.black87),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) => Text(
                          DateFormat('dd').format(days[value.toInt()]),
                          style: GoogleFonts.poppins(fontSize: 12 * fontScale, color: Colors.black87),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: chartColor,
                      barWidth: 1,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: chartColor.withOpacity(0.2)),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}