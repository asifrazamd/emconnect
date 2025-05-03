import 'dart:io';
import 'package:flutter/material.dart';
import 'package:universal_ble_example/BottomNavigation.dart';
import 'package:url_launcher/url_launcher.dart'
    show LaunchMode, canLaunch, canLaunchUrl, launch, launchUrl;
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:universal_ble_example/info.dart';
import 'package:universal_ble_example/log.dart';
import 'package:universal_ble_example/about.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BottomNavigationHandler(initialIndex: 0);
  }
}

class Beacontab extends StatelessWidget {
  const Beacontab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Info();
  }

}

class Logtab extends StatelessWidget {
  const Logtab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Log();
  }
}


void _showDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}



class Settingstab extends StatelessWidget {
  const Settingstab({super.key});

  @override
  Widget build(BuildContext context) {
    return const About();
  }
}
