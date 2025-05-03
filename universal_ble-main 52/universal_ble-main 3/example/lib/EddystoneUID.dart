import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:collection/collection.dart';
import 'package:universal_ble_example/global.dart';
import 'package:path_provider/path_provider.dart';

bool isTextFieldVisible = false;
bool isOn = true;

String namespaceID = '';
String instanceID = '';

int? interval1;
int? txPowerLevel;
Uint8List? response;

int? selectedRadioIndex;

bool isEnabled = false;

class EddystoneScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  final ({
    BleService service,
    BleCharacteristic characteristic1,
    BleCharacteristic characteristic2,
  })? selectedCharacteristic;
  const EddystoneScreen(
      {super.key,
      required this.deviceId,
      required this.deviceName,
      required this.selectedCharacteristic});

  @override
  _EddystoneScreenState createState() {
    return _EddystoneScreenState();
  }
}

class _EddystoneScreenState extends State<EddystoneScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? selectedHex;
  String selectedFormat = "";
  String formattedText = "";
  String? textFieldError = "";
  Set<int> selectedIndexes = {};
  Set<int> updateIndexes = {};
  bool identify = true;

  final Map<String, String> dataTypeToFormat = {
    "76": "U8",
    "56": "U16",
    "57": "U16",
    "63": "U8",
    "43": "U16",
    "44": "U16",
    "45": "U32",
    "46": "U32",
    "78": "S8",
    "58": "S16",
    "79": "S8",
    "59": "S16",
    "7A": "S8",
    "5A": "S16",
    "7a": "S8",
    "5a": "S16",
    "74": "S8",
    "54": "S16",
    "55": "S16",
    "52": "U32",
    "53": "U32",
  };

  List<String> originalData = List.generate(24, (index) => "00");
  List<String> textFieldData = List.generate(24, (index) => "00");
  List<Map<String, dynamic>> rows = [];
  List<TextEditingController> textControllers = [];
  String? errorMessage;
  int rowlength = 0;

  bool isEnabled = false; // Reset state on page rebuild

  int getComplete = 0;
  bool isFetchComplete = false;
  int add_row = 0;
  @override
  void initState() {
    super.initState();

    UniversalBle.onValueChange = _handleValueChange;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      readBeacon();

      addgetrow(sharedText);
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

  void updateTextField(bool data) {
    List<String> tempData = List.generate(24, (index) => "00");
    int index;
    String dataType;

    for (var row in rows) {
      if (row['selectedIndex'] == null ||
          row['selectedDataType'] == null ||
          row['selectedFormat'] == null) {
        continue;
      }

      index = row['selectedIndex'];
      dataType = row['selectedDataType'];

      for (int i = 0; i < selectedIndexes.length; i++) {
        updateIndexes.add(selectedIndexes.elementAt(i));
      }
      tempData[index] = dataType;
      if (data) {
        row['isDisabled'] = true;
      }
    }

    setState(() {
      textFieldData[0] = tempData[0];
      textFieldData[1] = tempData[1];
      sharedText = textFieldData.join();

      formattedText = textFieldData.join("").replaceAll(" ", "");
    });
    print(formattedText);
  }

  bool validateindex1 = false;
  void addRow() {
    setState(() {
      if (rows.isNotEmpty) {
        var lastRow = rows.last;

        // Validate if Data Type and Index are selected
        if (lastRow['selectedDataType'] == null ||
            lastRow['selectedIndex'] == null) {
          errorMessage =
              "Please enter both Data Type and Index before adding a new row.";
          return;
        }

        int lastIndex = lastRow['selectedIndex'];
        String? lastFormat = lastRow['selectedFormat'];

        // Restrict U16 and S16 formats at index 1
        if ((lastFormat == "U16" || lastFormat == "S16") && lastIndex == 1) {
          errorMessage =
              "It is not possible to add this data type in this index.";

          //deleteRow(lastIndex);
          lastRow['selectedFormat'] = null;
          lastRow['selectedDataType'] = null;
          lastRow['selectedIndex'] = null;
          updateIndexes.remove(1);
          selectedIndexes.remove(1);
          //updateTextField(false);
          return;
        }
        if (lastIndex == 1) {
          validateindex1 = true;
        }
        if (validateindex1 && (lastFormat == "U16" || lastFormat == "S16")) {
          //deleteRow(lastRow['selectedIndex']);
          lastRow['selectedFormat'] = null;
          lastRow['selectedDataType'] = null;
          lastRow['selectedIndex'] = null;
          updateIndexes.remove(0);
          selectedIndexes.remove(0);
          //updateTextField(false);
          errorMessage =
              "It is not possible to add this data type in this index.";
          validateindex1 = false;
          return;
        }

        // Allow U16 and S16 formats at index 0
        if ((lastFormat == "U16" || lastFormat == "S16") && lastIndex == 0) {
          updateTextField(true);
          lastRow['isLastRow'] = false;
          errorMessage = null;
          return;
        }

        lastRow['isLastRow'] = false;
      }

      // Add a new row if the row count is below the limit
      if (rowlength < 2) {
        rows.add({
          'selectedDataType': null,
          'selectedFormat': null,
          'selectedIndex': null,
          'isLastRow': true,
          'isDisabled': false,
        });
        rowlength++;
      }

      errorMessage = null;
      updateTextField(true);
    });
  }

  void deleteRow(int index) {
    setState(() {
      // Free the indices occupied by the row being deleted
      if (rows[index]['selectedIndex'] != null) {
        int prevIndex = rows[index]['selectedIndex'];
        String? prevFormat = rows[index]['selectedFormat'];
        int prevBlockSize = getBlockSize(prevFormat);

        for (int i = prevIndex; i < prevIndex + prevBlockSize; i++) {
          updateIndexes.remove(i);
          selectedIndexes.remove(i);
        }
      }

      if (rows[index]['selectedIndex'] == 0 &&
          (rows[index]['selectedFormat'] == "S16" ||
              rows[index]['selectedFormat'] == "U16")) {
        rows.add({
          'selectedDataType': null,
          'selectedFormat': null,
          'selectedIndex': null,
          'isLastRow': true,
          'isDisabled': false, // Initialize as false
        });
      }

      // Remove the row
      rowlength--;
      rows.removeAt(index);
      errorMessage = null;
      // Adjusting indices
      if (rows.isNotEmpty) rows.last['isLastRow'] = true;

      updateTextField(false);
    });
  }

  void addgetrow(String hexString) {
    setState(() {
      if (hexString.length != 48) {
        print("Error: The hex string must be exactly 48 characters long.");
        return;
      }

      for (int i = 0; i < 24; i++) {
        String byte = hexString.substring(i * 2, (i * 2) + 2).toUpperCase();
        textFieldData[i] = byte;
        // Extract 2 hex characters (1 byte) // Extract 2 characters (1 byte)
        if (i > 1) continue;
        if (i == 1 &&
            (dataTypeToFormat[byte] == "U16" ||
                dataTypeToFormat[byte] == "U16")) {
          continue;
        }
        if (byte.compareTo("00") > 0 &&
            !(dataTypeToFormat[byte] == "U32" ||
                dataTypeToFormat[byte] == "S32")) {
          rows.add({
            'selectedDataType': byte,
            'selectedFormat': dataTypeToFormat[byte],
            'selectedIndex': i,
            'isLastRow': false,
            'isDisabled': true, // Initialize as false
          });

          for (int j = i; j < i + getBlockSize(dataTypeToFormat[byte]); j++) {
            selectedIndexes.add(j);
            updateIndexes.add(j);
          }

          rowlength++;
        }

        if (i == 0 &&
            (dataTypeToFormat[byte] == "U16" ||
                dataTypeToFormat[byte] == "U16")) {
          rowlength = 2;
        }
      }
      if (textFieldData[0] == "00" && textFieldData[1] == "00") {
        rows.add({
          'selectedDataType': null,
          'selectedFormat': null,
          'selectedIndex': null,
          'isLastRow': true,
          'isDisabled': false, // Initialize as false
        });
        rowlength++;
        formattedText = textFieldData.join();
        return;
      }
      formattedText = textFieldData.join();
      if ((rows.last['selectedFormat'] != "U16" ||
              rows.last['selectedFormat'] != "S16") &&
          rowlength < 2) {
        rows.add({
          'selectedDataType': null,
          'selectedFormat': null,
          'selectedIndex': null,
          'isLastRow': true,
          'isDisabled': false, // Initialize as false
        });
        rowlength++;
      }
      //check = true;
    });
  }

  int getBlockSize(String? format) {
    if (format == null) return 1;
    if (format.contains("U8") || format.contains("S8")) return 1;
    if (format.contains("U16") || format.contains("S16")) return 2;

    return 1;
  }

  //Method to read beacon values
  Future readBeacon() async {
    Uint8List deviceInfoopcode = Uint8List.fromList([0x32]);

    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      debugPrint("into eddystone uuid get\n");

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

      if (value[1] == 0x32) {
        //check = true;
        print("entered eddystone");
        setState(() {
          namespaceID = value
              .sublist(3, 13)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
          instanceID = value
              .sublist(13, 19) // From 4th to 19th byte
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
      String hex = SubstituitionSettings.map(
          (byte) => byte.toRadixString(16).padLeft(2, '0')).join('-');
      print("Substitution packet sent: $hex");
      _addLog("Sent", hex);
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
          "Eddystone-UID",
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
                                  ' Namespace (10 Bytes)',
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
                                inputFormatters: _namespaceInputFormatters,
                                initialValue: namespaceID,
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
                                  if (value.length != 20) {
                                    return 'Namespace ID must be exactly 20 characters (10 bytes)';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  namespaceID = value;
                                },
                              ),
                            ),
                            SizedBox(height: 16),

                            // Instance ID field
                            Row(
                              children: [
                                Text(
                                  ' Instance (6 Bytes)',
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
                                inputFormatters: _instanceInputFormatters,
                                initialValue: instanceID,
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
                                  if (value.length != 12) {
                                    return 'Instance ID must be exactly 12 characters (6 bytes)';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  instanceID = value;
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
                                    'Enable RFU Byte Substitution',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                            if (isEnabled) // Show only when enabled
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Column(
                                  children: [
                                    Container(
                                      alignment: Alignment.center,
                                      child: Table(
                                        border: TableBorder.all(
                                            color: Colors.grey.shade400,
                                            width: 1),
                                        columnWidths: {
                                          0: FixedColumnWidth(40),
                                          1: FixedColumnWidth(40)
                                        },
                                        children: [
                                          // Byte Indices Row
                                          TableRow(
                                            children: List.generate(2, (index) {
                                              return Padding(
                                                padding: EdgeInsets.all(2),
                                                child: Text(
                                                  index.toString(),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade400,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                          // Byte Values Row (TextFields)
                                          TableRow(
                                            children: List.generate(2, (index) {
                                              return Padding(
                                                padding: EdgeInsets.all(2),
                                                child: SizedBox(
                                                  height: 20,
                                                  child: TextFormField(
                                                    controller:
                                                        TextEditingController(
                                                            text: textFieldData[
                                                                index]),
                                                    textAlign: TextAlign.center,
                                                    maxLength:
                                                        2, // Restrict to 2-byte input
                                                    style: TextStyle(
                                                        color: updateIndexes
                                                                .contains(index)
                                                            ? Colors.blue
                                                            : Colors
                                                                .grey.shade400,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                    decoration: InputDecoration(
                                                      counterText:
                                                          '', // Hide character count
                                                      border:
                                                          OutlineInputBorder(
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 5),
                                                    ),
                                                    keyboardType:
                                                        TextInputType.text,
                                                    onChanged: (value) {
                                                      if (value.length <= 2) {
                                                        textFieldData[index] =
                                                            value;
                                                      }
                                                    },
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                        children:
                                            List.generate(rows.length, (index) {
                                      return buildRow(index);
                                    })),
                                  ],
                                ),
                              ),
                            SizedBox(height: 20),

                            // Dynamically Generated Rows

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
                              if (textFieldData.equals(originalData)) {
                                errorMessage =
                                    "Please validate your entry with + action.";
                              } else {
                                Set_Eddystone_UID_Packet(
                                    namespaceID, instanceID);
                                setSubstitutionPacket(formattedText);
                                Navigator.pop(context);
                              }
                            } else {
                              Set_Eddystone_UID_Packet(namespaceID, instanceID);
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
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: Row(
        //mainAxisAlignment: MainAxisAlignment.center,
        //crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space between columns
          Expanded(
            flex: 11,
            child: Card(
              margin: EdgeInsets.fromLTRB(0, 0, 2, 0),
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              child: Container(
                height: 30, // Ensure all cards have the same height
                padding: EdgeInsets.fromLTRB(4, 0, 1, 0),
                alignment: Alignment.center,
                child: DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  value: rows[index]['selectedDataType'],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelStyle: TextStyle(fontSize: 10),
                    labelText: rows[index]['selectedDataType'] == null
                        ? "Data Type"
                        : null,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  ),
                  items: [
                    {"label": "Battery voltage 100 (mV) (U8)", "value": "76"},
                    {"label": "Battery voltage (mV) (U16) (LE)", "value": "56"},
                    {"label": "Battery voltage (mV) (U16) (BE)", "value": "57"},
                    {"label": "8-bit counter (U8)", "value": "63"},
                    {"label": "16-bit counter (U16) (LE)", "value": "43"},
                    {"label": "16-bit counter (U16) (BE)", "value": "44"},
                    {"label": "Accel X axis(1/32g) (S8)", "value": "78"},
                    {
                      "label": "Accel X axis(1/2048g) (S16) (LE)",
                      "value": "58"
                    },
                    {"label": "Accel Y axis(1/32g) (S8)", "value": "79"},
                    {
                      "label": "Accel Y axis(1/2048g) (S16) (LE)",
                      "value": "59"
                    },
                    {"label": "Accel Z axis(1/32g) (S8)", "value": "7A"},
                    {
                      "label": "Accel Z axis(1/2048g) (S16) (LE)",
                      "value": "5A"
                    },
                    {"label": "Temperature(°C) (S8)", "value": "74"},
                    {"label": "Temperature(0.01°C) (S16) (LE)", "value": "54"},
                    {"label": "Temperature(1/256°C) S16 BE", "value": "55"},
                  ]
                      .map((item) => DropdownMenuItem(
                            value: item["value"],
                            child: Text(item["label"]!,
                                style: TextStyle(fontSize: 10)),
                          ))
                      .toList(),
                  menuMaxHeight: 300,
                  onChanged: (rows[index]['isDisabled'] ?? false)
                      ? null
                      : (value) {
                          setState(() {
                            rows[index]['selectedDataType'] = value;
                            rows[index]['selectedFormat'] =
                                dataTypeToFormat[value] ?? "Unknown";
                          });
                        },
                ),
              ),
            ),
          ),

          //SizedBox(width: 1), // Space between columns
          Expanded(
            flex: 3,
            child: Card(
              margin: EdgeInsets.all(0),
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              child: Container(
                height: 30, // Keep height consistent
                padding: EdgeInsets.all(0),
                alignment: Alignment.center,
                child: DropdownButtonFormField<int>(
                  value: rows[index]['selectedIndex'],
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    labelStyle: TextStyle(fontSize: 10),
                    labelText:
                        rows[index]['selectedIndex'] == null ? "Index" : null,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.fromLTRB(4, 0, 0, 0),
                  ),
                  items: List.generate(2, (i) => i)
                      .where((i) =>
                          !selectedIndexes.contains(i) ||
                          i == rows[index]['selectedIndex'])
                      .map((i) => DropdownMenuItem<int>(
                            value: i,
                            child: Text("$i", style: TextStyle(fontSize: 10)),
                          ))
                      .toList(),
                  onChanged: (rows[index]['isDisabled'] ?? false)
                      ? null
                      : (value) {
                          setState(() {
                            if (rows[index]['selectedIndex'] != null) {
                              int prevIndex = rows[index]['selectedIndex'];
                              String? prevFormat =
                                  rows[index]['selectedFormat'];
                              int prevBlockSize = getBlockSize(prevFormat);
                              for (int i = prevIndex;
                                  i < prevIndex + prevBlockSize;
                                  i++) {
                                selectedIndexes.remove(i);
                              }
                            }

                            rows[index]['selectedIndex'] = value;
                            String? format = rows[index]['selectedFormat'];
                            int blockSize = getBlockSize(format);
                            for (int i = value!; i < value + blockSize; i++) {
                              selectedIndexes.add(i);
                            }
                          });
                        },
                ),
              ),
            ),
          ),
          //SizedBox(width: 1),
          Expanded(
            flex: 1,
            child: IconButton(
              padding: EdgeInsets.fromLTRB(2, 0, 2, 0),
              icon: Icon(
                rows[index]['isLastRow']
                    ? Icons.add_circle
                    : Icons.remove_circle,
                color: rows[index]['isLastRow'] ? Colors.green : Colors.red,
                size: 21,
              ),
              onPressed: () {
                if (rows[index]['isLastRow']) {
                  addRow();
                } else {
                  deleteRow(index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void Set_Eddystone_UID_Packet(String namespaceId, String instanceId) async {
    Uint8List Advopcode = Uint8List.fromList([0x33]);
    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;
      Uint8List EddyBeaconSettings =
          createEddystoneUIDSettings(Advopcode, namespaceId, instanceId);

      print("characteristics: ${selChar.uuid}");
      print("DeviceID: ${widget.deviceId}");
      print("Advertising Settings: $createEddystoneUIDSettings");
      _addLog(
          "Sent",
          EddyBeaconSettings.map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join('-'));

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        EddyBeaconSettings,
        BleOutputProperty.withResponse,
      );

      setState(() {
        response = EddyBeaconSettings;
      });
      String hex = EddyBeaconSettings.map(
          (byte) => byte.toRadixString(16).padLeft(2, '0')).join('-');
      _addLog("Sent", hex);
      print("Received response from the device: $hex");
    } catch (e) {
      print("Error writing advertising settings: $e");
    }
  }

  Uint8List createEddystoneUIDSettings(
      Uint8List Advopcode, String namespaceIDHex, String instanceIDHex) {
    // Convert hex string to byte array for Namespace ID
    Uint8List namespaceBytes = hexStringToBytes(namespaceIDHex);
    Uint8List instanceBytes = hexStringToBytes(instanceIDHex);

    if (namespaceBytes.length != 10) {
      throw Exception(
          "Namespace ID must be exactly 10 bytes (20 hex characters)");
    }
    if (instanceBytes.length != 6) {
      throw Exception(
          "Instance ID must be exactly 6 bytes (12 hex characters)");
    }

    return Uint8List.fromList([
      Advopcode[0],
      ...namespaceBytes,
      ...instanceBytes,
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

  void setAltBeaconPacket(
      String mfgIDHex, String beaconIDHex, mfgDataHex) async {
    Uint8List Advopcode = Uint8List.fromList([0x37]); // AltBeacon opcode
    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      Uint8List AltBeaconSettings =
          createAltBeaconSettings(Advopcode, mfgIDHex, beaconIDHex, mfgDataHex);

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

final List<TextInputFormatter> _namespaceInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(20),
  _NAMESPACETextFormatter(),
];

final List<TextInputFormatter> _instanceInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(12),
  _INSTANCETextFormatter(),
];

class _NAMESPACETextFormatter extends TextInputFormatter {
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

class _INSTANCETextFormatter extends TextInputFormatter {
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
