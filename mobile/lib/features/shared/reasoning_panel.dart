import 'package:flutter/material.dart';

// Dummy classes to represent data models from the JSON structure
class ReasoningOption {
  final String providerId;
  final String headline;
  final String reasoning;
  final String tradeoff;

  ReasoningOption({
    required this.providerId,
    required this.headline,
    required this.reasoning,
    required this.tradeoff,
  });
}

class BookingReasoning {
  final ReasoningOption option1;
  final ReasoningOption option2;
  final String whyOthersExcluded;

  BookingReasoning({
    required this.option1,
    required this.option2,
    required this.whyOthersExcluded,
  });
}

class ReasoningPanel extends StatelessWidget {
  final BookingReasoning reasoning;

  const ReasoningPanel({Key? key, required this.reasoning}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark theme for agent
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.blueAccent,
          collapsedIconColor: Colors.grey,
          title: const Row(
            children: [
              Icon(Icons.smart_toy, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                "Agentic Reasoning",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reasoning.whyOthersExcluded.isNotEmpty) ...[
                    Text(
                      "Filters applied: ${reasoning.whyOthersExcluded}",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildOption(reasoning.option1, isPrimary: true),
                  if (reasoning.option2.providerId.isNotEmpty) ...[
                    const Divider(color: Colors.white24, height: 24),
                    _buildOption(reasoning.option2, isPrimary: false),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(ReasoningOption opt, {required bool isPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isPrimary ? Icons.star : Icons.star_border,
              color: isPrimary ? Colors.amber : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                opt.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          opt.reasoning,
          style: TextStyle(color: Colors.grey[300], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.compare_arrows, color: Colors.deepOrange, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                opt.tradeoff,
                style: const TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
