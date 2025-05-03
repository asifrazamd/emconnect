import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

final Map<String, Color> _deviceColors = {};

Color getColorForDevice(String deviceId) {
  return _deviceColors.putIfAbsent(
    deviceId,
    () => Color.fromARGB(
      255,
      Random().nextInt(256),
      Random().nextInt(256),
      Random().nextInt(256),
    ),
  );
}

class ScannedItemWidget extends StatelessWidget {
  final BleDevice bleDevice;
  final VoidCallback? onTap;

  const ScannedItemWidget({super.key, required this.bleDevice, this.onTap});

  String? _identifyBeacon(ManufacturerData? manufacturerData) {
    // Add your beacon identification logic here based on manufacturer data
    // For example, check for specific prefixes or data patterns
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = bleDevice.name?.isNotEmpty == true ? bleDevice.name! : 'NA';
    final manufacturerData = bleDevice.manufacturerDataList.firstOrNull;
    final deviceId = bleDevice.deviceId;
    final beaconType = _identifyBeacon(manufacturerData);
    final beaconId = manufacturerData != null
        ? 'ID: 0x${manufacturerData.companyId.toRadixString(16).padLeft(4, '0').toUpperCase()}'
        : '';
    final displayName = beaconType != null ? '$name ($beaconType)' : name;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 0, end: 0, top: 0, bottom: 0),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  backgroundColor: beaconType == null
                      ? const Color.fromARGB(255, 19, 237, 34)
                      : const Color.fromARGB(255, 248, 203, 3),
                  foregroundColor: Colors.black,
                ),
                child: Icon(
                  beaconType == null ? Icons.bluetooth : Icons.rss_feed,
                  size: 30,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(width: 150),
                          child: Text(
                            displayName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: onTap,
                              style: ElevatedButton.styleFrom(
                                foregroundColor:
                                    const Color.fromRGBO(250, 247, 243, 1),
                                backgroundColor:
                                    const Color.fromRGBO(45, 127, 224, 1),
                                elevation: 4.0,
                                shadowColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: const Text('Connect'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (Platform.isAndroid)
                      Text(
                        'Mac Address: $deviceId',
                        style: const TextStyle(fontSize: 12),
                      ),
                    _buildSignalAndInterval(
                        bleDevice.rssi, bleDevice.adv_interval),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalAndInterval(int? rssi, int? advInterval) {
    return Row(
      children: [
        _getSignalIcon(rssi),
        Text(
          ' $rssi',
          style: const TextStyle(fontSize: 12),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(30, 0, 0, 0)),
        Transform.rotate(
          angle: 45 * pi / 180,
          child: const Icon(
            Icons.open_in_full,
            color: Colors.grey,
            size: 18,
          ),
        ),
        Text(
          ' $advInterval ms',
          style: const TextStyle(fontSize: 12),
        )
      ],
    );
  }

  Icon _getSignalIcon(int? rssi) {
    const towerSize = 15.0;
    if (rssi != null) {
      if (rssi >= -60) {
        return const Icon(
          Icons.signal_cellular_4_bar,
          color: Color.fromARGB(255, 82, 137, 83),
          size: towerSize,
        ); // Excellent
      } else if (rssi >= -90) {
        return const Icon(
          Icons.network_cell,
          color: Color.fromARGB(255, 212, 202, 110),
          size: towerSize,
        ); // Good
      }
    }
    return const Icon(
      Icons.signal_cellular_null,
      color: Color.fromARGB(255, 235, 111, 103),
      size: towerSize,
    ); // Poor or null
  }
}

extension FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}