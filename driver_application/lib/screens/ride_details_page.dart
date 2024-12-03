import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver_application/screens/map_widget.dart';
import 'package:driver_application/services/location_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

import 'home_page.dart';

class RideDetailsScreen extends StatefulWidget {
  final String rideId;

  const RideDetailsScreen({super.key, required this.rideId});

  @override
  _RideDetailsScreenState createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late Future<List<LatLng>> _routePointsFuture;
  final MapController _mapController = MapController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _rideStarted = false ;

  List<Map<String, dynamic>> _participants = [];
  bool _isLoadingParticipants = true; // Loading state for participants

  @override
  void initState() {
    super.initState();
    _routePointsFuture = _fetchRoutePoints();
    _fetchParticipantData();
  }

  Future<void> _startRide() async{
    setState(() {
      _rideStarted = true ;
    });
  }

  Future<List<LatLng>> _fetchRoutePoints() async {
    final rideDataSnapshot = await FirebaseDatabase.instance
        .ref()
        .child('rides/${widget.rideId}')
        .once();
    final rideData = rideDataSnapshot.snapshot.value as Map<dynamic, dynamic>;

    final pickupLocation = LatLng(
      rideData['pickup_location']['latitude'],
      rideData['pickup_location']['longitude'],
    );
    final destinationLocation = LatLng(
      rideData['destination_location']['latitude'],
      rideData['destination_location']['longitude'],
    );

    return await LocationService.getRoute(pickupLocation, destinationLocation);
  }

  Future<void> _fetchParticipantData() async {
    final dbRef = FirebaseDatabase.instance.ref().child('rides/${widget.rideId}');
    final rideDataSnapshot = await dbRef.once();
    final rideData = rideDataSnapshot.snapshot.value as Map<dynamic, dynamic>;

    final dynamic participantsData = rideData['participants'];
    
    if (participantsData == null) {
      setState(() {
        _participants = [];
        _isLoadingParticipants = false;
      });
      return;
    }

    List<Map<String, dynamic>> participantDetails = [];

    if (participantsData is Map<dynamic, dynamic>) {
      participantsData.forEach((key, value) {
        final userId = value.toString();
        _addParticipantListener(userId, participantDetails);
      });
    } else if (participantsData is List<dynamic>) {
      for (var participant in participantsData) {
        final userId = participant['userId'].toString();
        _addParticipantListener(userId, participantDetails);
      }
    }
  }

  void _addParticipantListener(String userId, List<Map<String, dynamic>> participantDetails) {
    final userRideRef = FirebaseDatabase.instance.ref().child('user_ride/$userId/paid');

    userRideRef.onValue.listen((DatabaseEvent event) async {
      final isPaid = event.snapshot.value == true;
      print("User $userId paid status: $isPaid"); // Debugging

      if (isPaid) {
        await _fetchParticipantDetails(userId, participantDetails);

        // After fetching, filter the paid participants
        setState(() {
          _participants = participantDetails
              .where((participant) => participant['paid'] == true)
              .toList();
          _isLoadingParticipants = _participants.isEmpty;
        });
      }
    });
  }

  Future<void> _fetchParticipantDetails(String userId, List<Map<String, dynamic>> participantDetails) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      final existingIndex = participantDetails.indexWhere((participant) => participant['userId'] == userId);

      // Update or add participant data
      final participantData = {
        'userId': userId,
        'name': userData!['name'],
        'phone': userData['phone'],
        'profileImage': userData['profilePhotoUrl'] ?? '',
        'paid': true, // Assume paid since we're only fetching details when paid
      };

