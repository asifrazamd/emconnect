import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/protos/generated/firmware_package.pb.dart';
import 'package:universal_ble_example/dashboard.dart';
import 'package:path_provider/path_provider.dart';

bool hasErrorOccurred = false;

int? lastErrorCode;

bool _shouldReboot = false;
int blockSize = 0;

bool isOn = true;

Uint8List? response;

bool isEnabled = false;

class FotaPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final ({
    BleService service,
    BleCharacteristic characteristic1,
    BleCharacteristic characteristic2,
  }) selectedCharacteristic;

  const FotaPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.selectedCharacteristic,
  });

  @override
  _FotaPageState createState() => _FotaPageState();
}

class _FotaPageState extends State<FotaPage> {
  List<BleService> discoveredServices = [];
  // final List<String> _logs = [];
  final binaryCode = TextEditingController();
  bool showButtons = false;
  bool isOn = false;

  int selectedValue = 0;
  int advertisingInterval = 0;
  bool isConnecting = true;
  bool isSubscriptionAvl = false;
  bool isParseComplete = false;
  int blockSize = 0;
  int getComplete = 0;
  bool isFetchComplete = false;

  @override
  void initState() {
    super.initState();

    UniversalBle.onValueChange = _handleValueChange;
    print("Device ID: ${widget.deviceId}");
    print("Device Name: ${widget.deviceName}");
    print(
        "Characteristic UUID: ${widget.selectedCharacteristic.characteristic2.uuid}");
  }

  @override
  void dispose() {
    super.dispose();

    UniversalBle.onValueChange = null;
  }

  Uint8List convert16BitEndian(Uint8List bigEndianData) {
    Uint8List littleEndianData = Uint8List(bigEndianData.length);
    for (int i = 0; i < bigEndianData.length; i += 2) {
      if (i + 1 < bigEndianData.length) {
        littleEndianData[i] = bigEndianData[i + 1];
        littleEndianData[i + 1] = bigEndianData[i];
      }
    }
    return littleEndianData;
  }

  bool check = false; // Flag to track dialog state
  ValueNotifier<int?> errorCodeNotifier = ValueNotifier(null);

//Method to extract byte values for all beacon types from response
  // void _handleValueChange(
  //     String deviceId, String characteristicId, Uint8List value) {
  //   if (hasErrorOccurred) return;
  //   String hexString =
  //       value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('-');
  //   Uint8List tempval = convert16BitEndian(value);
  //   if (tempval[0] == 0x00 && tempval[1] == 0x10) {
  //     blockSize = tempval[2] << 8 | tempval[3];
  //   }
  //   String s = String.fromCharCodes(value);
  //   String data = '$s\nRaw: ${value.toString()}\nHex: $hexString';

  //   print('_handleValueChange $deviceId, $characteristicId, $s');

  //   print('Received hex data: $hexString');
  //   _addLog("Received", hexString);

  //   if (value[1] != 0x00) {
  //     hasErrorOccurred = true; // Set the error flag

  //     lastErrorCode = value[1]; // store error code
  //     logNotifier.value =
  //         "Firmware update failed with error code: 0x${lastErrorCode!.toRadixString(16).padLeft(2, '0')}";

  //     progressNotifier.value = 0;
  //     // _showDialog(
  //     //   context,
  //     //   "Error",
  //     //   "Firmware Update Failed with error: ${value[1].toRadixString(16).padLeft(2, '0')}",
  //     // );
  //     int errorCode = lastErrorCode ?? 0xFF;
  //     showErrorDialog("Firmware Block Failed",
  //         "Firmware update failed with error code: 0x${errorCode.toRadixString(16).padLeft(2, '0').toUpperCase()}");
  //     return;
  //   }

  //   _addLog("Received", hexString);
  //   isFetchComplete = true;
  // }
  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    if (hasErrorOccurred) return;
    lastErrorCode = value[1]; // store error code
    String hexString =
        value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('-');
    Uint8List tempval = convert16BitEndian(value);
    if (tempval[0] == 0x00 && tempval[1] == 0x10) {
      blockSize = tempval[2] << 8 | tempval[3];
    }
    String s = String.fromCharCodes(value);
    String data = '$s\nRaw: ${value.toString()}\nHex: $hexString';

    print('_handleValueChange $deviceId, $characteristicId, $s');

