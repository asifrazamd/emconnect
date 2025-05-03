import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';

import 'package:universal_ble_example/global.dart';
import 'package:path_provider/path_provider.dart';

bool isOn = true;

int packetType = 0;
int? interval1;
int? txPowerLevel;
Uint8List? response;
bool isBeaconing = false;
String mfgID = '';
String beaconID = '';
String mfgData = '';
int? selectedRadioIndex;

String? mfgRSVD = ''; // Store manufacturer data
bool isEnabled = false;

class AltBeaconScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  final ({
    BleService service,
    BleCharacteristic characteristic1,
    BleCharacteristic characteristic2,
  })? selectedCharacteristic;
  const AltBeaconScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.selectedCharacteristic,
  });

  @override
  _AltBeaconScreenState createState() {
    return _AltBeaconScreenState();
  }
}

class _AltBeaconScreenState extends State<AltBeaconScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? selectedHex;
  String selectedFormat = "";
  String formattedText = "";
  String? textFieldError = "";
  Set<int> selectedIndexes = {};
  Set<int> updateIndexes = {};
  bool identify = true;
  int i = 0;
  final Map<String, String> dataTypeToFormat = {
    "76": "U8",
    "56": "U16 LE",
    "57": "U16 BE",
    "63": "U8",
    "43": "U16 LE",
    "44": "U16 BE",
    "45": "U32 LE",
    "46": "U32 BE",
    "78": "S8",
    "58": "S16 LE",
    "79": "S8",
    "59": "S16 LE",
    "7A": "S8",
    "5A": "S16 LE",
    "74": "S8 LE",
    "54": "S16 LE",
    "55": "S16 BE",
    "52": "U32 LE",
    "53": "U32 BE",
  };

  void updateTextField() {
    List<String> tempData = List.generate(24, (index) => "00");
    int index;
    String dataType;

    for (var row in rows) {
      if (row['selectedDataType'] == null) continue;

      index = 0;
      dataType = row['selectedDataType'];
      tempData[index] = dataType;

      selectedIndexes.add(0);
      row['isDisabled'] = false;
    }

    setState(() {
      textFieldData[0] = tempData[0];
      sharedText = textFieldData.join();
      formattedText = textFieldData.join("").replaceAll(" ", "");
    });
    print(formattedText);
  }

  void addRow() {
    setState(() {
      for (int i = 0; i < 24; i++) {
        String byte = sharedText.substring(i * 2, (i * 2) + 2).toUpperCase();
        textFieldData[i] = byte;
      }
      formattedText = textFieldData.join();
      if (rows.isNotEmpty) {
        var lastRow = rows.last;
        if (lastRow['selectedDataType'] == null) {
          errorMessage = "Please enter data type.";
          return;
        }
        updateTextField();
        identify = false;
      }
      if (textFieldData[0] == "00") {
        rows.add({
          'selectedDataType': null,
          'selectedFormat': null,
          'selectedIndex': null,
          'isLastRow': true,
          'isDisabled': false, // Initialize as false
        });
        return;
      }

      if (i == 0 &&
          (textFieldData[0] != "00") &&
          (dataTypeToFormat[textFieldData[0]] == "U8" ||
              dataTypeToFormat[textFieldData[0]] == "S8")) {
        rows.add({
          'selectedDataType': textFieldData[0],
          'selectedFormat': dataTypeToFormat[textFieldData[0]],
          'selectedIndex': 0,
          'isLastRow': true,
          'isDisabled': false, // Initialize as false
        });
        i++;
      } else {
        rows.add({
          'selectedDataType': null,
          'selectedFormat': null,
          'selectedIndex': null,
          'isLastRow': true,
          'isDisabled': false, // Initialize as false
        });
        return;
      }

      errorMessage = null;
      updateTextField();
    });
  }

  // Store selected indexes

  int getBlockSize(String? format) {
    if (format == null) return 1;
    if (format.contains("U8") || format.contains("S8")) return 2;
    if (format.contains("U16") || format.contains("S16")) return 3;
    if (format.contains("U32")) return 5;
    return 1;
  }

  List<String> originalData = List.generate(24, (index) => "00");
  List<String> textFieldData = List.generate(24, (index) => "00");
  List<Map<String, dynamic>> rows = [];
  List<TextEditingController> textControllers = [];
  String? errorMessage;
  int addrow = 0;

  bool isEnabled = false; // Reset state on page rebuild

  int getComplete = 0;
  bool isFetchComplete = false;
  @override
  void initState() {
    super.initState();

    UniversalBle.onValueChange = _handleValueChange;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      readBeacon();

      addRow();
    });
  }

  @override
  void dispose() {
    super.dispose();

    UniversalBle.onValueChange = null;
  }

  //Method to read beacon values
  Future readBeacon() async {
    Uint8List deviceInfoopcode;

    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      isFetchComplete = false;

      deviceInfoopcode = Uint8List.fromList([0x36]);

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
    _addLog("Received", hexString);

    if (value[0] == 0x80) {
      if (value[2] > 0x01) {
        _showDialog(
            context, "Error", "Parameters are Invalid\nLog: $hexString");
      }
    }

    if (value.length > 3) {
      int packetType = value[3]; // Get the fourth byte
      String message = '';

      if (value[1] == 0x36) {
        //check = true;
        print("entered altbeacon");
        setState(() {
          mfgID = value
              .sublist(3, 5)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          beaconID = value
              .sublist(5, 25)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();

          mfgData = value
              .sublist(25, 26)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          getComplete += 1;
        });
        check = true;
        print('mfid $mfgID');
        print('beaconid $beaconID');
        print('mfgData: $mfgData');
      }

      setState(() async {});
    } else {
      print("Insufficient data received.");
    }
    isFetchComplete = true;
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

  Uint8List createSubstitutionSettings(Uint8List Advopcode, String hex) {
    List<int> byteList = [];

    for (int i = 0; i < hex.length; i += 2) {
      byteList.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    print(byteList);
    return Uint8List.fromList([
      Advopcode[0],
      ...byteList,
    ]);
  }

  void setSubstitutionPacket(String hexString) async {
    Uint8List Advopcode = Uint8List.fromList([0x61]);

    //Convert string pairs into hex bytes
    // AltBeacon opcode

    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      Uint8List SubstituitionSettings =
          createSubstitutionSettings(Advopcode, hexString);
      print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        SubstituitionSettings,
        BleOutputProperty.withResponse,
      );

      print("Substitution packet sent: $SubstituitionSettings");
    } catch (e) {
      print("Error writing substitution settings: $e");
    }
  }

  Uint8List createAdvertisingSettings(
      Uint8List Advopcode, int packetType, interval, int txPowerLevel) {
    if (interval < 20 || interval > 10240) {
      throw Exception(
          "Invalid advertising interval. Accepted values: 20 – 10240.");
    }
    interval = (interval * 1.6).round();
    debugPrint("@@txpowerLevel1: $txPowerLevel ");
    if (txPowerLevel < -60 || txPowerLevel > 10) {
      throw Exception(
          "Invalid Tx Power Level. Accepted values: -60 to 10 dBm.");
    }

    return Uint8List.fromList([
      Advopcode[0],
      packetType, // Advertising Packet Type
      interval & 0xFF, // Lower byte of interval
      (interval >> 8) & 0xFF, // Upper byte of interval
      txPowerLevel, // Tx Power Level
    ]);
  }

  Future GetAdvertising_settings() async {
    BleService selService = widget.selectedCharacteristic!.service;
    BleCharacteristic selChar = widget.selectedCharacteristic!.characteristic1;

    Uint8List DeviceInfoopcode = Uint8List.fromList([0x21]);
    print("characteristics: ${selChar.uuid}");
    print("DeviceID: ${widget.deviceId}");

    try {
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        DeviceInfoopcode,
        BleOutputProperty.withResponse,
      );
      readBeacon();
    } catch (e) {
      print("Error writing advertising settings: $e");
      return Uint8List(0); // Return empty data on error
    }
  }

  void Set_Advertising_Settings(
      int packetType, int interval, int txPowerLevel) async {
    Uint8List Advopcode = Uint8List.fromList([0x22]);
    // Uint8List? response;
    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;
      Uint8List advertisingSettings = createAdvertisingSettings(
          Advopcode, packetType, interval, txPowerLevel);

      print("characteristics: ${selChar.uuid}");
      print("DeviceID: ${widget.deviceId}");
      print("Advertising Settings: $advertisingSettings");

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        advertisingSettings,
        BleOutputProperty.withResponse,
      );

      setState(() {
        response = advertisingSettings;
      });

      print("Received response from the device: $advertisingSettings");
    } catch (e) {
      print("Error writing advertising settings: $e");
    }
  }

  void _applySettings() {
    try {
      // Check the toggle switch state
      if (isOn) {
        // Enable advertising (Opcode: 0x20, Enable response: 20-01)
        _setAdvertisingState(true);
      } else {
        // Disable advertising (Opcode: 0x20, Disable response: 20-00)
        _setAdvertisingState(false);
      }
      Set_Advertising_Settings(selectedRadioIndex!, interval1!, txPowerLevel!);
      _showDialog(
          context, "Success", "Changes have been applied successfully.");
    } catch (e) {
      _showDialog(
          context, "Error", "Changes could not be applied: ${e.toString()}");
    }
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
          "AltBeacon",
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
                                  'Manufacturer ID (2 Bytes)',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _manufactureridInputFormatters,
                                initialValue: mfgID,
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
                                  if (value == null || value.length != 4) {
                                    return 'Enter valid 4 hex characters.';
                                  }
                                  // Check for valid hexadecimal characters (0-9, a-f)
                                  if (!RegExp(r'^[0-9a-fA-F]+$')
                                      .hasMatch(value)) {
                                    return 'Only hexadecimal characters (0-9, A-F) are allowed';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    mfgID = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: 16),

                            // Beacon ID field
                            Row(
                              children: [
                                Text(
                                  'Beacon ID (20 Bytes)',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _beaconidInputFormatters,
                                initialValue: beaconID,
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
                                  if (value == null || value.length != 40) {
                                    return 'Enter valid 40 hex characters.';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    beaconID = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: 16),

                            // Manufacturer Data field
                            Row(
                              children: [
                                Text(
                                  'Manufacturer Data (1 Byte)',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey),
                                ),
                              ],
                            ),
                            Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: TextFormField(
                                style: TextStyle(fontSize: 15),
                                inputFormatters: _mfgdataInputFormatters,
                                initialValue: mfgData,
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
                                  if (value == null || value.length != 2) {
                                    return 'Enter valid 2 hex characters.';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    mfgData = value;
                                  });
                                },
                              ),
                            ),

                            SizedBox(height: 16),

                            // Manufacturer Data field
                            Row(
                              children: [
                                Transform.translate(
                                  offset: Offset(-15, 0),
                                  child: Checkbox(
                                    value: isEnabled,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        isEnabled = value ?? true;
                                      });
                                    },
                                    side: BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                    fillColor:
                                        WidgetStateProperty.resolveWith<Color>(
                                      (Set<WidgetState> states) {
                                        if (states
                                            .contains(WidgetState.selected)) {
                                          return Colors.blue;
                                        }
                                        return const Color.fromARGB(
                                            255, 187, 186, 186);
                                      },
                                    ),
                                    checkColor: Colors.white,
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(-15, 0),
                                  child: Text(
                                    'Enable MFG RSVD Substitution',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black),
                                  ),
                                )
                              ],
                            ),
                            if (isEnabled)
                              Column(
                                  children: List.generate(rows.length, (index) {
                                return buildRow(index);
                              })), // Show only when enabled

                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
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
                            if (isEnabled) {
                              if (textFieldData[0] == "00") {
                                errorMessage =
                                    "Please validate your entry by selecting  dropdown.";
                              } else {
                                setAltBeaconPacket(mfgID, beaconID, mfgData);
                                setSubstitutionPacket(formattedText);
                                Navigator.pop(context);
                              }
                            } else {
                              setAltBeaconPacket(mfgID, beaconID, mfgData);
                              Navigator.pop(context);
                            }
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

  Widget buildRow(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 1, horizontal: 0), // Reduce vertical padding
      child: Row(
        children: [
          Expanded(
            child: Material(
              elevation: 1,
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 6, vertical: 0), // Reduce padding further
                child: DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  value: rows[index]['selectedDataType'],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelStyle: TextStyle(fontSize: 12),
                    labelText: rows[index]['selectedDataType'] == null
                        ? "Data Type"
                        : null,
                    border: OutlineInputBorder(),
                    isDense: true, // Makes the dropdown more compact
                    contentPadding: EdgeInsets.symmetric(
                        vertical: 6, horizontal: 8), // Adjust vertical padding
                  ),
                  items: [
                    {"label": "Battery voltage 100 (mV) (U8)", "value": "76"},
                    {"label": "8-bit counter (U8)", "value": "63"},
                    {"label": "Accel X axis(1/32g) (S8)", "value": "78"},
                    {"label": "Accel Y axis(1/32g) (S8)", "value": "79"},
                    {"label": "Accel Z axis(1/32g) (S8)", "value": "7A"},
                    {"label": "Temperature(°C) (S8)", "value": "74"},
                  ]
                      .map((item) => DropdownMenuItem(
                            value: item["value"],
                            child: Text(item["label"]!,
                                style: TextStyle(fontSize: 10)),
                          ))
                      .toList(),
                  menuMaxHeight: 250,
                  onChanged: (rows[index]['isDisabled'] ?? false)
                      ? null
                      : (value) {
                          setState(() {
                            rows[index]['selectedDataType'] = value;
                            rows[index]['selectedFormat'] =
                                dataTypeToFormat[value] ?? "Unknown";
                            rows[index]['isDisabled'] = false;
                            updateTextField();
                          });
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Uint8List createAltBeaconSettings(Uint8List Advopcode, String mfgIDHex,
      String beaconIDHex, String mfgDataHex) {
    Uint8List mfgIDBytes = hexStringToBytes(mfgIDHex);
    Uint8List beaconIDBytes = hexStringToBytes(beaconIDHex);
    Uint8List mfgDataBytes = hexStringToBytes(mfgDataHex);

    if (mfgIDBytes.length != 2) {
      throw Exception(
          "Manufacturer ID must be exactly 2 bytes (4 hex characters)");
    }
    if (beaconIDBytes.length != 20) {
      throw Exception("Beacon ID must be exactly 20 bytes (40 hex characters)");
    }
    if (mfgDataBytes.length != 1) {
      throw Exception("Beacon ID must be exactly 20 bytes (40 hex characters)");
    }

    return Uint8List.fromList([
      Advopcode[0],
      ...mfgIDBytes,
      ...beaconIDBytes,
      ...mfgDataBytes,
    ]);
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

  void setAltBeaconPacket(
      String mfgIDHex, String beaconIDHex, mfgDataHex) async {
    Uint8List Advopcode = Uint8List.fromList([0x37]); // AltBeacon opcode
    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      Uint8List AltBeaconSettings =
          createAltBeaconSettings(Advopcode, mfgIDHex, beaconIDHex, mfgDataHex);
      _addLog(
          "Sent",
          AltBeaconSettings.map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join('-'));

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        AltBeaconSettings,
        BleOutputProperty.withResponse,
      );

      print("AltBeacon packet sent: $AltBeaconSettings");
    } catch (e) {
      print("Error writing AltBeacon settings: $e");
    }
  }

  final _manufactureridRegex = RegExp(r'^[0-9a-fA-F]{4}$');
  final List<TextInputFormatter> _manufactureridInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
    LengthLimitingTextInputFormatter(4),
    _MANUFACTURERIDTextFormatter(),
  ];

  final _beaconidRegex = RegExp(r'^[0-9a-fA-F]{40}$');
  final List<TextInputFormatter> _beaconidInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
    LengthLimitingTextInputFormatter(40),
    _BEACONIDTextFormatter(),
  ];

  final _mfgdatadRegex = RegExp(r'^[0-9a-fA-F]{2}$');
  final List<TextInputFormatter> _mfgdataInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
    LengthLimitingTextInputFormatter(2),
    _MFGDATATextFormatter(),
  ];

  // Added for manufacturer RSVD in Altbeacon
  final _mfgdataRSVDRegex = RegExp(r'^[0-9a-fA-F]{48}$');
  final List<TextInputFormatter> _mfgRSVDInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
    LengthLimitingTextInputFormatter(48),
    _MFGRSVDTextFormatter(),
  ];
}

class _MANUFACTURERIDTextFormatter extends TextInputFormatter {
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

class _BEACONIDTextFormatter extends TextInputFormatter {
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

class _MFGDATATextFormatter extends TextInputFormatter {
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

class _MFGRSVDTextFormatter extends TextInputFormatter {
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
