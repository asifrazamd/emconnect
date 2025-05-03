import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class EddystoneUrl extends StatefulWidget {
  final Function(int prefix, String url, int? suffix) onApply;

  const EddystoneUrl({super.key, required this.onApply});

  @override
  State<EddystoneUrl> createState() => _EddystoneUrlState();
}

class _EddystoneUrlState extends State<EddystoneUrl> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int? prefix = 0;
  int? suffix = 0;
  String displayurl = "";
  String url = "";

  final _urlInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/_]')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(247, 247, 244, 244),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Eddystone-URL",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 16),
                  const Text(' Encoding', style: TextStyle(fontSize: 15, color: Colors.grey)),
                  DropdownButtonFormField<int>(
                    value: prefix,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text("http://www.")),
                      DropdownMenuItem(value: 1, child: Text("https://www.")),
                      DropdownMenuItem(value: 2, child: Text("http://")),
                      DropdownMenuItem(value: 3, child: Text("https://")),
                    ],
                    onChanged: (value) => setState(() => prefix = value),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text(' URL (max 16 char)', style: TextStyle(fontSize: 15, color: Colors.grey)),
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(10),
                    child: TextFormField(
                      style: const TextStyle(fontSize: 15),
                      inputFormatters: _urlInputFormatters,
                      initialValue: displayurl,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'URL cannot be empty.';
                        }
                        final regex = RegExp(r'^[a-zA-Z0-9/_]+$');
                        if (!regex.hasMatch(value)) {
                          return 'URL should contain only letters, numbers, / and _.';
                        }
                        final encodedUrl = utf8.encode(value);
                        if (encodedUrl.length > 16) {
                          return 'URL should be max 16 bytes after encoding.';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          displayurl = value;
                          url = utf8.encode(value).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(' Suffix', style: TextStyle(fontSize: 15, color: Colors.grey)),
                  DropdownButtonFormField<int?>(
                    value: suffix,
                    items: const [
                      DropdownMenuItem(value: 0x00, child: Text(".com/")),
                      DropdownMenuItem(value: 0x01, child: Text(".org/")),
                      DropdownMenuItem(value: 0x02, child: Text(".edu/")),
                      DropdownMenuItem(value: 0x03, child: Text(".net/")),
                      DropdownMenuItem(value: 0x04, child: Text(".info/")),
                      DropdownMenuItem(value: 0x05, child: Text(".biz/")),
                      DropdownMenuItem(value: 0x06, child: Text(".gov/")),
                      DropdownMenuItem(value: 0x07, child: Text(".com")),
                      DropdownMenuItem(value: 0x08, child: Text(".org")),
                      DropdownMenuItem(value: 0x09, child: Text(".edu")),
                      DropdownMenuItem(value: 0x0a, child: Text(".net")),
                      DropdownMenuItem(value: 0x0b, child: Text(".info")),
                      DropdownMenuItem(value: 0x0c, child: Text(".biz")),
                      DropdownMenuItem(value: 0x0d, child: Text(".gov")),
                    ],
                    onChanged: (value) => setState(() => suffix = value),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ]),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16.0, bottom: 32.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                backgroundColor: const Color.fromRGBO(45, 127, 224, 1),
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onApply(prefix!, url, suffix);
                  Navigator.pop(context);
                } else {
                  print('Validation failed. Please correct the inputs.');
                }
              },
              child: const Text(
                'Apply',
                style: TextStyle(color: Color.fromRGBO(250, 247, 243, 1), fontSize: 16),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
