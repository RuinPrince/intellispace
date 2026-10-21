import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/users?order=id.asc&select=*');
      if (response is List) {
        _teachers = response.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {
      // Handled silently
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createTeacher() async {
    final nameController = TextEditingController();
    final teacherIdController = TextEditingController(); // Email/User ID
    final passwordController = TextEditingController(text: 'password');
    final departmentController = TextEditingController();
    String selectedRole = 'teacher';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.indigo),
              SizedBox(width: 10),
              Text('Create Teacher Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Dr. Sarah Jenkins',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teacherIdController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Teacher ID / Login Identifier *',
                    hintText: 'e.g. sarah@intellispace.com or TCH101',
                    helperText: 'Used by the teacher to log into the application',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'System Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    hintText: 'e.g. Information Technology',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Initial Password *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameController.text.trim();
                final teacherId = teacherIdController.text.trim();
                final password = passwordController.text.trim();

                if (name.isEmpty || teacherId.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name, Teacher ID, and Password are required')),
                  );
                  return;
                }

                try {
                  await _api.post('/users', body: {
                    'name': name,
                    'email': teacherId,
                    'password': password,
                    'role': selectedRole,
                    'department': departmentController.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error creating teacher: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadTeachers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher account created successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  /// Alter/Modify existing Teacher ID, Name, Role, Department, or Password
  Future<void> _editTeacher(Map<String, dynamic> teacher) async {
    final nameController = TextEditingController(text: teacher['name'] ?? '');
    final teacherIdController = TextEditingController(text: teacher['email'] ?? '');
    final departmentController = TextEditingController(text: teacher['department'] ?? '');
    final passwordController = TextEditingController();
    String selectedRole = teacher['role'] ?? 'teacher';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.indigo),
              SizedBox(width: 10),
              Text('Alter / Modify Teacher'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: teacherIdController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Teacher ID / Login Identifier *',
                    helperText: 'Changing this modifies the teacher\'s login identifier',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'New Password (leave blank to keep current)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                final newTeacherId = teacherIdController.text.trim();
                if (newTeacherId.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Teacher ID cannot be empty')),
                  );
                  return;
                }

                try {
                  final body = <String, dynamic>{
                    'name': nameController.text.trim(),
                    'email': newTeacherId,
                    'role': selectedRole,
                    'department': departmentController.text.trim(),
                  };
                  if (passwordController.text.trim().isNotEmpty) {
                    body['password'] = passwordController.text.trim();
                  }

                  await _api.patch(
                    '/users?id=eq.${teacher['id']}',
                    body: body,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error updating teacher: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadTeachers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher ID & details updated successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final passwordController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 10),
              const Expanded(child: Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_off, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${teacher['name'] ?? 'Unknown'}\n${teacher['email'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This action is irreversible. Enter your admin password to confirm:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Admin Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                enabled: !isVerifying,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: isVerifying
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      if (password.isEmpty) {
                        setDialogState(() => errorText = 'Password is required');
                        return;
                      }
                      setDialogState(() {
                        isVerifying = true;
                        errorText = null;
                      });

                      // Verify admin password against Supabase
                      try {
                        final currentUser = await _api.get('/users?role=eq.admin&password=eq.$password&select=id');
                        if (currentUser is List && currentUser.isNotEmpty) {
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            isVerifying = false;
                            errorText = 'Incorrect admin password!';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isVerifying = false;
                          errorText = 'Verification failed: $e';
                        });
                      }
                    },
              icon: isVerifying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever),
              label: Text(isVerifying ? 'Verifying...' : 'Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _api.delete('/users?id=eq.${teacher['id']}');
        _loadTeachers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${teacher['name']}" has been deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Teachers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTeachers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTeacher,
        icon: const Icon(Icons.person_add),
        label: const Text('New Teacher'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeachers,
              child: _teachers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No teacher accounts found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Tap + New Teacher to create one', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _teachers[index];
                        final isTeacherAdmin = teacher['role'] == 'admin';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                              child: Text(
                                (teacher['name'] ?? 'T')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    teacher['name'] ?? '',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isTeacherAdmin ? Colors.purple.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (teacher['role'] ?? 'teacher').toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isTeacherAdmin ? Colors.purple : Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Teacher ID: ${teacher['email'] ?? ''}\nDept: ${teacher['department'] ?? 'Not specified'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _editTeacher(teacher);
                                if (value == 'delete') _deleteTeacher(teacher);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18, color: Colors.indigo),
                                      SizedBox(width: 8),
                                      Text('Alter / Modify ID'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
