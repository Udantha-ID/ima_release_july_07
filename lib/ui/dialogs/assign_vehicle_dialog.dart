import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import '../../Services/transport_service_config.dart';

class AvailableVehicleOption {
  final int id;
  final String regNo;
  final String make;
  final String model;
  final String vehicleTypeName;

  AvailableVehicleOption({
    required this.id,
    required this.regNo,
    required this.make,
    required this.model,
    required this.vehicleTypeName,
  });

  factory AvailableVehicleOption.fromJson(Map<String, dynamic> json) {
    return AvailableVehicleOption(
      id: int.tryParse((json["id"] ?? "").toString()) ?? 0,
      regNo: (json["reg_no"] ?? "").toString().trim(),
      make: (json["make"] ?? "").toString().trim(),
      model: (json["model"] ?? "").toString().trim(),
      vehicleTypeName: (json["vehicle_type_name"] ?? "").toString().trim(),
    );
  }

  String get displayLabel => "$regNo - ${"$make $model".trim()}";
}

Future<void> showAssignVehicleDialog({
  required BuildContext context,
  required String vehicleType,
  required String title,
  required String assignedStartAt,
  required String assignedEndAt,
  required int? transportServiceId,
  required Future<void> Function({
    required String vehicleType,
    required String vehicleNo,
    required int vehicleId,
    required String reason,
  }) onConfirm,
}) async {
  final availableVehicleController = TextEditingController();
  final reasonController = TextEditingController();
  final vehicleTypeController = TextEditingController(text: vehicleType);
  final formKey = GlobalKey<FormState>();

  bool submitting = false;
  bool isLoadingVehicles = false;
  String? vehicleError;
  int checkGeneration = 0;
  List<AvailableVehicleOption> availableVehicles = [];
  AvailableVehicleOption? selectedVehicle;
  bool didInitialFetch = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.90).clamp(300.0, 430.0);

      return StatefulBuilder(
        builder: (context, setState) {
          String _toApiDate(String value) {
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

          Future<void> fetchAvailableVehicles() async {
            final gen = ++checkGeneration;
            setState(() {
              isLoadingVehicles = true;
              vehicleError = null;
              availableVehicles = [];
              selectedVehicle = null;
              availableVehicleController.clear();
            });

            try {
              final start = _toApiDate(assignedStartAt);
              final end = _toApiDate(assignedEndAt);
              if (start.isEmpty || end.isEmpty) {
                setState(() {
                  vehicleError = "Invalid assigned date range for this trip.";
                  isLoadingVehicles = false;
                });
                return;
              }

              final uri = Uri.parse(TransportServiceConfig.availableVehiclesUrl).replace(
                queryParameters: {"start_date": start, "end_date": end},
              );
              final response = await http.get(uri, headers: const {"Accept": "application/json"});

              if (gen != checkGeneration) return;
              final body = response.body.trim();
              if (body.isEmpty) {
                setState(() {
                  vehicleError = "No response from server.";
                  isLoadingVehicles = false;
                });
                return;
              }

              final payload = Map<String, dynamic>.from(jsonDecode(body) as Map);
              final requiredType = vehicleType.trim().toLowerCase();
              final list = (payload["data"] as List? ?? [])
                  .whereType<Map>()
                  .map((e) => AvailableVehicleOption.fromJson(Map<String, dynamic>.from(e)))
                  .where((e) {
                    if (requiredType.isEmpty) return true;
                    return e.vehicleTypeName.trim().toLowerCase() == requiredType;
                  })
                  .where((e) => e.regNo.isNotEmpty)
                  .toList();

              if (payload["success"] != true) {
                setState(() {
                  vehicleError = (payload["message"] ?? "Could not load vehicles.").toString();
                  isLoadingVehicles = false;
                });
                return;
              }

              setState(() {
                availableVehicles = list;
                vehicleError = list.isEmpty
                    ? "No available vehicles found for assigned dates with type: $vehicleType."
                    : null;
                isLoadingVehicles = false;
              });
            } catch (_) {
              if (gen != checkGeneration) return;
              setState(() {
                vehicleError = "Could not load available vehicles. Please try again.";
                isLoadingVehicles = false;
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
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header ──
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Assign Vehicle",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      submitting ? null : () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title == "Change Vehicle"
                                  ? "Vehicle type is fixed for this trip. Select a new available vehicle for assigned dates and enter reason."
                                  : "Vehicle type is fixed for this trip. Select an available vehicle for assigned dates and enter reason.",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Vehicle Type (read-only) ──
                            const Text(
                              "Vehicle Type",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: vehicleTypeController,
                              readOnly: true,
                              decoration: _fieldDecoration("Vehicle type"),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Vehicle type is required"
                                      : null,
                            ),
                            const SizedBox(height: 14),

                            // ── Vehicle Number ──
                            const Text(
                              "Available Vehicle",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TypeAheadField<AvailableVehicleOption>(
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
                                  final full = "${vehicle.regNo} ${vehicle.make} ${vehicle.model} ${vehicle.vehicleTypeName}".toLowerCase();
                                  return full.contains(q);
                                }).toList();
                              },
                              itemBuilder: (context, suggestion) => ListTile(
                                dense: true,
                                tileColor: Colors.white,
                                title: Text(
                                  suggestion.displayLabel,
                                  style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                                ),
                                subtitle: Text(
                                  suggestion.vehicleTypeName,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ),
                              onSelected: (suggestion) {
                                setState(() {
                                  selectedVehicle = suggestion;
                                  availableVehicleController.text = suggestion.displayLabel;
                                  vehicleTypeController.text = suggestion.vehicleTypeName;
                                  vehicleError = null;
                                });
                              },
                              builder: (context, controller, focusNode) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: _fieldDecoration("Search vehicle by number or model"),
                                  validator: (_) {
                                    if (isLoadingVehicles) return "Please wait for vehicles to load";
                                    if (vehicleError != null) return vehicleError;
                                    if (selectedVehicle == null) return "Please select an available vehicle";
                                    final selectedType = selectedVehicle!.vehicleTypeName.trim().toLowerCase();
                                    final fixedType = vehicleType.trim().toLowerCase();
                                    if (fixedType.isNotEmpty && selectedType != fixedType) {
                                      return "Selected vehicle type must be $vehicleType";
                                    }
                                    return null;
                                  },
                                );
                              },
                              emptyBuilder: (context) => const Padding(
                                padding: EdgeInsets.all(10),
                                child: Text("No matching vehicles found."),
                              ),
                            ),

                            // ── Validation feedback ──
                            if (isLoadingVehicles)
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
                            if (!isLoadingVehicles && vehicleError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        vehicleError!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!isLoadingVehicles && selectedVehicle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        color: Colors.green, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Selected: ${selectedVehicle!.regNo} · Type: ${selectedVehicle!.vehicleTypeName}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 14),

                            // ── Reason / Note ──
                            const Text(
                              "Reason / Note",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: reasonController,
                              maxLines: 3,
                              decoration:
                                  _fieldDecoration("Enter reason / note"),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Reason is required"
                                      : null,
                            ),

                            const SizedBox(height: 18),

                            // ── Action buttons ──
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
                                        color:
                                            Color.fromARGB(255, 196, 196, 196),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: (submitting ||
                                                isLoadingVehicles ||
                                                selectedVehicle == null)
                                            ? const [
                                                Color(0xFFBDBDBD),
                                                Color(0xFF9E9E9E)
                                              ]
                                            : const [
                                                Color(0xFF0060A6),
                                                Color(0xFF003580)
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (submitting ||
                                              isLoadingVehicles ||
                                              selectedVehicle == null)
                                          ? null
                                          : () async {
                                              if (!formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }
                                              setState(
                                                  () => submitting = true);
                                              try {
                                                await onConfirm(
                                                  vehicleType:
                                                      vehicleTypeController
                                                          .text
                                                          .trim(),
                                                  vehicleNo: selectedVehicle!.regNo,
                                                  vehicleId: selectedVehicle!.id,
                                                  reason: reasonController
                                                      .text
                                                      .trim(),
                                                );
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx);
                                                }
                                              } catch (e) {
                                                setState(() =>
                                                    submitting = false);
                                                ScaffoldMessenger.of(ctx)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        "Failed to assign vehicle: $e"),
                                                  ),
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
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
                                          : Text(
                                              title == "Change Vehicle"
                                                  ? "Change"
                                                  : "Assign",
                                              style: const TextStyle(
                                                  color: Colors.white),
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
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
