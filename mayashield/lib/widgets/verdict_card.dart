import 'package:flutter/material.dart';
import '../models/analysis_result.dart';

class VerdictCard extends StatelessWidget {
  final AnalysisResult result;
  final String callerNumber;

  const VerdictCard({
    super.key,
    required this.result,
    required this.callerNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isScam = result.isScam;
    final primaryColor =
        isScam ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    final accentColor =
        isScam ? const Color(0xFFEF5350) : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Column(
        children: [
          // Icon
          Icon(
            isScam ? Icons.shield_outlined : Icons.shield,
            color: accentColor,
            size: 56,
          ),
          const SizedBox(height: 12),

          // Verdict label
          Text(
            isScam ? 'SCAM DETECTED' : 'CALL SAFE',
            style: TextStyle(
              color: accentColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            callerNumber,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Confidence bar
          _ConfidenceBar(confidence: result.confidence, color: accentColor),
          const SizedBox(height: 16),

          // Reason
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          // Indicators chips
          if (result.indicators.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.indicators
                  .map((i) => Chip(
                        label: Text(i,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final int confidence;
  final Color color;

  const _ConfidenceBar({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Confidence',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            Text('$confidence%',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence / 100,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
