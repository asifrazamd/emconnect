import 'dart:io';
import 'package:flutter/material.dart';
import 'package:universal_ble_example/BottomNavigation.dart';
import 'package:url_launcher/url_launcher.dart'
    show LaunchMode, canLaunch, canLaunchUrl, launch, launchUrl;
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';


class About extends StatelessWidget {
  const About({super.key});

  Future<Map<String, String>> _getAppInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return {
      'version': packageInfo.version, // Get the version number
      'buildNumber': packageInfo.buildNumber, // Get the build number
    };
  }

  Future<void> _launchURL(Uri url) async {
    if (true) {
      await launchUrl(url);
    } else {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(247, 247, 244, 244),
      appBar: AppBar(
        title: Text(
          'About',
          style: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color.fromARGB(184, 252, 250, 250),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 10),
                  _buildHeading('ABOUT THIS APP'),
                ],
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.zero,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8), // Adjust the radius as needed
                  ),
                  color: Colors.white,
                  margin: EdgeInsets.all(1),
                  child: SizedBox(
                    width: 500, // Set your desired width
                    height: 35, // Set your desired height
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  SizedBox(width: 20),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Text('Application Version'),
                                    ),
                                  ),
                                  FutureBuilder<Map<String, String>>(
                                    future: _getAppInfo(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return CircularProgressIndicator();
                                      } else if (snapshot.hasError) {
                                        return Text('Error');
                                      } else {
                                        final version =
                                            snapshot.data?['version'] ?? 'N/A';
                                        final buildNumber =
                                            snapshot.data?['buildNumber'] ??
                                                'N/A';
                                        // return Text('$version (Build: $buildNumber)');
                                        return Text('$version($buildNumber)');
                                      }
                                    },
                                  ),
                                  SizedBox(width: 20),
                                ],
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildCard1('Feedback & Report Issue', ''),
              _buildCard1('Acknowledgements', ''),
              _buildCard2(
                  'Privacy Policy', 'https://sclabsglobal.com/PrivacyPolicy'),
              SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(width: 10),
                  _buildHeading('WHO ARE WE'),
                ],
              ),
              SizedBox(height: 10),
              _buildCard2('About Us', 'https://sclabsglobal.com/AboutUs'),
              _buildCard3('Services and Capabilities', ''),
              _buildCard3('Project Inquiry', ''),
              SizedBox(height: 10),
              Center(
                child: Text(
                  'Copyright © 2025 EM Microelectronic - Marin SA',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              SizedBox(height: 40),
              Center(
                child: Text(
                  "em | connect",
                  style: TextStyle(
                      color: Color.fromARGB(255, 50, 127, 168),
                      fontSize: 30,
                      fontWeight: FontWeight.bold),
                ),
              ),
              //  SizedBox(height: 20),
              // Center(
              //   child: Image.asset(
              //     'assets/about_logo.png',
              //     width: 200,
              //     // height: 100,
              //   ),
              // ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Image.asset(
                    'assets/splash.png',
                    width: 220,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 15, color: Colors.grey),
    );
  }

  Widget _buildCard1(String name, String link) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Adjust the radius as needed
        ),
        color: Colors.white,
        margin: EdgeInsets.all(1),
        child: SizedBox(
          width: 500, // Set desired width
          height: 35, // Set desired height
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.grey, // Set text color to grey
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                color: Colors.grey,
                onPressed: () async {
                  final Uri url = Uri.parse(link);
                  _launchURL(url);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard2(String name, String link) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Adjust the radius as needed
        ),
        color: Colors.white,
        margin: EdgeInsets.all(1),
        child: SizedBox(
          width: 500,
          height: 35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    name,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () async {
                  final Uri url = Uri.parse(link);
                  _launchURL(url);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard3(String name, String link) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Adjust the radius as needed
        ),
        color: Colors.white,
        margin: EdgeInsets.all(1),
        child: SizedBox(
          width: 500, // Set your desired width
          height: 35, // Set your desired height
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.grey, // Set text color to grey
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                color: Colors.grey,
                onPressed: () async {
                  final Uri url = Uri.parse(link);
                  _launchURL(url);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