    print('Received hex data: $hexString');
    _addLog("Received", hexString);

    if (value[1] != 0x00) {
      hasErrorOccurred = true;
      _showDialog(context, "Error",
          "Firmware Update Failed with error code: 0x0${value[1]}");
      return;
    }

    isFetchComplete = true;
  }

  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title, style: TextStyle(color: Colors.black)),
          content: Text(message, style: TextStyle(color: Colors.black)),
          actions: <Widget>[
            TextButton(
              child: Text(
                "OK",
                style: TextStyle(
                    color: Color.fromRGBO(
                        45, 127, 224, 1)), // Set text color using RGB(0,0,0)
              ),

              // Optional: Change button text color
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

  ValueNotifier<String> logNotifier = ValueNotifier<String>("");
  ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);

  Future<void> _pickFirmwareFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'bin', 'hex', 'pack'],
      allowMultiple: false,
      withData: true,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      _showFileTypeSelectionDialog(file);
    } else {
      _addLog('FirmwareUpdate', 'No file selected.');
    }
  }

  void _showFileTypeSelectionDialog(PlatformFile file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('File Selected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Selected file: ${file.name}'),
              SizedBox(
                  height: 10), // Add some space between the text and the button
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // Start firmware update with the selected file
                _startFirmwareUpdate(file, 'packfile');
                Navigator.of(context).pop();
                Future.delayed(const Duration(milliseconds: 500));
              },
              child: Text('Confirm',
                  style: TextStyle(color: Color.fromRGBO(45, 127, 224, 1))),
            ),
          ],
        );
      },
    );
  }

  ValueNotifier<FirmwareDetails?> firmwareDetailsNotifier =
      ValueNotifier<FirmwareDetails?>(null);

  _processFirmwareUpdate(
    List<int> fileData,
    String fileType,
    List<int> firmwareData,
    List<int> signatureX,
    List<int> signatureY,
    List<int> digest,
  ) async {
    ValueNotifier<String> statusNotifier =
        ValueNotifier<String>("Initializing...");
    // logNotifier.value = "Starting firmware update...\n"; // Clear previous logs
    // progressNotifier.value = 0;
    ValueNotifier<bool> showUploadProgress = ValueNotifier<bool>(false);

    var fte = {
      "0": "FW Updater",
      "1": "EM-Core",
      "3": "User App",
      "4": "Customer Bootloader"
    };
    print("FWU");

    print(
        "Processing firmware update for $fileType with file data of size ${fileData.length} bytes.");

    await Future.delayed(const Duration(milliseconds: 200));

    // Parse the binary data into Protobuf message
    try {
      var myFWPackage = FW_Package.fromBuffer(fileData);

      print("Firmware Package count: ${myFWPackage.fwCount}}\n");
      print(
          "Firmware Package generation for  ${myFWPackage.targetInfo.productId}(EM  ${myFWPackage.targetInfo.siliconInfo.siliconType}-D${myFWPackage.targetInfo.siliconInfo.siliconRev}\n");

      for (var fw_element in myFWPackage.fwElements) {
        //fw_element_count = fw_element_count+1;
        var sigx = (fw_element.fwSignature.x);
        // print('sigx : $sigx');
        var sigy = (fw_element.fwSignature.y);
        // print('sigy : $sigy');
        var digest = (fw_element.digest);

        var name = fw_element.fwHdr.sectionCode;

        var firmwarePackage = FW_Package.fromBuffer(fileData);

        var fwsignature = FW_Signature.fromBuffer(fileData);

        var fwCount = FW_Package.fromBuffer(fileData);

        print("Parsed Firmware Package:\n $firmwarePackage\n");
        print("Firmware Encryption type: ${fw_element.encType}\n");

        print("fwhdr: ${fw_element.fwHdr}\n");
        print("fwhdrRaw: ${fw_element.fwHdrRaw}\n");
        print("fwCodeRaw: ${fw_element.fwCodeRaw}\n");
        print("fwsignature: ${fw_element.fwSignature}\n");
        print("encType: ${fw_element.encType}\n");
        print("Crypto Init: ${fw_element.cryptoInitData}\n");
        print("Digest: ${fw_element.digest}\n");
        print("Firmware count: $fwCount");

// Append firmware details to logNotifier
        logNotifier.value += "\n=== Firmware Details ===\n";
        logNotifier.value += "Firmware Count: ${myFWPackage.fwCount}\n";
        logNotifier.value +=
            "Product ID: ${myFWPackage.targetInfo.productId}\n";
        logNotifier.value +=
            "Silicon Type: ${myFWPackage.targetInfo.siliconInfo.siliconType}\n";
        logNotifier.value +=
            "Silicon Rev: ${myFWPackage.targetInfo.siliconInfo.siliconRev}\n";
        logNotifier.value += "Section Code: ${fw_element.fwHdr.sectionCode}\n";
        logNotifier.value +=
            "FW Start Address: ${fw_element.fwHdr.fwStartAddr}\n";
        logNotifier.value += "FW Size: ${fw_element.fwHdr.fwSize} bytes\n";
        logNotifier.value += "FW CRC: ${fw_element.fwHdr.fwCrc}\n";
        logNotifier.value += "FW Version: ${fw_element.fwHdr.fwVer}\n";
        logNotifier.value += "Header Length: ${fw_element.fwHdr.hdrLen}\n";
        logNotifier.value += "Header CRC: ${fw_element.fwHdr.hdrCrc}\n";
        logNotifier.value += "Emcore CRC: ${fw_element.fwHdr.emcoreCrc}\n";
        logNotifier.value += "========================\n";

        for (var n = 0; n < firmwarePackage.fwElements.length; n++) {
          var fwElement = firmwarePackage.fwElements[n];

          print("Firmware Element: $n");
          print("EncType: ${fwElement.encType}");

          // Process encType
          Object encryptionType;
          encryptionType = [
            fwElement.encType.value
          ]; // Extract integer value from enum
        
          // Validate and process cryptoInitData
          Uint8List? cryptoData;
          cryptoData = Uint8List.fromList(
              fwElement.cryptoInitData); // Convert to Uint8List
        
          logNotifier.value += "Switching Device to bootloader mode...\n";
          await Future.delayed(const Duration(milliseconds: 500));

          GetAreaCount();

          await Future.delayed(const Duration(milliseconds: 500));

          GetFirmwareInfo();
          await Future.delayed(const Duration(milliseconds: 500));

          fwuCryptoEngineInit(encryptionType, cryptoData);
          logNotifier.value += "Initializing crypto engine...\n";
          await Future.delayed(const Duration(milliseconds: 500));

          // Upload signature material
          uploadSignatureMaterial(fwElement.fwSignature.x,
              fwElement.fwSignature.y, fwElement.digest);
          logNotifier.value += "Uploading signature material...\n";
          await Future.delayed(const Duration(milliseconds: 500));

          await sendFirmwareUploadInit(fwElement.fwHdrRaw);
          logNotifier.value += "Sending firmware upload initialization...\n";

          await Future.delayed(const Duration(milliseconds: 2000));
          print('block size: $blockSize');
          await Future.delayed(const Duration(milliseconds: 2000));
          print('Number of blocks: ${(fwElement.fwHdr.fwSize) / blockSize}');
          int showPrct = 1;
          int i;
          for (i = 0; i < fwElement.fwHdr.fwSize; i += blockSize) {
            if (hasErrorOccurred) {
              print("Error detected. Stopping firmware transfer loop.");
              logNotifier.value +=
                  "\nError occurred. Firmware transfer aborted.\n";
              _showDialog(context, "Error",
                  "Firmware Update Failed with error code: 0x0$lastErrorCode");
              // int errorCode = lastErrorCode ?? 0xFF;
              // showErrorDialog("Firmware Block Failed",
              //     "Firmware update failed with error code: 0x${errorCode.toRadixString(16).padLeft(2, '0').toUpperCase()}");

              return;
            }
            int prct = ((i / fwElement.fwHdr.fwSize) * 100).toInt();

            if (prct >= showPrct) {
              print('percentage: $prct');
              progressNotifier.value = prct; // Update UI

              showPrct = prct + 13;
            }

            bool status = await writeFirmwareData(
                fwElement.fwCodeRaw
                    .sublist(i, min(i + blockSize, fwElement.fwCodeRaw.length)),
                200);
            await Future.delayed(const Duration(milliseconds: 100));

            status = await storeFirmwareBlock();
            if (!status) {
              //  int errorCode = lastErrorCode ?? 0xFF; // fallback code

              // showErrorDialog("Store Firmware Block Failed",
              //     "Firmware update failed with error code: 0x${errorCode.toRadixString(16).padLeft(2, '0').toUpperCase()}");
              _showDialog(context, "Error",
                  "Firmware Update Failed with error code: 0x0$lastErrorCode");
              logNotifier.value +=
                  "\nError occurred. Firmware transfer aborted.\n";
              print("Error storing firmware block");
              return;
            }

            await Future.delayed(const Duration(milliseconds: 200));
          }

          validateFirmware();
          logNotifier.value += "Validating firmware...\n";
          await Future.delayed(const Duration(milliseconds: 200));

          progressNotifier.value = 100; // Mark as complete

          if (_shouldReboot) {
            if (progressNotifier.value == 100) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyHomePage(),
                ),
              );
            }
            reboot_to_ApplicationMode();
          }

          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      print("Error parsing firmware package: $e");
    }
  }

  void showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title, style: TextStyle(color: Colors.black)),
          content: Text(message, style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              child: Text(
                "OK",
                style: TextStyle(color: Color.fromRGBO(45, 127, 224, 1)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _reconnectToBootloader() async {
    await Future.delayed(Duration(seconds: 1)); // Wait for reboot

    // Connect to the bootloader mode device
    await UniversalBle.connect(widget.deviceId);
    subscribeNotification(BleInputProperty.notification);

    print("Reconnected to Bootloader Mode Device!");
  }

  Future<void> subscribeNotification(BleInputProperty inputProperty) async {
    try {
      if (inputProperty != BleInputProperty.disabled) {
        List<CharacteristicProperty> properties =
            widget.selectedCharacteristic.characteristic1.properties;
        if (properties.contains(CharacteristicProperty.notify)) {
          inputProperty = BleInputProperty.notification;
        } else if (properties.contains(CharacteristicProperty.indicate)) {
          inputProperty = BleInputProperty.indication;
        } else {
          throw 'No notify or indicate property';
        }
      }
      await UniversalBle.setNotifiable(
        widget.deviceId,
        widget.selectedCharacteristic.service.uuid,
        widget.selectedCharacteristic.characteristic1.uuid,
        inputProperty,
      );
      // _addLog('BleInputProperty', inputProperty);
      setState(() {});
    } catch (e) {
      //_addLog('NotifyError', e);
    }
  }

  void Emcore_mode() async {
    Uint8List Infoopcode = Uint8List.fromList([0x04, 0x01]);

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        Infoopcode,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = Infoopcode;
      });

      print("Received response from the device: $Infoopcode");
      print("Firmware update Information received successfully");
    } catch (e) {
      print("Get Firmwareupdate Failed: $e");
    }
  }

  ValueNotifier<bool> showUploadProgress = ValueNotifier<bool>(false);

  void _startFirmwareUpdate(PlatformFile file, String fileType) {
    showUploadProgress.value = true;
    List<int> firmwareData = [];
    List<int> signatureX = [];
    List<int> signatureY = [];
    List<int> digest = [];

    if (file.path != null) {
      File selectedFile = File(file.path!);
      selectedFile.readAsBytes().then((fileData) {
        // Proceed with firmware update using fileData
        _processFirmwareUpdate(
            fileData, fileType, firmwareData, signatureX, signatureY, digest);
      });
    }
  }

  void _showUploadingIndicator(
      BuildContext context, ValueNotifier<int> progressNotifier) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Uploading Firmware"),
          content: ValueListenableBuilder<int>(
            valueListenable: progressNotifier,
            builder: (context, progress, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress / 100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromRGBO(45, 127, 224, 1)), // Blue color
                    backgroundColor: Colors.grey[300], // Light grey background
                  ),
                  //  SizedBox(height: 10),
                  Text("$progress% uploaded",
                      style: TextStyle(
                          color: Color.fromRGBO(45, 127, 224, 1),
                          fontWeight: FontWeight.bold)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void GetAreaCount() async {
    Uint8List opcode = Uint8List.fromList([0x02]);

    print("DeviceID: ${widget.deviceId}");

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;
      print("DeviceID: ${widget.deviceId}");
      // _addLog("Sent",
      //     opcode.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-'));

      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        opcode,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = opcode;
      });

      print("Received response from the device: $opcode");
    } catch (e) {
      print("Get Area Count Failed: $e");
    }
  }

  void GetFirmwareupdateInfo() async {
    Uint8List Infoopcode = Uint8List.fromList([0x01]);

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;
      // _addLog("Sent",
      //     Infoopcode.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        Infoopcode,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = Infoopcode;
      });

      print("Received response from the device: $Infoopcode");
      print("Firmware update Information received successfully");
    } catch (e) {
      print("Get Firmwareupdate Failed: $e");
    }
  }

  void GetFirmwareInfo() async {
    Uint8List Infoopcode = Uint8List.fromList([0x03, 0x00]);

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;
      // _addLog("Sent",
      //     Infoopcode.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        Infoopcode,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = Infoopcode;
      });

      print("Received response from the device: $Infoopcode");
      print("Firmware update Information received successfully");
    } catch (e) {
      print("Get Firmwareupdate Failed: $e");
    }
  }

  Uint8List createCryptoEngineInitPacket(
      dynamic encryptionType, dynamic initializationData) {
    // Convert initializationData to Uint8List if it's a List<int>
    if (initializationData is List<int>) {
      initializationData = Uint8List.fromList(initializationData);
    }

    // Validate initializationData length
    if (initializationData != null &&
        initializationData.isNotEmpty &&
        initializationData.length != 16) {
      throw Exception(
          "The size of the initialization data (0x${initializationData.length.toRadixString(16)}) is not 16");
    }

    // Construct the BLE command packet
    return Uint8List.fromList([
      0x30,

      ...encryptionType, // Encryption type bytes
      if (initializationData != null)
        ...initializationData, // Initialization data bytes
    ]);
  }

  Future<void> fwuCryptoEngineInit(
      dynamic encryptionType, dynamic initializationData) async {
    // Handle `encryptionType` as either `int` or `List<int>`
    if (encryptionType is int) {
      encryptionType = [encryptionType]; // Convert single int to a List<int>
    } else if (encryptionType is List<int>) {
      // No action needed
    } else {
      throw Exception(
          "Unsupported encryptionType format. Expected int or List<int>.");
    }

    // Convert initializationData to Uint8List if it's a List<int>
    if (initializationData is List<int>) {
      initializationData = Uint8List.fromList(initializationData);
    }

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;

      Uint8List cryptoEnginePacket =
          createCryptoEngineInitPacket(encryptionType, initializationData);

      print("Characteristic UUID: ${selChar.uuid}");
      print("Device ID: ${widget.deviceId}");
      print("Crypto Engine Init Packet: $cryptoEnginePacket");
      // _addLog(
      //     "Sent",
      //     cryptoEnginePacket
      //         .map((b) => b.toRadixString(16).padLeft(2, '0'))
      //         .join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        cryptoEnginePacket,
        BleOutputProperty.withResponse,
      );

      setState(() {
        response = cryptoEnginePacket;
      });

      print(
          "Crypto engine initialized successfully with response: $cryptoEnginePacket");
    } catch (e) {
      print("Error initializing crypto engine: $e");
    }
  }

  void uploadSignatureMaterial(
      List<int> sigx, List<int> sigy, List<int> digest) async {
    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;

      // Convert List<int> to Uint8List
      Uint8List sigxBytes = Uint8List.fromList(sigx);
      Uint8List sigyBytes = Uint8List.fromList(sigy);
      Uint8List digestBytes = Uint8List.fromList(digest);

      // Combine all the data into a single Uint8List
      Uint8List signaturePacket = Uint8List.fromList([
        0x31,
        ...sigxBytes,
        ...sigyBytes,
        ...digestBytes,
      ]);

      print("characteristics: ${selChar.uuid}");
      print("DeviceID: ${widget.deviceId}");
      // _addLog(
      //     "Sent",
      //     signaturePacket
      //         .map((b) => b.toRadixString(16).padLeft(2, '0'))
      //         .join('-'));

      // Write to BLE characteristic
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        signaturePacket,
        BleOutputProperty.withResponse,
      ).timeout(Duration(seconds: 15), onTimeout: () {
        throw TimeoutException(
            "BLE write operation timed out after 15 seconds.");
      });

      setState(() {
        response = signaturePacket;
      });

      print("Signature material uploaded successfully:$signaturePacket");
    } catch (e) {
      print("Error uploading signature material: $e");
    }
  }

  Uint8List prepareFirmwareHeader(dynamic header) {
    // Convert hex string to bytes
    if (header is String) {
      header = header.replaceAll("0x", "");
      return Uint8List.fromList(List.generate(header.length ~/ 2, (i) {
        return int.parse(header.substring(i * 2, i * 2 + 2), radix: 16);
      }));
    }
    // If already Uint8List, return it
    if (header is Uint8List) {
      return header;
    }
    throw ArgumentError("Invalid header type. Must be String or Uint8List.");
  }

  Map<String, String> decodeFwHeader(Uint8List header) {
    return {"header_crc_ctrl": "OK"}; // Simulating a valid CRC response
  }

  Future<int> sendFirmwareUploadInit(dynamic header) async {
    // response.where((byte) => ![70, 72, 68, 82].contains(byte)).toList();
    Uint8List preparedHeader = prepareFirmwareHeader(header);

    // Ensure header is exactly 0x28 (40 bytes)
    if (preparedHeader.length != 0x28) {
      print("Error: Header size (${preparedHeader.length}) is incorrect.");
      return preparedHeader.length;
    }

    // Perform CRC check
    String crcCheck = decodeFwHeader(preparedHeader)["header_crc_ctrl"] ?? "";
    if (!crcCheck.startsWith("OK")) {
      print("CRC Error: $crcCheck");
      return preparedHeader.length;
    }

    Uint8List firmwareInitPacket =
        Uint8List.fromList([0x10, ...preparedHeader]);

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;
      // _addLog(
      //     "Sent",
      //     firmwareInitPacket
      //         .map((b) => b.toRadixString(16).padLeft(2, '0'))
      //         .join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        firmwareInitPacket,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response =
            //    response.where((byte) => ![70, 72, 68, 82].contains(byte)).toList();
            response = firmwareInitPacket;
      });
      print('Response from sendFirmwareUploadInit: $response');
