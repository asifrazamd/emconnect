import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:path_provider/path_provider.dart';

String AoA_Enable = '';
String AoA_Interval = '';
String AoA_CTE_length = '';
String AoA_CTE_count = '';

bool isTextFieldVisible = false;
bool isOn = true;

String namespaceID = '';
String instanceID = '';

int? interval1;
int? txPowerLevel;
Uint8List? response;

int? selectedRadioIndex;

bool isEnabled = false;

class AoAScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  final ({
    BleService service,
    BleCharacteristic characteristic1,
    BleCharacteristic characteristic2,
  })? selectedCharacteristic;
  const AoAScreen(
      {super.key,
      required this.deviceId,
      required this.deviceName,
      required this.selectedCharacteristic});

  @override
  _AoAScreenState createState() {
    return _AoAScreenState();
  }
}

class _AoAScreenState extends State<AoAScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? selectedHex;
  String selectedFormat = "";
  String formattedText = "";
  String? textFieldError = "";
  Set<int> selectedIndexes = {};
  Set<int> updateIndexes = {};
  bool identify = true;

  List<String> originalData = List.generate(24, (index) => "00");
  List<String> textFieldData = List.generate(24, (index) => "00");
  List<Map<String, dynamic>> rows = [];
  List<TextEditingController> textControllers = [];
  String? errorMessage;

  bool isEnabled = false; // Reset state on page rebuild

  int getComplete = 0;
  bool isFetchComplete = false;

  @override
  void initState() {
    super.initState();

    UniversalBle.onValueChange = _handleValueChange;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      readBeacon();
    });
  }

  @override
  void dispose() {
    super.dispose();

    UniversalBle.onValueChange = null;
  }

  final List<String> _logs = [];
  void _addLog(String type, dynamic data) async {
    // Get the current timestamp and manually format it as YYYY-MM-DD HH:mm:ss
    DateTime now = DateTime.now();
    String timestamp =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // Log entry with just the formatted timestamp
    String logEntry = '[$timestamp]:$type: ${data.toString()}\n';

    _logs.add(logEntry);

    await _writeLogToFile(logEntry);
  }

  Future<void> _writeLogToFile(String logEntry) async {
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File('${directory.path}/logs.txt');
    await logFile.writeAsString(logEntry, mode: FileMode.append);
  }

  //Method to read beacon values
  Future readBeacon() async {
    Uint8List deviceInfoopcode = Uint8List.fromList([0x70]);

    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      debugPrint("into AoA get\n");

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        deviceInfoopcode,
        BleOutputProperty.withResponse,
      );
      await Future.delayed(const Duration(milliseconds: 2000));
    } catch (e) {
      print("Error writing advertising settings: $e");
    }
  }

  bool check = false; // Flag to track dialog state

