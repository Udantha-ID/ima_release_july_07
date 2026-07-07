class VehicleQrModel {
  final bool status;
  final String message;
  final VehicleQrData? data;

  VehicleQrModel({
    required this.status,
    required this.message,
    this.data,
  });

  factory VehicleQrModel.fromJson(Map<String, dynamic> json) {
    return VehicleQrModel(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? VehicleQrData.fromJson(json['data'])
          : null,
    );
  }
}

class VehicleQrData {
  final String vehicleNumber;
  final String companyName;
  final String image;

  VehicleQrData({
    required this.vehicleNumber,
    required this.companyName,
    required this.image,
  });

  factory VehicleQrData.fromJson(Map<String, dynamic> json) {
    return VehicleQrData(
      vehicleNumber: json['vehicle_number'] ?? '',
      companyName: json['company_name'] ?? '',
      image: json['image'] ?? '',
    );
  }
}