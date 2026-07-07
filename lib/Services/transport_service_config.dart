class TransportServiceConfig {
  static const String _baseUrl = "https://srilankaautorentals.com";

  static String get validateVehicleUrl => "$_baseUrl/api/transport-services/validate-vehicle";

  static String get availableVehiclesUrl => "$_baseUrl/api/available-vehicles";
  
}
