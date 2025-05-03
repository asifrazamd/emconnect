import 'dart:io';
import 'package:flutter/material.dart';
import 'package:universal_ble_example/BottomNavigation.dart';
import 'package:url_launcher/url_launcher.dart'
    show LaunchMode, canLaunch, canLaunchUrl, launch, launchUrl;
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';


class Log extends StatefulWidget {
  const Log({super.key});

  @override
  State<Log> createState() => _LogState();
}

class _LogState extends State<Log> with WidgetsBindingObserver {
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLogs(); // Load logs after checking
  }

  // Handling lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _deleteLogFile(); // Delete the log file when the app is paused or detached
    }
  }

  // Load logs for display in UI
  Future<void> _loadLogs() async {
    List<String> logs = await _readLastConnectionLogs();
    setState(() {
      _logs = logs;
    });
  }

  // Read the last connection logs only from file
  Future<List<String>> _readLastConnectionLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/logs.txt');

    if (await logFile.exists()) {
      String contents = await logFile.readAsString();
      List<String> connections = contents.split('--Connection Start--');
      if (connections.isNotEmpty) {
        return connections.last
            .split('\n')
            .where((line) => line.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  // Delete the log file
  Future<void> _deleteLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/logs.txt');
    if (await logFile.exists()) {
      await logFile.delete();
      print("Log file deleted"); // Print confirmation for debugging
    } else {
      print("Log file not found"); // If file does not exist
    }
  }

  // Clear the logs in the UI and the log file
  Future<void> _clearLogs() async {
    setState(() {
      _logs.clear(); // Clear the logs in the UI
    });

    // Also delete the log file
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/logs.txt');
    if (await logFile.exists()) {
      await logFile.delete(); // Delete the file
      print("Log file deleted");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(248, 247, 245, 1),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text("Logs",
            style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold)),
        backgroundColor: Color.fromRGBO(248, 247, 245, 1),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () {
              _clearLogs(); // Trigger the clear functionality
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              _logs[index],
              style: TextStyle(
                fontSize: 13.0, // Set the font size here
                color: Colors.black, // Optional: Adjust the color
              ),
            ),
          );
        },
      ),
    );
  }
}
