import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/student_directory.dart';
import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import '../../core/widgets/student_avatar.dart';
import 'admin_create_student_modal.dart';

class AdminStudentScreen extends StatefulWidget {
  const AdminStudentScreen({super.key});

  @override
  State<AdminStudentScreen> createState() => _AdminStudentScreenState();
}

class _AdminStudentScreenState extends State<AdminStudentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchIdController = TextEditingController();
  String _selectedSectionFilter = 'All';

  // Academic Configuration Controllers
  late TextEditingController _semDurationController;
  late TextEditingController _departmentController;
  late TextEditingController _academicYearController;
  late TextEditingController _yearController;
  late TextEditingController _sectionController;
  late TextEditingController _semesterController;
  late TextEditingController _batchController;

  StudentIdCardDetails? _retrievedStudent;
  bool _isSearching = false;
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    final config = StudentDirectory.academicConfig;
    _semDurationController = TextEditingController(text: config.semesterDuration);
    _departmentController = TextEditingController(text: config.department);
    _academicYearController = TextEditingController(text: config.academicYear);
    _yearController = TextEditingController(text: config.year);
    _sectionController = TextEditingController(text: config.section);
    _semesterController = TextEditingController(text: config.semester);
    _batchController = TextEditingController(text: config.batch);

    // Initial render starts clean: no lingering student details when search bar is empty
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchIdController.dispose();
    _semDurationController.dispose();
    _departmentController.dispose();
    _academicYearController.dispose();
    _yearController.dispose();
    _sectionController.dispose();
    _semesterController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  Future<void> _saveAcademicConfig() async {
    final newConfig = AcademicConfig(
      semesterDuration: _semDurationController.text.trim(),
      department: _departmentController.text.trim(),
      academicYear: _academicYearController.text.trim(),
      year: _yearController.text.trim(),
      section: _sectionController.text.trim(),
      semester: _semesterController.text.trim(),
      batch: _batchController.text.trim(),
    );

    await StudentDirectory.saveAcademicConfig(newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Academic parameters updated & saved successfully!'),
          backgroundColor: AppConstants.statusGreen,
        ),
      );
    }
  }

  Future<void> _retrieveStudentById(String idOrRoll, {bool showPopup = false}) async {
    final query = idOrRoll.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    // 1. Check local registry first
    StudentIdCardDetails? found = StudentDirectory.findByIdOrRoll(query);

    // 2. If not found locally, query Supabase
    if (found == null) {
      final clean = StudentDirectory.cleanCode(query);
      try {
        final res = await _api.get('/students?or=(register_number.eq.$clean,id.eq.$clean)&select=*');
        if (res is List && res.isNotEmpty) {
          final s = res[0] as Map<String, dynamic>;
          final calc = StudentDirectory.calculateYearAndSemester(
            batch: '2023 – 2027',
            rollNo: s['register_number'] ?? clean,
          );
          found = StudentIdCardDetails(
            id: s['id'].toString(),
            barcode: s['register_number'] ?? clean,
            name: s['student_name'] ?? 'Student',
            course: 'B.Tech.',
            department: s['department'] ?? 'Information Technology',
            college: 'K.L.N. COLLEGE OF ENGINEERING',
            collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
            validity: 'August 2023 to May 2027',
            address: s['address'] ?? 'Campus Residential Hall, Pottapalayam',
            pincode: '630612',
            email: s['email'] ?? '$clean@college.edu',
            phones: [s['phone'] ?? '9842014033'],
            dob: s['dob'] ?? '19-12-2005',
            bloodGroup: s['blood_group'] ?? 'O+VE',
            year: calc.year,
            section: s['section'] ?? 'A',
            semester: calc.semester,
            batch: '2023 - 2027',
            semesterDuration: calc.semesterDuration,
          );
        }
      } catch (e) {
        print('Supabase student lookup error: $e');
      }
    }

    setState(() {
      _retrievedStudent = found;
      _isSearching = false;
      _searchIdController.text = query;
    });

    if (found == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No student found matching "$query"'),
          backgroundColor: AppConstants.statusRed,
        ),
      );
    } else if (found != null && showPopup && mounted) {
      _showStudentDetailsDialog(found);
    }
  }

  void _confirmDeleteStudent(StudentIdCardDetails student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Student?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete student "${student.name}" (${student.barcode}) from local storage and cloud database?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await StudentDirectory.deleteStudent(student.barcode);
              if (mounted) {
                setState(() {
                  if (_retrievedStudent?.barcode == student.barcode || _retrievedStudent?.id == student.id) {
                    _retrievedStudent = null;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Student "${student.name}" deleted successfully.' : 'Failed to delete student.'),
                    backgroundColor: success ? AppConstants.statusGreen : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _openEditStudentModal(StudentIdCardDetails student, {bool isNew = false}) {
    // Dynamic recalculation for Year 4 & Semester 7
    final calc = StudentDirectory.calculateYearAndSemester(
      batch: student.batch,
      validity: student.validity,
      rollNo: student.barcode,
    );
    final initialYear = (student.year.isEmpty || student.year == '3') ? calc.year : student.year;
    final initialSem = (student.semester.isEmpty || student.semester == 'Semester 5') ? calc.semester : student.semester;
    final initialDuration = (student.semesterDuration.isEmpty || student.semesterDuration.contains('2025'))
        ? calc.semesterDuration
        : student.semesterDuration;

    final nameCtrl = TextEditingController(text: student.name);
    final rollCtrl = TextEditingController(text: student.barcode);
    final deptCtrl = TextEditingController(text: student.department);
    final courseCtrl = TextEditingController(text: student.course);
    final yearCtrl = TextEditingController(text: initialYear);
    final secCtrl = TextEditingController(text: student.section.isNotEmpty ? student.section : 'A');
    final semCtrl = TextEditingController(text: initialSem);
    final batchCtrl = TextEditingController(text: student.batch.isNotEmpty ? student.batch : '2023 – 2027');
    final semDurationCtrl = TextEditingController(text: initialDuration);
    final addressCtrl = TextEditingController(text: student.address);
    final pinCtrl = TextEditingController(text: student.pincode);
    final emailCtrl = TextEditingController(text: student.email);
    final phoneCtrl = TextEditingController(text: student.phones.join(', '));
    final dobCtrl = TextEditingController(text: student.dob);
    final bloodCtrl = TextEditingController(text: student.bloodGroup);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNew ? 'Register New Student' : 'Edit Student Details',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Form fields - 1 Field Per Row
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rollCtrl,
                decoration: const InputDecoration(labelText: 'Roll / Register No', prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bloodCtrl,
                decoration: const InputDecoration(labelText: 'Blood Group (e.g. B+, O+VE)', prefixIcon: Icon(Icons.bloodtype), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dobCtrl,
                decoration: const InputDecoration(labelText: 'Date of Birth (DD-MM-YYYY)', prefixIcon: Icon(Icons.cake), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseCtrl,
                decoration: const InputDecoration(labelText: 'Course (e.g. B.Tech., B.E.)', prefixIcon: Icon(Icons.school), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(labelText: 'Year (1-4)', prefixIcon: Icon(Icons.timeline), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secCtrl,
                decoration: const InputDecoration(labelText: 'Section (e.g. A, B)', prefixIcon: Icon(Icons.group), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: semCtrl,
                decoration: const InputDecoration(labelText: 'Semester (e.g. Semester 7)', prefixIcon: Icon(Icons.menu_book), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchCtrl,
                decoration: const InputDecoration(labelText: 'Batch (e.g. 2023 – 2027)', prefixIcon: Icon(Icons.layers), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: semDurationCtrl,
                decoration: const InputDecoration(labelText: 'Semester Duration', prefixIcon: Icon(Icons.date_range), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number(s)', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Residential Address', prefixIcon: Icon(Icons.home), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: 'Pincode', prefixIcon: Icon(Icons.pin_drop), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 18),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.statusGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(isNew ? 'Create Student' : 'Save & Update Details'),
                  onPressed: () async {
                    final phonesList = phoneCtrl.text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
                    final updated = student.copyWith(
                      id: isNew ? DateTime.now().millisecondsSinceEpoch.toString() : student.id,
                      name: nameCtrl.text.trim(),
                      barcode: rollCtrl.text.trim(),
                      department: deptCtrl.text.trim(),
                      course: courseCtrl.text.trim(),
                      year: yearCtrl.text.trim(),
                      section: secCtrl.text.trim(),
                      semester: semCtrl.text.trim(),
                      batch: batchCtrl.text.trim(),
                      semesterDuration: semDurationCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      pincode: pinCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      phones: phonesList.isNotEmpty ? phonesList : ['9842014033'],
                      dob: dobCtrl.text.trim(),
                      bloodGroup: bloodCtrl.text.trim(),
                    );

                    await StudentDirectory.saveStudent(updated);

                    // Sync with Supabase if online
                    try {
                      await _api.post(
                        '/students',
                        headers: {'Prefer': 'resolution=merge-duplicates'},
                        body: {
                          'student_name': updated.name,
                          'register_number': updated.barcode,
                          'department': updated.department,
                          'year': int.tryParse(updated.year) ?? 4,
                          'section': updated.section,
                          'email': updated.email,
                        },
                      );
                    } catch (_) {}

                    if (mounted) {
                      Navigator.pop(ctx);
                      setState(() {
                        _retrievedStudent = updated;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Student ${updated.name} saved successfully!')),
                      );
                    }
                  },
                ),
              ),
              if (!isNew) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Student Record'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDeleteStudent(student);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openCreateStudentModal() {
    showDialog(
      context: context,
      builder: (ctx) => AdminCreateStudentModal(
        onStudentSaved: (newStudent) {
          setState(() {
            _retrievedStudent = newStudent;
            _searchIdController.text = newStudent.barcode;
            _tabController.animateTo(0);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    // Strict Role-Based Access Control
    if (authProvider.role != AppRole.administrator) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Restricted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 72, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Access Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Teacher logins are strictly for student viewing and attendance marking. Student creation and ID scanning are restricted to Administrators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Attendance'),
                  onPressed: () => context.go('/more/attendance'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel: Student & Academic Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Students from Cloud',
            onPressed: () async {
              await StudentDirectory.syncFromCloud();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student directory synced with Supabase cloud!'),
                    backgroundColor: AppConstants.statusGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.statusGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.document_scanner, size: 16),
            label: const Text('Scan 2 ID Images', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _openCreateStudentModal,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'All Students'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Academic Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Merged Tab: All Students with Integrated Lookup & Search
          _buildAllStudentsTab(theme),

          // Tab 2: Academic Configuration
          _buildAcademicSettingsTab(theme),
        ],
      ),
    );
  }

  Widget _buildAllStudentsTab(ThemeData theme) {
    final allStudents = StudentDirectory.getAll();
    final query = _searchIdController.text.trim().toLowerCase();

    final filtered = allStudents.where((s) {
      if (_selectedSectionFilter != 'All' && s.section.toUpperCase() != _selectedSectionFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final nameMatch = s.name.toLowerCase().contains(query);
        final rollMatch = s.barcode.toLowerCase().contains(query);
        final cleanQuery = StudentDirectory.cleanCode(query);
        final cleanRoll = StudentDirectory.cleanCode(s.barcode);
        final barcodeMatch = cleanRoll.contains(cleanQuery);
        final deptMatch = s.department.toLowerCase().contains(query);
        return nameMatch || rollMatch || barcodeMatch || deptMatch;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await StudentDirectory.syncFromCloud();
        if (mounted) setState(() {});
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 80.0),
        children: [
          // Merged Student Search & Retrieval Header Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Student Search & ID Retrieval',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search by roll number, name or barcode. Tap any student to view or edit their institutional record.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchIdController,
                          decoration: InputDecoration(
                            hintText: 'e.g. 235014, 235025, Ashish...',
                            prefixIcon: const Icon(Icons.person_search, size: 20),
                            suffixIcon: _searchIdController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchIdController.clear();
                                      setState(() {
                                        _retrievedStudent = null;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _retrieveStudentById(val, showPopup: true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (_searchIdController.text.trim().isNotEmpty) {
                            _retrieveStudentById(_searchIdController.text, showPopup: true);
                          }
                        },
                        icon: _isSearching
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Retrieve'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Section & Quick Pick Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('All (${allStudents.length})'),
                          selected: _selectedSectionFilter == 'All',
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedSectionFilter = 'All');
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: Text('Sec A (${allStudents.where((s) => s.section.toUpperCase() == 'A').length})'),
                          selected: _selectedSectionFilter == 'A',
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedSectionFilter = 'A');
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: Text('Sec B (${allStudents.where((s) => s.section.toUpperCase() == 'B').length})'),
                          selected: _selectedSectionFilter == 'B',
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedSectionFilter = 'B');
                          },
                        ),
                        const SizedBox(width: 10),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        const SizedBox(width: 10),
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 14),
                          label: const Text('235014 (Aravindsamy)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _searchIdController.text = '235014';
                            _retrieveStudentById('235014', showPopup: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 14),
                          label: const Text('235025 (Madhankumar)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _searchIdController.text = '235025';
                            _retrieveStudentById('235025', showPopup: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 14),
                          label: const Text('235002 (Ashish)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _searchIdController.text = '235002';
                            _retrieveStudentById('235002', showPopup: true);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Enrolled Students Roster Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ENROLLED STUDENTS (${filtered.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _selectedSectionFilter == 'All' ? 'All Sections' : 'Section $_selectedSectionFilter',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Student List
          if (filtered.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      query.isNotEmpty
                          ? 'No student found matching "$query"'
                          : 'No students enrolled in Section $_selectedSectionFilter',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (query.isNotEmpty || _selectedSectionFilter != 'All')
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Search & Filters'),
                        onPressed: () {
                          _searchIdController.clear();
                          setState(() {
                            _selectedSectionFilter = 'All';
                            _retrievedStudent = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((student) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10.0),
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: StudentAvatar(
                    avatarUrl: student.avatarUrl,
                    barcode: student.barcode,
                    studentName: student.name,
                    radius: 24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(
                    student.name.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roll: ${student.barcode} • ${student.department}',
                          style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Year ${student.year} • Sec ${student.section} • ${student.semester} (${student.batch})',
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
                        tooltip: 'Edit Student',
                        onPressed: () => _openEditStudentModal(student),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete Student',
                        onPressed: () => _confirmDeleteStudent(student),
                      ),
                    ],
                  ),
                  onTap: () => _showStudentDetailsDialog(student),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAcademicSettingsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Institution Academic Parameters',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'As Administrator, configure institutional parameters including semester duration, department, academic year, batch, year, and semester. These automatically synchronize with all student attendance rosters.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  // Semester Duration
                  TextField(
                    controller: _semDurationController,
                    decoration: const InputDecoration(
                      labelText: 'Semester Duration',
                      hintText: 'e.g. August 2026 – December 2026',
                      prefixIcon: Icon(Icons.date_range),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Department
                  TextField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      hintText: 'e.g. Information Technology',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Academic Year
                  TextField(
                    controller: _academicYearController,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      hintText: 'e.g. 2026 – 2027',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Batch
                  TextField(
                    controller: _batchController,
                    decoration: const InputDecoration(
                      labelText: 'Batch',
                      hintText: 'e.g. 2023 – 2027',
                      prefixIcon: Icon(Icons.layers),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Year
                  TextField(
                    controller: _yearController,
                    decoration: const InputDecoration(
                      labelText: 'Year (1-4)',
                      hintText: 'e.g. 4',
                      prefixIcon: Icon(Icons.timeline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section
                  TextField(
                    controller: _sectionController,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      hintText: 'e.g. A',
                      prefixIcon: Icon(Icons.group),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Semester
                  TextField(
                    controller: _semesterController,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      hintText: 'e.g. Semester 7',
                      prefixIcon: Icon(Icons.menu_book),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Configuration Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Institutional Parameters', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _saveAcademicConfig,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetailsDialog(StudentIdCardDetails student) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE65100),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    const Text(
                      'K.L.N. COLLEGE OF ENGINEERING',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      student.collegeAffiliation,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 9),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + Name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StudentAvatar(
                          avatarUrl: student.avatarUrl,
                          barcode: student.barcode,
                          studentName: student.name,
                          width: 76,
                          height: 94,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade300, width: 2),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFC2410C),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${student.course}, ${student.department}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Roll No: ${student.barcode}',
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Year ${student.year} • Section ${student.section} • ${student.semester}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                              ),
                              Text(
                                'Validity: ${student.validity}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  'Blood Group: ${student.bloodGroup}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Academic & Residential Profile
                    const Text(
                      'ACADEMIC & RESIDENTIAL PROFILE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.date_range, 'Sem Duration', student.semesterDuration),
                    _buildDetailRow(Icons.layers, 'Batch', student.batch),
                    _buildDetailRow(
                      Icons.home,
                      'Address',
                      student.pincode.isNotEmpty && !student.address.contains(student.pincode)
                          ? '${student.address} (PIN: ${student.pincode})'
                          : student.address,
                    ),
                    _buildDetailRow(Icons.email, 'Email', student.email),
                    _buildDetailRow(Icons.phone, 'Phones', student.phones.join(', ')),
                    _buildDetailRow(Icons.cake, 'DOB', student.dob),

                    const SizedBox(height: 16),

                    // Action Buttons Row: Edit / Delete / Add
                    // Delete button alignment issue resolved with compact padding and FittedBox
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.edit_note, size: 16),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Edit',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openEditStudentModal(student);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Delete',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmDeleteStudent(student);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.statusGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Add',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              final calc = StudentDirectory.calculateYearAndSemester(
                                batch: _batchController.text,
                              );
                              final newStudent = StudentIdCardDetails(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                barcode: '',
                                name: '',
                                course: 'B.Tech.',
                                department: _departmentController.text,
                                college: 'K.L.N. COLLEGE OF ENGINEERING',
                                collegeAffiliation: 'An Autonomous Institution, Affiliated to Anna University, Chennai',
                                validity: 'August 2023 to May 2027',
                                address: 'Madurai, Tamil Nadu',
                                pincode: '625012',
                                email: '',
                                phones: [''],
                                dob: '01-01-2005',
                                bloodGroup: 'O+VE',
                                year: calc.year,
                                section: _sectionController.text,
                                semester: calc.semester,
                                batch: _batchController.text,
                                semesterDuration: calc.semesterDuration,
                              );
                              _openEditStudentModal(newStudent, isNew: true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
