import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profilescreen.dart'; // Ensure you have this screen defined in your project

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String name;
  final String verificationId;

  OTPScreen({Key? key, required this.phoneNumber, required this.verificationId, required this.name}) : super(key: key);

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();

  void _verifyOTP(String otpCode, BuildContext context) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId, // Accessing verificationId passed to OTPScreen
      smsCode: otpCode,
    );

    try {
      final UserCredential authResult = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = authResult.user;


      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(widget.phoneNumber).set({
          'name': widget.name,
          // Add other user details here if necessary, like 'name': 'User Name'
        });


        // OTP verification succeeded, navigate to ProfileScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
      } else {
        // User is null, handle error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to sign in.")));
      }
    } catch (e) {
      // An error occurred, handle error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error during OTP verification: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("OTP Verification"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter the OTP sent to ${widget.phoneNumber}",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _verifyOTP(_otpController.text, context),
              child: Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
