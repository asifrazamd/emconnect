// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart' show Barcode, BarcodeCapture, MobileScanner;
// import 'package:provider/provider.dart';
// import 'package:universal_ble/universal_ble.dart';
// import 'package:universal_ble_example/BleScanState.dart';
// import 'package:universal_ble_example/data/permission_handler.dart';
// import 'package:universal_ble_example/data/scan_filter_model.dart';
// import 'package:universal_ble_example/data/uicolors.dart';
// import 'package:universal_ble_example/peripheral_details/peripheral.dart';
// import 'package:universal_ble_example/home/widgets/scanned_item_widget.dart';
// import 'package:universal_ble_example/home/widgets/scan_filter_widget.dart';

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   final List<BleDevice> _bleDevices = [];
//   bool _isScanning = false;
//   bool _showInitialUI = true;
//   bool _showQRIcon = false;
//   TextEditingController namePrefixController = TextEditingController();
//   AvailabilityState? bleAvailabilityState;

//   @override
//   void initState() {
//     super.initState();
//     final scanState = Provider.of<BleScanState>(context, listen: false);
//     namePrefixController.text = scanState.nameFilter;

//     namePrefixController.addListener(() {
//       scanState.updateFilters(
//         scanState.macFilter,
//         namePrefixController.text,
//         scanState.rssiFilter,
//       );
//     });

//     UniversalBle.onAvailabilityChange = (state) {
//       setState(() {
//         bleAvailabilityState = state;
//       });
//     };

//     UniversalBle.onScanResult = (result) async {
//       final deviceId = result.deviceId;
//       final now = DateTime.now();
//       await Future.delayed(const Duration(milliseconds: 300));

//       debugPrint('@@@${result.deviceId}:${result.name}:${result.rawName}');

//       final index = _bleDevices.indexWhere((e) => e.deviceId == deviceId);
//       if (index == -1) {
//         final bleDevice = result..time_stamp = now.millisecondsSinceEpoch;
//         Provider.of<BleScanState>(context, listen: false).addOrUpdateDevice(bleDevice);
//         _bleDevices.add(bleDevice);
//       } else {
//         _bleDevices[index]
//           ..name = result.name
//           ..rssi = result.rssi
//           ..adv_interval = now.millisecondsSinceEpoch - _bleDevices[index].time_stamp
//           ..time_stamp = now.millisecondsSinceEpoch;
//         debugPrint('@@adv_interval ${_bleDevices[index].adv_interval}');
//       }
//       setState(() {});
//     };
//   }

// Future<void> _showMacRssiFilterDialog() async {
//   final scanState = Provider.of<BleScanState>(context, listen: false);
//   final model = await showDialog<ScanFilterModel>(
//     context: context,
//     builder: (context) => Dialog(
//       backgroundColor: UIColors.emGrey,
//       alignment: const Alignment(0, -0.55),
//       insetPadding: EdgeInsets.zero,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
//       child: Container( // Apply padding to the Container
//         height: 250,
//         width: 500,
//         padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0), // Corrected line
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ScanFilterWidget(
//                 scanState.macFilter,
//                 scanState.rssiFilter.toDouble(),
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );

//   if (model != null) {
//     scanState.updateFilters(
//       model.macAddr,
//       namePrefixController.text,
//       model.rssiVal,
//     );
//   }
// } Future<void> _startScan() async {
//     await UniversalBle.startScan();
//   }

//   void _showEnableBluetoothDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Enable Bluetooth"),
//         content: const Text("Bluetooth is disabled. Please enable it in the Settings app."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text("Ok"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _processScannedQRCode(String qrCode) async {
//     debugPrint("Processing QR Code: $qrCode");
//     if (qrCode.isNotEmpty && qrCode != "-1") {
//       try {
//         final snToInt = int.parse(qrCode);
//         debugPrint("Parsed SN: $snToInt");
//         String hexValue = snToInt.toRadixString(16).toUpperCase();
//         debugPrint("Hex Value: $hexValue");

//         if (hexValue.length % 2 != 0) {
//           hexValue = "0$hexValue";
//         }

//         final bytePairs = <String>[];
//         for (var i = 0; i < hexValue.length; i += 2) {
//           bytePairs.add(hexValue.substring(i, i + 2));
//         }
//         debugPrint("Byte Pairs: $bytePairs");
//         final fullMac = bytePairs.reversed.join(":");
//         debugPrint("Full MAC: $fullMac");

