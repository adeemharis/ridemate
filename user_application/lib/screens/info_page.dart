import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  _InfoPageState createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final TextEditingController _feedbackController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to open announcements pop-up
  void _showAnnouncements() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Announcements'),
        content: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('app_info').doc('announcements').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasData && snapshot.data!.exists) {
              return Text(snapshot.data!['content'] ?? 'No announcements at this time.');
            }
            return const Text('No announcements available.');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Method to submit feedback
  Future<void> _submitFeedback() async {
    if (_feedbackController.text.isNotEmpty) {
      await _firestore.collection('feedback').add({
        'feedback': _feedbackController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _feedbackController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.announcement),
            onPressed: _showAnnouncements,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RideMate App allows you to book a ride and share it with your college mates to and from Jodhpur City. This app is currently in the testing phase. We welcome your feedback!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Feedback',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: 'Write your feedback here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitFeedback,
              child: const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}