import 'package:firebase_core/firebase_core.dart';
import 'package:driver_application/screens/login_page.dart';
import 'package:driver_application/screens/home_page.dart';
import 'package:driver_application/screens/signup_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:driver_application/screens/profile_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthCheck(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has data, the user is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return HomeScreen(); // Direct user to the Home Screen
        }
        // Otherwise, redirect to the login screen
        return LoginPage();
      },
    );
  }
}