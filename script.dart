import 'dart:io';

void main() {
  final files = {
    'lib/models/sensor.dart': '''
import '../core/constants/app_constants.dart';

class Sensor {
  final String id;
  final String name;
  final String category;
  final String location;
  final double? value;
  final String? stringValue;
  final String unit;
  final SensorStatus status;
  final DateTime lastUpdated;

  Sensor({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    this.value,
    this.stringValue,
    required this.unit,
    required this.status,
    required this.lastUpdated,
  });
}
''',
    'lib/models/device.dart': '''
import '../core/constants/app_constants.dart';

class Device {
  final String id;
  final String name;
  final DeviceType type;
  bool isSwitchedOn;
  final SensorStatus status;

  Device({
    required this.id,
    required this.name,
    required this.type,
    this.isSwitchedOn = false,
    this.status = SensorStatus.online,
  });
}
''',
    'lib/models/lab.dart': '''
import 'device.dart';

class Lab {
  final String id;
  final String name;
  final List<Device> devices;

  Lab({
    required this.id,
    required this.name,
    required this.devices,
  });
}
''',
    'lib/models/energy_reading.dart': '''
class EnergyReading {
  final DateTime time;
  final double value;

  EnergyReading({
    required this.time,
    required this.value,
  });
}

class EnergyPrediction {
  final DateTime time;
  final double predictedValue;
  final double lowerBound;
  final double upperBound;

  EnergyPrediction({
    required this.time,
    required this.predictedValue,
    required this.lowerBound,
    required this.upperBound,
  });
}
''',
    'lib/models/attendance_record.dart': '''
class Student {
  final String id;
  final String name;
  final String registerNumber;
  final String department;

  Student({
    required this.id,
    required this.name,
    required this.registerNumber,
    required this.department,
  });
}

class AttendanceRecord {
  final String id;
  final Student student;
  final DateTime timestamp;
  final bool isPresent;
  final String? remarks;

  AttendanceRecord({
    required this.id,
    required this.student,
    required this.timestamp,
    required this.isPresent,
    this.remarks,
  });
}
''',
    'lib/models/camera.dart': '''
import '../core/constants/app_constants.dart';

class Camera {
  final String id;
  final String name;
  final String location;
  final SensorStatus status;
  final DateTime lastActivity;
  final String streamUrl;

  Camera({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.lastActivity,
    this.streamUrl = '',
  });
}

class SecurityEvent {
  final String id;
  final String cameraId;
  final String title;
  final SeverityLevel severity;
  final DateTime timestamp;
  final String status;

  SecurityEvent({
    required this.id,
    required this.cameraId,
    required this.title,
    required this.severity,
    required this.timestamp,
    required this.status,
  });
}
''',
    'lib/models/notification_item.dart': '''
import '../core/constants/app_constants.dart';

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String category;
  final SeverityLevel severity;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
    required this.severity,
    this.isRead = false,
  });
}
''',
    'lib/repositories/mock_sensor_repository.dart': '''
import '../models/sensor.dart';
import '../core/constants/app_constants.dart';

class MockSensorRepository {
  List<Sensor> getSensors() {
    return [
      Sensor(id: 's1', name: 'Temp Sensor 1', category: 'Environment', location: 'Lab 1', value: 27.4, unit: 'C', status: SensorStatus.online, lastUpdated: DateTime.now()),
      Sensor(id: 's2', name: 'Humidity 1', category: 'Environment', location: 'Lab 1', value: 61.0, unit: '%', status: SensorStatus.online, lastUpdated: DateTime.now()),
      Sensor(id: 's3', name: 'Motion 1', category: 'Motion', location: 'Lab 1', stringValue: 'Detected', unit: '', status: SensorStatus.online, lastUpdated: DateTime.now()),
      Sensor(id: 's4', name: 'Light 1', category: 'Light', location: 'Lab 1', stringValue: 'ON', unit: '', status: SensorStatus.online, lastUpdated: DateTime.now()),
      Sensor(id: 's5', name: 'Temp Sensor 2', category: 'Environment', location: 'Physics Lab', value: null, unit: 'C', status: SensorStatus.offline, lastUpdated: DateTime.now().subtract(const Duration(hours: 2))),
    ];
  }
}
''',
    'lib/repositories/mock_device_repository.dart': '''
import '../models/device.dart';
import '../models/lab.dart';
import '../core/constants/app_constants.dart';

class MockDeviceRepository {
  List<Lab> getLabs() {
    return [
      Lab(
        id: 'l1',
        name: 'Lab 1',
        devices: [
          Device(id: 'd1_1', name: 'Lights', type: DeviceType.light, isSwitchedOn: true),
          Device(id: 'd1_2', name: 'Fans', type: DeviceType.fan, isSwitchedOn: false),
          Device(id: 'd1_3', name: 'AC', type: DeviceType.ac, isSwitchedOn: true),
          Device(id: 'd1_4', name: 'Projector', type: DeviceType.projector, isSwitchedOn: false),
          Device(id: 'd1_5', name: 'Main Power', type: DeviceType.power, isSwitchedOn: true),
        ],
      ),
      Lab(
        id: 'l2',
        name: 'Lab 2',
        devices: [
          Device(id: 'd2_1', name: 'Lights', type: DeviceType.light, isSwitchedOn: false),
          Device(id: 'd2_2', name: 'Fans', type: DeviceType.fan, isSwitchedOn: false),
          Device(id: 'd2_3', name: 'AC', type: DeviceType.ac, isSwitchedOn: false),
          Device(id: 'd2_4', name: 'Projector', type: DeviceType.projector, isSwitchedOn: false),
          Device(id: 'd2_5', name: 'Main Power', type: DeviceType.power, isSwitchedOn: false),
        ],
      ),
    ];
  }
}
''',
    'lib/repositories/mock_energy_repository.dart': '''
import '../models/energy_reading.dart';

class MockEnergyRepository {
  List<EnergyReading> getTodayReadings() {
    final now = DateTime.now();
    return List.generate(24, (index) {
      final hour = index;
      double value = 20.0 + (hour > 8 && hour < 18 ? 40.0 : 0.0);
      if (hour == 14) value = 61.4; // Peak
      return EnergyReading(
        time: DateTime(now.year, now.month, now.day, hour),
        value: value,
      );
    });
  }

  List<EnergyPrediction> getPredictions() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return List.generate(24, (index) {
      final hour = index;
      double value = 22.0 + (hour > 8 && hour < 18 ? 45.0 : 0.0);
      if (hour == 14) value = 68.2; // Predicted Peak
      return EnergyPrediction(
        time: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour),
        predictedValue: value,
        lowerBound: value * 0.9,
        upperBound: value * 1.1,
      );
    });
  }
}
''',
    'lib/repositories/mock_attendance_repository.dart': '''
import '../models/attendance_record.dart';

class MockAttendanceRepository {
  List<AttendanceRecord> getTodayAttendance() {
    final students = [
      Student(id: 'st1', name: 'Alice Smith', registerNumber: 'CS101', department: 'Computer Science'),
      Student(id: 'st2', name: 'Bob Johnson', registerNumber: 'CS102', department: 'Computer Science'),
      Student(id: 'st3', name: 'Charlie Brown', registerNumber: 'CS103', department: 'Computer Science'),
    ];
    
    final now = DateTime.now();
    return [
      AttendanceRecord(id: 'a1', student: students[0], timestamp: now, isPresent: true),
      AttendanceRecord(id: 'a2', student: students[1], timestamp: now, isPresent: true),
      AttendanceRecord(id: 'a3', student: students[2], timestamp: now, isPresent: false, remarks: 'Absent'),
    ];
  }
}
''',
    'lib/repositories/mock_security_repository.dart': '''
import '../models/camera.dart';
import '../core/constants/app_constants.dart';

class MockSecurityRepository {
  List<Camera> getCameras() {
    return [
      Camera(id: 'c1', name: 'Main Gate', location: 'Entrance', status: SensorStatus.online, lastActivity: DateTime.now()),
      Camera(id: 'c2', name: 'Block A Corridor', location: 'Block A', status: SensorStatus.online, lastActivity: DateTime.now()),
      Camera(id: 'c3', name: 'Lab 1', location: 'Lab 1', status: SensorStatus.online, lastActivity: DateTime.now()),
      Camera(id: 'c4', name: 'Lab 2', location: 'Lab 2', status: SensorStatus.online, lastActivity: DateTime.now()),
      Camera(id: 'c5', name: 'Parking Area', location: 'Parking', status: SensorStatus.offline, lastActivity: DateTime.now().subtract(const Duration(hours: 12))),
    ];
  }

  List<SecurityEvent> getEvents() {
    return [
      SecurityEvent(id: 'e1', cameraId: 'c3', title: 'Unauthorized movement detected', severity: SeverityLevel.critical, timestamp: DateTime.now().subtract(const Duration(minutes: 5)), status: 'Active'),
      SecurityEvent(id: 'e2', cameraId: 'c1', title: 'Person detected in restricted zone', severity: SeverityLevel.warning, timestamp: DateTime.now().subtract(const Duration(hours: 1)), status: 'Resolved'),
      SecurityEvent(id: 'e3', cameraId: 'c5', title: 'Camera disconnected', severity: SeverityLevel.critical, timestamp: DateTime.now().subtract(const Duration(hours: 12)), status: 'Active'),
    ];
  }
}
''',
    'lib/repositories/mock_notification_repository.dart': '''
import '../models/notification_item.dart';
import '../core/constants/app_constants.dart';

class MockNotificationRepository {
  List<NotificationItem> getNotifications() {
    return [
      NotificationItem(id: 'n1', title: 'Security Alert', description: 'Unauthorized movement detected in Lab 3', timestamp: DateTime.now().subtract(const Duration(minutes: 5)), category: 'Security', severity: SeverityLevel.critical),
      NotificationItem(id: 'n2', title: 'Energy Alert', description: 'Energy consumption exceeded expected threshold', timestamp: DateTime.now().subtract(const Duration(hours: 2)), category: 'Energy', severity: SeverityLevel.warning),
      NotificationItem(id: 'n3', title: 'Device Alert', description: 'Temperature sensor offline in Physics Lab', timestamp: DateTime.now().subtract(const Duration(hours: 5)), category: 'Device', severity: SeverityLevel.warning, isRead: true),
      NotificationItem(id: 'n4', title: 'Attendance', description: 'Attendance synchronization completed', timestamp: DateTime.now().subtract(const Duration(days: 1)), category: 'Attendance', severity: SeverityLevel.info, isRead: true),
    ];
  }
}
''',
    'lib/core/widgets/status_card.dart': '''
import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Icon(icon, color: iconColor, size: 24),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
''',
    'lib/core/widgets/device_toggle.dart': '''
import 'package:flutter/material.dart';

class DeviceToggle extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSwitchedOn;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const DeviceToggle({
    super.key,
    required this.name,
    required this.icon,
    required this.isSwitchedOn,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSwitchedOn ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              isSwitchedOn ? 'ON' : 'OFF',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSwitchedOn ? activeColor : null,
                  ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isSwitchedOn,
              onChanged: onChanged,
              activeColor: activeColor,
            ),
          ],
        ),
      ),
    );
  }
}
'''
  };

  files.forEach((path, content) {
    File(path).writeAsStringSync(content);
  });
}
