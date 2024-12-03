import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  String? _name, _phone, _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    setState(() {
      _name = userDoc['name'];
      _phone = userDoc['phone'];
      _profilePhotoUrl = userDoc['profilePhotoUrl'];
    });
  }

  Future<void> _updateUserProfile() async {
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'name': _name,
      'phone': _phone,
      'profilePhotoUrl': _profilePhotoUrl,
    });
  }


  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      final File file = File(image.path);
      final String filePath = 'user_pictures/${_auth.currentUser!.uid}/${_auth.currentUser!.uid}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(filePath);
      final uploadTask = storageRef.putFile(file);

      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() => _profilePhotoUrl = downloadUrl);
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'profilePhotoUrl': downloadUrl,
      });
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  void _showEditDialog() {
    final TextEditingController nameController = TextEditingController(text: _name);
    final TextEditingController phoneController = TextEditingController(text: _phone);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                  ? Column(
                      children: [
                        const Text("Current Profile Picture"),
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(_profilePhotoUrl!),
                        ),
                        TextButton(
                          onPressed: _pickAndUploadImage,
                          child: const Text("Change Profile Picture"),
                        ),
                      ],
                    )
                  : TextButton(
                      onPressed: _pickAndUploadImage,
                      child: const Text("Upload Profile Picture"),
                    ),
              SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Enter Name"),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(hintText: "Enter Phone Number"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _name = nameController.text;
                  _phone = phoneController.text;
                });
                _updateUserProfile();
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProfile() async {
    final userId = _auth.currentUser!.uid;
    final storageRef = FirebaseStorage.instance.ref().child('user_pictures/$userId');

    try {
      // Delete all files in the driver's folder in Firebase Storage
      await storageRef.listAll().then((result) async {
        for (final fileRef in result.items) {
          await fileRef.delete();
        }
      });

      // Delete the Firestore document for the driver
      await _firestore.collection('users').doc(userId).delete();

      // Log the user out
      await _auth.signOut();

      await _auth.currentUser!.delete();

      // Navigate back to login screen or home screen
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print("Error deleting profile: $e");
    }
  }

  void _confirmDeleteProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Profile"),
          content: Text("Are you sure you want to delete your profile? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProfile();
              },
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                        ? NetworkImage(_profilePhotoUrl!)
                        : null,
                    child: _profilePhotoUrl == null || _profilePhotoUrl!.isEmpty
                        ? IconButton(
                            icon: Icon(Icons.camera_alt),
                            onPressed: _pickAndUploadImage,
                          )
                        : Container(),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 10),
                      // Text('Vehicle No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      // SizedBox(height: 10),
                      Text('Phone No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(":     ${_name ?? 'N/A'}", style: TextStyle(fontSize: 18)),
                      SizedBox(height: 10),
                      Text(":     ${_phone ?? 'N/A'}", style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _showEditDialog,
                child: Text('Edit Profile'),
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: _confirmDeleteProfile,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete Profile', style: TextStyle(color: Colors.white),),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _pickAndUploadImage() async {
  //   try {
  //     // Pick an image from the gallery
  //     final ImagePicker picker = ImagePicker();
  //     final XFile? image = await picker.pickImage(source: ImageSource.gallery);

  //     if (image == null) return; // User canceled image selection

  //     // Upload image to Firebase Storage
  //     final File file = File(image.path);
  //     final String filePath = 'profile_pictures/${_auth.currentUser!.uid}.jpg';
  //     final storageRef = FirebaseStorage.instance.ref().child(filePath);
  //     final uploadTask = storageRef.putFile(file);

  //     // Wait for upload to complete
  //     final TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

  //     // Get the download URL
  //     final String downloadUrl = await snapshot.ref.getDownloadURL();

  //     // Update the user's profile photo URL in Firestore
  //     setState(() => _profilePhotoUrl = downloadUrl);  // Update the local state
  //     await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
  //       'profilePhotoUrl': downloadUrl,
  //     });
  //   } catch (e) {
  //     print("Error uploading image: $e");
  //   }
  // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Profile')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             CircleAvatar(
//               radius: 50,
//               backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
//               child: IconButton(
//                 icon: Icon(Icons.camera_alt),
//                 onPressed: _pickAndUploadImage,
//               ),
//             ),
//             SizedBox(height: 20),
//             _buildEditableField('Name', _name, _isEditingName, (value) => setState(() => _name = value)),
//             _buildEditableField('Phone', _phone, _isEditingPhone, (value) => setState(() => _phone = value)),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _updateUserProfile,
//               child: Text('Save Changes'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildEditableField(String label, String? value, bool isEditing, ValueChanged<String> onChanged) {
//     return Row(
//       children: [
//         Text(label),
//         Expanded(
//           child: isEditing
//               ? TextField(
//                   onChanged: onChanged,
//                   decoration: InputDecoration(hintText: label),
//                 )
//               : Text(value ?? ''),
//         ),
//         IconButton(
//           icon: Icon(isEditing ? Icons.check : Icons.edit),
//           onPressed: () => setState(() => isEditing = !isEditing),
//         ),
//       ],
//     );
//   }
}
