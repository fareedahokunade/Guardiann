import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'signup_screen.dart'; // Your SignupScreen widget
import 'profilescreen.dart';
import 'dart:io';
// Your HomePage widget

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter bindings are initialized
  await Firebase.initializeApp();
  startServiceInPlatform();// Initialize Firebase
  runApp(MyApp());
}

void startServiceInPlatform() async {
  if(Platform.isAndroid){
    var methodChannel = MethodChannel("com.example.guardian");
    String data = await methodChannel.invokeMethod("startService");
    debugPrint(data);
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  final FirebaseAuth _auth = FirebaseAuth.instance;




  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Angel',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            User? user = snapshot.data;
            if (user == null) {
              return SignupScreen(); // Show signup screen if not logged in
            }
            return ProfileScreen(); // Direct to HomePage if logged in
          } else {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(), // Show loading indicator while checking auth state
              ),
            );
          }
        },
      ),
    );
  }
}
