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
