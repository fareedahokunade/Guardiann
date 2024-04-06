
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'homescreen.dart';
import 'main.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  static const int _thresholdMilliseconds = 500;
  Timer? _timer;// Time threshold for double press
  DateTime? _lastVolumeChangeTime;
  late StreamSubscription<double> _volumeSubscription;
  String _userName = ''; // Added for user's name
  String _userPhone = ''; // Added for user's phone number
  String? _userLocation = 'Unknown';
  String _recognizedWord = '';
  int _confirmationCount = 0;
  String _confirmedPanicCode = 'Record Panic Code';
  final List<String> _attemptedCodes = [];
  void _logout(){
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyApp()));
    // Navigate to login screen or handle log out as needed
  }
  int _selectedIndex = 0;
  final List<Widget> _widgetOptions = [
    ProfileScreen(),
    HomePage(panicWord: '',),
    Text('Log Out'),
  ];


  void _onItemTapped(int index) {
    if (index == 2) {
      // Log out logic here
      _logout();
    }
    else if (index == 1){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(panicWord: _confirmedPanicCode)),
      );
    }

    else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }


  Future<void> _requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  final List<TextEditingController> _emailControllers = List.generate(3, (index) => TextEditingController());
  bool _editMode = false;

  final List<TextEditingController> _contactControllers = List.generate(3, (ind) => TextEditingController());
  bool _edittMode = false;




  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermission();
    _fetchExistingData();
    startServiceInPlatform();
    _volumeSubscription = FlutterVolumeController.addListener(
        _handleVolumeChange,
        emitOnStart: true,);
  }

  void _handleVolumeChange(double volume) {
    final DateTime now = DateTime.now();
    print('Debug: Volume change detected. Volume: $volume'); // Debug print

    if (_lastVolumeChangeTime != null) {
      final int millisecondsSinceLastChange = now.difference(_lastVolumeChangeTime!).inMilliseconds;
      print('Debug: Milliseconds since last volume change: $millisecondsSinceLastChange'); // Debug print

      if (millisecondsSinceLastChange <= _thresholdMilliseconds) {
        // Detected a rapid change in volume, which could indicate a double press
        print('Debug: Rapid volume change detected, indicating a potential double press.'); // Debug print
        ;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(panicWord: '')), // Adjust panicWord as needed
        );
      }
    } else {
      print('Debug: This is the first volume change detected since the listener was added or the app was started.'); // Debug print
    }
    _lastVolumeChangeTime = now;
  }


  Future<void> _fetchExistingData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).get();

      if (userData.exists) {
        Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['name'] ?? ''; // Fetch and set user's name
          _userPhone = user.phoneNumber ?? '';


          _confirmedPanicCode = data['panicCode'] ?? 'Record Panic Code';
          List<dynamic> emails = data['emails'] ?? [];
          for (int i = 0; i < _emailControllers.length && i < emails.length; i++) {
            _emailControllers[i].text = emails[i];
          }
          List<dynamic> contacts = data['contacts'] ?? [];
          for (int i = 0; i < _contactControllers.length && i < contacts.length; i++) {
            _contactControllers[i].text = contacts[i];
          }
        });
      }
      else {
        // Handle the case where user data does not exist in Firestore
        print('User data does not exist in Firestore');
      }
    } else {
      // Handle the case where there is no authenticated user
      print('No authenticated user found');
    }
  }

  void startServiceInPlatform() async {
    if(Platform.isAndroid){
      var methodChannel = MethodChannel("com.example.guardian");
      String data = await methodChannel.invokeMethod("startService");
      debugPrint(data);
    }
  }

  void _listenForPanicCode() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedWord = result.recognizedWords;
            if (result.finalResult && _recognizedWord.isNotEmpty) {
              _isListening = false;
              _speech.stop();
              _attemptedCodes.add(_recognizedWord);

              if (_attemptedCodes.length == 3) {
                if (_attemptedCodes.toSet().length == 1) { // All attempts are the same
                  _confirmedPanicCode = _recognizedWord;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Panic code confirmed: $_confirmedPanicCode")));
                  _editMode = false; // Exit edit mode after confirming the code
                  _attemptedCodes.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Panic code not matched. Please try again.")));
                  _attemptedCodes.clear(); // Reset attempts
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please say the panic code again.")));
              }
            }
          });
        },
      );
    } else {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Speech recognition not available.")));
    }
  }

  Widget _buildEmailField(int index) {
    return TextField(
      controller: _emailControllers[index],
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
        labelText: 'Emergency Email ${index + 1}',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        suffixIcon: _editMode
            ? IconButton(
          icon: Icon(Icons.clear),
          onPressed: () => _emailControllers[index].clear(),
        )
            : null,
      ),
      readOnly: !_editMode,
    );
  }
  Widget _buildContactField(int ind) {
    return TextField(
      controller: _contactControllers[ind],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
        labelText: 'Emergency Contact ${ind + 1}',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        ),
        suffixIcon: _edittMode
            ? IconButton(
          icon: Icon(Icons.clear),
          onPressed: () => _contactControllers[ind].clear(),
        )
            : null,
      ),
      readOnly: !_edittMode,
    );
  }

  void _saveDataToFirestore() async {
    // Get the current user from FirebaseAuth
    User? user = FirebaseAuth.instance.currentUser;
    String? phoneNumber = user?.phoneNumber; // User's phone number

    if (phoneNumber != null) {
      CollectionReference users = FirebaseFirestore.instance.collection('users');

      await users.doc(phoneNumber).update({
        'panicCode': '$_confirmedPanicCode',
        'emails': _emailControllers.map((controller) => controller.text).toList(),
        'contacts': _contactControllers.map((controller) => controller.text).toList(),
      }).then((_) {
        print("Data saved successfully!");
        // Navigate to HomePage or show a success message
      }).catchError((error) {
        print("Failed to save data: $error");
        // Handle the error, e.g., show an error message
      });
    } else {
      print("No authenticated user found.");
      // Handle the case where there is no authenticated user
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Setup", style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.deepPurple, Colors.purpleAccent],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.black),
            onPressed: () => setState(() {
              _editMode = !_editMode;
              _edittMode = !_edittMode;
              if (_editMode || _edittMode) {
                // Clear previous attempts when entering edit mode
                _attemptedCodes.clear();
              }
            }),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(

          children: [
            Card(
              elevation: 4.0,
              child: ListTile(
                leading: Icon(Icons.account_circle, color: Colors.black,size: 50),
                title: Text(_userName), // Replace with actual user name variable
                subtitle: Text("Phone: $_userPhone"), // Replace with actual phone number and location variables
              ),
            ),
            SizedBox(height: 40),
            InkWell(
              onTap: _editMode ? _listenForPanicCode : null, // Allow recording only in edit mode
              child: Chip(
                label: Text(_confirmedPanicCode),
                avatar: Icon(_isListening ? Icons.mic : Icons.mic_none),
              ),
            ),
            SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust the padding for desired spacing
              child: _buildEmailField(0),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust the padding for desired spacing
              child: _buildEmailField(1),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust the padding for desired spacing
              child: _buildEmailField(2),
            ),

            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust the padding for desired spacing
              child: _buildContactField(0),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust the padding for desired spacing
              child: _buildContactField(1),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust the padding for desired spacing
              child: _buildContactField(2),
            ),

            if (_editMode)
              ElevatedButton(
                onPressed: () {
                  // Save the contacts and panic code
                  _saveDataToFirestore();
                  print("Panic Code: $_confirmedPanicCode");
                  _emailControllers.forEach((controller) => print("Contact: ${controller.text}"));
                  _contactControllers.forEach((controller) => print("Number: ${controller.text}"));
                  setState(() => _editMode = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage(panicWord: '$_confirmedPanicCode',)),
                  );// Exit edit mode after saving
                },
                child: Text('Save'),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Log Out',
          ),

        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple[800],
        onTap: _onItemTapped,
      ),
    );
  }


  @override
  void dispose() {
    _emailControllers.forEach((controller) => controller.dispose());
    _contactControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }


}

