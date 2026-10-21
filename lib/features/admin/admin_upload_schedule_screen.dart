import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../models/academic_timetable.dart';
import '../../models/academic_calendar.dart';
import '../../repositories/academic_schedule_repository.dart';

class AdminUploadScheduleScreen extends StatefulWidget {
  const AdminUploadScheduleScreen({super.key});

  @override
  State<AdminUploadScheduleScreen> createState() => _AdminUploadScheduleScreenState();
}

class _AdminUploadScheduleScreenState extends State<AdminUploadScheduleScreen> {
  final ImagePicker _picker = ImagePicker();

  String _selectedTarget = 'TIMETABLE_A'; // 'TIMETABLE_A', 'TIMETABLE_B', 'CALENDAR'
  bool _isLoading = true;
  bool _isSaving = false;

  SectionTimetable? _timetableA;
  SectionTimetable? _timetableB;
  AcademicCalendar? _calendar;

  // Controllers for editing
  late TextEditingController _inChargeCtrl;
  late TextEditingController _inChargeCodeCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _effectiveDateCtrl;
  late TextEditingController _calendarRefCtrl;
  late TextEditingController _workingDaysCtrl;

  @override
  void initState() {
    super.initState();
    _inChargeCtrl = TextEditingController();
    _inChargeCodeCtrl = TextEditingController();
    _roomCtrl = TextEditingController();
    _effectiveDateCtrl = TextEditingController();
    _calendarRefCtrl = TextEditingController();
    _workingDaysCtrl = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _inChargeCtrl.dispose();
    _inChargeCodeCtrl.dispose();
    _roomCtrl.dispose();
    _effectiveDateCtrl.dispose();
    _calendarRefCtrl.dispose();
    _workingDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await AcademicScheduleRepository.init();
    _timetableA = await AcademicScheduleRepository.getTimetable('A');
    _timetableB = await AcademicScheduleRepository.getTimetable('B');
    _calendar = await AcademicScheduleRepository.getCalendar();

    _populateFields();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _populateFields() {
    if (_selectedTarget == 'TIMETABLE_A' && _timetableA != null) {
      _inChargeCtrl.text = _timetableA!.classInCharge;
      _inChargeCodeCtrl.text = _timetableA!.inChargeCode;
      _roomCtrl.text = _timetableA!.roomNo;
      _effectiveDateCtrl.text = _timetableA!.effectiveDate;
    } else if (_selectedTarget == 'TIMETABLE_B' && _timetableB != null) {
      _inChargeCtrl.text = _timetableB!.classInCharge;
      _inChargeCodeCtrl.text = _timetableB!.inChargeCode;
      _roomCtrl.text = _timetableB!.roomNo;
      _effectiveDateCtrl.text = _timetableB!.effectiveDate;
    } else if (_selectedTarget == 'CALENDAR' && _calendar != null) {
      _calendarRefCtrl.text = _calendar!.circularRef;
      _workingDaysCtrl.text = _calendar!.totalWorkingDays.toString();
    }
  }

  Future<void> _pickAndUploadDocument(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isSaving = true);
      final uploadedData = await AcademicScheduleRepository.uploadDocument(
        docType: _selectedTarget,
        filePathOrBase64: picked.path,
      );

      if (mounted) {
        setState(() {
          if (_selectedTarget == 'TIMETABLE_A' && _timetableA != null) {
            _timetableA = _timetableA!.copyWith(customImageUrl: uploadedData);
          } else if (_selectedTarget == 'TIMETABLE_B' && _timetableB != null) {
            _timetableB = _timetableB!.copyWith(customImageUrl: uploadedData);
          } else if (_selectedTarget == 'CALENDAR' && _calendar != null) {
            _calendar = _calendar!.copyWith(customImageUrl: uploadedData);
          }
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document successfully uploaded & synced to Supabase Cloud for ${_getTargetTitle()}!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveMetadata() async {
    setState(() => _isSaving = true);
    try {
      if (_selectedTarget == 'TIMETABLE_A' && _timetableA != null) {
        final updated = _timetableA!.copyWith(
          classInCharge: _inChargeCtrl.text.trim(),
          inChargeCode: _inChargeCodeCtrl.text.trim(),
          roomNo: _roomCtrl.text.trim(),
          effectiveDate: _effectiveDateCtrl.text.trim(),
        );
        _timetableA = updated;
        await AcademicScheduleRepository.saveTimetable(updated);
      } else if (_selectedTarget == 'TIMETABLE_B' && _timetableB != null) {
        final updated = _timetableB!.copyWith(
          classInCharge: _inChargeCtrl.text.trim(),
          inChargeCode: _inChargeCodeCtrl.text.trim(),
          roomNo: _roomCtrl.text.trim(),
          effectiveDate: _effectiveDateCtrl.text.trim(),
        );
        _timetableB = updated;
        await AcademicScheduleRepository.saveTimetable(updated);
      } else if (_selectedTarget == 'CALENDAR' && _calendar != null) {
        final updated = _calendar!.copyWith(
          circularRef: _calendarRefCtrl.text.trim(),
          totalWorkingDays: int.tryParse(_workingDaysCtrl.text.trim()) ?? 88,
        );
        _calendar = updated;
        await AcademicScheduleRepository.saveCalendar(updated);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule details updated and synced to Supabase Cloud!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _resetToOfficialDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Official Defaults?'),
        content: Text('This will restore the original KLNCE official schedule for ${_getTargetTitle()}. Custom uploads will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    if (_selectedTarget == 'TIMETABLE_A') {
      _timetableA = AcademicScheduleRepository.defaultTimetableA;
      await AcademicScheduleRepository.saveTimetable(_timetableA!);
    } else if (_selectedTarget == 'TIMETABLE_B') {
      _timetableB = AcademicScheduleRepository.defaultTimetableB;
      await AcademicScheduleRepository.saveTimetable(_timetableB!);
    } else if (_selectedTarget == 'CALENDAR') {
      _calendar = AcademicScheduleRepository.defaultCalendar;
      await AcademicScheduleRepository.saveCalendar(_calendar!);
    }

    _populateFields();
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored official defaults successfully!')),
      );
    }
  }

  String _getTargetTitle() {
    if (_selectedTarget == 'TIMETABLE_A') return 'Section A Timetable';
    if (_selectedTarget == 'TIMETABLE_B') return 'Section B Timetable';
    return 'Academic Calendar (Circular 321)';
  }

  String? _getCurrentCustomImage() {
    if (_selectedTarget == 'TIMETABLE_A') return _timetableA?.customImageUrl;
    if (_selectedTarget == 'TIMETABLE_B') return _timetableB?.customImageUrl;
    return _calendar?.customImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin: Upload & Manage Schedules',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Selection Segmented Tab Bar
                _buildTargetSelector(),
                const SizedBox(height: 16),

                // Upload & Camera Action Card
                _buildUploadActionCard(),
                const SizedBox(height: 16),

                // Existing Document Image Preview
                _buildDocumentPreviewCard(),
                const SizedBox(height: 16),

                // Edit Metadata Form
                _buildMetadataEditForm(),
                const SizedBox(height: 20),

                // Action Buttons
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              title: 'Section A',
              subtitle: 'Timetable',
              isSelected: _selectedTarget == 'TIMETABLE_A',
              onTap: () {
                setState(() => _selectedTarget = 'TIMETABLE_A');
                _populateFields();
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              title: 'Section B',
              subtitle: 'Timetable',
              isSelected: _selectedTarget == 'TIMETABLE_B',
              onTap: () {
                setState(() => _selectedTarget = 'TIMETABLE_B');
                _populateFields();
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentButton(
              title: 'Calendar',
              subtitle: 'Circular 321',
              isSelected: _selectedTarget == 'CALENDAR',
              onTap: () {
                setState(() => _selectedTarget = 'CALENDAR');
                _populateFields();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white.withOpacity(0.85) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadActionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Document for ${_getTargetTitle()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Upload PDF or image circular scan. Auto-synced to all app clients.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Pick Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : () => _pickAndUploadDocument(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Scan Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : () => _pickAndUploadDocument(ImageSource.camera),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreviewCard() {
    final imageBase64 = _getCurrentCustomImage();
    if (imageBase64 == null || imageBase64.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No custom document image uploaded yet. The official built-in KLNCE layout is currently active.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Uploaded Document Scan Active',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                TextButton(
                  onPressed: () async {
                    if (_selectedTarget == 'TIMETABLE_A' && _timetableA != null) {
                      _timetableA = _timetableA!.copyWith(customImageUrl: '');
                      await AcademicScheduleRepository.saveTimetable(_timetableA!);
                    } else if (_selectedTarget == 'TIMETABLE_B' && _timetableB != null) {
                      _timetableB = _timetableB!.copyWith(customImageUrl: '');
                      await AcademicScheduleRepository.saveTimetable(_timetableB!);
                    } else if (_selectedTarget == 'CALENDAR' && _calendar != null) {
                      _calendar = _calendar!.copyWith(customImageUrl: '');
                      await AcademicScheduleRepository.saveCalendar(_calendar!);
                    }
                    setState(() {});
                  },
                  child: const Text('Remove Image', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: _renderBase64(imageBase64),
          ),
        ],
      ),
    );
  }

  Widget _renderBase64(String raw) {
    try {
      String clean = raw;
      if (clean.contains(',')) clean = clean.split(',')[1];
      return Image.memory(base64Decode(clean), width: double.infinity, fit: BoxFit.contain);
    } catch (_) {
      return Container(height: 100, color: Colors.grey.withOpacity(0.1), child: const Center(child: Text('Invalid image format')));
    }
  }

  Widget _buildMetadataEditForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Metadata for ${_getTargetTitle()}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
          ),
          const Divider(height: 20),
          if (_selectedTarget == 'CALENDAR') ...[
            _buildTextField(_calendarRefCtrl, 'Circular Reference', 'e.g. KLNCE/Academic Calendar/2026-2027/321'),
            const SizedBox(height: 12),
            _buildTextField(_workingDaysCtrl, 'Total Working Days', 'e.g. 88', isNumber: true),
          ] else ...[
            _buildTextField(_inChargeCtrl, 'Class In-Charge Name', 'e.g. Mrs. K. Rani, AP/IT'),
            const SizedBox(height: 12),
            _buildTextField(_inChargeCodeCtrl, 'In-Charge Faculty Code', 'e.g. 10535062'),
            const SizedBox(height: 12),
            _buildTextField(_roomCtrl, 'Classroom / Hall Number', 'e.g. M.E.-02'),
            const SizedBox(height: 12),
            _buildTextField(_effectiveDateCtrl, 'Effective Date / Revision', 'e.g. 20/07/2026 Rev:2'),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_done_rounded, size: 20),
            label: Text(_isSaving ? 'Saving to Cloud...' : 'Save & Sync Changes to Cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSaving ? null : _saveMetadata,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restore_rounded, size: 18, color: AppColors.error),
            label: const Text('Reset to KLNCE Official Default', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSaving ? null : _resetToOfficialDefault,
          ),
        ),
      ],
    );
  }
}
