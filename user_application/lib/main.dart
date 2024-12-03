import 'package:firebase_core/firebase_core.dart';
import 'package:user_application/screens/login_page.dart';
import 'package:user_application/screens/home_page.dart';
import 'package:user_application/screens/signup_page.dart';
import 'package:user_application/screens/profile_page.dart';
import 'package:user_application/screens/info_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        '/info': (context) => const InfoPage(),
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
        // '/ride': (context) => const RideDetailsPage(rideid: _rideid, currentLatLng: _currentLatLng),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has data, the user is signed in
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen(); // Direct user to the Home Screen
        }
        // Otherwise, redirect to the login screen
        return const LoginPage();
      },
    );
  }
}