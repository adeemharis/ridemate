// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:user_application/services/booking_services.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:user_application/services/location_service.dart';
// import 'package:intl/intl.dart';

// class RideDetailsPage extends StatefulWidget {
//   final String rideid;
//   final LatLng? currentLatLng;

//   const RideDetailsPage({
//     super.key,
//     required this.rideid,
//     required this.currentLatLng,
//   });

//   @override
//   _RideDetailsPageState createState() => _RideDetailsPageState();
// }

// class _RideDetailsPageState extends State<RideDetailsPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   Map<String, dynamic>? _rideData = {};
//   final MapController _mapController = MapController();
//   LatLng pickupLatLng = LatLng(0.0, 0.0);
//   LatLng destinationLatLng = LatLng(0.0, 0.0);
//   List<LatLng> routePoints = [];
//   bool _isMapReady = false;

//   Future<void> _getRideData(String rideId) async {
//     final ref = FirebaseDatabase.instance.ref().child('rides/$rideId');
    
//     ref.onValue.listen((DatabaseEvent event) async {
//       if (event.snapshot.exists) {
//         final data = event.snapshot.value as Map<dynamic, dynamic>?;
//         if (data != null) {
//           Map<String, dynamic> rideData = data.cast<String, dynamic>();

//           // Parse pickup and destination locations
//           if (rideData.containsKey('pickup_location') && rideData['pickup_location'] is Map) {
//             final pickupData = rideData['pickup_location'] as Map<dynamic, dynamic>;
//             pickupLatLng = LatLng(
//               (pickupData['latitude'] as num).toDouble(),
//               (pickupData['longitude'] as num).toDouble(),
//             );
//           }
//           if (rideData.containsKey('destination_location') && rideData['destination_location'] is Map) {
//             final destinationData = rideData['destination_location'] as Map<dynamic, dynamic>;
//             destinationLatLng = LatLng(
//               (destinationData['latitude'] as num).toDouble(),
//               (destinationData['longitude'] as num).toDouble(),
//             );
//           }

//           // Fetch route points
//           routePoints = await LocationService.getRoute(pickupLatLng, destinationLatLng);
//           if (_isMapReady) _fitMapBounds();

//           // Check if 'assigned' is true and fetch driver details if so
//           if (rideData['assigned'] == true) {
//             _getDriverDetails(rideData['driver_uid']);
//           }

//           setState(() {
//             _rideData = rideData;
//           });
//         }
//       }
//     });
//   }

//   Future<void> _getDriverDetails(String driverId) async {
//     final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
//     if (driverDoc.exists) {
//       final driverData = driverDoc.data();
//       if (driverData != null) {
//         setState(() {
//           _rideData!['driverName'] = driverData['name'];
//           _rideData!['driverContact'] = driverData['phone'];
//           _rideData!['vehicleNo'] = driverData['vehicle']; // Vehicle number
//           _rideData!['profilePhotoUrl'] = driverData['profilePhotoUrl']; // Profile photo URL
//         });
//       }
//     }
//   }

//   void _fitMapBounds() {
//     final centerLat = (pickupLatLng.latitude + destinationLatLng.latitude) / 2;
//     final centerLng = (pickupLatLng.longitude + destinationLatLng.longitude) / 2;
//     final center = LatLng(centerLat, centerLng);

//     final distance = const Distance().as(LengthUnit.Kilometer, pickupLatLng, destinationLatLng);
//     double zoomLevel ;
//     if (distance < 1) {
//         zoomLevel = 15.5; // Close zoom
//       } else if (distance < 5) {
//         zoomLevel = 13.0; // Medium zoom
//       } else {
//         zoomLevel = 10.0; // Wide zoom for longer distances
//       }

//     _mapController.move(center, zoomLevel);
//   }

//   String formatTime(String isoString) {
//     DateTime dateTime = DateTime.parse(isoString);
//     return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
//   }

//   @override
//   void initState() {
//     super.initState();
//     _getRideData(widget.rideid);
//   }

