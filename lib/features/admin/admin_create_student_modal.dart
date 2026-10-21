import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/student_avatar.dart';
import '../../repositories/student_directory.dart';
import '../../services/id_card_scanner_service.dart';

class AdminCreateStudentModal extends StatefulWidget {
  final Function(StudentIdCardDetails) onStudentSaved;

  const AdminCreateStudentModal({super.key, required this.onStudentSaved});

  @override
  State<AdminCreateStudentModal> createState() => _AdminCreateStudentModalState();
}

class _AdminCreateStudentModalState extends State<AdminCreateStudentModal> {
  final ImagePicker _picker = ImagePicker();
  
  XFile? _frontImage;
  XFile? _backImage;
  bool _isProcessing = false;
  bool _isExtracted = false;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  final _courseController = TextEditingController(text: 'B.Tech.');
  final _deptController = TextEditingController(text: 'Information Technology');
  final _collegeController = TextEditingController(text: 'K.L.N. COLLEGE OF ENGINEERING');
  final _affiliationController = TextEditingController(
    text: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
  );
  final _validityController = TextEditingController(text: 'August 2023 to May 2027');
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phonesController = TextEditingController();
  final _dobController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _yearController = TextEditingController();
  final _sectionController = TextEditingController();
  final _semesterController = TextEditingController();
  final _batchController = TextEditingController();
  final _semDurationController = TextEditingController();

  String _avatarBase64 = '';
  String? _customPhotoPath;