//Method to extract byte values for all beacon types from response
  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    BleService selService = widget.selectedCharacteristic!.service;
    BleCharacteristic selChar = widget.selectedCharacteristic!.characteristic1;
    String hexString =
        value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('-');

    String s = String.fromCharCodes(value);
    String data = '$s\nRaw: ${value.toString()}\nHex: $hexString';

    print('_handleValueChange $deviceId, $characteristicId, $s');

    print('Received hex data: $hexString');
    // _addLog("Received", hexString);
    if (value[0] == 0x80) {
      if (value[2] > 0x01) {
        _showDialog(
            context, "Error", "Parameters are Invalid\nLog: $hexString");
      }
    }

    if (value.length > 3) {
      int packetType = value[3]; // Get the fourth byte
      String message = '';

      // if (value[1] == 0x32) {
      //   //check = true;
      //   print("entered eddystone");
      //   setState(() {
      //     namespaceID = value
      //         .sublist(3, 13)
      //         .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      //         .join();
      //     instanceID = value
      //         .sublist(13, 19) // From 4th to 19th byte
      //         .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      //         .join();
      //     getComplete += 1;
      //     check = true;
      //   });
      // }

      // if (value[0] == 0x70 && value.length >= 6) {
      //   setState(() {
      //     AoA_Enable = value[1]; // 1 byte
      //     AoA_Interval = (value[3] << 8) | value[2]; // 2 bytes, little endian
      //     AoA_CTE_length = value[4]; // 1 byte
      //     AoA_CTE_count = value[5]; // 1 byte
      //   });
      // }
      if (value[1] == 0x70) {
        print("entered AoA");
        setState(() {
          AoA_Enable = value
              .sublist(3, 4)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          AoA_Interval = value
              .sublist(4, 6) // From 4th to 19th byte
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          AoA_CTE_length = value
              .sublist(6, 7) // From 4th to 19th byte
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          AoA_CTE_count = value
              .sublist(7, 8) // From 4th to 19th byte
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          getComplete += 1;
          check = true;
        });
      }

      setState(() async {});
    } else {
      print("Insufficient data received.");
    }
    isFetchComplete = true;
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void setAOA(
      String enableHex, // 1 byte
      String intervalHex, // 2 bytes
      String cteLengthHex, // 1 byte
      String cteCountHex // 1 byte
      ) async {
    Uint8List Advopcode = Uint8List.fromList([0x71]); // Example opcode for AOA

    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      Uint8List aoaSettings = createAOASettings(
          Advopcode, enableHex, intervalHex, cteLengthHex, cteCountHex);

      _addLog(
        "Sent",
        aoaSettings.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-'),
      );

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        aoaSettings,
        BleOutputProperty.withResponse,
      );

      setState(() {
        response = aoaSettings;
      });

      String hex =
          aoaSettings.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-');
      print("Received response from the device: $hex");
    } catch (e) {
      print("Error writing AOA settings: $e");
    }
  }

  Uint8List createAOASettings(Uint8List Advopcode, String enableHex,
      String intervalHex, String cteLengthHex, String cteCountHex) {
    Uint8List enable = hexStringToBytes(enableHex); // 1 byte
    Uint8List interval = hexStringToBytes(intervalHex); // 2 bytes
    Uint8List cteLength = hexStringToBytes(cteLengthHex); // 1 byte
    Uint8List cteCount = hexStringToBytes(cteCountHex); // 1 byte

    if (interval.length != 2) {
      throw Exception("Interval must be exactly 2 bytes (4 hex characters)");
    }

    return Uint8List.fromList([
      Advopcode[0],
      enable[0],
      interval[0],
      interval[1],
      cteLength[0],
      cteCount[0]
    ]);
  }

  void _setAdvertisingState(bool enable) async {
    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      // Create advertising command
      Uint8List Advopcode = enable
          ? Uint8List.fromList([0x20, 0x01]) // Enable advertising
          : Uint8List.fromList([0x20, 0x00]); // Disable advertising

      print("characteristics: ${selChar.uuid}");
      print("DeviceID: ${widget.deviceId}");
      print("Advertising Command: $Advopcode");

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        Advopcode,
        BleOutputProperty.withResponse,
      );

      print(
          "Advertising ${enable ? "enabled" : "disabled"} successfully: $Advopcode");
    } catch (e) {
      print("Error updating advertising state: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int columnsPerRow = (screenWidth ~/ 30)
        .clamp(6, 12); // Adjust columns based on screen width
    int totalRows = (24 / columnsPerRow).ceil();
    return Scaffold(
      backgroundColor: Color.fromARGB(247, 247, 244, 244),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "AoA",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: !check
          ? Center(
              child: CircularProgressIndicator(), // Show loader while loading
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Manufacturer ID field
                            Row(
                              children: [
                                Text(
                                  ' Enable (1 Byte)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _enableInputFormatters,
                                initialValue: AoA_Enable.toString(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a value';
                                  }

                                  // Check for valid hexadecimal characters (0-9, a-f)
                                  if (!RegExp(r'^[0-9a-fA-F]+$')
                                      .hasMatch(value)) {
                                    return 'Only hexadecimal characters (0-9, A-F) are allowed';
                                  }
                                  // Check length for Namespace ID (20 hex characters = 10 bytes)
                                  if (value.length != 2) {
                                    return 'Enable must be exactly 2 characters (10 bytes)';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  AoA_Enable = value;
                                },
                              ),
                            ),
                            SizedBox(height: 16),

                            // Instance ID field
                            Row(
                              children: [
                                Text(
                                  ' Interval (2 Bytes)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _intervalInputFormatters,
                                initialValue: AoA_Interval.toString(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a value';
                                  }
                                  // Check for valid hexadecimal characters (0-9, a-f)
                                  if (!RegExp(r'^[0-9a-fA-F]+$')
                                      .hasMatch(value)) {
                                    return 'Only hexadecimal characters (0-9, A-F) are allowed';
                                  }
                                  // Check length for Instance ID (12 hex characters = 6 bytes)
                                  if (value.length != 4) {
                                    return 'Instance ID must be exactly 4 characters (6 bytes)';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  AoA_Interval = value;
                                },
                              ),
                            ),

                            SizedBox(height: 16),

                            Row(
                              children: [
                                Text(
                                  ' CTE Length (1 Bytes)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _ctelengthInputFormatters,
                                initialValue: AoA_CTE_length.toString(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a value';
                                  }
                                  // Check for valid hexadecimal characters (0-9, a-f)
                                  if (!RegExp(r'^[0-9a-fA-F]+$')
                                      .hasMatch(value)) {
                                    return 'Only hexadecimal characters (0-9, A-F) are allowed';
                                  }
                                  // Check length for Instance ID (12 hex characters = 6 bytes)
                                  if (value.length != 2) {
                                    return 'CTE Length must be exactly 2 characters (6 bytes)';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  AoA_CTE_length = value;
                                },
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  ' CTE Count (1 Byte)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _ctecountInputFormatters,
                                initialValue: AoA_CTE_count.toString(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  fillColor: Colors.white,
                                  filled: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a value';
                                  }
                                  // Check for valid hexadecimal characters (0-9, a-f)
                                  if (!RegExp(r'^[0-9a-fA-F]+$')
                                      .hasMatch(value)) {
                                    return 'Only hexadecimal characters (0-9, A-F) are allowed';
                                  }
                                  // Check length for Instance ID (12 hex characters = 6 bytes)
                                  if (value.length != 2) {
                                    return 'CTE Count must be exactly 12 characters (6 bytes)';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  AoA_CTE_count = value;
                                },
                              ),
                            ),

                            // Manufacturer Data field

                            SizedBox(height: 20),

                            // Dynamically Generated Rows
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Apply Button at the bottom
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16.0, bottom: 32.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        backgroundColor: Color.fromRGBO(45, 127, 224, 1),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            setAOA(AoA_Enable, AoA_Interval, AoA_CTE_length,
                                AoA_CTE_count);

                            Navigator.pop(context);
                          }); // Close the screen after execution
                        }
                      },
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                            color: Color.fromRGBO(250, 247, 243, 1),
                            fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

// Function to convert hex string to Uint8List
  Uint8List hexStringToBytes(String hex) {
    hex = hex.replaceAll(
        RegExp(r'[^0-9A-Fa-f]'), ''); // Remove non-hexadecimal characters
    if (hex.length % 2 != 0) {
      hex = "0$hex"; // Pad with a leading 0 if the length is odd
    }
    return Uint8List.fromList(List.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }
}

final List<TextInputFormatter> _enableInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(2),
  _ENABLETextFormatter(),
];

final List<TextInputFormatter> _intervalInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(4),
  _INTERVALTextFormatter(),
];
final List<TextInputFormatter> _ctelengthInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(2),
  _CTELENGTHTextFormatter(),
];
final List<TextInputFormatter> _ctecountInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(2),
  _CTECOUNTTextFormatter(),
];

class _ENABLETextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;

    // Format the new text if needed
    String formattedText = newText;

    // Calculate the new cursor position based on the user's input
    int newOffset =
        newValue.selection.baseOffset + (formattedText.length - newText.length);

    // Ensure the new offset is within bounds
    newOffset = newOffset.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class _INTERVALTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;

    // Format the new text if needed
    String formattedText = newText;

    // Calculate the new cursor position based on the user's input
    int newOffset =
        newValue.selection.baseOffset + (formattedText.length - newText.length);

    // Ensure the new offset is within bounds
    newOffset = newOffset.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class _CTELENGTHTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;

    // Format the new text if needed
    String formattedText = newText;

    // Calculate the new cursor position based on the user's input
    int newOffset =
        newValue.selection.baseOffset + (formattedText.length - newText.length);

    // Ensure the new offset is within bounds
    newOffset = newOffset.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class _CTECOUNTTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text;

    // Format the new text if needed
    String formattedText = newText;

    // Calculate the new cursor position based on the user's input
    int newOffset =
        newValue.selection.baseOffset + (formattedText.length - newText.length);

    // Ensure the new offset is within bounds
    newOffset = newOffset.clamp(0, formattedText.length);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
