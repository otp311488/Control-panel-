import 'package:flutter/material.dart';

class DemoUser_DetailScreen extends StatelessWidget {
  final List<Map<String, dynamic>> demoUsers;

  const DemoUser_DetailScreen({Key? key, required this.demoUsers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("Demo users in detail screen: $demoUsers"); // Debug print
    return Scaffold(
      appBar: AppBar(
        title: Text("All Demo Users"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Main content (if any)
          Expanded(
            child: ListView.builder(
              itemCount: demoUsers.length,
              itemBuilder: (context, index) {
                final user = demoUsers[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      user["mobile_number"],
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(
                      "Default Pack: ${user["default_pack"]}\nValidity: ${user["validity"]} days\nFile: ${user["file_name"]}",
                    ),
                    leading: Icon(Icons.person, color: Colors.blue),
                    onTap: () {
                      // Optional: Navigate to a detailed view of the selected user
                    },
                  ),
                );
              },
            ),
          ),
          // Bottom section to display all demo users
          Container(
            height: 100, // Adjust height as needed
            color: Colors.grey[200],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: demoUsers.length,
              itemBuilder: (context, index) {
                final user = demoUsers[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Chip(
                    label: Text(user["mobile_number"]),
                    avatar: Icon(Icons.person, color: Colors.blue),
                    backgroundColor: Colors.white,
                    elevation: 2,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}