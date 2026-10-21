import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../models/lab.dart';

class AdminLabScreen extends StatefulWidget {
  const AdminLabScreen({super.key});

  @override
  State<AdminLabScreen> createState() => _AdminLabScreenState();
}

class _AdminLabScreenState extends State<AdminLabScreen> {
  final ApiClient _api = ApiClient();
  List<Lab> _labs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/labs?select=*&order=id.asc');
      if (response is List) {
        _labs = response.map((json) => Lab.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading labs: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createLab() async {
    final nameController = TextEditingController();
    final buildingController = TextEditingController();
    final floorController = TextEditingController();
    final roomController = TextEditingController();
    int fanCount = 1;
    int lightCount = 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_business, color: Colors.teal),
              SizedBox(width: 10),
              Text('Create New Lab'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Lab Name *',
                    hintText: 'e.g. Computer Lab 2',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.science),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: buildingController,
                  decoration: InputDecoration(
                    labelText: 'Building',
                    hintText: 'e.g. Block A',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: floorController,
                        decoration: InputDecoration(
                          labelText: 'Floor',
                          hintText: 'e.g. 2',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: roomController,
                        decoration: InputDecoration(
                          labelText: 'Room No.',
                          hintText: 'e.g. 201',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                Text('Devices to Add', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mode_fan_off, color: Colors.cyan),
                        SizedBox(width: 8),
                        Text('Fans'),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: fanCount > 0 ? () => setDialogState(() => fanCount--) : null,
                        ),
                        Text('$fanCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setDialogState(() => fanCount++),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Lights'),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: lightCount > 0 ? () => setDialogState(() => lightCount--) : null,
                        ),
                        Text('$lightCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setDialogState(() => lightCount++),
                        ),
                      ],
                    ),
                  ],
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Lab name is required')),
                  );
                  return;
                }

                try {
                  // Create lab
                  final labRes = await _api.post(
                    '/labs',
                    headers: {'Prefer': 'return=representation'},
                    body: {
                      'lab_name': name,
                      'building': buildingController.text.trim(),
                      'floor': floorController.text.trim(),
                      'room_number': roomController.text.trim(),
                    },
                  );

                  // Get lab ID
                  String labId = '';
                  if (labRes is List && labRes.isNotEmpty) {
                    labId = labRes[0]['id'].toString();
                  } else if (labRes is Map && labRes['id'] != null) {
                    labId = labRes['id'].toString();
                  }

                  if (labId.isNotEmpty) {
                    // Create fan devices
                    for (int i = 1; i <= fanCount; i++) {
                      await _api.post('/devices', body: {
                        'device_name': fanCount == 1 ? 'Fan' : 'Fan $i',
                        'device_type': 'fan',
                        'lab_id': int.tryParse(labId) ?? labId,
                        'power_state': 'OFF',
                        'status': 'online',
                      });
                    }

                    // Create light devices
                    for (int i = 1; i <= lightCount; i++) {
                      await _api.post('/devices', body: {
                        'device_name': lightCount == 1 ? 'Light' : 'Light $i',
                        'device_type': 'light',
                        'lab_id': int.tryParse(labId) ?? labId,
                        'power_state': 'OFF',
                        'status': 'online',
                      });
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error creating lab: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Create Lab'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadLabs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lab created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteLab(Lab lab) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lab?'),
        content: Text('Are you sure you want to delete "${lab.name}" and all its devices? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete associated devices first
        await _api.delete('/devices?lab_id=eq.${lab.id}');
        // Delete the lab
        await _api.delete('/labs?id=eq.${lab.id}');
        _loadLabs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${lab.name}" deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting lab: $e'), backgroundColor: Colors.red),
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
        title: const Text('Manage Labs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLabs,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLab,
        icon: const Icon(Icons.add),
        label: const Text('New Lab'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLabs,
              child: _labs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No labs found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Tap + New Lab to create one', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _labs.length,
                      itemBuilder: (context, index) {
                        final lab = _labs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.withValues(alpha: 0.1),
                              child: const Icon(Icons.science, color: Colors.teal),
                            ),
                            title: Text(lab.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${lab.building.isNotEmpty ? lab.building : 'No building'} • Floor ${lab.floor.isNotEmpty ? lab.floor : '-'} • Room ${lab.roomNumber.isNotEmpty ? lab.roomNumber : '-'}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteLab(lab),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
