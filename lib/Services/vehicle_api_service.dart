import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:test_app/app_config.dart';

class VehicleApiService {

  // ── Base URL for Vehicle API ────────────────────────────────────────────────
  static const String baseUrl = "${AppConfig.baseUrl}/vehicle";

  static String? _googlePlacesApiKeyCache;

  static String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Request timed out. Please check your connection and retry.';
    }
    if (msg.contains('Connection timed out') || msg.contains('errno = 110')) {
      return 'Server is unreachable. Please check your internet connection and try again.';
    }
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data.';
    }
    if (msg.contains('404')) return 'Service not found. Please contact support.';
    if (msg.contains('500')) return 'Server error. Please try again later.';
    return 'Something went wrong. Please try again.';
  }

  /// Loads the Places key from [get_google_places_key.php]; cached for the app session.
  static Future<String?> getGooglePlacesApiKey({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _googlePlacesApiKeyCache != null &&
        _googlePlacesApiKeyCache!.isNotEmpty) {
      return _googlePlacesApiKeyCache;
    }

    try {
      final uri = Uri.parse("$baseUrl/get_google_places_key.php");
      final res = await http
          .get(uri, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      final body = res.body.trim();
      if (body.isEmpty) return null;

      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      if (decoded["success"] != true) return null;

      final key = (decoded["api_key"] ?? "").toString().trim();
      if (key.isEmpty) return null;

      _googlePlacesApiKeyCache = key;
      return key;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> assignVehicleToTrip({
    required int tripId,
    required String vehicleType,
    required String vehicleNo,
    required int vehicleId,
    required String reason,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/assign_vehicle_to_trip.php");

      final request = http.MultipartRequest("POST", uri)
        ..fields["trip_id"] = tripId.toString()
        ..fields["vehicle_type"] = vehicleType
        ..fields["vehicle_no"] = vehicleNo
        ..fields["vehicle_id"] = vehicleId.toString()
        ..fields["reason"] = reason;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.body.trim().isEmpty) throw Exception('No response from server.');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> changeVehicleByManager({
    required int tripId,
    required String currentVehicleType,
    required String selectedVehicleType,
    required String vehicleNo,
    required int vehicleId,
    String reason = "Changed by manager",
  }) async {
    final fixedType = currentVehicleType.trim().toLowerCase();
    final selectedType = selectedVehicleType.trim().toLowerCase();
    if (fixedType.isNotEmpty && fixedType != selectedType) {
      throw Exception("Only $currentVehicleType type can be changed");
    }

    return assignVehicleToTrip(
      tripId: tripId,
      vehicleType: selectedVehicleType.trim(),
      vehicleNo: vehicleNo.trim(),
      vehicleId: vehicleId,
      reason: reason,
    );
  }

  static Future<Map<String, dynamic>> changePersonalRequestVehicle({
    required int requestId,
    required String currentVehicleType,
    required String selectedVehicleType,
    required String vehicleNo,
    required int vehicleId,
    String reason = "Changed by manager",
  }) async {
    final fixedType = currentVehicleType.trim().toLowerCase();
    final selectedType = selectedVehicleType.trim().toLowerCase();
    if (fixedType.isNotEmpty && fixedType != selectedType) {
      throw Exception("Only $currentVehicleType type can be changed");
    }

    try {
      final uri = Uri.parse("$baseUrl/change_personal_request_vehicle.php");
      final request = http.MultipartRequest("POST", uri)
        ..fields["request_id"] = requestId.toString()
        ..fields["vehicle_type"] = selectedVehicleType.trim()
        ..fields["vehicle_no"] = vehicleNo.trim()
        ..fields["vehicle_id"] = vehicleId.toString()
        ..fields["reason"] = reason;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.body.trim().isEmpty) throw Exception('No response from server.');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> fetchVehicleDetails({
    required String transportServiceId,
  }) async {
    try {
      final uri = Uri.parse(
        "https://exploresuite.lk/api/transport-services/$transportServiceId/vehicle-details",
      );

      final res = await http
          .get(uri, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      final json = jsonDecode(res.body);

      if (res.statusCode != 200) {
        throw Exception(json["error"] ?? "Failed to fetch vehicle details");
      }

      return Map<String, dynamic>.from(json);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static int? transportServiceIdFromRequest(Map<String, dynamic> r) {
    for (final key in [
      "transport_service_id",
      "transportServiceId",
      "trip_id",
      "tripId",
      "request_id",
      "id",
    ]) {
      final v = r[key];
      final n = int.tryParse((v ?? "").toString());
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static Future<String?> fetchVehicleMakeModelForRequest(
    Map<String, dynamic> request,
  ) async {
    final tsId = transportServiceIdFromRequest(request);
    if (tsId == null) return null;
    try {
      final d = await fetchVehicleDetails(transportServiceId: tsId.toString());
      final make = (d["make"] ?? "").toString().trim();
      final model = (d["model"] ?? "").toString().trim();
      final name = "$make $model".trim();
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchShuttleTrips({
    required String employeeId,
    required String status,
  }) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/get_shuttle_trips.php?employee_id=$employeeId&status=$status",
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      final json = jsonDecode(res.body);

      if (json["success"] != true) {
        throw Exception(json["message"] ?? "Failed to load trips");
      }

      final List list = json["data"] ?? [];
      return list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPersonalTrips({
    required String employeeId,
    required String status,
  }) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/get_personal_trip.php?employee_id=$employeeId&status=$status",
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      final json = jsonDecode(res.body);

      if (json["success"] != true) {
        throw Exception(json["message"] ?? "Failed to load trips");
      }

      final List list = json["data"] ?? [];
      return list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTransferTrips({
    required String employeeId,
    required String status,
  }) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/get_transfer_trips.php?employee_id=$employeeId&status=$status",
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      final json = jsonDecode(res.body);

      if (json["success"] != true) {
        throw Exception(json["message"] ?? "Failed to load trips");
      }

      final List list = json["data"] ?? [];
      return list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<int> fetchShuttleAssignedCount({
    required String employeeId,
  }) async {
    final list = await fetchShuttleTrips(
      employeeId: employeeId,
      status: "ASSIGNED",
    );
    return list.length;
  }

  static Future<int> fetchTransferAssignedCount({
    required String employeeId,
  }) async {
    final list = await fetchTransferTrips(
      employeeId: employeeId,
      status: "ASSIGNED",
    );
    return list.length;
  }

  static Future<Map<String, dynamic>> generateTripCode({
    required int tripId,
    required String tripCode,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/generate_trip_code.php");

      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"tripId": tripId, "tripCode": tripCode}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> startTrip({
    required int    transportServiceId,
    required int    odometer,
    required double fuelPercent,
    required File   photoFile,
    String?         remark,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/start_trip.php");

      final req = http.MultipartRequest("POST", uri);
      req.fields["transport_service_id"] = transportServiceId.toString();
      req.fields["odometer"]             = odometer.toString();
      req.fields["fuel_percent"]         = fuelPercent.toString();
      if (remark != null && remark.isNotEmpty) req.fields["start_remark"] = remark;
      req.files.add(await http.MultipartFile.fromPath("photo", photoFile.path));

      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final body = await streamed.stream.bytesToString();

      if (body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> stopTrip({
    required int    transportServiceId,
    required int    endOdometer,
    required double endFuelPercent,
    required File   photoFile,
    String?         remark,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/stop_trip.php");

      final req = http.MultipartRequest("POST", uri);
      req.fields["transport_service_id"] = transportServiceId.toString();
      req.fields["end_odometer"]         = endOdometer.toString();
      req.fields["end_fuel_percent"]     = endFuelPercent.toString();
      if (remark != null && remark.isNotEmpty) req.fields["end_remark"] = remark;
      req.files.add(await http.MultipartFile.fromPath("photo", photoFile.path));

      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final body = await streamed.stream.bytesToString();

      if (body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getDefaultManagers({required int employeeId}) async {
    try {
      final url = Uri.parse("$baseUrl/get_default_managers.php?employee_id=$employeeId");
      final res = await http.get(url).timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> createOfficeVehicleRequest({
    required String employeeId,
    required String managerId,
    required String vehicleNo,
    required String fromDate,
    required String toDate,
    required String destination,
    required String contactNo,
    required String employeeName,
    String   reason       = "Office Service",
    String?  vehicleType,
    int?     vehicleId,
    String? remark,
    List<int> companionEmployeeIds = const [],
  }) async {
    try {
      final url = Uri.parse("$baseUrl/create_office_vehicle_request.php");

      final res = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept"       : "application/json",
            },
            body: jsonEncode({
              "employee_id"            : employeeId,
              "manager_id"             : managerId,
              "vehicle_no"             : vehicleNo,
              "from_date"              : fromDate,
              "to_date"                : toDate,
              "destination"            : destination,
              "chauffer_phone"         : contactNo,
              "chauffer_name"          : employeeName,
              "contact_no"             : contactNo,
              "reason"                 : reason,
              "vehicle_type"           : vehicleType,
              "vehicle_id"             : vehicleId,
              "companion_employee_ids" : companionEmployeeIds,
              "remark": remark ?? "",

            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> createPersonalVehicleRequest({
    required String employeeId,
    required String managerId,
    required String vehicleNo,
    required String fromDate,
    required String toDate,
    required String contactNo,
    required String employeeName,
    String reason = "Personal Service",
    String? vehicleType,
    int? vehicleId,
    String? remark,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/create_personal_vehicle_request.php");

      final res = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "contact_no": contactNo,
              "employee_id": employeeId,
              "manager_id": managerId,
              "vehicle_no": vehicleNo,
              "from_date": fromDate,
              "to_date": toDate,
              "chauffer_phone": contactNo,
              "chauffer_name": employeeName,
              "reason": reason,
              "vehicle_type": vehicleType,
              "vehicle_id": vehicleId,
              "remark": remark ?? "",

            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');

      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getMyTrips({required String employeeId}) async {
    try {
      final url = Uri.parse("$baseUrl/get_my_trips.php?employee_id=$employeeId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      final body = res.body.trim();
      if (body.isEmpty) throw Exception('No response from server.');
      if (!body.startsWith("{") && !body.startsWith("[")) {
        throw Exception('Unexpected response from server.');
      }
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> changeVehicleMidTrip({
    required int    transportServiceId,
    required int    oldEndMeter,
    required double oldEndFuel,
    required File   oldEndPhoto,
    required String newVehicleNo,
    required int    newStartMeter,
    required double newStartFuel,
    required File   newStartPhoto,
    String?         remark,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/change_vehicle_mid_trip.php");

      final req = http.MultipartRequest("POST", uri);
      req.fields["transport_service_id"] = transportServiceId.toString();
      req.fields["old_end_meter"]        = oldEndMeter.toString();
      req.fields["old_end_fuel"]         = oldEndFuel.toString();
      req.fields["new_vehicle_no"]       = newVehicleNo;
      req.fields["new_start_meter"]      = newStartMeter.toString();
      req.fields["new_start_fuel"]       = newStartFuel.toString();
      if (remark != null && remark.isNotEmpty) req.fields["remark"] = remark;
      req.files.add(await http.MultipartFile.fromPath("old_end_photo",   oldEndPhoto.path));
      req.files.add(await http.MultipartFile.fromPath("new_start_photo", newStartPhoto.path));

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();

      if (body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> endCurrentVehicle({
    required int    transportServiceId,
    required int    endMeter,
    required double endFuel,
    required File   endPhoto,
    String?         remark,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/end_current_vehicle.php");
      final req = http.MultipartRequest("POST", uri);
      req.fields["transport_service_id"] = transportServiceId.toString();
      req.fields["end_meter"]            = endMeter.toString();
      req.fields["end_fuel"]             = endFuel.toString();
      if (remark != null && remark.isNotEmpty) req.fields["end_vehicle_remark"] = remark;
      req.files.add(await http.MultipartFile.fromPath("photo", endPhoto.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> startNewVehicle({
    required int    transportServiceId,
    required String newVehicleNo,
    required int    startMeter,
    required double startFuel,
    required File   startPhoto,
    String?         remark,
    String?         destination,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/start_new_vehicle.php");
      final req = http.MultipartRequest("POST", uri);
      req.fields["transport_service_id"] = transportServiceId.toString();
      req.fields["new_vehicle_no"]       = newVehicleNo;
      req.fields["start_meter"]          = startMeter.toString();
      req.fields["start_fuel"]           = startFuel.toString();
      if (remark      != null && remark.isNotEmpty)      req.fields["remark"]      = remark;
      if (destination != null && destination.isNotEmpty) req.fields["destination"] = destination;
      req.files.add(await http.MultipartFile.fromPath("photo", startPhoto.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (body.trim().isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> cancelTrip({required String id}) async {
    try {
      final url = Uri.parse("$baseUrl/cancel_trip.php");
      final res = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({"id": int.parse(id)}),
          )
          .timeout(const Duration(seconds: 15));

      final body = res.body.trim();
      if (body.isEmpty) throw Exception('No response from server.');
      return Map<String, dynamic>.from(jsonDecode(body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> removeVehicleCompanion({
    required int transportServiceId,
    required int companionId,
    required int managerId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/remove_vehicle_companion.php");

      final res = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept"       : "application/json",
            },
            body: jsonEncode({
              "transport_service_id": transportServiceId,
              "companion_id"        : companionId,
              "manager_id"          : managerId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> fetchManagerVehicleRequests({
    required String managerId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_manager_vehicle_requests.php?manager_id=$managerId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = jsonDecode(res.body);
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load requests");
      }
      return List<Map<String, dynamic>>.from(decoded["data"] ?? []);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> fetchManagerPersonalRequests({
    required String managerId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/get_manager_personal_request.php?manager_id=$managerId");
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = jsonDecode(res.body);
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Failed to load requests");
      }
      return List<Map<String, dynamic>>.from(decoded["data"] ?? []);
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// HOD-approved personal trips for General Manager.
  ///
  /// **Do not send [userId]** unless your PHP uses it only for auth/audit. Many backends
  /// incorrectly add `AND e.employee_id = user_id`, which hides every request not filed
  /// by that employee (empty inbox for the GM).
static Future<List<Map<String, dynamic>>> fetchGeneralManagerPersonalRequests({
  String? userId,
}) async {
  try {
    final base = Uri.parse("$baseUrl/get_general_manager_personal_vehicle_request.php");
    final url  = (userId != null && userId.isNotEmpty)
        ? base.replace(queryParameters: {"user_id": userId})
        : base;

    final res = await http
        .get(url, headers: {"Accept": "application/json"})
        .timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) throw Exception('No response from server.');
    final decoded = jsonDecode(res.body);
    if (decoded["success"] != true) {
      throw Exception(decoded["message"] ?? "Failed to load requests");
    }
    return List<Map<String, dynamic>>.from(decoded["data"] ?? []);
  } on TimeoutException {
    throw Exception('Request timed out.');
  } catch (e) {
    throw Exception(_friendlyError(e));
  }
}
  /// Calls approve endpoint. PHP expects `hod_comment` (manager/HOD note on forward step).
  /// Response [data] may include `trip_code` only after final approval (e.g. GM step for personal).
  static Future<Map<String, dynamic>> approveVehicleRequest({
    required int requestId,
    String? hodComment,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/approve_vehicle_request.php");
      final note = (hodComment ?? "").trim();
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"request_id": requestId, "hod_comment": note}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Approve failed");
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Trip code from API [data], if server generated one (not sent on HOD forward-only step).
  static String? tripCodeFromApproveResponse(Map<String, dynamic> decoded) {
    final data = decoded["data"];
    if (data is! Map) return null;
    final t = data["trip_code"];
    if (t == null) return null;
    final s = t.toString().trim();
    return s.isEmpty ? null : s;
  }

  static Future<void> rejectVehicleRequest({
    required int requestId,
    required String comment,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/reject_vehicle_request.php");
      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json", "Accept": "application/json"},
            body: jsonEncode({"request_id": requestId, "comment": comment}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final decoded = jsonDecode(res.body);
      if (decoded["success"] != true) {
        throw Exception(decoded["message"] ?? "Reject failed");
      }
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<int> getPersonalUsageCount(String employeeId) async {
    try {
      final url = Uri.parse("$baseUrl/get_personal_usage_count.php?employee_id=$employeeId");
      final res = await http.get(url).timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      final json = jsonDecode(res.body);
      if (json["success"] != true) {
        throw Exception(json["message"] ?? "Failed to fetch usage count");
      }
      return json["data"]["count"] ?? 0;
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getManagerOfficeTransportSummary({
    required int managerId,
  }) async {
    try {
      final url = Uri.parse(
        "$baseUrl/get_office_vehicle_summary.php?manager_id=$managerId",
      );
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getGeneralManagerPersonalTransportSummary() async {
    try {
      final url = Uri.parse(
        "$baseUrl/get_general_manager_personal_vehicle_summary.php",
      );
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getManagerPersonalTransportSummary({
    required int managerId,
  }) async {
    try {
      final url = Uri.parse(
        "$baseUrl/get_personal_vehicle_summary.php?manager_id=$managerId",
      );
      final res = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 15));

      if (res.body.trim().isEmpty) throw Exception('No response from server.');
      if (res.statusCode != 200) throw Exception('Server error (${res.statusCode}).');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } on TimeoutException {
      throw Exception('Request timed out. Please check your connection and retry.');
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
