import 'package:flutter/material.dart';

class ServiceStatusIndicator extends StatelessWidget {
  final bool isCallScreeningActive;
  final bool hasOverlayPermission;
  final VoidCallback onEnableCallScreening;
  final VoidCallback onEnableOverlay;

  const ServiceStatusIndicator({
    super.key,
    required this.isCallScreeningActive,
    required this.hasOverlayPermission,
    required this.onEnableCallScreening,
    required this.onEnableOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final allActive = isCallScreeningActive && hasOverlayPermission;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allActive
            ? const Color(0xFF1B5E20).withOpacity(0.3)
            : const Color(0xFF7F0000).withOpacity(0.3),
        border: Border.all(
          color: allActive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allActive ? Icons.shield : Icons.shield_outlined,
                color: allActive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                allActive ? 'MayaShield Active' : 'Setup Required',
                style: TextStyle(
                  color: allActive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: 'Call Screening',
            active: isCallScreeningActive,
            onFix: isCallScreeningActive ? null : onEnableCallScreening,
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: 'Alert Overlay',
            active: hasOverlayPermission,
            onFix: hasOverlayPermission ? null : onEnableOverlay,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onFix;

  const _StatusRow({
    required this.label,
    required this.active,
    this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.cancel,
          color: active ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        if (!active && onFix != null)
          GestureDetector(
            onTap: onFix,
            child: const Text(
              'Enable',
              style: TextStyle(
                color: Color(0xFF42A5F5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
