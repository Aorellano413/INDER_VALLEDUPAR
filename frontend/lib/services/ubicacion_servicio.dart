// lib/services/location_service.dart
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> abrirUbicacionEnMapas(String direccion) async {
    if (direccion.trim().isEmpty) return false;

    final queryEncoded = Uri.encodeComponent(direccion.trim());
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$queryEncoded');

    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      print('Error al abrir Google Maps: $e');
      return false;
    }
  }
}