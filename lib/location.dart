
import 'package:google_maps_webservice_ex/places.dart';
import 'package:google_maps_webservice_ex/distance.dart';
import 'package:google_maps_webservice_ex/geocoding.dart';
import 'package:google_maps_webservice_ex/geolocation.dart';
import 'package:location/location.dart' as loc;




Future<loc.LocationData> _getLocation() async {
  loc.Location location = loc.Location();
  return await location.getLocation();
}



Future<List<String>> getSafeAreas() async {
  late loc.LocationData _currentLocation;
  _currentLocation = await _getLocation();
  // Initialize the Places API client with your API key
  final apiKey ='AIzaSyAkYw2mZlmZOCr91KyvTcFoHKVfgmP-YGQ';
  GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: apiKey);
  print (_currentLocation.latitude!);
  print (_currentLocation.longitude!);

  // Define the location and radius for the nearby search
  final location = Location(lat: _currentLocation.latitude!, lng: _currentLocation.longitude!); // Example location (San Francisco)
  final radius = 5000; // 1000 meters (1km)

  // Perform the nearby search
  PlacesSearchResponse response = await _places.searchNearbyWithRadius(location,radius, type: 'hospital', // Place type (e.g., 'hospital', 'clinic', 'fire_station')
  );


  // Extract relevant information from the response
  final safeAreas = response.results;


  // Extract names of safe areas
  List<String> safeAreaNames = safeAreas.map((place) => place.name).toList();
  List<String?> safeAreaAddress = safeAreas.map((place) => place.formattedAddress).toList();
  List<String?> safeAreaAreas = safeAreas.map((place) => place.placeId).toList();
  List<String?> safeAreaId = safeAreas.map((place) => place.placeId).toList();


  print (safeAreaNames);
  print (safeAreaAddress);
  print(safeAreaId);
  print(safeAreaAreas);

  return safeAreaNames;
}


