import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, request user to enable it
      return Future.error('Location services are disabled.');
    }

    // Check for permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, handle appropriately
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return Future.error('Location permissions are permanently denied.');
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Adjust as needed
      ),
    );
    
    return position ;
  }

  // Function to fetch route from OpenRouteService
  static Future<List<LatLng>> getRoute(LatLng start, LatLng destination) async {
    const apiKey = '5b3ce3597851110001cf6248a65d228dee884d84bed03187adbb9f99';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${destination.longitude},${destination.latitude}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routeCoordinates = data['features'][0]['geometry']['coordinates'];

      List<LatLng> routePoints = routeCoordinates
            .map<LatLng>((point) => LatLng(point[1], point[0]))
            .toList();

      return routePoints ;
    } else {
      throw Exception('Failed to load route');
    }
  }

  static Future<List<String>> getSuggestions(String pattern, Position currentPosition) async {
    List<String> suggestions = [];

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

    if (pattern.isNotEmpty) {
      // Filter the default suggestions based on the input pattern
      suggestions.addAll(defaultLocationsMap.keys.where((location) =>
        location.toLowerCase().contains(pattern.toLowerCase())));
    } else {
      // If the pattern is empty, return all default suggestions
      return defaultLocationsMap.keys.toList();
    }

    if (pattern.isNotEmpty) {
      String url =
          'https://nominatim.openstreetmap.org/search?q=$pattern&format=json&limit=5&lat=${currentPosition.latitude}&lon=${currentPosition.longitude}&addressdetails=1&extratags=1';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          print(data) ;
          for (var location in data) {
            print(location) ;
            suggestions.add(location['display_name']);
          }
        } else {
          throw Exception('Failed to load suggestions');
        }
      } catch (e) {
        print(e);
        // Handle the error (e.g., show a message)
      }
    }
    return suggestions;
  }
}