//         final macParts = fullMac.split(":");
//         final deviceName = "EM-${macParts.sublist(macParts.length - 3).join("")}";
//         debugPrint("Device Name: $deviceName");

//         setState(() {
//           namePrefixController.text = deviceName;
//         });

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Device Name: $deviceName")),
//         );

//         await UniversalBle.startScan();
//         await Future.delayed(const Duration(seconds: 1));
//       } catch (e) {
//         debugPrint(" Error processing QR code: $e");
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final scanState = Provider.of<BleScanState>(context);
//     final filteredDevices = scanState.devices.where((device) {
//       final nameFilter = scanState.nameFilter.toLowerCase();
//       final nameMatches = nameFilter.isEmpty ||
//           (device.name?.toLowerCase().contains(nameFilter) ?? false);
//       final macMatches = device.deviceId.toLowerCase().contains(scanState.macFilter.toLowerCase());
//       final rssiMatches = device.rssi! >= scanState.rssiFilter;
//       return nameMatches && macMatches && rssiMatches;
//     }).toList()
//       ..sort((a, b) => b.rssi!.compareTo(a.rssi!));

//     return Scaffold(
//       backgroundColor: const Color.fromARGB(255, 249, 247, 247),
//       appBar: AppBar(
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         backgroundColor: const Color.fromARGB(255, 249, 247, 247),
//         title: const Text(
//           'Scan',
//           style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.filter_alt_outlined, color: Colors.black),
//             onPressed: _showMacRssiFilterDialog,
//           ),
//           Row(
//             children: [
//               if (_showQRIcon)
//                 IconButton(
//                   icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
//                   onPressed: () {
//                     showDialog(
//                       context: context,
//                       builder: (context) => Dialog(
//                         insetPadding: EdgeInsets.zero,
//                         child: SizedBox(
//                           width: MediaQuery.of(context).size.width,
//                           height: MediaQuery.of(context).size.height,
//                           child: MobileScanner(
//                             fit: BoxFit.cover,
//                             onDetect: (BarcodeCapture capture) {
//                               final barcodes = capture.barcodes;
//                               if (barcodes.isNotEmpty && barcodes.first.displayValue != null) {
//                                 _processScannedQRCode(barcodes.first.displayValue!);
//                                 Navigator.pop(context);
//                               }
//                             },
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 )
//             ],
//           ),
//           IconButton(
//             icon: Icon(
//               _isScanning ? Icons.stop : Icons.play_arrow,
//               color: Colors.black,
//             ),
//             onPressed: () async {
//               if (_isScanning) {
//                 await UniversalBle.stopScan();
//                 setState(() {
//                   _isScanning = false;
//                   _showQRIcon = true;
//                   _showInitialUI = true;
//                 });
//               } else {
//                 bool permissionsGranted = true;
//                 bool bluetoothEnabled = true;
//                 if (Platform.isAndroid) {
//                   permissionsGranted = await PermissionHandler.arePermissionsGranted();
//                   bluetoothEnabled = await UniversalBle.enableBluetooth();
//                 }

