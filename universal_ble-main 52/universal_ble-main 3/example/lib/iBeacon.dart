import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class iBeacon extends StatefulWidget {
  final String uuid;
  final int majorId;
  final int minorId;
  final Function(String uuid, int majorId, int minorId) onApply;

  iBeacon({
    required this.uuid,
    required this.majorId,
    required this.minorId,
    required this.onApply,
  });

  @override
  _iBeaconState createState() => _iBeaconState();
}

class _iBeaconState extends State<iBeacon> {
  late String uuid;
  int? majorId;
  int? minorId;
  String? errortext1;
  final _formKey = GlobalKey<FormState>();

  final _uuidInputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F-]')),
    LengthLimitingTextInputFormatter(36),
  ];
  final _majoridInputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(5),
  ];
  final _minoridInputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(5),
  ];

  final RegExp _uuidRegex = RegExp(r'^[0-9a-fA-F]{32}$');

  @override
  void initState() {
    super.initState();
    uuid = widget.uuid;
    majorId = widget.majorId;
    minorId = widget.minorId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Color.fromARGB(247, 247, 244, 244),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("iBeacon", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
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
                      _buildLabel("Proximity UUID (16 Bytes)"),
                      _buildUUIDField(),
                      SizedBox(height: 16),
                      _buildLabel("Major ID (0 to 65535)"),
                      _buildMajorIdField(),
                      SizedBox(height: 16),
                      _buildLabel("Minor ID (0 to 65535)"),
                      _buildMinorIdField(),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
            _buildApplyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Row(
        children: [Text(text, style: TextStyle(fontSize: 15, color: Colors.grey))],
      );

  Widget _buildUUIDField() => Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: TextFormField(
          style: TextStyle(fontSize: 15),
          inputFormatters: _uuidInputFormatters,
          initialValue: uuid,
          decoration: InputDecoration(
            hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
            hintStyle: TextStyle(color: Colors.grey),
            contentPadding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'UUID cannot be empty.';
            } else if (!_uuidRegex.hasMatch(value.replaceAll('-', ''))) {
              return 'Invalid UUID format. It should be 32 hex characters.';
            }
            return null;
          },
          onChanged: (value) => setState(() => uuid = value.replaceAll('-', '')),
        ),
      );

  Widget _buildMajorIdField() => Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: TextFormField(
          style: TextStyle(fontSize: 15),
          inputFormatters: _majoridInputFormatters,
          initialValue: majorId.toString(),
          decoration: InputDecoration(
            errorText: errortext1,
            contentPadding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            int? val = int.tryParse(value ?? '');
            if (val == null || val < 0 || val > 65535) {
              return 'Please enter a valid Major ID (0 - 65535).';
            }
            return null;
          },
          onChanged: (value) {
            majorId = int.tryParse(value) ?? 1;
            setState(() {
              errortext1 = (majorId! > 65535) ? 'Please enter a valid Major ID (0 - 65535).' : null;
            });
          },
        ),
      );

  Widget _buildMinorIdField() => Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: TextFormField(
          style: TextStyle(fontSize: 15),
          inputFormatters: _minoridInputFormatters,
          initialValue: minorId.toString(),
          decoration: InputDecoration(
            errorText: errortext1,
            contentPadding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            int? val = int.tryParse(value ?? '');
            if (val == null || val < 0 || val > 65535) {
              return 'Please enter a valid Minor ID (0 - 65535).';
            }
            return null;
          },
          onChanged: (value) {
            minorId = int.tryParse(value);
            setState(() {
              errortext1 = (minorId! > 65535) ? 'Please enter a valid Minor ID (0 - 65535).' : null;
            });
          },
        ),
      );

  Widget _buildApplyButton() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16.0, bottom: 32.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            backgroundColor: Color.fromRGBO(45, 127, 224, 1),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onApply(uuid, majorId!, minorId!);
              Navigator.pop(context);
            }
          },
          child: const Text('Apply', style: TextStyle(color: Color.fromRGBO(250, 247, 243, 1), fontSize: 16)),
        ),
      );
}
