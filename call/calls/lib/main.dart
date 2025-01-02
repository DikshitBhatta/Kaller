import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CallByNameScreen(),
    );
  }
}

class CallByNameScreen extends StatefulWidget {
  @override
  _CallByNameScreenState createState() => _CallByNameScreenState();
}

class _CallByNameScreenState extends State<CallByNameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _spokenText = "";

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
  }

  Future<void> _initSpeechToText() async {
    bool available = await _speech.initialize();
    if (!available) {
      print("Speech recognition not available.");
    }
  }

  Future<void> requestPermissions() async {
    await Permission.contacts.request();
    await Permission.phone.request();
    await Permission.microphone.request();
  }

  Future<String?> getPhoneNumberByName(String name) async {
    Iterable<Contact> contacts = await ContactsService.getContacts(query: name);

    for (var contact in contacts) {
      if (contact.displayName != null &&
          contact.displayName!.toLowerCase() == name.toLowerCase()) {
        if (contact.phones != null && contact.phones!.isNotEmpty) {
          return contact.phones!.first.value; // Return the first phone number
        }
      }
    }
    return null; // Return null if no match found
  }

  Future<void> makeDirectCall(String phoneNumber) async {
    const platform = MethodChannel('direct_call');
    try {
      await platform.invokeMethod('makeCall', {"phoneNumber": phoneNumber});
    } on PlatformException catch (e) {
      print("Failed to make call: ${e.message}");
    }
  }

  Future<void> initiateCall(String name) async {
    await requestPermissions();

    String? phoneNumber = await getPhoneNumberByName(name);

    if (phoneNumber != null) {
      await makeDirectCall(phoneNumber);
    } else {
      print("Contact not found.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Contact not found!")),
      );
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool hasPermission = await _speech.hasPermission;
      if (hasPermission) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _spokenText = result.recognizedWords;
              _nameController.text = _spokenText;
            });
          },
        );
      } else {
        print("Speech recognition permission not granted.");
      }
    }
  }

  void _stopListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Call by Name")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Enter Contact Name"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => initiateCall(_nameController.text),
              child: Text("Call"),
            ),
            SizedBox(height: 20),
            // Listening animation
            AnimatedOpacity(
              opacity: _isListening ? 1.0 : 0.0,
              duration: Duration(milliseconds: 500),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 1.0, end: 1.5),
                duration: Duration(milliseconds: 1000),
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.mic,
                      size: 80,
                      color: Colors.blue,
                    ),
                  );
                },
                onEnd: () {
                  if (_isListening) {
                    _startListening();
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              label: Text(_isListening ? "Stop Listening" : "Start Listening"),
            ),
          ],
        ),
      ),
    );
  }
}