  @override
  void initState() {
    super.initState();
    final config = StudentDirectory.academicConfig;
    _yearController.text = config.year;
    _sectionController.text = config.section;
    _semesterController.text = config.semester;
    _batchController.text = config.batch;
    _semDurationController.text = config.semesterDuration;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _courseController.dispose();
    _deptController.dispose();
    _collegeController.dispose();
    _affiliationController.dispose();
    _validityController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _emailController.dispose();
    _phonesController.dispose();
    _dobController.dispose();
    _bloodGroupController.dispose();
    _yearController.dispose();
    _sectionController.dispose();
    _semesterController.dispose();
    _batchController.dispose();
    _semDurationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked != null) {
        setState(() {
          if (isFront) {
            _frontImage = picked;
          } else {
            _backImage = picked;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickCustomAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90);
      if (picked != null) {
        setState(() {
          _customPhotoPath = picked.path;
          _avatarBase64 = picked.path; // StudentAvatar widget handles file paths
        });
      }
    } catch (e) {
      debugPrint('Custom avatar error: $e');
    }
  }

  Future<void> _extractDetails() async {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload BOTH Front and Back images of the student ID card.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final data = await IdCardScannerService.processIdCards(
        frontImagePath: _frontImage!.path,
        backImagePath: _backImage!.path,
      );

      setState(() {
        _nameController.text = data.name;
        _rollController.text = data.rollNo;
        _courseController.text = data.course;
        _deptController.text = data.department;
        _collegeController.text = data.college;
        _affiliationController.text = data.collegeAffiliation;
        _validityController.text = data.validity;
        _addressController.text = data.address;
        _pincodeController.text = data.pincode;
        _emailController.text = data.email;
        _phonesController.text = data.phones.join(', ');
        _dobController.text = data.dob;
        _bloodGroupController.text = data.bloodGroup;
        _avatarBase64 = data.avatarBase64;
        _customPhotoPath = data.avatarFilePath;

        // Auto-extract batch from validity if present (e.g. August 2023 to May 2027)
        final batchMatch = RegExp(r'(\d{4})\s*(?:to|-|–)\s*(\d{4})').firstMatch(data.validity);
        if (batchMatch != null) {
          _batchController.text = '${batchMatch.group(1)} – ${batchMatch.group(2)}';
        }

        _isExtracted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID Details & Student Photo extracted successfully!'),
            backgroundColor: AppConstants.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final config = StudentDirectory.academicConfig;
    final phonesList = _phonesController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final newStudent = StudentIdCardDetails(
      id: DateTime.now().millisecondsSinceEpoch.toString().substring(7),
      barcode: _rollController.text.trim(),
      name: _nameController.text.trim().toUpperCase(),
      course: _courseController.text.trim(),
      department: _deptController.text.trim(),
      college: _collegeController.text.trim(),
      collegeAffiliation: _affiliationController.text.trim(),
      validity: _validityController.text.trim(),
      address: _addressController.text.trim(),
      pincode: _pincodeController.text.trim(),
      email: _emailController.text.trim(),
      phones: phonesList.isNotEmpty ? phonesList : ['9876543210'],
      dob: _dobController.text.trim(),
      bloodGroup: _bloodGroupController.text.trim(),
      avatarUrl: _avatarBase64.isNotEmpty ? _avatarBase64 : (_customPhotoPath ?? ''),
      year: _yearController.text.trim().isNotEmpty ? _yearController.text.trim() : config.year,
      section: _sectionController.text.trim().isNotEmpty ? _sectionController.text.trim() : config.section,
      semester: _semesterController.text.trim().isNotEmpty ? _semesterController.text.trim() : config.semester,
      batch: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : config.batch,
      semesterDuration: _semDurationController.text.trim().isNotEmpty ? _semDurationController.text.trim() : config.semesterDuration,
    );

    await StudentDirectory.saveStudent(newStudent);
    widget.onStudentSaved(newStudent);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Student ${newStudent.name} (${newStudent.barcode}) created & saved!'),
          backgroundColor: AppConstants.statusGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Student Registration'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_isExtracted)
              TextButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _saveStudent,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instruction Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade400, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_outlined, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI College ID Card Scanner',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Upload 2 images (Front & Back). The app will automatically extract all student details and crop their face photo.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Upload Cards: Front & Back
              Row(
                children: [
                  Expanded(child: _buildImageCard('Front of ID Card', _frontImage, true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildImageCard('Back of ID Card', _backImage, false)),
                ],
              ),
              const SizedBox(height: 16),

              // Action Button to Process
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : _extractDetails,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isProcessing ? 'Analyzing ID Cards & Cropping Photo...' : 'Extract Details & Photo from Images',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),

              const SizedBox(height: 24),

              // Review & Verification Form
              if (_isExtracted) ...[
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Extracted Student Profile',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: const Text('Auto-Extracted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: Colors.green.shade800),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Student Photo Display + Edit Option
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange.shade400, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: StudentAvatar(
                              avatarUrl: _avatarBase64.isNotEmpty ? _avatarBase64 : _customPhotoPath,
                              studentName: _nameController.text,
                              width: 100,
                              height: 120,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.primary,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                padding: EdgeInsets.zero,
                                onPressed: () => _showAvatarOptions(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Retake / Change Photo', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showAvatarOptions(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Editable Fields Form
                // Editable Fields Form - 1 Field Per Row
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Core Identity
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'STUDENT IDENTITY',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
                        ),
                      ),
                      _buildTextField(_nameController, 'Student Full Name', Icons.person, required: true),
                      const SizedBox(height: 14),
                      _buildTextField(_rollController, 'Roll / Register No', Icons.badge, required: true),
                      const SizedBox(height: 14),
                      _buildTextField(_bloodGroupController, 'Blood Group (e.g. B+, O+VE)', Icons.bloodtype),
                      const SizedBox(height: 14),
                      _buildTextField(_dobController, 'Date of Birth (DD-MM-YYYY)', Icons.cake),

                      const SizedBox(height: 18),
                      // Section 2: Academic Program & Class
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'ACADEMIC PROGRAM & CLASS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
                        ),
                      ),
                      _buildTextField(_courseController, 'Course (e.g. B.Tech., B.E.)', Icons.school),
                      const SizedBox(height: 14),
                      _buildTextField(_deptController, 'Department', Icons.business),
                      const SizedBox(height: 14),
                      _buildTextField(_yearController, 'Year (e.g. 1, 2, 3, 4)', Icons.timeline),
                      const SizedBox(height: 14),
                      _buildTextField(_sectionController, 'Section (e.g. A, B)', Icons.group),
                      const SizedBox(height: 14),
                      _buildTextField(_semesterController, 'Semester (e.g. Semester 5)', Icons.menu_book),
                      const SizedBox(height: 14),
                      _buildTextField(_batchController, 'Batch (e.g. 2023 – 2027)', Icons.layers),

                      const SizedBox(height: 18),
                      // Section 3: Contact & Address
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'CONTACT & RESIDENTIAL DETAILS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
                        ),
                      ),
                      _buildTextField(_emailController, 'Email Address', Icons.email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _buildTextField(_phonesController, 'Phone Numbers (comma-separated)', Icons.phone, keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),
                      _buildTextField(_addressController, 'Residential Address', Icons.home, maxLines: 2),
                      const SizedBox(height: 14),
                      _buildTextField(_pincodeController, 'Pincode', Icons.pin_drop, keyboardType: TextInputType.number),

                      const SizedBox(height: 18),
                      // Section 4: Institutional Details
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'INSTITUTIONAL INFORMATION',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
                        ),
                      ),
                      _buildTextField(_validityController, 'ID Validity Duration', Icons.date_range),
                      const SizedBox(height: 14),
                      _buildTextField(_collegeController, 'College Name', Icons.account_balance),
                      const SizedBox(height: 24),

                      // Final Save Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.statusGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _saveStudent,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text('CONFIRM & SAVE STUDENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(String label, XFile? image, bool isFront) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: image != null ? AppConstants.statusGreen : theme.colorScheme.outlineVariant,
                  width: image != null ? 2 : 1,
                ),
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image.path),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFront ? Icons.badge_outlined : Icons.flip_to_back_outlined,
                            size: 36,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No image selected',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.camera_alt, size: 14),
                    label: const Text('Camera', style: TextStyle(fontSize: 11)),
                    onPressed: () => _pickImage(isFront, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.photo_library, size: 14),
                    label: const Text('Gallery', style: TextStyle(fontSize: 11)),
                    onPressed: () => _pickImage(isFront, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Student Photo (Camera)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCustomAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Photo from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCustomAvatar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