//   String getShortenedLocation(String location) {
//     List<String> parts = location.split(',');
//     return parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : location;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_rideData == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Ride Details')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.red),
//                         const SizedBox(width: 8),
//                         Text('Pickup: ${getShortenedLocation(_rideData!['pickup']?.toString() ?? "Loading...")}'),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.green),
//                         const SizedBox(width: 8),
//                         Text('Destination: ${getShortenedLocation(_rideData!['destination']?.toString() ?? "Loading...")}'),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Text('Fare: ₹${_rideData!['fare']?.toString() ?? "N/A"}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                     Text('Time: ${formatTime(_rideData!['time']?.toString() ?? "N/A")}', style: TextStyle(fontSize: 16)),
//                   ],
//                 ),
//               ),
//             ),

//             // Driver Details Section
//             Card(
//               elevation: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Driver Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 10),
//                     if (_rideData!['driverName'] == null)
//                       const Row(
//                         children: [
//                           CircularProgressIndicator(),
//                           SizedBox(width: 10),
//                           Text('Waiting for driver...', style: TextStyle(fontSize: 16)),
//                         ],
//                       )
//                     else ...[
//                       Row(
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: Colors.grey[300],
//                             backgroundImage: _rideData!['profilePhotoUrl'] != null && _rideData!['profilePhotoUrl'].isNotEmpty
//                               ? NetworkImage(_rideData!['profilePhotoUrl']) 
//                               : null,
//                             child: _rideData!['profilePhotoUrl'] == null || _rideData!['profilePhotoUrl'].isEmpty
//                               ? Text(
//                                   _rideData!['driverName'][0].toUpperCase(),
//                                   style: const TextStyle(fontSize: 20, color: Colors.black),
//                                 )
//                               : null,
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text('Name: ${_rideData!['driverName']}', style: TextStyle(fontSize: 16)),
//                                 Text('Contact: ${_rideData!['driverContact']}', style: TextStyle(fontSize: 16)),
//                                 Text('Vehicle No: ${_rideData!['vehicleNo'] ?? "N/A"}', style: TextStyle(fontSize: 16)),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),

