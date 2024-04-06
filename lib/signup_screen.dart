import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'otp_screen.dart'; // Ensure this import path is correct

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_screen.dart'; // Ensure this import path is correct

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); // Name controller


  @override
  void initState() {
    super.initState();
    startServiceInPlatform();
  }

  void startServiceInPlatform() async {
    if(Platform.isAndroid){
      var methodChannel = MethodChannel("com.example.guardian");
      String data = await methodChannel.invokeMethod("startService");
      debugPrint(data);
    }
  }

  void _verifyPhoneNumber() async {
    final String phoneNumber = _phoneController.text.trim();
    final String name = _nameController.text.trim(); // Get the name input

    if (phoneNumber.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Name and phone number cannot be empty")));
      return;
    }

    // Trigger phone number verification
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification
        await _auth.signInWithCredential(credential).then((
            userCredential) async {
          if (userCredential.user != null) {
            print(
                "Phone number automatically verified and user signed in: ${userCredential
                    .user?.phoneNumber}");

            // Upload the name and phone number to Firestore
            await FirebaseFirestore.instance.collection('users').doc(
                userCredential.user!.phoneNumber).set({
              'name': name,
              'phone': phoneNumber,
            });
          }
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification failed: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        // Navigate to OTP screen immediately after the code is sent
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OTPScreen(
                  name: name,
                  phoneNumber: phoneNumber,
                  verificationId: verificationId,
                ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto-retrieval time out
        print("Verification code auto retrieval timeout");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Replace with your image file
                  Image.asset(
                    'assets/images/wings.jpg',
                    width: 300,
                    height: 300,
                  ),
                  Text(
                    'GUARDIAN',
                    style: GoogleFonts.josefinSans(
                      textStyle: TextStyle(color: Colors.deepPurple, fontSize: 32, fontWeight: FontWeight.bold),
                    ),),
                  SizedBox(height:40),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter Full Name',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                    ),
                    keyboardType: TextInputType.name,
                    style: TextStyle(fontSize: 15, color:Colors.black),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: 'Enter Phone Number',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.phone, color: Colors.deepPurple),
                    ),
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: 15, color:Colors.black,
                  ),),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _verifyPhoneNumber,
                    child: Text('Get OTP'),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.white, // Button background color
                      onPrimary: Colors.black, // Button text color
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        side: BorderSide(color: Colors.deepPurple)

                      ),
                      textStyle: TextStyle(
                        fontSize: 18,

                        color: Colors.black
                      ),
                    ),
                  ),
                  SizedBox(height: 30),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}