//                 if (bluetoothEnabled && permissionsGranted) {
//                   setState(() {
//                     _bleDevices.clear();
//                     scanState.clearDevices();
//                     _isScanning = true;
//                     _showQRIcon = true;
//                     _showInitialUI = false;
//                   });
//                   await _startScan();
//                 }
//               }
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: SizedBox(
//               height: 40,
//               child: TextField(
//                 controller: namePrefixController,
//                 decoration: InputDecoration(
//                   hintText: 'Search by name',
//                   prefixIcon: const Icon(Icons.search),
//                   contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0)),
//                   fillColor: const Color.fromARGB(234, 234, 234, 234),
//                   filled: true,
//                 ),
//                 style: const TextStyle(height: 1.4),
//                 onChanged: (value) {
//                   scanState.updateFilters(
//                     scanState.macFilter,
//                     value,
//                     scanState.rssiFilter,
//                   );
//                 },
//               ),
//             ),
//           ),
//           Expanded(
//             child: _showInitialUI
//                 ? Padding(
//                     padding: const EdgeInsets.fromLTRB(0, 200, 0, 0),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Text(
//                           "Scan EM Beacon QR Code",
//                           style: TextStyle(
//                             fontSize: 17,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Container(
//                           padding: const EdgeInsets.all(7),
//                           decoration: const BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: Colors.blue,
//                           ),
//                           child: IconButton(
//                             icon: const Icon(
//                               Icons.qr_code_scanner,
//                               color: Colors.white,
//                               size: 30,
//                             ),
//                             onPressed: () async {
//                               if (_isScanning) {
//                                 await UniversalBle.stopScan();
//                                 setState(() {
//                                   _isScanning = false;
//                                 });
//                               } else {
//                                 bool permissionsGranted = true;
//                                 bool bluetoothEnabled = true;
//                                 if (Platform.isAndroid) {
//                                   permissionsGranted =
//                                       await PermissionHandler.arePermissionsGranted();
//                                   bluetoothEnabled = await UniversalBle.enableBluetooth();
//                                 }

//                                 if (bluetoothEnabled && permissionsGranted) {
//                                   setState(() {
//                                     _bleDevices.clear();
//                                     _isScanning = true;
//                                     _showQRIcon = true;
//                                     _showInitialUI = false;
//                                   });
//                                   await _startScan();
//                                 }
//                               }

//                               showDialog(
//                                 context: context,
//                                 builder: (context) => Dialog(
//                                   insetPadding: EdgeInsets.zero,
//                                   child: SizedBox(
//                                     width: MediaQuery.of(context).size.width,
//                                     height: MediaQuery.of(context).size.height,
//                                     child: MobileScanner(
//                                       fit: BoxFit.cover,
//                                       onDetect: (BarcodeCapture capture) {
//                                         final barcodes = capture.barcodes;
//                                         if (barcodes.isNotEmpty &&
//                                             barcodes.first.displayValue != null) {
//                                           _processScannedQRCode(barcodes.first.displayValue!);
//                                           Navigator.pop(context);
//                                         }
//                                       },
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : filteredDevices.isEmpty
//                     ? const Center(child: CircularProgressIndicator())
//                     : ListView.separated(
//                         itemCount: filteredDevices.length,
//                         separatorBuilder: (context, index) => const Divider(),
//                         itemBuilder: (context, index) {
//                           final device = filteredDevices[index];
//                           return ScannedItemWidget(
//                             bleDevice: device,
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) => PeripheralDetailPage(
//                                     device.deviceId,
//                                     device.name ?? "Unknown Peripheral",
//                                   ),
//                                 ),
//                               );
//                               UniversalBle.stopScan();
//                               setState(() {
//                                 _isScanning = false;
//                               });
//                             },
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mobile_scanner/mobile_scanner.dart'
    show Barcode, BarcodeCapture, MobileScanner;
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/BleScanState.dart';
import 'package:universal_ble_example/data/permission_handler.dart';
import 'package:universal_ble_example/data/scan_filter_model.dart';
import 'package:universal_ble_example/data/uicolors.dart';

import 'package:universal_ble_example/peripheral_details/peripheral.dart';
import 'package:universal_ble_example/home/widgets/scanned_item_widget.dart';
import 'package:universal_ble_example/home/widgets/scan_filter_widget.dart';

bool _showInitialUI = true;
bool enabled = false;
bool permissions = false;
int interval = 0;
String scannedMacAddress = ""; // Store the scanned MAC address

bool _showQRIcon = false; // Controls QR icon visibility

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _bleDevices = <BleDevice>[];
  bool _isScanning = false;
  bool _isBuffering = false;
  TextEditingController servicesFilterController = TextEditingController();
  TextEditingController namePrefixController = TextEditingController();
  TextEditingController macPrefixController = TextEditingController();
  TextEditingController manufacturerDataController = TextEditingController();
  int rssiValue = -100;
  String macFilter = "";
  int rssiFilter = -100;

  AvailabilityState? bleAvailabilityState;
  ScanFilter? scanFilter;

  @override
  void initState() {
    super.initState();

    final scanState = Provider.of<BleScanState>(context, listen: false);

    // Initialize controllers with the current filter values
    namePrefixController.text = scanState.nameFilter;
    macPrefixController.text = scanState.macFilter;
    rssiValue = scanState.rssiFilter;

    // Add listeners to update the state when the input changes
    namePrefixController.addListener(() {
      scanState.updateFilters(
        scanState.macFilter,
        namePrefixController.text,
        scanState.rssiFilter,
      );
    });

    macPrefixController.addListener(() {
      scanState.updateFilters(
        macPrefixController.text,
        scanState.nameFilter,
        scanState.rssiFilter,
      );
    });

    UniversalBle.onAvailabilityChange = (state) {
      setState(() {
        bleAvailabilityState = state;
      });
    };

    UniversalBle.onScanResult = (result) async {
      String deviceId = result.deviceId;
      // Get the current time
      DateTime now = DateTime.now();
      await Future.delayed(Duration(milliseconds: 300)); // slows down UI update

      debugPrint('@@@${result.deviceId}:${result.name}:${result.rawName}');
      // Add the device to the list if it's not already present
      int index = _bleDevices.indexWhere((e) => e.deviceId == deviceId);
      if (index == -1) {
        BleDevice bledevice = result;
        bledevice.time_stamp = now.millisecondsSinceEpoch;
        Provider.of<BleScanState>(context, listen: false)
            .addOrUpdateDevice(bledevice);
        _bleDevices.add(bledevice);
      } else {
        _bleDevices[index].name = result.name;
        _bleDevices[index].rssi = result.rssi;
        _bleDevices[index].adv_interval =
            now.millisecondsSinceEpoch - _bleDevices[index].time_stamp;
        _bleDevices[index].time_stamp = now.millisecondsSinceEpoch;
        debugPrint('@@adv_interval ${_bleDevices[index].adv_interval}');
      }
      setState(() {});
    };
  }

  void showMacRssiFilterDialog() async {
    ScanFilterModel? model = await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: UIColors.emGrey,
          alignment: Alignment(0, -0.55),
          insetPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.0),
          ),
          child: Container(
            height: 250,
            width: 500,
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScanFilterWidget(
                    macPrefixController.text,
                    rssiValue.toDouble(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (model != null) {
      setState(() {
        macFilter = model.macAddr;
        rssiValue = model.rssiVal;
      });

      Provider.of<BleScanState>(context, listen: false).updateFilters(
        macFilter,
        namePrefixController.text,
        rssiValue,
      );
    }
  }

  Future<void> startScan() async {
    await UniversalBle.startScan();
  }

  void showEnableBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Enable Bluetooth"),
        content: Text(
            "Bluetooth is disabled. Please enable it in the Settings app."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Ok"),
          ),
        ],
      ),
    );
  }

  void processScannedQRCode(String qrCode) async {
    if (qrCode.isNotEmpty) {
      if (qrCode != "-1") {
        try {
          int snToInt = int.parse(qrCode);
          String hexValue = snToInt.toRadixString(16).toUpperCase();

          if (hexValue.length % 2 != 0) {
            hexValue = "0$hexValue";
          }

          List<String> bytePairs = [];
          for (int i = 0; i < hexValue.length; i += 2) {
            bytePairs.add(hexValue.substring(i, i + 2));
          }
          String fullMac = bytePairs.reversed.join(":");

          List<String> macParts = fullMac.split(":");
          String deviceName =
              "EM-" + macParts.sublist(macParts.length - 3).join("");

          setState(() {
            scannedMacAddress = deviceName;
            namePrefixController.text = deviceName; // Update the search box
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Device Name: $scannedMacAddress")),
          );

          await UniversalBle.startScan();
          await Future.delayed(Duration(seconds: 1));
        } catch (e) {
          debugPrint(" Error processing QR code: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = Provider.of<BleScanState>(context);
    final filteredDevices = scanState.devices.where((device) {
      final nameFilter = scanState.nameFilter.toLowerCase();
      final nameMatches = nameFilter.isEmpty ||
          (device.name
                  ?.toLowerCase()
                  .contains(scanState.nameFilter.toLowerCase()) ??
              false);
      final macMatches = device.deviceId
          .toLowerCase()
          .contains(scanState.macFilter.toLowerCase());
      final rssiMatches = device.rssi! >= scanState.rssiFilter;
      // final scannedMacMatches = scannedMacAddress.isEmpty ||
      //     device.deviceId.toLowerCase() == scannedMacAddress.toLowerCase();

      return nameMatches && macMatches && rssiMatches;
    }).toList()..sort((a, b) => b.rssi!.compareTo(a.rssi!));


    return Scaffold(
      backgroundColor: Color.fromARGB(255, 249, 247, 247),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color.fromARGB(255, 249, 247, 247),
        title: const Text(
          'Scan',
          style: TextStyle(
              color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Colors.black),
            onPressed: showMacRssiFilterDialog,
          ),
          // Controls visibility of QR code scanner

          Row(
            children: [
              if (_showQRIcon)
                IconButton(
                  icon: Icon(Icons.qr_code_scanner, color: Colors.black),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        insetPadding: EdgeInsets.zero,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: MobileScanner(
                            fit: BoxFit
                                .cover, // Ensures the camera fills the entire dialog
                            onDetect: (BarcodeCapture capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty &&
                                  barcodes.first.displayValue != null) {
                                processScannedQRCode(
                                    barcodes.first.displayValue!);
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                )
            ],
          ),

          // Play/Stop Button
          IconButton(
            icon: Icon(
              _isScanning ? Icons.stop : Icons.play_arrow,
              color: Colors.black,
            ),
            onPressed: () async {
              if (_isScanning) {
                await UniversalBle.stopScan();
                setState(() {
                  _isScanning = false;
                  _showQRIcon = true;
                  scannedMacAddress = "";
                  // _showInitialUI = true;
                });
              } else {
                if (Platform.isAndroid) {
                  permissions = await PermissionHandler.arePermissionsGranted();
                  enabled = await UniversalBle.enableBluetooth();
                } else {
                  permissions = true;
                  enabled = true;
                }

                if (enabled && permissions) {
                  setState(() {
                    _bleDevices.clear();
                    scanState.clearDevices();
                    if (!_isScanning) {
                      // Clear only if starting a new scan explicitly
                    }
                    _isScanning = true;
                    _isBuffering = false;
                    _showQRIcon = true;
                    _showInitialUI = false; // Show QR icon when scanning starts
                  });
                  await startScan();
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: namePrefixController,
                decoration: InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  fillColor: Color.fromARGB(234, 234, 234, 234),
                  filled: true,
                ),
                style: const TextStyle(height: 1.4),
                onChanged: (value) {
                  Provider.of<BleScanState>(context, listen: false)
                      .updateFilters(
                    scanState.macFilter,
                    value, // Pass the updated name filter
                    scanState.rssiFilter,
                  );
                  setState(() {});
                },
              ),
            ),
          ),
          (!_showInitialUI)
              ? ((filteredDevices.isEmpty)
                  ? (CircularProgressIndicator())
                  : Padding(padding: EdgeInsets.all(0)))
              : Padding(
                  padding: EdgeInsets.fromLTRB(0, 200, 0, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Scan EM Beacon QR Code",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                          padding: EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue, // Background color
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () async {
                              if (_isScanning) {
                                await UniversalBle.stopScan();
                                setState(() {
                                  _isScanning = false;
                                });
                              } else {
                                if (Platform.isAndroid) {
                                  permissions = await PermissionHandler
                                      .arePermissionsGranted();
                                  enabled =
                                      await UniversalBle.enableBluetooth();
                                } else {
                                  permissions = true;
                                  enabled = true;
                                }

                                if (enabled && permissions) {
                                  setState(() {
                                    _bleDevices.clear();

                                    _isScanning = true;
                                    _isBuffering = false;
                                    _showQRIcon = true;
                                    _showInitialUI = false;
                                  });
                                  await startScan();
                                }
                              }

                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  insetPadding: EdgeInsets.zero,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.height,
                                    child: MobileScanner(
                                      fit: BoxFit
                                          .cover, // Ensures the camera fills the entire dialog
                                      onDetect: (BarcodeCapture capture) {
                                        final List<Barcode> barcodes =
                                            capture.barcodes;
                                        if (barcodes.isNotEmpty &&
                                            barcodes.first.displayValue !=
                                                null) {
                                          processScannedQRCode(
                                              barcodes.first.displayValue!);
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          )),
                    ],
                  ),
                ),
          Divider(
            color: Colors.grey,
            thickness: 1.0,
            height: 1.0,
          ),
          SizedBox(height: 8.0),
          Expanded(
            child: filteredDevices.isEmpty
                ? Center()
                : ListView.separated(
                    itemCount: filteredDevices.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final device = filteredDevices[index];
                      return ScannedItemWidget(
                        bleDevice: device,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PeripheralDetailPage(
                                device.deviceId,
                                device.name ?? "Unknown Peripheral",
                              ),
                            ),
                          );
                          UniversalBle.stopScan();
                          setState(() {
                            _isScanning = false;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
