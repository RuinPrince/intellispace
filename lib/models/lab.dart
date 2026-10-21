import 'device.dart';

class Lab {
  final String id;
  final String name;
  final String building;
  final String floor;
  final String roomNumber;
  final List<Device> devices;

  Lab({
    required this.id,
    required this.name,
    required this.building,
    required this.floor,
    required this.roomNumber,
    required this.devices,
  });

  factory Lab.fromJson(Map<String, dynamic> json) {
    return Lab(
      id: json['id']?.toString() ?? '',
      name: json['lab_name'] ?? '',
      building: json['building'] ?? '',
      floor: json['floor'] ?? '',
      roomNumber: json['room_number'] ?? '',
      devices: [], // Usually populated by separate calls
    );
  }
}
