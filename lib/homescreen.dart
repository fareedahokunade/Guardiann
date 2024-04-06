import 'dart:async';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:background_sms/background_sms.dart';
import 'package:guardian/location.dart';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_service/flutter_foreground_service.dart';
import 'package:another_audio_recorder/another_audio_recorder.dart';
import 'package:guardian/main.dart';
import 'package:google_maps_webservice_ex/places.dart' as loc;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' hide PermissionStatus;
import 'package:path/path.dart' as path;
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profilescreen.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_background_service/flutter_background_service.dart';




class HomePage extends StatefulWidget {
  final String panicWord;


  HomePage({Key? key, required this.panicWord}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}



class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin{
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  late StreamSubscription<double> _volumeSubscription;
  DateTime? _lastVolumeChangeTime;
  static const int _thresholdMilliseconds = 500;
  Timer? _timer;// Time threshold for double press
  bool _showText = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Location _location = Location();
  bool _isRecording = false;
  String? _localRecordingPath;
  List<String> _safetyAreas = [];
  int _panicWordCount = 0;
  String name = "";
  int _selectedIndex = 1; // Default index for Home Page

  void _logout(){
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyApp()));
    // Navigate to login screen or handle log out as needed
  }
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
    else if (index == 0){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }

    else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }




  List<String> _emergencyContacts = ["113 - Traffic Accidents", '997 - Anti-Corruption', '3512 -Gender Based Violence', "112 - Emergency", "116 - Child Help Line", "3511 - Abuse By Police Officer", "118 - Traffic Police"]; // Example safety areas


  @override
  void initState() {
    super.initState();
    startServiceInPlatform();
    _initializeSpeech();
    fetchSafeAreas();
    _requestPermissions();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _buttonAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _volumeSubscription = FlutterVolumeController.addListener(
      _handleVolumeChange,
      emitOnStart: true,

    );

    // Inside your initState or equivalent setup method
    MethodChannel channel = MethodChannel('com.example.guardian/channel');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerPanicAction') {
        print("Emergency called");
      }
    });

  }



  void startServiceInPlatform() async {
    if(Platform.isAndroid){
      var methodChannel = MethodChannel("com.example.guardian");
      String data = await methodChannel.invokeMethod("startService");
      debugPrint(data);
    }
  }



  void fetchSafeAreas() async {
    List<String> safeAreas = await getSafeAreas();
    setState(() {
      _safetyAreas = safeAreas;
    });
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
        _panicWordCount++;
        _performPanicAction(_panicWordCount);
      }
    } else {
      print('Debug: This is the first volume change detected since the listener was added or the app was started.'); // Debug print
    }
    _lastVolumeChangeTime = now;
  }
  Future<void> _requestPermissions() async {
    await [Permission.location, Permission.microphone, Permission.sms, Permission.storage].request();
    //await telephony.requestPhoneAndSmsPermissions;
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize();
    if (available) {
      _startListening();
    } else {
      print("The user has denied the use of speech recognition.");
    }
  }






  void _startListening() {

    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.toLowerCase() == widget.panicWord.toLowerCase() && !_isRecording) {
          _panicWordCount++;
          _performPanicAction(_panicWordCount);
        }
      },
    );
    setState(() => _isListening = true);
  }

  Future<void> _stopRecording() async {
    if (_recorder != null && _isRecording) {
      // Stop the recorder
      await _recorder!.stop();
      setState(() {
        _isRecording = false; // Update the recording state
      });
    }
  }

  Future<void> _sendRecordingToEmergencyContacts() async {
    // Ensure recording is stopped and file is available
    await _stopRecording();

    // Fetch emergency contacts
    List<String> recipients = await _fetchEmergencyContacts();

    if (recipients.isNotEmpty && _localRecordingPath != null) {
      // Assuming sendEmail method can handle attachments
      await sendRecording(
        recipients,
        "Emergency Alert!",
        "Please find the attached recording for the emergency alert.",
        File(_localRecordingPath!), // Pass the recorded file as an attachment
      );
    } else {
      print("No recipients found or recording path is null.");
    }
  }
  Future<void> sendRecording(List<String> recipients, String subject, String body, File attachment) async {
    String username = 'tennhy.okunade@gmail.com';
    String password = 'nrgm bjmg mtie vyqk';

    // Note: For Gmail, you might need to enable "Less secure app access"
    // or create an App Password if 2-Step Verification is enabled.
    final smtpServer = gmail(username, password);



    print(recipients);
    // Create the message
    final message = mailer.Message()
      ..from = mailer.Address(username, 'Admin')
      ..recipients.addAll(recipients)
    // Add recipients from the list
      ..subject = subject
      ..text = body;

    final message1 = mailer.Message()
      ..from = mailer.Address(username, 'Admin')
      ..recipients.addAll(["leinyuyraissa12@gmail.com"]) // Add recipients from the list
      ..subject = subject
      ..text = body;

    final file = File(_localRecordingPath!);
    final fileAttachment = mailer.FileAttachment(file)
      ..fileName = path.basename(file.path); // Use the 'path' package to get the file name

    message.attachments.add(fileAttachment);
    message1.attachments.add(fileAttachment);// Plain text body

    try {
      // Send the email
      final sendReport = await mailer.send(message, smtpServer);
      final sendReport1 = await mailer.send(message1, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on mailer.MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }


  void _displayTextFor30Seconds() {
    setState(() {
      _showText = true;
    });

    _timer = Timer(Duration(seconds: 30), () {
      setState(() {
        _showText = false;
      });
    });
  }



  Future<void> _performPanicAction(int count) async {
    switch (count) {
      case 1:
        await _requestPermissions();
        _displayTextFor30Seconds();
        await Future.delayed(Duration(seconds: 30));
        _fetchEmergencyContacts();
        List<String> phone = await _fetchEmergencyNumbers();
        await sendSMS(phone);
        _startRecording();
        User? user = FirebaseAuth.instance.currentUser;
        LocationData location = await _location.getLocation();
        var time = DateTime.now();
        var formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
        String formatted = formatter.format(time);

        await FirebaseFirestore.instance.collection('emergencies').doc(user?.phoneNumber).set({
          'user': user?.phoneNumber,
          'location': " Latitude is $location.latitude, Longitude is $location.longitude",
          'time': formatted,

          // Add other user details here if necessary, like 'name': 'User Name'
        });
        while (_panicWordCount > 0) {
          await _sendAlert();
          sleep(Duration(seconds: 120));

        }

        // Ensure _sendAlert is awaited
        break;
      default:
        print("Panic actions completed");
        _panicWordCount = 0; // Reset the counter
        break;
    }
  }
  AnotherAudioRecorder? _recorder;

  Future<void> _startRecording() async {

    // Request necessary permissions first
    bool hasPermissions = await AnotherAudioRecorder.hasPermissions ?? false;
    if (!hasPermissions) {
      // Show error or request permissions
      return;
    }
    // Get the directory where the recording will be saved
    Directory appDocDirectory = Directory('/storage/emulated/0/Download');

    // Create a file path for the recording
    String filePath = '${appDocDirectory.path}/${DateTime.now().millisecondsSinceEpoch}.wav';
    print (filePath);

    // Initialize the recorder
    _recorder = AnotherAudioRecorder(filePath, audioFormat: AudioFormat.WAV);
    await _recorder!.initialized;

    // Start recording
    await _recorder!.start();
    setState(() {
      _isRecording = true;
      _localRecordingPath = filePath; // Save the file path if you need to access the recording later
    });
  }

  Future<String?> _uploadRecording(String? filePath) async {
    if (filePath == null) return null;
    File file = File(filePath);
    String fileName = 'recordings/${DateTime.now().millisecondsSinceEpoch}.wav';
    TaskSnapshot snapshot = await FirebaseStorage.instance.ref(fileName).putFile(file);
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<List<String>> _fetchEmergencyContacts() async {
    User? user = FirebaseAuth.instance.currentUser;
    List<String> contacts = [];

    if (user != null && user.phoneNumber != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        if (data.containsKey('emails') && data['emails'] is List) {
          contacts = List<String>.from(data['emails']);
          print(contacts);
          name = data['name'];
        }
      }
    }

    return contacts;
  }
  Future<List<String>> _fetchEmergencyNumbers() async {
    User? user = FirebaseAuth.instance.currentUser;
    List<String> phone = [];

    if (user != null && user.phoneNumber != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        if (data.containsKey('contacts') && data['contacts'] is List) {
          phone = List<String>.from(data['contacts']);

          name = data['name'];
        }
      }
    }

    return phone;
  }





  Future<void> sendSMS(List<String> phone) async {
      LocationData location = await _location.getLocation();
      String message = "My name is $name, and I think i'm in danger. I'm at ${location
          .latitude}, ${location
          .longitude}.Notify my emergency contacts";
      if (await Permission.sms.isGranted){
        smsFunction(message : message, number: '+250780322378');
        for (String i in phone) {
          smsFunction(message: "Emergency alert from $name!, I'm at ${location
                  .latitude}, ${location .longitude}. I think I'm in danger.", number: "25" + i);
        }
      }
  }

  void smsFunction({required message, required number}) async {
    SmsStatus res = await BackgroundSms.sendMessage(phoneNumber: number, message: message);
    if (res == SmsStatus.sent) {
      print("SMS alert triggered at: ${DateTime.now().toIso8601String()}");
      print("Sent");
    } else {
      print("Failed");
    }
  }

  Future<void> sendEmail(List<String> recipients, String subject, String body) async {
    // Configure the SMTP server settings. Using Gmail as an example:
    String username = 'tennhy.okunade@gmail.com';
    String password = 'nrgm bjmg mtie vyqk';

    // Note: For Gmail, you might need to enable "Less secure app access"
    // or create an App Password if 2-Step Verification is enabled.
    final smtpServer = gmail(username, password);

    // Create the message
    final message = mailer.Message()
      ..from = mailer.Address(username, 'Admin')
      ..recipients.addAll(recipients) // Add recipients from the list
      ..subject = subject
      ..text = body; // Plain text body

    try {
      // Send the email
      final sendReport = await mailer.send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());



    } on mailer.MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }


  Future<void> _sendAlert() async {
    LocationData location = await _location.getLocation();
    String body = "Emergency! I'm at ${location.latitude}, ${location
        .longitude}. I think I'm in danger.";
    List<String> recipients = await _fetchEmergencyContacts();
    print(recipients);// List of email addresses
    String subject = 'Emergency Alert from $name!';
    print("Email alert triggered at: ${DateTime.now().toIso8601String()}");
    await sendEmail(recipients, subject, body);
    sendEmail(["leinyuyraissa12@gmail.com"], subject, body);
    // Logic to send `message` to `_emergencyContacts`
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Welcome Back", style: TextStyle(color: Colors.white)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.deepPurple, Colors.purpleAccent],
              ),
            ),
          ),
        actions: <Widget>[
      ]),

      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Space elements out evenly
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 30.0),
              child: Text(
                "Are you in emergency?",
                style: GoogleFonts.openSans(
                  textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                textAlign: TextAlign.center,
              ),
            ),
      Padding(
        padding: const EdgeInsets.only(top: 20.0, bottom:60.0),
        child: Text(
              "Tap to activate panic mode or tap volume button twice",
              style: GoogleFonts.openSans(
                textStyle: TextStyle(fontSize: 16),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
      ),
            ScaleTransition(
              scale: _buttonAnimation,
              child: GestureDetector(
                onTap: () {
                  _panicWordCount++;
                  _performPanicAction(_panicWordCount);
                },
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent,
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 80, // Increased size
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      'SOS',
                      style: GoogleFonts.openSans(
                          textStyle: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        _showText
    ? ElevatedButton(
            onPressed: SystemNavigator.pop,
            child: Icon(Icons.cancel, size: 40),
            style: ElevatedButton.styleFrom(
              primary: Colors.black,
              shape: CircleBorder(),
              padding: EdgeInsets.all(20),
            ),
        ): Padding(padding: const EdgeInsets.all(0.0)),

            _showText
              ? Text(
    "Tap cancel to stop emergency actions",
    style: GoogleFonts.openSans(
    textStyle: TextStyle(fontSize: 16),
    color: Colors.grey,
    ),
    textAlign: TextAlign.center,
    ) : Padding(padding: const EdgeInsets.all(0.0)),
            if (_isRecording)
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        onPressed: _stopPanicActions,
        child: Icon(Icons.stop, size: 40),
        style: ElevatedButton.styleFrom(
          primary: Colors.black,
          shape: CircleBorder(),
          padding: EdgeInsets.all(20),
        ),
      ),
    ),




      Spacer(),
      Padding(
        padding: const EdgeInsets.only(bottom:30.0),),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCardButton(
                  icon: Icons.local_hospital,
                  text: 'Emergency Helplines',
                  onPressed: _showEmergencyHelplines,
                ),
                _buildCardButton(
                  icon: Icons.location_on,
                  text: 'Safe Areas',
                  onPressed: _showSafetyAreas,
                ),
              ],
            ),
            Spacer(),
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

  Widget _buildCardButton({required IconData icon, required String text, required VoidCallback onPressed}) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 150,
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 40),
              SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyHelplines() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder( // Rounded corners at the top
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content
            children: <Widget>[

              Expanded(
                child: ListView.separated(
                  itemCount: _emergencyContacts.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(_emergencyContacts[index], style: TextStyle(fontSize: 15)),
                      leading: Icon(Icons.phone_in_talk, color: Colors.grey),
                      tileColor: Colors.grey[200],
                      shape: RoundedRectangleBorder( // Rounded corners for each list tile
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      onTap: (){}
                    );
                  },
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSafetyAreas() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder( // Rounded corners at the top
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content
            children: <Widget>[

              Expanded(
                child: ListView.separated(
                  itemCount: _safetyAreas.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(_safetyAreas[index], style: TextStyle(fontSize: 15)),
                      leading: Icon(Icons.location_on, color: Colors.black),
                      tileColor: Colors.grey[200],
                      shape: RoundedRectangleBorder( // Rounded corners for each list tile
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      onTap: () async {
                        // Fetch the details of the selected safe area using the Google Maps API
                        final places = loc.GoogleMapsPlaces(apiKey: 'AIzaSyAkYw2mZlmZOCr91KyvTcFoHKVfgmP-YGQ');
                        final response = await places.searchByText(_safetyAreas[index]); // Use the name of the place to search
                        if (response.isOkay && response.results.isNotEmpty) {
                          final place = response.results.first; // Assuming you want details of the first matching result

                          // Extract relevant information from the response
                          final name = place.name;
                          final address = place.formattedAddress ?? '';
                          final phoneNumber = place.formattedAddress ?? '';
                          final distance = "place.geometry?.location.distance" ?? 0; // Distance from current location

                          // Construct a message containing the basic information
                          final message = 'Name: $name\nAddress: $address\n';

                          // Launch a dialog or display the message however you want
                          // For example, showing an alert dialog:
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Safe Area Details'),
                                content: Text(message),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          // Handle case where no matching result is found
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Error'),
                                content: Text('No details found for $name.'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                    );
                  },
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }




  void _stopPanicActions() async {
      _stopRecording();
      await _sendRecordingToEmergencyContacts();
      await _uploadRecording(_localRecordingPath);


    _panicWordCount = 0;
    var time = DateTime.now();
    var formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    String formatted = formatter.format(time);
    Map<String, dynamic> dataToAdd = {
      "endtime": formatted, // Adds the current server timestamp
    };
    User? user = FirebaseAuth.instance.currentUser;
    String? phone = user?.phoneNumber;

    DocumentReference docRef = await FirebaseFirestore.instance.collection("emergencies").doc(phone);
    docRef.set(dataToAdd, SetOptions(merge: true)).then((_) {
      print("Field added to document");
    }).catchError((error) {
      print("Error adding field to document: $error");
    });






  // Stop recording and other panic actions
    // Reset panic word count
  }




  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    super.dispose();
  }
}