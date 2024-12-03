import 'package:firebase_auth/firebase_auth.dart';
import 'package:driver_application/reusable_widgets/reusable_widget.dart';
import 'package:driver_application/screens/home_page.dart';
import 'package:driver_application/screens/signup_page.dart';
import 'package:driver_application/screens/reset_password_page.dart';
// import 'package:driver_application/utils/color_utils.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _passwordTextController = TextEditingController();
  final TextEditingController _phoneTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(colors: [
        //     hexStringToColor("CB2B93"),
        //     hexStringToColor("9546C4"),
        //     hexStringToColor("5E61F4")
        //   ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        // ),
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).size.height * 0.2, 20, 0),
            child: Column(
              children: <Widget>[
                // logoWidget("assets/images/ridemate_logo.jpeg"),
                Image.asset(
                  'assets/images/ridemate_c_logo.jpg',
                  fit: BoxFit.fill, // or BoxFit.cover, BoxFit.fill depending on the requirement
                ),
                const SizedBox(height: 30),
                reusableTextField(
                    "Enter Phone No.", Icons.phone, false, _phoneTextController),
                const SizedBox(height: 10),
                reusableTextField(
                    "Enter Password", Icons.lock_outline, true, _passwordTextController),
                const SizedBox(height: 5),
                forgetPassword(context),
                firebaseUIButton(context, "Sign In", () {
                  _signInUser();
                }),
                signUpOption()
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInUser() async {
    final phone = _phoneTextController.text.trim();
    final password = _passwordTextController.text.trim();
    final email = '$phone@example.com'; // Simulate email for Firebase Auth

    try {
      // Attempt to sign in with the phone number
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // If successful, navigate to the home screen or perform necessary actions
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
    } on FirebaseAuthException catch (e) {
      print("error id, $e") ;
      if (e.code == 'invalid-credential') {
        // Show a user-friendly message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Credentials ! If not Registered , Sign Up!"),
            backgroundColor: Colors.red,
          ),
        );
      }
      else {
        // Handle other potential errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An unexpected error occurred: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Row signUpOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            );
          },
          child: const Text(
            " Sign Up",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }

  Widget forgetPassword(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 35,
      alignment: Alignment.bottomRight,
      child: TextButton(
        child: const Text(
          "Forgot Password?",
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.right,
        ),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (context) => ResetPasswordPage())),
      ),
    );
  }
}