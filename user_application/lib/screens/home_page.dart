import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:user_application/services/location_service.dart';
import 'package:user_application/services/booking_services.dart';
import 'package:user_application/screens/ride_page.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final MapController _mapController = MapController();

  // final List<String> _pickupHistory = [];
  // final List<String> _destinationHistory = [];
  final List<Map<String, dynamic>> _availableRides = []; // List to hold available rides

  Position? _currentPosition;
  LatLng? _currentLatLng;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  bool _isPickupSelected = false ;
  bool _isDestinationSelected = false ;
  bool _isShareable = false; // Variable to track if the ride is shareable

  String? _rideid = "" ;
  String userName = "" ;
  String userMail = "" ;
  String? _profilePhotoUrl ;

  // Create a mapping of suggestions to their coordinates
  Map<String, LatLng> defaultLocationsMap = {
      'IITJ Hostels': const LatLng(26.472943, 73.116277),
      'IITJ Main Gate': const LatLng(26.466476, 73.115312),
      'IITJ Side Gate': const LatLng(26.460374, 73.110387),
      'Jodhpur Railway Station': const LatLng(26.283834, 73.022235),
      'GhantaGhar Jodhpur': const LatLng(26.294203, 73.024255),
      'MBM College Jodhpur': const LatLng(26.269980, 73.035070),
      'Jodhpur Airport': const LatLng(26.265078,73.050570),
      'RaikaBagh Railway Station': const LatLng(26.291173,73.039120),
      'Paota Circle': const LatLng(26.294110, 73.038920),
      'Sardarpura Jodhpur': const LatLng(26.275149, 73.007635),
  };

  void _getCurrentLocation() async {
      try{
        Position position = await LocationService.getCurrentLocation() ;
        setState(() {
          _currentPosition = position;
          _currentLatLng = LatLng(position.latitude, position.longitude);
          _pickupLatLng = _currentLatLng;
          _pickupController.text = 'Current Location' ;
          _markers.add(
            Marker(
              point: _pickupLatLng!,
              width: 40.0,
              height: 40.0,
              child: const Icon(
                Icons.my_location,
                color: Colors.red,
                size: 40.0,
              ),
            )
          );
        });
      } catch(e){
        print(e) ;
      }
      _mapController.move(_currentLatLng!, 13.0);
  }

  void _onPickupSelected (String suggestion) async{
    LatLng pickupLatLng = _currentLatLng!;
    if (defaultLocationsMap.containsKey(suggestion)) {
      pickupLatLng = defaultLocationsMap[suggestion]!;
    }else{
      List<Location> locations = await locationFromAddress(suggestion);
      if (locations.isNotEmpty) {
        pickupLatLng =
            LatLng(locations.first.latitude, locations.first.longitude);
      }
    }
    setState(() {
      _pickupController.text = suggestion;
      _pickupLatLng = pickupLatLng;
      _isPickupSelected = true ;
      _clearMarkers();
      _clearMap();
      _addMarker(_pickupLatLng!, Colors.red);
      if(_isDestinationSelected){
        _addMarker(_destinationLatLng!, Colors.green);
        _drawRoute();
      }
      else{
        _moveMap(_pickupLatLng!);
      }
    });
  }

  void _onDestinationSelected(String suggestion) async{
    if(!_isPickupSelected) return ;
    LatLng destinationLatLng = _currentLatLng!;
    if (defaultLocationsMap.containsKey(suggestion)) {
      destinationLatLng = defaultLocationsMap[suggestion]!;
    }else{
      List<Location> locations = await locationFromAddress(suggestion);
      if (locations.isNotEmpty) {
        destinationLatLng =
            LatLng(locations.first.latitude, locations.first.longitude);
      }
    }
    setState(() {
      _destinationController.text = suggestion;
      _destinationLatLng = destinationLatLng;
      _clearMarkers();
      _clearMap();
      _addMarker(_pickupLatLng!, Colors.red); // Add pickup marker again
      _addMarker(_destinationLatLng!, Colors.green);
      //_moveMap(_destinationLatLng!);
      _isDestinationSelected = true ;
      _drawRoute(); // Call route drawing function
    });
  }

   void _clearMarkers() {
    setState(() {
      _markers.clear();
    });
  }

  void _addMarker(LatLng point, Color color) {
    setState(() {
      _markers.add(
        Marker(
          point: point,
          width: 40.0,
          height: 40.0,
          child: Icon(
            Icons.location_pin,
            color: color,
            size: 40.0,
          ),
        ),
      );
    });
  }

  void _moveMap(LatLng point) {
    _mapController.move(point, 13.0);
  }

  void _clearMap() {
    setState(() {
      _routePoints.clear(); // Clear the route
    });
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _drawRoute() async {
    if (_pickupLatLng != null && _destinationLatLng != null) {
      _routePoints = await LocationService.getRoute(_pickupLatLng!, _destinationLatLng!);

      // Calculate the center point
      final centerLat = (_pickupLatLng!.latitude + _destinationLatLng!.latitude) / 2;
      final centerLng = (_pickupLatLng!.longitude + _destinationLatLng!.longitude) / 2;
      final centerPoint = LatLng(centerLat, centerLng);

      // Calculate approximate zoom level based on distance
      final distance = Distance().as(LengthUnit.Kilometer, _pickupLatLng!, _destinationLatLng!);
      double zoomLevel;

      if (distance < 1) {
        zoomLevel = 15.5; // Close zoom
      } else if (distance < 5) {
        zoomLevel = 13.0; // Medium zoom
      } else {
        zoomLevel = 11.0; // Wide zoom for longer distances
      }
      // Add route polyline to the map
      setState(() {  
        // Update the map view
         _mapController.move(centerPoint, zoomLevel);
      });
    }
  }

  void _showBookingBottomSheet(BuildContext context) {
    double paymentAmount = 400.0;  // Placeholder for fare calculation
    DateTime? selectedDateTime;
    bool isNowSelected = true; // To track if "Now!" is selected

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Confirm Ride',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pickup: ${_pickupController.text}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Destination: ${_destinationController.text}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),

                  // Pickup Time Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pickup Time:'),
                      Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: isNowSelected,
                            onChanged: (value) {
                              setState(() {
                                isNowSelected = value!;
                                selectedDateTime = null; // Reset selection
                              });
                            },
                          ),
                          const Text('Now!'),
                          Radio<bool>(
                            value: false,
                            groupValue: isNowSelected,
                            onChanged: (value) {
                              setState(() {
                                isNowSelected = value!;
                              });
                            },
                          ),
                          const Text('Select Time'),
                        ],
                      ),
                    ],
                  ),
                  // Display selected date and time if not "Now!"
                  if (!isNowSelected && selectedDateTime != null)
                    Text(
                      'Selected Time: ${DateFormat('yyyy-MM-dd – kk:mm').format(selectedDateTime!)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  if (!isNowSelected)
                    ElevatedButton(
                      onPressed: () async {
                        DateTime? pickedDateTime = await showDateTimePicker(context);
                        if (pickedDateTime != null) {
                          setState(() {
                            selectedDateTime = pickedDateTime;
                          });
                        }
                      },
                      child: const Text('Choose Date & Time'),
                    ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Checkbox(
                        value: _isShareable,
                        onChanged: (bool? value) {
                          setState(() {
                            _isShareable = value ?? false;
                          });
                        },
                      ),
                      const Text('Make this ride shareable'),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Making the ride shareable will divide the amount equally between all passengers.',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Payment Amount: ₹${paymentAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      // Update the paymentAmount based on pickup and destination
                      paymentAmount = await calculateFare(
                        _pickupLatLng!,
                        _destinationLatLng!,
                        _isShareable,
                      );
                      selectedDateTime = isNowSelected ? DateTime.now() : selectedDateTime ;
                      _rideid = await BookingService.bookRide(
                        _pickupController,
                        _pickupLatLng,
                        _destinationController,
                        _destinationLatLng,
                        _auth,
                        _isShareable,
                        selectedDateTime,
                        paymentAmount,
                      );
                      print(_rideid);
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RideDetailsPage(rideid: _rideid!, currentLatLng: _currentLatLng)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Book Ride'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Function to calculate fare based on pickup and destination
  Future<double> calculateFare(LatLng pickup, LatLng destination, bool isShareable) async {
    // Implement your fare calculation logic here
    // Example: return a fixed amount or calculate based on distance
    double baseFare = 100.0; // Example base fare
    double distanceFare = 300.0; // Example fare based on distance
    double totalFare = baseFare + distanceFare;

    return totalFare; // Divide fare if shareable
  }

  // DateTime picker function
  Future<DateTime?> showDateTimePicker(BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );
      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
    return null; // Return null if no date/time is picked
  }


  void _updatePickupState() {
    setState(() {
      _isPickupSelected = _pickupController.text.isNotEmpty;
      if (!_isPickupSelected) {
        // Clear markers and routes from the map

        _clearMap();
      }
    });
  }

  void _updateDestinationState() {
    setState(() {
      _isDestinationSelected = _destinationController.text.isNotEmpty;
      if (!_isDestinationSelected) {
        // Clear markers and routes from the map
        _clearMap();
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getAvailableRides() async {
    final ref = FirebaseDatabase.instance.ref('rides');
    // Here, we are assuming you're looking for rides matching the pickup location
    final snapshot = await ref.orderByChild('pickup_lat').equalTo(_pickupLatLng?.latitude).once();

    List<Map<String, dynamic>> availableRides = [];

    // Use the 'snapshot' property to check for data existence
    if (snapshot.snapshot.children.isNotEmpty) {
      // Iterate through the children (rides) in the snapshot
      for (final child in snapshot.snapshot.children) {
        final rideData = child.value as Map<dynamic, dynamic>;

        // Cast to Map<String, dynamic> for safer access
        final rideMap = Map<String, dynamic>.from(rideData);

        // Check if the ride's destination matches the user's input
        if (rideMap['destination'] == _destinationController.text) {
          availableRides.add(rideMap);
        }
      }
    }

    return availableRides;
  }

  Widget _buildRideCard(String pickup, String drop, String rideKey, String user, int pc) {
    // Limit the displayed name to the first two words
    String limitedPickup = pickup.split(' ').take(3).join(' ');
    String limitedDrop = drop.split(' ').take(3).join(' ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Pickup location
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Text(limitedPickup, style: const TextStyle(fontSize: 16)),
              ],
            ),
            // Drop location
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 8),
                Text(limitedDrop, style: const TextStyle(fontSize: 16)),
              ],
            ),
            // Join Ride button
            ElevatedButton(
              onPressed: () {
                _joinRide(rideKey, user, pc); // Implement joining the ride
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Change button color as needed
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              ),
              child: const Text('Join Ride', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _checkAvailableRides(BuildContext context) async {
    final availableRides = await _getAvailableRides();
    
    if (availableRides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available rides for this route.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Available Rides'),
          content: SingleChildScrollView(
            child: ListBody(
              children: availableRides.map((ride) {
                return ListTile(
                  title: Text('Pickup: ${ride['pickup']}'),
                  subtitle: Text('Destination: ${ride['destination']}'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Fetch available rides from Firebase
  Future<void> _fetchAvailableRides() async {
    final ref = FirebaseDatabase.instance.ref().child('rides');
    final userId = _auth.currentUser?.uid;

    // Get all rides
    final snapshot = await ref.once();
    final ridesData = snapshot.snapshot.value as Map<dynamic, dynamic>?;

    if (ridesData != null) {
      // Clear the existing rides
      _availableRides.clear();

      ridesData.forEach((key, value) {
        // Only include rides that are shareable and not booked by the current user
        if (value['share'] == true && value['user'] != userId && value['participant_count']<3){
          if(value['participant_count']==2){
            if(value['participants']['userId1']!=userId){
               _availableRides.add({
                'key': key,
                'pickup': value['pickup'],
                'destination': value['destination'],
                'user': value['user'],
                'pc': value['participant_count'],
              });
            }
          }
          else{
            _availableRides.add({
                'key': key,
                'pickup': value['pickup'],
                'destination': value['destination'],
                'user': value['user'],
                'pc': value['participant_count'],
              });
          }
        }
      });
      setState(() {});
    }
  }

  void _showAvailableRides(context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<void>(
          future: _fetchAvailableRides(), // Fetch rides here
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              // Check if there are available rides
              if (_availableRides.isEmpty) {
                return const Center(child: Text('No available rides.'));
              }

              return ListView.builder(
                itemCount: _availableRides.length,
                itemBuilder: (context, index) {
                  final ride = _availableRides[index];
                  return Card(
                    margin: EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text('${ride['pickup'].split(' ').take(3).join(' ')} to ${ride['destination'].split(' ').take(3).join(' ')}'),
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // Join ride logic here
                          _joinRide(ride['key'], ride['user'], ride['pc']);
                          Navigator.of(context).pop(); 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RideDetailsPage(rideid : ride['key'], currentLatLng: _currentLatLng)));
                        },
                        child: const Text('Join Ride'),
                      ),
                    ),
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  // Update ride information with the current user
  Future<void> _joinRide(String rideKey, String user, int pc) async {
    final userId = _auth.currentUser?.uid;
    final DatabaseReference userRideRef = FirebaseDatabase.instance.ref().child('user_ride/$userId');
    _rideid = rideKey ;


    final ref = FirebaseDatabase.instance.ref('rides/$rideKey');
    if(pc==1){
      await ref.child('participants').set({
        'user': user,
        'userId1': userId,
        // Add other participant info as needed
      });
    }
    else if(pc==2){
      await ref.child('participants').update({
        'userId2': userId,
        // Add other participant info as needed
      });
    }
    await ref.update({
      'participant_count' : pc+1,
    });
    try {
      await userRideRef.set({
        'currentRideId': ref.key!,
        'paid': false ,
      });
      print('Ride booked successfully for user: ${userId}');
    } catch (e) {
      print('Error booking ride: $e');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have joined the ride!')),
    );
  }

  // Future<void> getRideData() async {
  //   final userrideRef = FirebaseDatabase.instance
  //       .ref()
  //       .child('user_ride')
  //       .child(_auth.currentUser!.uid);

  //   // Get the DatabaseEvent and access the snapshot
  //   DatabaseEvent event = await userrideRef.once();
  //   DataSnapshot snapshot = event.snapshot;

  //   if (snapshot.value != null) {
  //     // Cast snapshot.value to Map<dynamic, dynamic> and then to Map<String, dynamic>
  //     Map<String, dynamic> rideData = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
  //     _rideid = rideData['currentRideId'];
  //     print(_rideid) ;
  //   } else {
  //     print('No ride data found for the current user.');
  //   }
  // }

  Future<void> getRideData(BuildContext context) async {
    final userRideRef = FirebaseDatabase.instance
        .ref()
        .child('user_ride')
        .child(_auth.currentUser!.uid);

    // Get the DatabaseEvent and access the snapshot
    DatabaseEvent event = await userRideRef.once();
    DataSnapshot snapshot = event.snapshot;

    if (snapshot.value != null) {
      // Cast snapshot.value to Map<String, dynamic>
      Map<String, dynamic> rideData = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      _rideid = rideData['currentRideId'];
      print(_rideid);

      // Fetch the ride details from the 'rides' node
      final rideRef = FirebaseDatabase.instance.ref().child('rides').child(_rideid!);
      DatabaseEvent rideEvent = await rideRef.once();
      DataSnapshot rideSnapshot = rideEvent.snapshot;

      if (rideSnapshot.value != null) {
        Map<String, dynamic> rideDetails = Map<String, dynamic>.from(rideSnapshot.value as Map<dynamic, dynamic>);
        bool isAssigned = rideDetails['assigned'] as bool;
        String rideTimeStr = rideDetails['time'] as String;
        String pickupLocation = rideDetails['pickup'] as String;
        String destinationLocation = rideDetails['destination'] as String;

        // Parse the ride time
        final rideTime = DateTime.parse(rideTimeStr);
        final currentTime = DateTime.now();

        // Check if the ride is unassigned and 5 minutes past the ride time
        if (!isAssigned && currentTime.isAfter(rideTime.add(Duration(minutes: 5)))) {
          // Delete the ride from both 'rides' and 'user_ride'
          await rideRef.remove();
          await userRideRef.remove();

          // Show a dialog with the message and ride information
          showDialog(
            context: context,
            barrierDismissible: false, // Prevents closing the dialog by tapping outside
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Unable to Find Driver"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("We are unable to find a driver at the moment. Please try again later."),
                    SizedBox(height: 16),
                    Text("Ride Information:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("Pickup: $pickupLocation"),
                    Text("Destination: $destinationLocation"),
                    Text("Scheduled Time: ${rideTime.toLocal()}"),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text("OK"),
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst); // Navigate back to home
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    } else {
      print('No ride data found for the current user.');
    }
  }

  Future<void> _getUserInfo() async{
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null) {
        setState(() {
          userName = userData['name'];
          userMail = userData['email'];
          _profilePhotoUrl = userData['profilePhotoUrl'] ;
        });
      }
    }
  }

  void _handleBookedRide(BuildContext context) async {
    if (_rideid != "") {
      // User has a booked ride, navigate to RideDetailsPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideDetailsPage(
            rideid: _rideid!,
            currentLatLng: _currentLatLng,
          ),
        ),
      );
    } else {
      // No booked ride found, show alert dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Booked Ride'),
          content: const Text('You don’t have any booked rides. Please book a ride first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showBookedDialog(context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ride Already Booked"),
          content: const Text("You already have a booked ride."),
          actionsAlignment: MainAxisAlignment.center, // Center-aligns the actions
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    BookingService.cancelRide(_rideid!, _auth);
                    _rideid = '';
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel Booked Ride"),
                ),
                const SizedBox(height: 8), // Space between buttons
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RideDetailsPage(
                          rideid: _rideid!,
                          currentLatLng: _currentLatLng,
                        ),
                      ),
                    );
                  },
                  child: const Text("Go to Ride Details"),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pickupController.addListener(_updatePickupState);
    _destinationController.addListener(_updateDestinationState);
    _getCurrentLocation();
    _getUserInfo();
    getRideData(context) ;
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Mate'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(userName.isNotEmpty ? userName : ''),  // Default to 'Guest' if userName is empty
              accountEmail: Text(userMail),
              // currentAccountPicture: CircleAvatar(
              //   backgroundColor: Colors.white,
              //   child: Text(
              //     userName.isNotEmpty ? userName[0] : '',  // Default to 'G' if userName is empty
              //     style: const TextStyle(fontSize: 40.0),
              //   ),
              // ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                    ? NetworkImage(_profilePhotoUrl!) // Show profile photo if available
                    : null, // No image means display the first letter
                child: _profilePhotoUrl == null || _profilePhotoUrl!.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0] : '',  // Default to empty if userName is empty
                        style: const TextStyle(fontSize: 40.0),
                      )
                    : null, // No text if image is shown
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Info'),
              onTap: () {
                Navigator.pushNamed(context, '/info');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
            ListTile (
              leading: const Icon(Icons.directions_car_filled),
              title: const Text('Booked Ride'),
              onTap: () async {
                  await getRideData(context) ;
                  _handleBookedRide(context);
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => RideDetailsPage(rideid : _rideid, currentLatLng: _currentLatLng)));
              }
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          // Pickup and Destination Search Bars
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Pickup Location Search Bar
                TypeAheadField<String>(
                  suggestionsCallback: (pattern) async {
                    // Get suggestions based on the pattern and current location
                    List<String> suggestions = await LocationService.getSuggestions(pattern, _currentPosition!);
                    //Add current location option
                    if (_currentLatLng != null) {
                      if(suggestions.isNotEmpty) {
                        suggestions.insert(0,"Use Current Location");
                      }else{
                        suggestions.add('Use Current Location');
                      }
                    }
                    return suggestions;
                  },
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: _pickupController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Select Pickup Location',
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: _pickupController.text.isNotEmpty ? Colors.red : Colors.grey,  // Red icon if pickup selected
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],  // Light background for modern look
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),  // Rounded corners
                          borderSide: BorderSide.none,  // No border
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                       _pickupController.text = suggestion;
                      _onPickupSelected(suggestion);
                    });
                    // setState(() {});  // Trigger UI update
                  },
                ),
                
                const SizedBox(height: 10),  // Spacing between search bars

                // Destination Location Search Bar
                TypeAheadField<String>(
                  suggestionsCallback: (pattern) async {
                    return await LocationService.getSuggestions(pattern, _currentPosition!);
                  },
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: _destinationController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Select Drop Location',
                        prefixIcon: Icon(
                          Icons.location_on,
                          color: _destinationController.text.isNotEmpty ? Colors.green : Colors.grey,  // Green icon if destination selected
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],  // Light background
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),  // Rounded corners
                          borderSide: BorderSide.none,  // No border
                        ),
                      ),
                      enabled: _isPickupSelected,  // Only enabled when pickup is selected
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      _destinationController.text = suggestion;
                      _onDestinationSelected(suggestion);
                    });  // Trigger UI update
                  },
                ),
              ],
            ),
          ),
          // Expanded map area
          Expanded(
            child: _currentLatLng == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLatLng!,
                      initialZoom: 13.0,
                      // maxZoom: 15.0,
                      // minZoom: 5.0,
                      cameraConstraint: CameraConstraint.contain(
                        bounds:(LatLngBounds(
                          const LatLng(6.0, 68.0), // South-West of India
                          const LatLng(37.0, 97.0), // North-East of India
                          )
                        )
                      ),
                      initialRotation: 0.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: _markers,
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _routePoints, strokeWidth: 4.0, color: Colors.blue),
                          ],
                        ),
                    ],
                  ),
          ),
          // Book Ride Button
          Container(
            width: double.infinity,  // Takes the full width
            height: 60,  // Button height
            child: ElevatedButton(
              onPressed: () async{
                if (_isPickupSelected && _isDestinationSelected) {
                  //_showConfirmationDialog(context);
                  await getRideData(context);
                  if (_rideid != "") {
                    // User has a booked ride, navigate to RideDetailsPage
                    _showBookedDialog(context) ;
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => RideDetailsPage(
                    //       rideid: _rideid!,
                    //       currentLatLng: _currentLatLng,
                    //     ),
                    //   ),
                    // );
                  } else{
                    _showBookingBottomSheet(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select both pickup and destination locations.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: (_isPickupSelected && _isDestinationSelected)
                    ? Colors.blue
                    : Colors.grey,  // Changes color based on selection
                foregroundColor: Colors.white,  // White text color
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,  // No rounded corners
                ),
              ),
              child: const Text(
                'Book Ride',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          Container(
            width: double.infinity, // Takes the full width
            height: 60, // Button height
            child: ElevatedButton(
              onPressed: () {
                // Add your logic to check available rides here
                _showAvailableRides(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Black background for this button
                foregroundColor: Colors.white, // White text color
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, // No rounded corners
                ),
              ),
              child: const Text(
                'Check Available Rides',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