      if (existingIndex >= 0) {
        participantDetails[existingIndex] = participantData;
      } else {
        participantDetails.add(participantData);
      }
    }
  }

    String formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return "N/A";
    }
    try {
      DateTime dateTime = DateTime.parse(isoString);
      String day = DateFormat('d').format(dateTime);
      String suffix = getDaySuffix(int.parse(day));
      String formattedDate =
          DateFormat("d'$suffix' MMM - h:mm a").format(dateTime);
      return formattedDate;
    } catch (e) {
      print("Error parsing date: $isoString");
      return "Invalid date";
    }
  }

  String getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference dbRef =
        FirebaseDatabase.instance.ref().child('rides/${widget.rideId}');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Details"),
      ),
      body: FutureBuilder<DatabaseEvent>(
        future: dbRef.once(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error fetching ride details."));
          }

          final rideData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final pickupLocation = LatLng(
              rideData['pickup_location']['latitude'],
              rideData['pickup_location']['longitude']);
          final destinationLocation = LatLng(
              rideData['destination_location']['latitude'],
              rideData['destination_location']['longitude']);
          final fare = rideData['fare'];
          final time = rideData['time'];

          return FutureBuilder<List<LatLng>>(
            future: _routePointsFuture,
            builder: (context, routeSnapshot) {
              if (routeSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (routeSnapshot.hasError) {
                return const Center(child: Text("Error fetching route data."));
              }

              final routePoints = routeSnapshot.data ?? [];

              return Column(
                children: [
                  ListTile(
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: "Pickup: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: rideData['pickup'],
                          ),
                        ],
                      ),
                    ),
                    leading: const Icon(Icons.location_on, color: Colors.red),
                  ),
                  ListTile(
                    title: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: "Destination: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: rideData['destination'],
                          ),
                        ],
                      ),
                    ),
                    leading: const Icon(Icons.location_on, color: Colors.green),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Fare: ₹$fare",
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Time: ${formatTime(time.toString())}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(thickness: 2),
                  const Text(
                    "Participants",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 200, // Set a fixed height
                    child: _isLoadingParticipants
                        ? const Center(child: CircularProgressIndicator())
                        : _participants.isEmpty
                          ? const Center(child: Text("No participants have paid yet."))
                          : ListView.builder(
                              itemCount: _participants.length,
                              itemBuilder: (context, index) {
                                final participant = _participants[index];
                                final name = participant['name'];
                                final profileImage = participant['profileImage'];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey,
                                    backgroundImage: profileImage != null && profileImage.isNotEmpty
                                        ? NetworkImage(profileImage)
                                        : null,
                                    child: profileImage == null || profileImage.isEmpty
                                        ? Text(
                                            name[0],
                                            style: const TextStyle(
                                                color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  title: Text(name),
                                  subtitle: Text(participant['phone']),
                                );
                              },
                            ),
                  ),
                  Expanded(
                    child: FlutterMapWidget(
                      currentLatLng: pickupLocation,
                      markers: [
                        Marker(
                          point: pickupLocation,
                          child: const Icon(Icons.location_on, color: Colors.red),
                        ),
                        Marker(
                          point: destinationLocation,
                          child:
                              const Icon(Icons.location_on, color: Colors.green),
                        ),
                      ],
                      routePoints: routePoints,
                      mapController: _mapController,
                    ),
                  ),
                  // SizedBox(
                  //   width: double.infinity, // Full width button
                  //   child: ElevatedButton(
                  //     onPressed: () {
                  //       _completeRide(widget.rideId);
                  //       //Navigator.pop(context);
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.green,
                  //       shape: const RoundedRectangleBorder(),
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //     ),
                  //     child: const Text(
                  //       "Complete Ride",
                  //       style: TextStyle(color: Colors.white, fontSize: 18),
                  //     ),
                  //   ),
                  // ),
                  SizedBox(
                    width: double.infinity, // Full-width button
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_rideStarted) {
                          _startRide();
                        } else {
                          _completeRide(widget.rideId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rideStarted ? Colors.green : Colors.blue,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _rideStarted ? "Complete Ride" : "Start Ride",
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                  if(!_rideStarted)
                    SizedBox(
                      width: double.infinity, // Full width button
                      child: ElevatedButton(
                        onPressed: () {
                          _dropRide(widget.rideId);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: const RoundedRectangleBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Drop Ride",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _completeRide(String rideId) async {
    bool? result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Complete Ride"),
          content: const Text("Have you reached the destination with all participants?"),
          actions: [
            TextButton(
              child: const Text("No"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text("Yes"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      // Move ride to archived_rides with completion status
      await _archiveRide(rideId, result);
      
      // Remove ride data from rides, user_ride, and driver_rides
      await _deleteRideData(rideId);

      _rideStarted = false ;

      // Redirect to home page after completion
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomeScreen()), 
        (route) => false,
      );

    }
  }

  Future<void> _archiveRide(String rideId, bool complete) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final rideDataSnapshot = await dbRef.child('rides/$rideId').once();
    final rideData = rideDataSnapshot.snapshot.value;

    if (rideData != null) {
      // Save to archived_rides with 'complete' status
      await dbRef.child('archived_rides/$rideId').set({
        ...rideData as Map<dynamic, dynamic>,
        'complete': complete,
      });
    }
  }

  Future<void> _deleteRideData(String rideId) async {
    final userId = _auth.currentUser?.uid;
    final dbRef = FirebaseDatabase.instance.ref();

    // Remove from rides
    await dbRef.child('rides/$rideId').remove();

    // Remove from user_ride for each user involved
    final userRideSnapshot = await dbRef.child('user_ride').once();
    if (userRideSnapshot.snapshot.exists) {
      final userRideData = userRideSnapshot.snapshot.value as Map<dynamic, dynamic>;
      userRideData.forEach((key, value) async {
        if (value['currentRideId'] == rideId) {
          await dbRef.child('user_ride/$key').remove();
        }
      });
    }

    // Remove from driver_rides
    final driverRef = dbRef.child('driver_rides/$userId');
    final driverRidesSnapshot = await driverRef.once();

    if (driverRidesSnapshot.snapshot.exists) {
      final currentRidesData = driverRidesSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final currentRidesCount = currentRidesData['currentrides'] ?? 0;

      if(currentRidesCount == 1){
         await driverRef.remove();
      }
      else{
        // Identify and remove the specific rideId
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

          // Update the ride count
          await driverRef.update({'currentrides': currentRidesCount - 1});
        }
      }
    }
  }

  Future<void> _dropRide(String rideId) async {
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
}