// Print the header length
      print("Header length: ${preparedHeader.length}");
      print("Firmware upload initialization:$firmwareInitPacket");

      return preparedHeader.length;
    } catch (e) {
      print("Error writing firmware upload init packet: $e");
      return preparedHeader.length;
    }
  }

  Future<bool> writeFirmwareData(List<int> block, int chunkSize) async {
    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic2;

      Uint8List chunksizeList = Uint8List.fromList([chunkSize]);

      int blocks = (block.length / chunkSize).ceil();
      // print('blocks: $blocks');
      // print('blocklength: ${block.length}');
      for (int i = 0; i < blocks; i++) {
        // Uint8List x = Uint8List.fromList([1, 3, 4]);
        Uint8List d = Uint8List.fromList(block.sublist(
            i * chunkSize, min(i * chunkSize + chunkSize, block.length)));
        Uint8List newList = Uint8List.fromList([...d]);
        // print('***newlist: $newList');
        // _addLog("Sent",
        //     newList.map((b) => b.toRadixString(16).padLeft(2, '0')).join('-'));
        await UniversalBle.writeValue(
          widget.deviceId,
          selService.uuid,
          selChar.uuid,
          newList,
          BleOutputProperty.withoutResponse,
        );

        await Future.delayed(Duration(milliseconds: 10));
      }

      return true;
    } catch (e) {
      print("Error writing firmware data block: $e");
      return false;
    }
  }

  Future<bool> storeFirmwareBlock() async {
    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;

      // Command for storing firmware block
      Uint8List firmwareBlockCommand = Uint8List.fromList([0x20]);

      print("Characteristics: ${selChar.uuid}");
      print("DeviceID: ${widget.deviceId}");
      print("Sending Firmware Block Store Command");
      // _addLog(
      //     "Sent",
      //     firmwareBlockCommand
      //         .map((b) => b.toRadixString(16).padLeft(2, '0'))
      //         .join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        firmwareBlockCommand,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = firmwareBlockCommand;
      });

      print("Firmware block stored successfully");
      return true;
    } catch (e) {
      print("Error storing firmware block: $e");
      return false;
    }
  }

  void validateFirmware() async {
    Uint8List Validateopcode = Uint8List.fromList([0x21]);

    print("DeviceID: ${widget.deviceId}");

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;
      print("DeviceID: ${widget.deviceId}");
      // _addLog(
      //     "Sent",
      //     Validateopcode.map((b) => b.toRadixString(16).padLeft(2, '0'))
      //         .join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        Validateopcode,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = Validateopcode;
      });

      print("Received response from the device: $Validateopcode");
    } catch (e) {
      print("Crypto Initialization Failed: $e");
    }
  }

  void reboot_to_ApplicationMode() async {
    Uint8List Rebootopcode = Uint8List.fromList([0x04, 0x02]);

    print("DeviceID: ${widget.deviceId}");

    try {
      BleService selService = widget.selectedCharacteristic.service;
      BleCharacteristic selChar =
          widget.selectedCharacteristic.characteristic1;
      print("DeviceID: ${widget.deviceId}");
      // _addLog(
      //     "Sent",
      //     Rebootopcode.map((b) => b.toRadixString(16).padLeft(2, '0'))
      //         .join('-'));
      await UniversalBle.writeValue(
        widget.deviceId,
        selService.uuid,
        selChar.uuid,
        Rebootopcode,
        BleOutputProperty.withResponse,
      );
      setState(() {
        response = Rebootopcode;
      });

      print("Received response from the device: $Rebootopcode");
    } catch (e) {
      print("Crypto Initialization Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(247, 247, 244, 244),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "Firmware Updater",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Transform.translate(
                  offset: Offset(-15, 0),
                  child: Checkbox(
                    value: _shouldReboot,
                    onChanged: (bool? value) {
                      setState(() {
                        _shouldReboot = value ?? true;
                      });
                    },
                    side: BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                    fillColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.blue;
                        }
                        return const Color.fromARGB(255, 187, 186, 186);
                      },
                    ),
                    checkColor: Colors.white,
                  ),
                ),
                Transform.translate(
                  offset: Offset(-15, 0),
                  child: Text(
                    'Reboot to Application Mode after update',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                )
              ],
            ),
            GestureDetector(
              onTap: _pickFirmwareFile,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, size: 24, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      "Select File",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            // SizedBox(height: 16),

            ValueListenableBuilder<String>(
              valueListenable: logNotifier,
              builder: (context, log, child) {
                return Text(
                  log,
                  style: TextStyle(fontSize: 14),
                );
              },
            ),

            // Show Progress Only When Confirm is Clicked
            ValueListenableBuilder<bool>(
              valueListenable: showUploadProgress,
              builder: (context, show, child) {
                return show
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 5),
                          Text(
                            "Uploading Firmware:",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          ValueListenableBuilder<int>(
                            valueListenable: progressNotifier,
                            builder: (context, progress, child) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    progress == 100
                                        ? "Firmware update done ✅"
                                        : "$progress% completed",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: progress == 100
                                          ? Color.fromRGBO(45, 127, 224, 1)
                                          : Color.fromRGBO(45, 127, 224, 1),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress / 100,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color.fromRGBO(45, 127, 224, 1),
                                    ),
                                    backgroundColor: Colors.grey[300],
                                  ),
                                  progress == 100
                                      ? Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                              top: 8.0, bottom: 0),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              minimumSize: const Size(200, 40),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              backgroundColor:
                                                  const Color.fromRGBO(
                                                      45, 127, 224, 1),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        )
                                      : SizedBox.shrink(),
                                ],
                              );
                            },
                          ),
                        ],
                      )
                    : SizedBox(); // Hide progress bar initially
              },
            ),
          ],
        ),
      ),
    );
  }
}

ValueNotifier<FirmwareDetails?> firmwareDetailsNotifier =
    ValueNotifier<FirmwareDetails?>(null);

class FirmwareDetails {
  String productId;
  int siliconType;
  int siliconRev;
  int firmwareVer;

  // String sectionCode;
  int fwStartAddr;
  int fwSize;
  int fwCrc;

  int hdrLen;
  int hdrCrc;
  int emcoreCrc;
  int firmwarecount;

  FirmwareDetails({
    required this.productId,
    required this.siliconType,
    required this.siliconRev,
    required this.firmwareVer,
    //  required this.sectionCode,
    required this.fwStartAddr,
    required this.fwSize,
    required this.fwCrc,
    required this.hdrLen,
    required this.hdrCrc,
    required this.emcoreCrc,
    required this.firmwarecount,
  });
}
