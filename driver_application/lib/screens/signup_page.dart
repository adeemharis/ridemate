import 'package:firebase_auth/firebase_auth.dart';
import 'package:driver_application/reusable_widgets/reusable_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver_application/screens/document_upload.dart' ;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _vehicleTextController = TextEditingController();
  final TextEditingController _phoneTextController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();
  final TextEditingController _nameTextController = TextEditingController();

  Future<void> saveUserData(String name, String vehicle, String password, String phone, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(userId)
          .set({
            'name': name,
            'vehicle': vehicle,
            'password': password,
            'phone': phone,
            'verified': false, // Add verified attribute as false
          });
    } catch (e) {
      print("Error saving user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Sign Up",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          child: SingleChildScrollView(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 0),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 20),
                reusableTextField("Enter Name", Icons.person_outline, false, _nameTextController),
                const SizedBox(height: 20),
                reusableTextField("Enter Vehicle No.", Icons.directions_car_filled, false, _vehicleTextController),
                const SizedBox(height: 20),
                reusableTextField("Enter Phone No.", Icons.phone, false, _phoneTextController),
                const SizedBox(height: 20),
                reusableTextField("Enter Password", Icons.lock_outline, true, _passwordTextController),
                const SizedBox(height: 20),
                firebaseUIButton(context, "Continue", () {
                  FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                          email: '${_phoneTextController.text.trim()}@example.com',
                          password: _passwordTextController.text)
                      .then((value) {
                    print("Created New Account");
                    String userId = value.user!.uid;
                    saveUserData(_nameTextController.text, _vehicleTextController.text, _passwordTextController.text, _phoneTextController.text, userId);

                    // Navigate to document upload screen after saving user data
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => DocumentUploadScreen(userId: userId)));
                  }).onError((error, stackTrace) {
                    print("Error ${error.toString()}");
                  });
                })
              ],
            ),
          ))),
    );
  }
}
