import 'package:driver_application/screens/document_upload.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver_application/screens/map_widget.dart';
import 'package:driver_application/services/location_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver_application/screens/ride_details_page.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  LatLng? _currentLatLng;
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  String selectedRideId = '';
  List<Map<String, dynamic>> availableRides = [];
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('rides');
  String driverName= "" ;
  String driverVehicle= "" ;
  String? _profilePhotoUrl ;
  bool isVerified = false ;
  bool isLoading = true ;

  Future<void> _getDriverInfo() async{
    final userDoc = await FirebaseFirestore.instance.collection('drivers').doc(_auth.currentUser!.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null) {
        setState(() {
          driverName = userData['name'];
          driverVehicle = userData['vehicle'];
          _profilePhotoUrl = userData['profilePhotoUrl'];
          isVerified = userData['verified'] ;
          isLoading = false ;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchAvailableRides();
    _getDriverInfo() ;
  }

  void _getCurrentLocation() async {
    try {
      Position position = await LocationService.getCurrentLocation();
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            point: _currentLatLng!,
            width: 40.0,
            height: 40.0,
            child: const Icon(Icons.my_location, color: Colors.red, size: 40.0),
          ),
        );
      });
    } catch (e) {
      print(e);
    }
  }

  void _fetchAvailableRides() {
    _dbRef.orderByChild('assigned').equalTo(false).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          availableRides = data.entries
              .map((entry) => {
                    ...Map<String, dynamic>.from(entry.value),
                    'rideId': entry.key,
                  })
              .toList();
        });
      }
    });
  }

  Future<List<LatLng>> getRoute(LatLng start, LatLng destination) async {
    const apiKey = '5b3ce3597851110001cf6248a65d228dee884d84bed03187adbb9f99';
    final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${destination.longitude},${destination.latitude}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routeCoordinates = data['features'][0]['geometry']['coordinates'];
      return routeCoordinates.map<LatLng>((point) => LatLng(point[1], point[0])).toList();
    } else {
      throw Exception('Failed to load route');
    }
  }

  void _updateMapWithRide(String selectedRideId) async {
    final selectedRide = availableRides.firstWhere((ride) => ride['rideId'] == selectedRideId);

    List<LatLng> route = await getRoute(
      LatLng(selectedRide['pickup_location']['latitude'], selectedRide['pickup_location']['longitude']),
      LatLng(selectedRide['destination_location']['latitude'], selectedRide['destination_location']['longitude']),
    );

    setState(() {
      _markers = [
        Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(selectedRide['pickup_location']['latitude'], selectedRide['pickup_location']['longitude']),
          child: const Icon(Icons.location_on, color: Colors.red),
        ),
        Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(selectedRide['destination_location']['latitude'], selectedRide['destination_location']['longitude']),
          child: const Icon(Icons.location_on, color: Colors.green),
        ),
      ];
      final centerLat = (selectedRide['pickup_location']['latitude'] + selectedRide['destination_location']['latitude']) / 2;
      final centerLng = (selectedRide['pickup_location']['longitude'] + selectedRide['destination_location']['longitude']) / 2;
      final center = LatLng(centerLat, centerLng);

      // Calculate zoom level based on distance
      final distance = const Distance().as(LengthUnit.Kilometer, LatLng(selectedRide['pickup_location']['latitude'], selectedRide['pickup_location']['longitude']), LatLng(selectedRide['destination_location']['latitude'], selectedRide['destination_location']['longitude']));
      double zoomLevel ;

      if (distance < 1) {
          zoomLevel = 15.5; // Close zoom
        } else if (distance < 5) {
          zoomLevel = 13.0; // Medium zoom
        } else {
          zoomLevel = 11.0; // Wide zoom for longer distances
        }

      // Check if the map controller has been initialized before moving
      _mapController.move(center, zoomLevel);
      _routePoints = route;
    });
  }

  void _removeRideFromList(String rideId) {
    setState(() {
      availableRides.removeWhere((ride) => ride['rideId'] == rideId);
    });
  }

  void _showRideAlreadyTakenDialog(String rideId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ride Already Taken"),
        content: const Text("This ride has already been assigned to another driver."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeRideFromList(rideId);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
    _resetMapToCurrentLocation() ;
  }

  void _takeRide(String rideId) async {
    try {
      final rideSnapshot = await _dbRef.child(rideId).get();
      final rideData = rideSnapshot.value as Map<dynamic, dynamic>;

      if (rideData['assigned'] == true) {
        // If ride is already assigned, show a dialog and remove the ride from the list
        _showRideAlreadyTakenDialog(rideId);
      } else {
        // Proceed with taking the ride if not assigned
        final userId = FirebaseAuth.instance.currentUser?.uid;

        if (userId == null) {
          print("User not logged in.");
          return;
        }

        final driverSnapshot = await _firestore.collection('drivers').doc(userId).get();
        if (!driverSnapshot.exists) {
          print("Driver details not found.");
          return;
        }

        final driverData = driverSnapshot.data();
        if (driverData != null) {
          final driverDetails = {
            'driver_name': driverData['name'],
            'vehicle_id': driverData['vehicle'],
            'driver_phone': driverData['phone'],
            'assigned': true,
            'driver_uid': userId,
          };

          await _dbRef.child(rideId).update(driverDetails);
          _fetchAvailableRides();
          _buildRideList() ; // To check if widget could be called as functions to update the contents .

          //Reference to the driver rides folder
          final driverRidesRef = FirebaseDatabase.instance.ref('driver_rides/$userId');

          // Check if the driver folder exists
          final driverRidesSnapshot = await driverRidesRef.once();
          if (!driverRidesSnapshot.snapshot.exists) {
            // Create the driver folder and initialize the current rides
            await driverRidesRef.set({
              'currentrides': 1,
              'current_ride_1': rideId,
            });
          } else {
            // Driver folder exists, increment currentrides and add the new ride
            final currentRidesData = driverRidesSnapshot.snapshot.value as Map<dynamic, dynamic>;
            final currentRidesCount = currentRidesData['currentrides'] ?? 0;

            // Increment the current rides count
            await driverRidesRef.update({
              'currentrides': currentRidesCount + 1,
            });

            // Create a new field for the new ride
            await driverRidesRef.update({
              'current_ride_${currentRidesCount + 1}': rideId,
            });
          }

          // Navigate to the ride details page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RideDetailsScreen(rideId: rideId)),
          );
        }
      }
    } catch (e) {
      print("Error taking ride: $e");
    }
  }

  Future<void> _showConfirmationDialog(String rideId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Ride"),
        content: const Text("Are you sure you want to take this ride?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _takeRide(rideId);
              Navigator.of(context).pop();
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver App"),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout),
        //     onPressed: () {
        //       _auth.signOut();
        //       Navigator.pushReplacementNamed(context, '/login');
        //     },
        //   ),
        // ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(driverName.isNotEmpty ? driverName : ''),  // Default to empty if userName is empty
              accountEmail: Text(driverVehicle),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                    ? NetworkImage(_profilePhotoUrl!) // Show profile photo if available
                    : null, // No image means display the first letter
                child: _profilePhotoUrl == null || _profilePhotoUrl!.isEmpty
                    ? Text(
                        driverName.isNotEmpty ? driverName[0] : '',  // Default to empty if userName is empty
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
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: isLoading
      ? const Center(child: CircularProgressIndicator())
      : Column(
          children: [
            if (!isVerified)
              Container(
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "You are not verified. Verify first to take rides.",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DocumentUploadScreen(userId: FirebaseAuth.instance.currentUser!.uid)));
                      },
                      child: const Text("Verify", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            // Top half for showing ride data and pickup/destination list
            // if(isVerified)
            //   Expanded(
            //     flex: 2,
            //     child: _buildRideList(), // Display list of available rides
            //   ),

            // // Bottom half for showing the map - fixed height, does not reduce
            // // SizedBox(
            // //   height: MediaQuery.of(context).size.height * 0.5,
            // //   child: _currentLatLng == null
            // //       ? const Center(child: CircularProgressIndicator())
            // //       : FlutterMapWidget(
            // //           currentLatLng: _currentLatLng!,
            // //           mapController: _mapController,
            // //           markers: _markers,
            // //           routePoints: _routePoints,
            // //         ),
            // // ),
            // Expanded(
            //     child: _currentLatLng == null
            //         ? const Center(child: CircularProgressIndicator())
            //         : FlutterMapWidget(
            //             currentLatLng: _currentLatLng!,
            //             mapController: _mapController,
            //             markers: _markers,
            //             routePoints: _routePoints,
            //           ),
            // ),

            // Use a Row with two Expanded widgets
            if (isVerified)
              Expanded(
                child: Column(
                  children: [
                    // Ride List
                    Expanded(
                      child: _buildRideList(),
                    ),
                    // Map
                    Expanded(
                      child: _currentLatLng == null
                          ? const Center(child: CircularProgressIndicator())
                          : FlutterMapWidget(
                              currentLatLng: _currentLatLng!,
                              mapController: _mapController,
                              markers: _markers,
                              routePoints: _routePoints,
                            ),
                    ),
                  ],
                ),
            ),

            if(!isVerified)
               Expanded(
                child: _currentLatLng == null
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMapWidget(
                        currentLatLng: _currentLatLng!,
                        mapController: _mapController,
                        markers: _markers,
                        routePoints: _routePoints,
                      ),
              ),

            // 'Take this Ride' button, fixed at bottom
            SizedBox(
              width: double.infinity, // Full width button
              child: ElevatedButton(
                onPressed: selectedRideId.isEmpty
                    ? null
                    : () {
                        _showConfirmationDialog(selectedRideId);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedRideId.isEmpty ? Colors.grey : Colors.green,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Take this Ride",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity, // Full width button
              child: ElevatedButton(
                onPressed: _showCurrentRidesModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Black background
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Show Current Rides",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
      ),
    );
  }

  void _showCurrentRidesModal() async {
    final userId = _auth.currentUser?.uid;
    final DatabaseReference Ref = FirebaseDatabase.instance.ref();

    if (userId == null) {
      print("User not logged in.");
      return;
    }

    List<Map<String, dynamic>> currentRides = [];

    // Fetch current rides for the driver
    final currentRidesSnapshot = await Ref.child('driver_rides/$userId').once();
    if(currentRidesSnapshot.snapshot.value != null){
      final currentRidesData = currentRidesSnapshot.snapshot.value as Map<dynamic, dynamic>;

      // Create a list of current rides
      for (int i = 1; i <= (currentRidesData['currentrides'] ?? 0); i++) {
        String? rideId = currentRidesData['current_ride_$i'];
        if(rideId!=null){
          final rideDetailsSnapshot = await Ref.child('rides/$rideId').once();
          final rideDetails = rideDetailsSnapshot.snapshot.value as Map<dynamic, dynamic>;

          currentRides.add({
            'rideId': rideId,
            'pickup': rideDetails['pickup'] ?? 'Pickup not found',
            'destination': rideDetails['destination'] ?? 'Destination not found',
            'fare': rideDetails['fare'] ?? 'N/A',
            'time': rideDetails['time'] ?? 'N/A',
          });
        }
      }
    }

    // Show the modal sheet with current rides
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Current Rides',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: currentRides.isEmpty
                    ? const Center(child: Text("No current rides."))
                    : ListView.builder(
                        itemCount: currentRides.length,
                        itemBuilder: (context, index) {
                          final ride = currentRides[index];
                          DateTime parsedTime = DateTime.parse(ride['time']);
                          final formattedTime = DateFormat("d MMM, h:mm a").format(parsedTime);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_pin, color: Colors.red),
                                      const SizedBox(width: 5),
                                      Text(
                                        ride['pickup'],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_pin, color: Colors.green),
                                      const SizedBox(width: 5),
                                      Text(
                                        ride['destination'],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Center(
                                    child: Text(
                                      "Fare: ₹${ride['fare']}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      "Time: $formattedTime",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _startRide(ride['rideId']);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white, // Text color set to white
                                          ),
                                          child: const Text("Start Ride"),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _dropRide(ride['rideId']);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white, // Text color set to white
                                          ),
                                          child: const Text("Drop Ride"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Example methods for starting and dropping a ride
  void _startRide(String rideId) {
    // Implement functionality to start the ride
    Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RideDetailsScreen(rideId: rideId)),
        );
    // You might want to update the ride status in your database here
  }

  void _dropRide(String rideId) async {
    final userId = _auth.currentUser?.uid;
    final dbRef = FirebaseDatabase.instance.ref().child('rides/$rideId');

    // Mark the ride as unassigned
    await dbRef.update({
      'assigned': false,
      'driver_name': null,
      'vehicle_id': null,
      'driver_phone': null,
      'driver_uid': null,
    });

    final driverRef = FirebaseDatabase.instance.ref().child('driver_rides/$userId');
    final driverRidesSnapshot = await driverRef.once();

    // Check if driver rides data exists
    if (driverRidesSnapshot.snapshot.exists) {
      final currentRidesData = driverRidesSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final currentRidesCount = currentRidesData['currentrides'] ?? 0;

      // Check if the user has only one ride
      if (currentRidesCount <= 1) {
        // If only one ride remains, remove the entire 'driver_rides/$userId' node
        await driverRef.remove();
      } else {
        // Otherwise, update rides count and remove the specific rideId
        await driverRef.update({'currentrides': currentRidesCount - 1});

        // Identify and remove the specific ride
        int rideIndexToRemove = -1;

        for (int i = 1; i <= currentRidesCount; i++) {
          if (currentRidesData['current_ride_$i'] == rideId) {
            rideIndexToRemove = i;
            break;
          }
        }

        if (rideIndexToRemove != -1) {
          await driverRef.child('current_ride_$rideIndexToRemove').remove();

          // Reorder `current_ride_i` entries to maintain continuity
          for (int i = rideIndexToRemove; i < currentRidesCount; i++) {
            String? nextRideId = currentRidesData['current_ride_${i + 1}'];
            if (nextRideId != null) {
              await driverRef.child('current_ride_$i').set(nextRideId);
              await driverRef.child('current_ride_${i + 1}').remove();
            }
          }
        }
      }
    } else {
      // Handle cases where no rides exist
      print("No rides found for user: $userId");
    }
  }

  String getTruncatedLocation(String location) {
    final parts = location.split(',');
    return parts.length > 2 ? '${parts[0]}, ${parts[1]}' : location;
  }

  void _resetMapToCurrentLocation() {
    // Assuming you have access to the current location coordinates
    if (_currentLatLng != null) {
      // Reset the map to the current location
      // _mapController.move(_currentLatLng!, 13.0);
      // // Clear any markers or routes if needed
      _markers.clear();
      _routePoints.clear();
      _getCurrentLocation() ;
      _mapController.move(_currentLatLng!, 13.0);
      // FlutterMapWidget(
      //   currentLatLng: _currentLatLng!,
      //   mapController: _mapController,
      //   markers: _markers,
      //   routePoints: _routePoints,
      // );
      setState(() {});
    }
  }

  Widget _buildRideList() {
    _fetchAvailableRides() ;
    if (availableRides.isEmpty) {
      return const Center(child: Text("No available rides."));
    }

    return ListView.builder(
      itemCount: availableRides.length,
      itemBuilder: (context, index) {
        final ride = availableRides[index];
        final pickupLocation = getTruncatedLocation(ride['pickup']);
        final destinationLocation = getTruncatedLocation(ride['destination']);
        final fare = ride['fare'].toString();
        
        // Parse and format the time
        DateTime parsedTime = DateTime.parse(ride['time']);
        final formattedTime = DateFormat("d MMM, h:mm a").format(parsedTime);

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          color: selectedRideId == ride['rideId'] ? Colors.grey[300] : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_pin, color: Colors.red),
                    const SizedBox(width: 5),
                    const Text(
                      'Pickup : ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      pickupLocation,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_pin, color: Colors.green),
                    const SizedBox(width: 5),
                    const Text(
                      'Destination : ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      destinationLocation,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Fare: ₹$fare",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 5),
                Center(
                  child: Text(
                    "Time: $formattedTime",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            onTap: () {
              // setState(() {
              //   selectedRideId = ride['rideId'];
              // });
              // _updateMapWithRide(selectedRideId);
              setState(() {
              // Check if the tapped ride is already selected
              if (selectedRideId == ride['rideId']) {
                // Deselect the ride and reset the map
                selectedRideId = ''; // Clear selection
                _resetMapToCurrentLocation(); // Reset the map to show current location
              } else {
                selectedRideId = ride['rideId'];
                _updateMapWithRide(selectedRideId);
              }
            });
            },
          ),
        );
      },
    );
  }
}
