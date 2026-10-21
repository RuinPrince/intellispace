import '../core/constants/app_constants.dart';

class Device {
  final String id;
  final String name;
  final String type;
  final String location;
  final bool isOn;
  final DeviceStatus status;
  final DateTime lastUpdated;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.isOn,
    required this.status,
    required this.lastUpdated,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    DeviceStatus devStatus = DeviceStatus.offline;
    if (json['status'] == 'online') {
      devStatus = DeviceStatus.online;
    }

    return Device(
      id: json['id']?.toString() ?? '',
      name: json['device_name'] ?? '',
      type: json['device_type'] ?? '',
      location: json['labs'] != null && json['labs']['lab_name'] != null
          ? json['labs']['lab_name']
          : (json['lab_name'] ?? 'Unknown Location'),
      isOn: json['power_state'] == 'ON',
      status: devStatus,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.tryParse(json['last_updated']) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}
