import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:path_provider/path_provider.dart';

bool isTextFieldVisible = false;
bool isOn = true;
String Batteryvoltage = '';
String Temperature = '';
String PDUcounter = '';
String Time = '';
int? interval1;
int? txPowerLevel;
Uint8List? response;
int? selectedRadioIndex;
bool isEnabled = false;

class EddystoneTLMScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  final ({
    BleService service,
    BleCharacteristic characteristic1,
    BleCharacteristic characteristic2,
  })? selectedCharacteristic;
  const EddystoneTLMScreen(
      {super.key,
      required this.deviceId,
      required this.deviceName,
      required this.selectedCharacteristic});

  @override
  _EddystoneTLMScreenState createState() {
    return _EddystoneTLMScreenState();
  }
}

class _EddystoneTLMScreenState extends State<EddystoneTLMScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? selectedHex;
  String selectedFormat = "";
  String formattedText = "";
  String? textFieldError = "";
  Set<int> selectedIndexes = {};
  Set<int> updateIndexes = {};
  bool identify = true;

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
    Uint8List deviceInfoopcode = Uint8List.fromList([0x3A]);

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

      // if (value[1] == 0x3A) {
      //   print("entered eddystone TLM ");
      //   setState(() {
      //     Batteryvoltage = value
      //         .sublist(3, 5)
      //         .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      //         .join();
      //     Temperature = value
      //         .sublist(5, 7)
      //         .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      //         .join();
      //     PDUcounter = value
      //         .sublist(7, 11)
      //         .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      //         .join();
      //     Time = value
      //         .sublist(11, 15)
      //         .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      //         .join();
      //     getComplete += 1;
      //     check = true;
      //   });
      // }
      if (value.length >= 15) {
        // Make sure full packet is received
        if (value[1] == 0x3A) {
          // Your filter for Eddystone-TLM
          print("Entered Eddystone-TLM");

          // Decode Battery Voltage (2 bytes, UINT16, big endian)
          int batteryVoltage = (value[3] << 8) | value[4];

          // Decode Temperature (2 bytes, INT16, big endian, divided by 256)
          int tempRaw = (value[5] << 8) | value[6];
          double temperature;
          if (tempRaw == 0x8000) {
            temperature = double.nan; // Not supported
          } else {
            temperature = tempRaw / 256.0;
          }

          // Decode PDU Counter (4 bytes, UINT32, big endian)
          int pduCounter =
              (value[7] << 24) | (value[8] << 16) | (value[9] << 8) | value[10];

          // Decode Time (4 bytes, UINT32, big endian, 0.1s units)
          int timeSinceResetRaw = (value[11] << 24) |
              (value[12] << 16) |
              (value[13] << 8) |
              value[14];
          double timeSinceReset =
              timeSinceResetRaw / 10.0; // convert to seconds

          setState(() {
            Batteryvoltage = '$batteryVoltage mV';
            Temperature =
                temperature.isNaN ? 'Not supported' : '$temperature °C';
            PDUcounter = '$pduCounter';
            Time = '$timeSinceReset seconds';
            getComplete += 1;
            check = true;
          });
        }
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

  void Set_Advertising_Settings(
      int packetType, int interval, int txPowerLevel) async {
    Uint8List Advopcode = Uint8List.fromList([0x22]);

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
          "Eddystone-TLM Info",
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
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  // Card for Product ID
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Battery Voltage",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        Spacer(),
                        Text(
                          Batteryvoltage,
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Card for Firmware Version Major
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Temperature",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        Spacer(),
                        Text(
                          Temperature,
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Card for Firmware Version Minor
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          "PDU Counter",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        Spacer(),
                        Text(
                          PDUcounter,
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Card for Hardware Version
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Time",
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                        Spacer(),
                        Text(
                          Time,
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void Set_Eddystone_TLM_Packet(String batteryVoltage, String temperature,
      String pduCount, String timeSinceReset) async {
    Uint8List Advopcode = Uint8List.fromList([0x3B]);

    try {
      BleService selService = widget.selectedCharacteristic!.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic!.characteristic1;

      Uint8List EddyBeaconSettings = createEddystoneTLMSettings(
        Advopcode,
        batteryVoltage,
        temperature,
        pduCount,
        timeSinceReset,
      );

      print("characteristics: ${selChar.uuid}");
      print("DeviceID: ${widget.deviceId}");

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

  Uint8List createEddystoneTLMSettings(
      Uint8List Advopcode,
      String BatteryvoltageHex,
      String TemperatureHex,
      String PDUcounterHex,
      String TimeHex) {
    Uint8List BatteryvoltageBytes = hexStringToBytes(BatteryvoltageHex);
    Uint8List TemperatureBytes = hexStringToBytes(TemperatureHex);
    Uint8List PDUcounterBytes = hexStringToBytes(PDUcounterHex);
    Uint8List TimeBytes = hexStringToBytes(TimeHex);
    if (BatteryvoltageBytes.length != 2) {
      throw Exception(
          "Battery voltage must be exactly 2 bytes (4 hex characters)");
    }

    if (TemperatureBytes.length != 2) {
      throw Exception(
          "Temperature must be exactly 10 bytes (20 hex characters)");
    }

    return Uint8List.fromList([
      Advopcode[0],
      ...BatteryvoltageBytes,
      ...TemperatureBytes,
      ...PDUcounterBytes,
      ...TimeBytes
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
}

final List<TextInputFormatter> _batteryvoltageInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(4),
  _BATTERYVOLTAGETextFormatter(),
];

final List<TextInputFormatter> _temperatureInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(4),
  _TEMPERATURETextFormatter(),
];
final List<TextInputFormatter> _pducounterInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(8),
  _PDUCOUNTERTextFormatter(),
];
final List<TextInputFormatter> _timeInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
  LengthLimitingTextInputFormatter(8),
  _TIMETextFormatter(),
];

class _BATTERYVOLTAGETextFormatter extends TextInputFormatter {
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

class _TEMPERATURETextFormatter extends TextInputFormatter {
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

class _PDUCOUNTERTextFormatter extends TextInputFormatter {
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

class _TIMETextFormatter extends TextInputFormatter {
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
