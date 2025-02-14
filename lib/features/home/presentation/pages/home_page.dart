import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    _initializeLocation();
    super.initState();
  }

  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _route = [];
  final Location _location = Location();
  final TextEditingController _locationController = TextEditingController();
  bool isLoading = true;

  Future<void> _initializeLocation() async {
    if (!await _checktheRequestPermissions()) return;

    // listen for location updates and update the current location
    _location.onLocationChanged.listen((LocationData locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
          isLoading = false; // stop loading once the location is obtained.
        });
        _fetchRoute();
      }
    });
  }

  Future<bool> _checktheRequestPermissions() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    // check if location permissions are granted
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }

    return true;
  }

  Future<void> _fetchCoordinatesPoints(String location) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        setState(() {
          _destination = LatLng(lat, lon);
        });

        await _fetchRoute();
      } else {
        errorMessage('Location not found. Please try another search.');
      }
    } else {
      errorMessage('Failed to fetch location. Try again later.');
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    final url = Uri.parse("http://router.project-osrm.org/route/v1/driving/"
        "${_currentLocation!.longitude},${_currentLocation!.latitude};"
        "${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=polyline");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final geometry = data['routes'][0]['geometry'];
      _decodePolyline(
          geometry); // Decode the polyline into a list of coordinates
    } else {
      errorMessage('Failed to fetch route. Try again later.');
    }
  }

  void errorMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    setState(() {
      _route = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    });
  }

  Future<void> _userCurrentLocation() async {
    final screenHeight = MediaQuery.of(context).size.height;

    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 17,
          offset: Offset(0, -screenHeight * 0.1));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Current location not available")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Map", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          isLoading
              ? Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                      initialCenter: _currentLocation ?? LatLng(0, 0),
                      initialZoom: 15,
                      minZoom: 0,
                      maxZoom: 100),
                  children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      CurrentLocationLayer(
                        style: LocationMarkerStyle(
                            headingSectorRadius: 80,
                            marker:
                                // DefaultLocationMarker
                                //   child:
                                Image.asset('assets/images/car_ic.png'),
                            // ),
                            markerSize: Size(65, 65),
                            markerDirection: MarkerDirection.heading),
                      ),
                      if (_destination != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _destination!,
                              width: 50,
                              height: 50,
                              child: const Icon(
                                Icons.location_pin,
                                size: 40,
                                color: Colors.red,
                              ),
                            ), // Marker
                          ],
                        ), // MarkerLayer
                      if (_currentLocation != null &&
                          _destination != null &&
                          _route.isNotEmpty)
                        PolylineLayer(polylines: [
                          Polyline(
                            points: _route,
                            strokeWidth: 8,
                            color: Colors.blueAccent,
                          ),
                        ]), // PolylineLayer
                    ]),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(children: [
                  // Expanded widget to make the text field take up available space
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter a location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ), // OutlineInputBorder
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                      ), // InputDecoration
                    ), // TextField
                  ), // Expanded
// IconButton to trigger the search for the entered location.

                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: () {
                      final location = _locationController.text.trim();
                      if (location.isNotEmpty) {
                        _fetchCoordinatesPoints(
                            location); // Fetch coordinates for the entered location.
                      }
                    },
                    icon: const Icon(Icons.search),
                  ), // IconButton
                ]) // Row

                ), // Padding  I
          ), // Positioned
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        onPressed: _userCurrentLocation,
        child: Icon(
          Icons.my_location,
          size: 30,
          color: Colors.white,
        ),
      ),
    );
  }
}
