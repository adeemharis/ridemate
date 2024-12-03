import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // For LatLng coordinates

class FlutterMapWidget extends StatelessWidget {
   final LatLng? currentLatLng; 
  final MapController mapController; 
  final List<Marker> markers; 
  final List<LatLng> routePoints; 

  FlutterMapWidget({
    required this.currentLatLng, 
    required this.mapController,
    required this.markers, 
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentLatLng!,
                initialZoom: 13.0,
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(6.0, 68.0),  // South-West of India
                    const LatLng(37.0, 97.0), // North-East of India
                  ),
                ),
                initialRotation: 0.0,
              ),
              // children: [
              //         TileLayer(
              //           urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              //           subdomains: const ['a', 'b', 'c'],
              //         ),
              //         MarkerLayer(
              //           markers: _markers,
              //         ),
              //         if (_routePoints.isNotEmpty)
              //           PolylineLayer(
              //             polylines: [
              //               Polyline(points: _routePoints, strokeWidth: 4.0, color: Colors.blue),
              //             ],
              //           ),
              //       ],
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: markers,
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
