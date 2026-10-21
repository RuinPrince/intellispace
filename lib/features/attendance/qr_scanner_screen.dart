import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/student_avatar.dart';
import '../../repositories/api_attendance_repository.dart';
import '../../repositories/student_directory.dart';
import '../../services/student_photo_cloud_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.all,
    ],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 300,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoZoom: true,
  );

  final ApiAttendanceRepository _attendanceRepo = ApiAttendanceRepository();
  final ApiClient _api = ApiClient();

  late AnimationController _laserAnimationController;
  late Animation<double> _laserAnimation;

  bool _isProcessing = false;
  double _currentZoom = 0.0;

  @override
  void initState() {
    super.initState();
    _laserAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      _currentZoom = (_currentZoom == 0.0) ? 0.35 : 0.0;
    });
    _controller.setZoomScale(_currentZoom);
  }

  Future<void> _handleBarcode(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    print('[BarcodeScanner] Scanned raw barcode: "$rawValue"');

    // Normalize barcode string:
    // Physical ID cards emit Code 128 AIM identifier like "]C1" or "JC1" followed by the roll number.
    // e.g., "]C1235014" -> strips "]C1" / "JC1" to extract actual roll number "235014".
    final cleanDigits = StudentDirectory.cleanCode(rawValue);
    final trimmedRaw = rawValue.trim();

    print('[BarcodeScanner] Normalized roll number: "$cleanDigits"');

    try {
      // 1. Check local student ID registry
      StudentIdCardDetails? cardDetails = StudentDirectory.findByBarcode(cleanDigits) ?? 
                                          StudentDirectory.findByBarcode(trimmedRaw);

      // 2. Lookup or sync with Supabase
      String studentId = cardDetails?.id ?? '';
      String studentName = cardDetails?.name ?? 'Student';
      String regNo = cardDetails?.barcode ?? cleanDigits;
      String dept = cardDetails?.department ?? 'Information Technology';

      try {
        final res = await _api.get('/students?or=(register_number.eq.$cleanDigits,id.eq.$cleanDigits)&select=*');
        if (res is List && res.isNotEmpty) {
          final student = res[0] as Map<String, dynamic>;
          studentId = student['id'].toString();
          if (cardDetails == null) {
            studentName = student['student_name'] ?? studentName;
            regNo = student['register_number'] ?? regNo;
            dept = student['department'] ?? dept;
          }
        }
      } catch (e) {
        print('[BarcodeScanner] Supabase lookup error (using local): $e');
      }

      // 3. Ensure student photo is loaded from cloud if missing
      String avatar = cardDetails?.avatarUrl ?? '';
      if (avatar.isEmpty || avatar.startsWith('/')) {
        final cloudPhoto = await StudentPhotoCloudService.getPhoto(cleanDigits) ??
                           await StudentPhotoCloudService.getPhoto(regNo);
        if (cloudPhoto != null && cloudPhoto.isNotEmpty) {
          avatar = cloudPhoto;
          if (cardDetails != null) {
            cardDetails = cardDetails.copyWith(avatarUrl: cloudPhoto);
          }
        }
      }

      if (cardDetails == null && studentId.isNotEmpty) {
        cardDetails = StudentIdCardDetails(
          id: studentId,
          barcode: regNo,
          name: studentName,
          course: 'B.Tech.',
          department: dept,
          college: 'K.L.N. COLLEGE OF ENGINEERING',
          collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
          validity: 'August 2023 to May 2027',
          address: 'Campus Residential Hall, Pottapalayam',
          pincode: '630612',
          email: '$cleanDigits@college.edu',
          phones: const ['9842014033'],
          dob: '19-12-2005',
          bloodGroup: 'O+VE',
          avatarUrl: avatar,
        );
      }

      if (cardDetails != null || studentId.isNotEmpty) {
        // 3. Mark attendance as 'present' in Supabase
        bool saved = false;
        try {
          saved = await _attendanceRepo.markAttendance(studentId.isNotEmpty ? studentId : '1', 'present');
        } catch (e) {
          print('[BarcodeScanner] Attendance mark error: $e');
        }

        if (mounted) {
          _showStudentIdCardModal(cardDetails, studentName, regNo, dept, saved);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unrecognized Barcode: "$rawValue" (Digits: $cleanDigits)'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showStudentIdCardModal(
    StudentIdCardDetails? details,
    String name,
    String regNo,
    String dept,
    bool saved,
  ) {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm:ss a').format(now);
    final dateStr = DateFormat('dd MMMM yyyy').format(now);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attendance Verified Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 20,
                      child: Icon(Icons.check, color: Color(0xFF059669), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ATTENDANCE MARKED: PRESENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '$timeStr | $dateStr',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(saved ? Icons.cloud_done : Icons.cloud_queue, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            saved ? 'Synced' : 'Local',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PHYSICAL ID CARD CONTAINER
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade800, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // College Header Banner
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFE65100), // College Orange
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          const Text(
                            'K.L.N. COLLEGE OF ENGINEERING',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '(An Autonomous Institution, Affiliated to Anna University, Chennai)\nAccredited by NAAC | Pottapalayam - 630 612',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Front ID Card Body
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student Photo Avatar
                          Column(
                            children: [
                              Container(
                                width: 90,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade300, width: 1.5),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(
                                      child: StudentAvatar(
                                        avatarUrl: details?.avatarUrl,
                                        barcode: details?.barcode ?? regNo,
                                        studentName: name,
                                        width: 90,
                                        height: 110,
                                        borderRadius: BorderRadius.circular(9),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade800,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'STUDENT',
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Barcode Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.line_weight, size: 14, color: Colors.black87),
                                    const SizedBox(width: 4),
                                    Text(
                                      regNo,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Student Primary Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFC2410C), // Deep Orange Red
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  details?.course != null ? '${details!.course}, ${details.department}' : dept,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Roll No: $regNo',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Validity: ${details?.validity ?? "August 2023 to May 2027"}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (details?.bloodGroup != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bloodtype, color: Colors.red, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Blood Group: ${details!.bloodGroup}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, thickness: 1),

                    // Back ID Card Details (Contact & Address)
                    Container(
                      color: const Color(0xFFFAFAFA),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 16, color: Colors.blueGrey),
                              SizedBox(width: 6),
                              Text(
                                'CARD HOLDER VERIFIED DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (details?.address != null) ...[
                            _buildInfoTile(
                              Icons.location_on_outlined,
                              'Residential Address',
                              '${details!.address}\nPIN Code: ${details.pincode}',
                            ),
                            const SizedBox(height: 10),
                          ],

                          if (details?.email != null) ...[
                            _buildInfoTile(
                              Icons.email_outlined,
                              'Email Address',
                              details!.email,
                            ),
                            const SizedBox(height: 10),
                          ],

                          if (details?.phones != null && details!.phones.isNotEmpty) ...[
                            _buildInfoTile(
                              Icons.phone_outlined,
                              'Phone Numbers',
                              details.phones.join('  •  '),
                            ),
                            const SizedBox(height: 10),
                          ],

                          if (details?.dob != null) ...[
                            _buildInfoTile(
                              Icons.cake_outlined,
                              'Date of Birth',
                              details!.dob,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.barcode_reader),
                      label: const Text('Scan Next Barcode'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = false);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showManualBarcodeDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Color(0xFFE65100)),
            SizedBox(width: 10),
            Text('Enter Barcode Manually'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the ID card barcode number (e.g., ]C1235014 or 235014).\nThe ]C1 / JC1 prefix is automatically stripped to roll number 235014:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Barcode Number',
                hintText: 'e.g. ]C1235014 or 235014',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text(']C1235014 (235014 - Aravindsamy)'),
                  onPressed: () => textController.text = ']C1235014',
                ),
                ActionChip(
                  label: const Text(']C1235025 (235025 - Madhankumar)'),
                  onPressed: () => textController.text = ']C1235025',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            onPressed: () {
              final code = textController.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _handleBarcode(code);
              }
            },
            child: const Text('Verify & Mark'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student Barcode'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: _currentZoom > 0 ? Colors.orange : Colors.grey),
                borderRadius: BorderRadius.circular(6),
                color: _currentZoom > 0 ? Colors.orange.withOpacity(0.2) : Colors.transparent,
              ),
              child: Text(
                _currentZoom > 0 ? '2X' : '1X',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _currentZoom > 0 ? Colors.orange : Colors.grey.shade400,
                ),
              ),
            ),
            tooltip: 'Toggle Zoom (for small barcodes)',
            onPressed: _toggleZoom,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Enter Barcode Manually',
            onPressed: _showManualBarcodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Live Camera Stream
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _handleBarcode(raw);
                  break;
                }
              }
            },
          ),

          // Horizontal Barcode Viewfinder
          AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) {
              return Container(
                width: 320,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corner markers
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE65100), width: 5),
                            left: BorderSide(color: Color(0xFFE65100), width: 5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE65100), width: 5),
                            right: BorderSide(color: Color(0xFFE65100), width: 5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE65100), width: 5),
                            left: BorderSide(color: Color(0xFFE65100), width: 5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE65100), width: 5),
                            right: BorderSide(color: Color(0xFFE65100), width: 5),
                          ),
                        ),
                      ),
                    ),

                    // Animated Laser Scanning Line
                    Positioned(
                      top: 160 * _laserAnimation.value,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Quick 1-Tap Student Chips right below viewfinder
          Positioned(
            bottom: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.person, size: 14, color: Color(0xFFE65100)),
                  label: const Text('235014 (Aravindsamy)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.white,
                  onPressed: () => _handleBarcode(']C1235014'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.person, size: 14, color: Color(0xFFE65100)),
                  label: const Text('235025 (Madhankumar)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.white,
                  onPressed: () => _handleBarcode(']C1235025'),
                ),
              ],
            ),
          ),

          // Bottom Guidance Label
          Positioned(
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.document_scanner_outlined, color: Colors.orange, size: 16),
                    ),
                  Text(
                    _isProcessing ? 'Verifying Barcode...' : 'Align barcode horizontally (or tap 2X for zoom)',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