//             Expanded(
//               child: FlutterMap(
//                 mapController: _mapController,
//                 options: MapOptions(
//                   initialCenter: widget.currentLatLng!,
//                   initialZoom: 14.0,
//                   onMapReady: () {
//                     setState(() {
//                       _isMapReady = true;
//                     });
//                     if (_rideData!.isNotEmpty) _fitMapBounds();
//                   },
//                   cameraConstraint: CameraConstraint.contain(
//                     bounds:(LatLngBounds(
//                       const LatLng(6.0, 68.0), // South-West of India
//                       const LatLng(37.0, 97.0), // North-East of India
//                     )
//                     )
//                   ),
//                 ),
//                 children: [
//                   TileLayer(
//                     urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     subdomains: const ['a', 'b', 'c'],
//                   ),
//                   if (routePoints.isNotEmpty)
//                     PolylineLayer(
//                       polylines: [
//                         Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue),
//                       ],
//                     ),
//                   MarkerLayer(
//                     markers: [
//                       Marker(
//                         point: pickupLatLng,
//                         child: const Icon(Icons.location_on, color: Colors.red, size: 32),
//                       ),
//                       Marker(
//                         point: destinationLatLng,
//                         child: const Icon(Icons.location_on, color: Colors.green, size: 32),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {
//                   BookingService.cancelRide(widget.rideid, _auth);
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: const Text('Cancel Ride', style: TextStyle(fontSize: 18)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_application/services/booking_services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_application/services/location_service.dart';
import 'package:intl/intl.dart';

class RideDetailsPage extends StatefulWidget {
  final String rideid;
  final LatLng? currentLatLng;

  const RideDetailsPage({
    super.key,
    required this.rideid,
    required this.currentLatLng,
  });

  @override
  _RideDetailsPageState createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _rideData = {};
  final MapController _mapController = MapController();
  LatLng pickupLatLng = LatLng(0.0, 0.0);
  LatLng destinationLatLng = LatLng(0.0, 0.0);
  List<LatLng> routePoints = [];
  bool _isMapReady = false;
  bool _isDriverAssigned = false; // Track if a driver is assigned
  bool _hasPaidServiceFee = false; // Track payment status

  Future<void> _getRideData(String rideId) async {
    final ref = FirebaseDatabase.instance.ref().child('rides/$rideId');

    ref.onValue.listen((DatabaseEvent event) async {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          Map<String, dynamic> rideData = data.cast<String, dynamic>();

          // Parse pickup and destination locations
          if (rideData.containsKey('pickup_location') && rideData['pickup_location'] is Map) {
            final pickupData = rideData['pickup_location'] as Map<dynamic, dynamic>;
            pickupLatLng = LatLng(
              (pickupData['latitude'] as num).toDouble(),
              (pickupData['longitude'] as num).toDouble(),
            );
          }
          if (rideData.containsKey('destination_location') && rideData['destination_location'] is Map) {
            final destinationData = rideData['destination_location'] as Map<dynamic, dynamic>;
            destinationLatLng = LatLng(
              (destinationData['latitude'] as num).toDouble(),
              (destinationData['longitude'] as num).toDouble(),
            );
          }

          // Fetch route points
          routePoints = await LocationService.getRoute(pickupLatLng, destinationLatLng);
          if (_isMapReady) _fitMapBounds();

          // Check if 'assigned' is true
          if (rideData['assigned'] == true) {
            _isDriverAssigned = true;
            _getDriverDetails(rideData['driver_uid']);
          } else {
            // Show loading if no driver assigned
            _isDriverAssigned = false;
          }

          setState(() {
            _rideData = rideData;
          });
        }
      }
    });
  }

  Future<void> _getDriverDetails(String driverId) async {
    final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
    if (driverDoc.exists) {
      final driverData = driverDoc.data();
      if (driverData != null) {
        setState(() {
          _rideData!['driverName'] = driverData['name'];
          _rideData!['driverContact'] = driverData['phone'];
          _rideData!['vehicleNo'] = driverData['vehicle']; // Vehicle number
          _rideData!['profilePhotoUrl'] = driverData['profilePhotoUrl']; // Profile photo URL
        });
      }
    }
  }

  void _fitMapBounds() {
    final centerLat = (pickupLatLng.latitude + destinationLatLng.latitude) / 2;
    final centerLng = (pickupLatLng.longitude + destinationLatLng.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    final distance = const Distance().as(LengthUnit.Kilometer, pickupLatLng, destinationLatLng);
    double zoomLevel;
    if (distance < 1) {
      zoomLevel = 15.5; // Close zoom
    } else if (distance < 5) {
      zoomLevel = 13.0; // Medium zoom
    } else {
      zoomLevel = 10.0; // Wide zoom for longer distances
    }

    _mapController.move(center, zoomLevel);
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pay Service Fee'),
          content: const Text('Do you want to pay the service fee for this ride?'),
          actions: [
            TextButton(
              onPressed: () async {
                // Update paid status in Firebase
                await FirebaseDatabase.instance.ref().child('user_ride/${_auth.currentUser!.uid}/paid').set(true);
                setState(() {
                  _hasPaidServiceFee = true; // Mark fee as paid
                });
                Navigator.of(context).pop();
              },
              child: const Text('Pay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel the dialog
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showUnableToFindDriverMessage(String rideId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Driver Not Found'),
          content: const Text('Unable to find a driver. Please try again.'),
          actions: [
            TextButton(
              onPressed: () {
                // Delete the ride info from the database
                FirebaseDatabase.instance.ref().child('rides/$rideId').remove().then((_) {
                  // Navigate back to the home page after deletion
                  Navigator.of(context).pushReplacementNamed('/home'); // Adjust the route name as needed
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String formatTime(String isoString) {
    DateTime dateTime = DateTime.parse(isoString);
    return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    _getRideData(widget.rideid);
  }

  String getShortenedLocation(String location) {
    List<String> parts = location.split(',');
    return parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : location;
  }

  @override
  Widget build(BuildContext context) {
    if (_rideData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Pickup: ${getShortenedLocation(_rideData!['pickup']?.toString() ?? "Loading...")}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Destination: ${getShortenedLocation(_rideData!['destination']?.toString() ?? "Loading...")}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Fare: ₹${_rideData!['fare']?.toString() ?? "N/A"}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Time: ${formatTime(_rideData!['time']?.toString() ?? "N/A")}', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),

            // Driver Details Section
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Driver Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (!_isDriverAssigned) ...[
                      const Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 10),
                          Text('Looking for driver...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    ] else ...[
                      // If driver is assigned, show driver details and payment option
                      Stack(
                        children: [
                          Opacity(
                            opacity: _hasPaidServiceFee ? 1.0 : 0.01, // Blur effect when fee is not paid
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: _rideData!['profilePhotoUrl'] != null && _rideData!['profilePhotoUrl'].isNotEmpty
                                        ? NetworkImage(_rideData!['profilePhotoUrl']) 
                                        : null,
                                      child: _rideData!['profilePhotoUrl'] == null || _rideData!['profilePhotoUrl'].isEmpty
                                        ? Text(
                                            _rideData!['driverName'][0].toUpperCase(),
                                            style: const TextStyle(fontSize: 20, color: Colors.black),
                                          )
                                        : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Name: ${_rideData!['driverName']}', style: TextStyle(fontSize: 16)),
                                          Text('Contact: ${_rideData!['driverContact']}', style: TextStyle(fontSize: 16)),
                                          Text('Vehicle No: ${_rideData!['vehicleNo'] ?? "N/A"}', style: TextStyle(fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // if (!_hasPaidServiceFee) // Show payment option
                                //   ElevatedButton(
                                //     onPressed: _showPaymentDialog,
                                //     child: const Text('Pay Service Fee', style: TextStyle(fontSize: 16)),
                                //   ),
                              ],
                            ),
                          ),
                          if (!_hasPaidServiceFee) // Show payment option
                          Center(
                            child : ElevatedButton(
                              onPressed: _showPaymentDialog,
                              child: const Text('Pay Service Fee', style: TextStyle(fontSize: 16)),
                            ),
                          )
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.currentLatLng!,
                  initialZoom: 14.0,
                  onMapReady: () {
                    setState(() {
                      _isMapReady = true;
                    });
                    if (_rideData!.isNotEmpty) _fitMapBounds();
                  },
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(6.0, 68.0), // South-West of India
                      const LatLng(37.0, 97.0), // North-East of India
                    )
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pickupLatLng,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                      ),
                      Marker(
                        point: destinationLatLng,
                        child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  BookingService.cancelRide(widget.rideid, _auth);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cancel Ride', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class RideDetailsPage extends StatefulWidget {
//   final String rideid;
//   final LatLng? currentLatLng;

//   const RideDetailsPage({
//     super.key,
//     required this.rideid,
//     required this.currentLatLng,
//   });

//   @override
//   _RideDetailsPageState createState() => _RideDetailsPageState();
// }

// class _RideDetailsPageState extends State<RideDetailsPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   Map<String, dynamic>? _rideData = {};
//   final MapController _mapController = MapController();
//   LatLng pickupLatLng = LatLng(0.0, 0.0);
//   LatLng destinationLatLng = LatLng(0.0, 0.0);
//   List<LatLng> routePoints = [];
//   bool _isMapReady = false;
//   bool _isPaid = false; // Track if the service fee is paid

//   Future<void> _getRideData(String rideId) async {
//     final ref = FirebaseDatabase.instance.ref().child('rides/$rideId');

//     ref.onValue.listen((DatabaseEvent event) async {
//       if (event.snapshot.exists) {
//         final data = event.snapshot.value as Map<dynamic, dynamic>?;
//         if (data != null) {
//           Map<String, dynamic> rideData = data.cast<String, dynamic>();

//           // Parse pickup and destination locations
//           if (rideData.containsKey('pickup_location') && rideData['pickup_location'] is Map) {
//             final pickupData = rideData['pickup_location'] as Map<dynamic, dynamic>;
//             pickupLatLng = LatLng(
//               (pickupData['latitude'] as num).toDouble(),
//               (pickupData['longitude'] as num).toDouble(),
//             );
//           }
//           if (rideData.containsKey('destination_location') && rideData['destination_location'] is Map) {
//             final destinationData = rideData['destination_location'] as Map<dynamic, dynamic>;
//             destinationLatLng = LatLng(
//               (destinationData['latitude'] as num).toDouble(),
//               (destinationData['longitude'] as num).toDouble(),
//             );
//           }

//           // Fetch route points
//           routePoints = await LocationService.getRoute(pickupLatLng, destinationLatLng);
//           if (_isMapReady) _fitMapBounds();

//           // Check if 'assigned' is true and fetch driver details if so
//           if (rideData['assigned'] == true) {
//             _getDriverDetails(rideData['driver_uid']);
//           } else {
//             // Check if the current time is 5 minutes more than ride time
//             DateTime rideTime = DateTime.parse(rideData['time']);
//             if (DateTime.now().isAfter(rideTime.add(const Duration(minutes: 5)))) {
//               // Show message and delete ride info
//               _showUnableToFindDriverMessage(rideId);
//             }
//           }

//           // Check if the user has paid the service fee
//           _isPaid = rideData['is_paid'] ?? false;

//           setState(() {
//             _rideData = rideData;
//           });
//         }
//       }
//     });
//   }

//   Future<void> _getDriverDetails(String driverId) async {
//     final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
//     if (driverDoc.exists) {
//       final driverData = driverDoc.data();
//       if (driverData != null) {
//         setState(() {
//           _rideData!['driverName'] = driverData['name'];
//           _rideData!['driverContact'] = driverData['phone'];
//           _rideData!['vehicleNo'] = driverData['vehicle']; // Vehicle number
//           _rideData!['profilePhotoUrl'] = driverData['profilePhotoUrl']; // Profile photo URL
//         });
//       }
//     }
//   }

//   void _fitMapBounds() {
//     final centerLat = (pickupLatLng.latitude + destinationLatLng.latitude) / 2;
//     final centerLng = (pickupLatLng.longitude + destinationLatLng.longitude) / 2;
//     final center = LatLng(centerLat, centerLng);

//     final distance = const Distance().as(LengthUnit.Kilometer, pickupLatLng, destinationLatLng);
//     double zoomLevel;
//     if (distance < 1) {
//       zoomLevel = 15.5; // Close zoom
//     } else if (distance < 5) {
//       zoomLevel = 13.0; // Medium zoom
//     } else {
//       zoomLevel = 10.0; // Wide zoom for longer distances
//     }

//     _mapController.move(center, zoomLevel);
//   }

//   String formatTime(String isoString) {
//     DateTime dateTime = DateTime.parse(isoString);
//     return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
//   }

//   void _showPaymentDialog() {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Pay Service Fee'),
//           content: const Text('Do you want to pay the service fee to view driver details?'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 // Here, update the paid status in the database
//                 _updatePaymentStatus();
//                 Navigator.of(context).pop();
//               },
//               child: const Text('Pay Fee'),
//             ),
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close dialog
//               },
//               child: const Text('Cancel Ride'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _updatePaymentStatus() async {
//     // Update the paid status in the Firebase Realtime Database
//     await FirebaseDatabase.instance.ref().child('user_rides/${_auth.currentUser!.uid}/${widget.rideid}').update({
//       'is_paid': true,
//     });

//     // Set _isPaid to true and refresh the ride data
//     setState(() {
//       _isPaid = true;
//     });
//     _getRideData(widget.rideid); // Refresh the ride data
//   }

//   @override
//   void initState() {
//     super.initState();
//     _getRideData(widget.rideid);
//   }

//   String getShortenedLocation(String location) {
//     List<String> parts = location.split(',');
//     return parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : location;
//   }

//     void _showUnableToFindDriverMessage(String rideId) {
//       // Show a dialog to inform the user
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: const Text('Driver Not Found'),
//             content: const Text('Unable to find a driver. Please try again.'),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   // Delete the ride info from the database
//                   FirebaseDatabase.instance.ref().child('rides/$rideId').remove().then((_) {
//                     // Navigate back to the home page after deletion
//                     Navigator.of(context).pushReplacementNamed('/home'); // Adjust the route name as needed
//                   });
//                 },
//                 child: const Text('OK'),
//               ),
//             ],
//           );
//         },
//       );
//     }

//   @override
//   Widget build(BuildContext context) {
//     if (_rideData == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Ride Details')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.red),
//                         const SizedBox(width: 8),
//                         Text('Pickup: ${getShortenedLocation(_rideData!['pickup']?.toString() ?? "Loading...")}'),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.green),
//                         const SizedBox(width: 8),
//                         Text('Destination: ${getShortenedLocation(_rideData!['destination']?.toString() ?? "Loading...")}'),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Text('Fare: ₹${_rideData!['fare']?.toString() ?? "N/A"}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                     Text('Time: ${formatTime(_rideData!['time']?.toString() ?? "N/A")}', style: TextStyle(fontSize: 16)),
//                   ],
//                 ),
//               ),
//             ),

//             // Driver Details Section
//             Card(
//               elevation: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Driver Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 10),
//                     if (!_isPaid) ...[
//                       const Text('Please pay the service fee to view driver details.', style: TextStyle(fontSize: 16)),
//                       const SizedBox(height: 10),
//                       ElevatedButton(
//                         onPressed: _showPaymentDialog,
//                         child: const Text('Pay Service Fee'),
//                       ),
//                     ] else ...[
//                       // If paid, show driver details
//                       if (_rideData!['driverName'] == null)
//                         const Row(
//                           children: [
//                             CircularProgressIndicator(),
//                             SizedBox(width: 10),
//                             Text('Waiting for driver...', style: TextStyle(fontSize: 16)),
//                           ],
//                         )
//                       else ...[
//                         Row(
//                           children: [
//                             CircleAvatar(
//                               backgroundColor: Colors.grey[300],
//                               backgroundImage: _rideData!['profilePhotoUrl'] != null && _rideData!['profilePhotoUrl'].isNotEmpty
//                                 ? NetworkImage(_rideData!['profilePhotoUrl']) 
//                                 : null,
//                               child: _rideData!['profilePhotoUrl'] == null || _rideData!['profilePhotoUrl'].isEmpty
//                                 ? Text(
//                                     _rideData!['driverName'][0].toUpperCase(),
//                                     style: const TextStyle(fontSize: 20, color: Colors.black),
//                                   )
//                                 : null,
//                             ),
//                             const SizedBox(width: 10),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Name: ${_rideData!['driverName']}', style: TextStyle(fontSize: 16)),
//                                   Text('Contact: ${_rideData!['driverContact']}', style: TextStyle(fontSize: 16)),
//                                   Text('Vehicle No: ${_rideData!['vehicleNo'] ?? "N/A"}', style: TextStyle(fontSize: 16)),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ],
//                 ),
//               ),
//             ),

//             Expanded(
//               child: FlutterMap(
//                 mapController: _mapController,
//                 options: MapOptions(
//                   initialCenter: widget.currentLatLng!,
//                   initialZoom: 14.0,
//                   onMapReady: () {
//                     setState(() {
//                       _isMapReady = true;
//                     });
//                     if (_rideData!.isNotEmpty) _fitMapBounds();
//                   },
//                   cameraConstraint: CameraConstraint.contain(
//                     bounds: LatLngBounds(
//                       const LatLng(6.0, 68.0), // South-West of India
//                       const LatLng(37.0, 97.0), // North-East of India
//                     ),
//                   ),
//                 ),
//                 children: [
//                   TileLayer(
//                     urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     subdomains: const ['a', 'b', 'c'],
//                   ),
//                   if (routePoints.isNotEmpty)
//                     PolylineLayer(
//                       polylines: [
//                         Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue),
//                       ],
//                     ),
//                   MarkerLayer(
//                     markers: [
//                       Marker(
//                         point: pickupLatLng,
//                         child: const Icon(Icons.location_on, color: Colors.red, size: 32),
//                       ),
//                       Marker(
//                         point: destinationLatLng,
//                         child: const Icon(Icons.location_on, color: Colors.green, size: 32),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {
//                   BookingService.cancelRide(widget.rideid, _auth);
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: const Text('Cancel Ride', style: TextStyle(fontSize: 18)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class RideDetailsPage extends StatefulWidget {
//   final String rideid;
//   final LatLng? currentLatLng;

//   const RideDetailsPage({
//     super.key,
//     required this.rideid,
//     required this.currentLatLng,
//   });

//   @override
//   _RideDetailsPageState createState() => _RideDetailsPageState();
// }

// class _RideDetailsPageState extends State<RideDetailsPage> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   Map<String, dynamic>? _rideData = {};
//   final MapController _mapController = MapController();
//   LatLng pickupLatLng = LatLng(0.0, 0.0);
//   LatLng destinationLatLng = LatLng(0.0, 0.0);
//   List<LatLng> routePoints = [];
//   bool _isMapReady = false;

//   Future<void> _getRideData(String rideId) async {
//     final ref = FirebaseDatabase.instance.ref().child('rides/$rideId');

//     ref.onValue.listen((DatabaseEvent event) async {
//       if (event.snapshot.exists) {
//         final data = event.snapshot.value as Map<dynamic, dynamic>?;
//         if (data != null) {
//           Map<String, dynamic> rideData = data.cast<String, dynamic>();

//           // Parse pickup and destination locations
//           if (rideData.containsKey('pickup_location') && rideData['pickup_location'] is Map) {
//             final pickupData = rideData['pickup_location'] as Map<dynamic, dynamic>;
//             pickupLatLng = LatLng(
//               (pickupData['latitude'] as num).toDouble(),
//               (pickupData['longitude'] as num).toDouble(),
//             );
//           }
//           if (rideData.containsKey('destination_location') && rideData['destination_location'] is Map) {
//             final destinationData = rideData['destination_location'] as Map<dynamic, dynamic>;
//             destinationLatLng = LatLng(
//               (destinationData['latitude'] as num).toDouble(),
//               (destinationData['longitude'] as num).toDouble(),
//             );
//           }

//           // Fetch route points
//           routePoints = await LocationService.getRoute(pickupLatLng, destinationLatLng);
//           if (_isMapReady) _fitMapBounds();

//           // Check if 'assigned' is true and fetch driver details if so
//           if (rideData['assigned'] == true) {
//             _getDriverDetails(rideData['driver_uid']);
//           } else {
//             // Check if the current time is 5 minutes more than ride time
//             DateTime rideTime = DateTime.parse(rideData['time']);
//             if (DateTime.now().isAfter(rideTime.add(const Duration(minutes: 5)))) {
//               // Show message and delete ride info
//               _showUnableToFindDriverMessage(rideId);
//             }
//           }

//           setState(() {
//             _rideData = rideData;
//           });
//         }
//       }
//     });
//   }

//   Future<void> _getDriverDetails(String driverId) async {
//     final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
//     if (driverDoc.exists) {
//       final driverData = driverDoc.data();
//       if (driverData != null) {
//         setState(() {
//           _rideData!['driverName'] = driverData['name'];
//           _rideData!['driverContact'] = driverData['phone'];
//           _rideData!['vehicleNo'] = driverData['vehicle']; // Vehicle number
//           _rideData!['profilePhotoUrl'] = driverData['profilePhotoUrl']; // Profile photo URL
//         });
//       }
//     }
//   }

//   void _fitMapBounds() {
//     final centerLat = (pickupLatLng.latitude + destinationLatLng.latitude) / 2;
//     final centerLng = (pickupLatLng.longitude + destinationLatLng.longitude) / 2;
//     final center = LatLng(centerLat, centerLng);

//     final distance = const Distance().as(LengthUnit.Kilometer, pickupLatLng, destinationLatLng);
//     double zoomLevel;
//     if (distance < 1) {
//       zoomLevel = 15.5; // Close zoom
//     } else if (distance < 5) {
//       zoomLevel = 13.0; // Medium zoom
//     } else {
//       zoomLevel = 10.0; // Wide zoom for longer distances
//     }

//     _mapController.move(center, zoomLevel);
//   }

//   String formatTime(String isoString) {
//     DateTime dateTime = DateTime.parse(isoString);
//     return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
//   }

//   void _showUnableToFindDriverMessage(String rideId) {
//     // Show a dialog to inform the user
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Driver Not Found'),
//           content: const Text('Unable to find a driver. Please try again.'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 // Delete the ride info from the database
//                 FirebaseDatabase.instance.ref().child('rides/$rideId').remove().then((_) {
//                   // Navigate back to the home page after deletion
//                   Navigator.of(context).pushReplacementNamed('/home'); // Adjust the route name as needed
//                 });
//               },
//               child: const Text('OK'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   void initState() {
//     super.initState();
//     _getRideData(widget.rideid);
//   }

//   String getShortenedLocation(String location) {
//     List<String> parts = location.split(',');
//     return parts.length >= 2 ? '${parts[0]}, ${parts[1]}' : location;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_rideData == null) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Scaffold(
//       appBar: AppBar(title: const Text('Ride Details')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.red),
//                         const SizedBox(width: 8),
//                         Text('Pickup: ${getShortenedLocation(_rideData!['pickup']?.toString() ?? "Loading...")}'),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Icon(Icons.location_on, color: Colors.green),
//                         const SizedBox(width: 8),
//                         Text('Destination: ${getShortenedLocation(_rideData!['destination']?.toString() ?? "Loading...")}'),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     Text('Fare: ₹${_rideData!['fare']?.toString() ?? "N/A"}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                     Text('Time: ${formatTime(_rideData!['time']?.toString() ?? "N/A")}', style: TextStyle(fontSize: 16)),
//                   ],
//                 ),
//               ),
//             ),

//             // Driver Details Section
//             Card(
//               elevation: 4,
//               margin: const EdgeInsets.only(bottom: 16),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Driver Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 10),
//                     if (_rideData!['driverName'] == null)
//                       const Row(
//                         children: [
//                           CircularProgressIndicator(),
//                           SizedBox(width: 10),
//                           Text('Waiting for driver...', style: TextStyle(fontSize: 16)),
//                         ],
//                       )
//                     else ...[
//                       Row(
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: Colors.grey[300],
//                             backgroundImage: _rideData!['profilePhotoUrl'] != null && _rideData!['profilePhotoUrl'].isNotEmpty
//                               ? NetworkImage(_rideData!['profilePhotoUrl']) 
//                               : null,
//                             child: _rideData!['profilePhotoUrl'] == null || _rideData!['profilePhotoUrl'].isEmpty
//                               ? Text(
//                                   _rideData!['driverName'][0].toUpperCase(),
//                                   style: const TextStyle(fontSize: 20, color: Colors.black),
//                                 )
//                               : null,
//                           ),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text('Name: ${_rideData!['driverName']}', style: TextStyle(fontSize: 16)),
//                                 Text('Contact: ${_rideData!['driverContact']}', style: TextStyle(fontSize: 16)),
//                                 Text('Vehicle No: ${_rideData!['vehicleNo'] ?? "N/A"}', style: TextStyle(fontSize: 16)),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),

//             Expanded(
//               child: FlutterMap(
//                 mapController: _mapController,
//                 options: MapOptions(
//                   initialCenter: widget.currentLatLng!,
//                   initialZoom: 14.0,
//                   onMapReady: () {
//                     setState(() {
//                       _isMapReady = true;
//                     });
//                     if (_rideData!.isNotEmpty) _fitMapBounds();
//                   },
//                   cameraConstraint: CameraConstraint.contain(
//                     bounds: LatLngBounds(
//                       const LatLng(6.0, 68.0), // South-West of India
//                       const LatLng(37.0, 97.0), // North-East of India
//                     )
//                   ),
//                 ),
//                 children: [
//                   TileLayer(
//                     urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     subdomains: const ['a', 'b', 'c'],
//                   ),
//                   if (routePoints.isNotEmpty)
//                     PolylineLayer(
//                       polylines: [
//                         Polyline(points: routePoints, strokeWidth: 4.0, color: Colors.blue),
//                       ],
//                     ),
//                   MarkerLayer(
//                     markers: [
//                       Marker(
//                         point: pickupLatLng,
//                         child: const Icon(Icons.location_on, color: Colors.red, size: 32),
//                       ),
//                       Marker(
//                         point: destinationLatLng,
//                         child: const Icon(Icons.location_on, color: Colors.green, size: 32),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {
//                   BookingService.cancelRide(widget.rideid, _auth);
//                   Navigator.of(context).pop();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: const Text('Cancel Ride', style: TextStyle(fontSize: 18)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
