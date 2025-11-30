import 'package:flutter/material.dart';

class ScrollingMessagesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> scrollingMessages; // Accept the scrollingMessages list

  const ScrollingMessagesScreen({Key? key, required this.scrollingMessages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("All Scrolling Messages"),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView.builder(
        itemCount: scrollingMessages.length,
        itemBuilder: (context, index) {
          final message = scrollingMessages[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                message["scrolling_name"],
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                "Script: ${message["script"]}\nTime Schedule: ${message["time_schedule"]}",
              ),
              leading: Icon(Icons.message, color: Colors.green),
              onTap: () {
                // Optional: Navigate to a detailed view of the selected message
                // You can create another screen for this if needed
              },
            ),
          );
        },
      ),
    );
  }
}