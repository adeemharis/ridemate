// import 'package:driver_application/screens/home_page.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'dart:io';
// import 'package:image_picker/image_picker.dart';

// // Document Upload Screen
// class DocumentUploadScreen extends StatefulWidget {
//   final String userId;

//   DocumentUploadScreen({required this.userId});

//   @override
//   _DocumentUploadScreenState createState() => _DocumentUploadScreenState();
// }

// class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
//   bool aadhaarFrontUploaded = false;
//   bool aadhaarBackUploaded = false;
//   bool licenseUploaded = false;

//   Future<bool> _showImagePreviewAndConfirm(BuildContext context, File file, String documentType) async {
//     return await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text("Confirm $documentType upload"),
//         content: Image.file(file),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: Text("Retake"),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: Text("Confirm"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _uploadDocument(BuildContext context, String imageUrlKey, String documentType) async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);

//     if (pickedFile != null) {
//       File file = File(pickedFile.path);
//       bool confirmed = await _showImagePreviewAndConfirm(context, file, documentType);
//       if (confirmed) {
//         final ref = FirebaseStorage.instance.ref().child("driver_pictures/${widget.userId}/$documentType.jpg");
//         await ref.putFile(file);
//         String downloadURL = await ref.getDownloadURL();

//         await FirebaseFirestore.instance.collection('drivers').doc(widget.userId).update({imageUrlKey: downloadURL});
//         setState(() {
//           if (documentType == 'aadhaar_front') {
//             aadhaarFrontUploaded = true;
//           } else if (documentType == 'aadhaar_back') {
//             aadhaarBackUploaded = true;
//           } else if (documentType == 'driver_license') {
//             licenseUploaded = true;
//           }
//         });

//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$documentType uploaded successfully')));

//         // Check if all documents are uploaded
//         if (aadhaarFrontUploaded && aadhaarBackUploaded && licenseUploaded) {
//           await FirebaseFirestore.instance.collection('drivers').doc(widget.userId).update({'verified': true});
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All documents uploaded. Verification complete!')));
//         }
//       }
//     } else {
//       print('No image selected for $documentType');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Upload Documents"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             ElevatedButton(
//               onPressed: () => _uploadDocument(context, 'aadhaarFrontUrl', 'aadhaar_front'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: aadhaarFrontUploaded ? Colors.green : Colors.red,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text("Upload Aadhaar Front"),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => _uploadDocument(context, 'aadhaarBackUrl', 'aadhaar_back'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: aadhaarBackUploaded ? Colors.green : Colors.red,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text("Upload Aadhaar Back"),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => _uploadDocument(context, 'licenseUrl', 'driver_license'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: licenseUploaded ? Colors.green : Colors.red,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text("Upload Driver License"),
//             ),
//             const Spacer(),
//             ElevatedButton(
//               onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen())),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 20),
//                 textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               child: const Text("Finish and Go to Home"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:driver_application/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Document Upload Screen
class DocumentUploadScreen extends StatefulWidget {
  final String userId;

  DocumentUploadScreen({required this.userId});

  @override
  _DocumentUploadScreenState createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  bool aadhaarFrontUploaded = false;
  bool aadhaarBackUploaded = false;
  bool licenseUploaded = false;

  @override
  void initState() {
    super.initState();
    _fetchDocumentStatus();
  }

  Future<void> _fetchDocumentStatus() async {
    DocumentSnapshot driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(widget.userId).get();
    setState(() {
      aadhaarFrontUploaded = driverDoc['aadhaarFrontUrl'] != null;
      aadhaarBackUploaded = driverDoc['aadhaarBackUrl'] != null;
      licenseUploaded = driverDoc['licenseUrl'] != null;
    });
  }

  Future<bool> _showImagePreviewAndConfirm(BuildContext context, File file, String documentType) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm $documentType upload"),
        content: Image.file(file),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Retake"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument(BuildContext context, String imageUrlKey, String documentType) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      bool confirmed = await _showImagePreviewAndConfirm(context, file, documentType);
      if (confirmed) {
        final ref = FirebaseStorage.instance.ref().child("driver_pictures/${widget.userId}/$documentType.jpg");
        await ref.putFile(file);
        String downloadURL = await ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('drivers').doc(widget.userId).update({imageUrlKey: downloadURL});
        setState(() {
          if (documentType == 'aadhaar_front') {
            aadhaarFrontUploaded = true;
          } else if (documentType == 'aadhaar_back') {
            aadhaarBackUploaded = true;
          } else if (documentType == 'driver_license') {
            licenseUploaded = true;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$documentType uploaded successfully')));

        // Check if all documents are uploaded
        if (aadhaarFrontUploaded && aadhaarBackUploaded && licenseUploaded) {
          await FirebaseFirestore.instance.collection('drivers').doc(widget.userId).update({'verified': true});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All documents uploaded. Verification complete!')));
        }
      }
    } else {
      print('No image selected for $documentType');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Documents"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: aadhaarFrontUploaded ? null : () => _uploadDocument(context, 'aadhaarFrontUrl', 'aadhaar_front'),
              style: ElevatedButton.styleFrom(
                backgroundColor: aadhaarFrontUploaded ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Upload Aadhaar Front"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: aadhaarBackUploaded ? null : () => _uploadDocument(context, 'aadhaarBackUrl', 'aadhaar_back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: aadhaarBackUploaded ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Upload Aadhaar Back"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: licenseUploaded ? null : () => _uploadDocument(context, 'licenseUrl', 'driver_license'),
              style: ElevatedButton.styleFrom(
                backgroundColor: licenseUploaded ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Upload Driver License"),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text("Finish and Go to Home"),
            ),
          ],
        ),
      ),
    );
  }
}
