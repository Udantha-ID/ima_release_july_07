import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import '../../Services/transport_service_config.dart';

class ManagerVehicleOption {
  final int id;
  final String regNo;
  final String make;
  final String model;
  final String vehicleTypeName;

  ManagerVehicleOption({
    required this.id,
    required this.regNo,
    required this.make,
    required this.model,
    required this.vehicleTypeName,
  });

  factory ManagerVehicleOption.fromJson(Map<String, dynamic> json) {
    return ManagerVehicleOption(
      id: int.tryParse((json["id"] ?? "").toString()) ?? 0,
      regNo: (json["reg_no"] ?? "").toString().trim(),
      make: (json["make"] ?? "").toString().trim(),
      model: (json["model"] ?? "").toString().trim(),
      vehicleTypeName: (json["vehicle_type_name"] ?? "").toString().trim(),
    );
  }

  String get displayLabel => "$regNo - ${"$make $model".trim()}";
}

Future<void> showManagerVehicleChangeDialog({
  required BuildContext context,
  required String currentVehicleType,
  required String fromDate,
  required String toDate,
  required Future<void> Function({
    required String vehicleType,
    required String vehicleNo,
    required int vehicleId,
  }) onConfirm,
}) async {
  final availableVehicleController = TextEditingController();
  bool submitting = false;
  bool loadingVehicles = false;
  String? vehicleError;
  int checkGeneration = 0;
  List<ManagerVehicleOption> availableVehicles = [];
  ManagerVehicleOption? selectedVehicle;
  bool didInitialFetch = false;

  String toApiDate(String value) {
    final v = value.trim();
    if (v.length >= 10) {
      final head = v.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(head)) return head;
    }
    final parsed = DateTime.tryParse(v);
    if (parsed != null) {
      final mm = parsed.month.toString().padLeft(2, "0");
      final dd = parsed.day.toString().padLeft(2, "0");
      return "${parsed.year}-$mm-$dd";
    }
    return "";
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.90).clamp(300.0, 430.0);

      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> fetchAvailableVehicles() async {
            final gen = ++checkGeneration;
            setState(() {
              loadingVehicles = true;
              vehicleError = null;
              availableVehicles = [];
              selectedVehicle = null;
              availableVehicleController.clear();
            });

            try {
              final start = toApiDate(fromDate);
              final end = toApiDate(toDate);
              if (start.isEmpty || end.isEmpty) {
                setState(() {
                  vehicleError = "Invalid request date range.";
                  loadingVehicles = false;
                });
                return;
              }

              final uri = Uri.parse(
                TransportServiceConfig.availableVehiclesUrl,
              ).replace(queryParameters: {"start_date": start, "end_date": end});

              final response = await http.get(
                uri,
                headers: const {"Accept": "application/json"},
              );

              if (gen != checkGeneration) return;
              final body = response.body.trim();
              if (body.isEmpty) {
                setState(() {
                  vehicleError = "No response from server.";
                  loadingVehicles = false;
                });
                return;
              }

              final payload = Map<String, dynamic>.from(jsonDecode(body) as Map);
              final currentType = currentVehicleType.trim().toLowerCase();
              final list = (payload["data"] as List? ?? [])
                  .whereType<Map>()
                  .map(
                    (e) => ManagerVehicleOption.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .where((e) => e.regNo.isNotEmpty)
                  .where((e) {
                    if (currentType.isEmpty) return true;
                    return e.vehicleTypeName.trim().toLowerCase() == currentType;
                  })
                  .toList();

              if (payload["success"] != true) {
                setState(() {
                  vehicleError =
                      (payload["message"] ?? "Could not load vehicles.")
                          .toString();
                  loadingVehicles = false;
                });
                return;
              }

              setState(() {
                availableVehicles = list;
                vehicleError = list.isEmpty
                    ? (currentVehicleType.trim().isEmpty
                        ? "No available vehicles found."
                        : "No available $currentVehicleType vehicles found.")
                    : null;
                loadingVehicles = false;
              });
            } catch (_) {
              if (gen != checkGeneration) return;
              setState(() {
                vehicleError = "Could not load vehicles. Please try again.";
                loadingVehicles = false;
              });
            }
          }

          if (!didInitialFetch) {
            didInitialFetch = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              fetchAvailableVehicles();
            });
          }

          return Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.transparent),
              ),
              Center(
                child: Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: dialogW,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz_rounded,
                                color: Color(0xFF1565C0),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Change Vehicle",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentVehicleType.trim().isEmpty
                                ? "Select an available vehicle to change."
                                : "Only $currentVehicleType type vehicles are allowed.",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAFF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDDE7F7)),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  "Current type",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  currentVehicleType.trim().isEmpty
                                      ? "-"
                                      : currentVehicleType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Available Vehicle",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TypeAheadField<ManagerVehicleOption>(
                            controller: availableVehicleController,
                            hideOnEmpty: true,
                            hideOnError: false,
                            hideOnUnfocus: false,
                            hideWithKeyboard: false,
                            decorationBuilder: (context, child) => Material(
                              color: Colors.white,
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: child,
                            ),
                            suggestionsCallback: (pattern) {
                              final q = pattern.trim().toLowerCase();
                              if (q.isEmpty) return availableVehicles;
                              return availableVehicles.where((vehicle) {
                                final full =
                                    "${vehicle.regNo} ${vehicle.make} ${vehicle.model} ${vehicle.vehicleTypeName}"
                                        .toLowerCase();
                                return full.contains(q);
                              }).toList();
                            },
                            itemBuilder: (context, suggestion) => ListTile(
                              dense: true,
                              tileColor: Colors.white,
                              title: Text(
                                suggestion.displayLabel,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                suggestion.vehicleTypeName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            onSelected: (suggestion) {
                              setState(() {
                                selectedVehicle = suggestion;
                                availableVehicleController.text =
                                    suggestion.displayLabel;
                                vehicleError = null;
                              });
                            },
                            builder: (context, controller, focusNode) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: _fieldDecoration(
                                  "Search by number or model",
                                ),
                              );
                            },
                            emptyBuilder: (context) => const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text("No matching vehicles found."),
                            ),
                          ),
                          if (loadingVehicles)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Loading available vehicles...",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!loadingVehicles && vehicleError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                vehicleError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (!loadingVehicles && selectedVehicle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "Selected: ${selectedVehicle!.regNo}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: submitting
                                      ? null
                                      : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0060A6),
                                    side: const BorderSide(
                                      color: Color.fromARGB(255, 196, 196, 196),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text("Cancel"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors:
                                          (submitting ||
                                              loadingVehicles ||
                                              selectedVehicle == null)
                                          ? const [
                                              Color(0xFFBDBDBD),
                                              Color(0xFF9E9E9E),
                                            ]
                                          : const [
                                              Color(0xFF0060A6),
                                              Color(0xFF003580),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
                                    onPressed:
                                        (submitting ||
                                            loadingVehicles ||
                                            selectedVehicle == null)
                                        ? null
                                        : () async {
                                            final selectedType = selectedVehicle!
                                                .vehicleTypeName
                                                .trim()
                                                .toLowerCase();
                                            final fixedType = currentVehicleType
                                                .trim()
                                                .toLowerCase();
                                            if (fixedType.isNotEmpty &&
                                                selectedType != fixedType) {
                                              setState(() {
                                                vehicleError =
                                                    "Only $currentVehicleType type is allowed.";
                                              });
                                              return;
                                            }
                                            setState(() => submitting = true);
                                            try {
                                              await onConfirm(
                                                vehicleType: selectedVehicle!
                                                    .vehicleTypeName
                                                    .trim(),
                                                vehicleNo: selectedVehicle!.regNo,
                                                vehicleId: selectedVehicle!.id,
                                              );
                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
                                              }
                                            } catch (_) {
                                              setState(
                                                () => submitting = false,
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: 0,
                                    ),
                                    child: submitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Change",
                                            style: TextStyle(color: Colors.white),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.4),
    ),
  );
}
