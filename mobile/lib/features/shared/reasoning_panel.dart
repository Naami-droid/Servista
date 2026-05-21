import 'package:flutter/material.dart';

// Data models representing the JSON structure
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
  final List<dynamic>? providers;

  const ReasoningPanel({
    Key? key,
    required this.reasoning,
    this.providers,
  }) : super(key: key);

  Map<String, dynamic>? _getProviderInfo(String providerId) {
    if (providers == null || providerId.isEmpty) return null;
    for (var item in providers!) {
      final p = item['provider_info'];
      if (p != null && p['uid'] == providerId) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasOption2 = reasoning.option2.providerId.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A).withOpacity(0.95), // Deep Slate Blue
            const Color(0xFF1E293B).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25), width: 1.5), // Glowing sky-blue border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: const Color(0xFF38BDF8),
          collapsedIconColor: Colors.grey,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI MATCH COMPARISON BOARD",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Multi-factor trade-off reasoning",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Excluded filter / context info
                  if (reasoning.whyOthersExcluded.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, color: Color(0xFF94A3B8), size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Filters applied: ${reasoning.whyOthersExcluded}",
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontStyle: FontStyle.italic,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Dynamic Side-by-Side Comparison Columns
                  if (hasOption2)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildColumnOption(
                              context,
                              reasoning.option1,
                              isPrimary: true,
                              badgeText: "🏆 PRIMARY MATCH",
                              badgeColor: const Color(0xFF10B981), // Emerald green
                            ),
                          ),
                          const VerticalDivider(
                            color: Colors.white10,
                            width: 20,
                            thickness: 1,
                          ),
                          Expanded(
                            child: _buildColumnOption(
                              context,
                              reasoning.option2,
                              isPrimary: false,
                              badgeText: "🥈 ALTERNATE MATCH",
                              badgeColor: const Color(0xFF0EA5E9), // Sky blue
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildColumnOption(
                      context,
                      reasoning.option1,
                      isPrimary: true,
                      badgeText: "🏆 BEST RECOMMENDED MATCH",
                      badgeColor: const Color(0xFF10B981),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnOption(
    BuildContext context,
    ReasoningOption opt, {
    required bool isPrimary,
    required String badgeText,
    required Color badgeColor,
  }) {
    final pInfo = _getProviderInfo(opt.providerId);
    final p = pInfo != null ? pInfo['provider_info'] : null;
    final String providerName = p != null ? (p['full_name'] ?? 'Provider') : 'Candidate ID: ${opt.providerId.substring(0, 5)}';
    final String rating = p != null ? "${p['rating']} ★" : "N/A";
    final String distance = pInfo != null ? "${pInfo['distance_km']} km" : "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Mini Profile Summary
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: badgeColor.withOpacity(0.2),
              child: Text(
                providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P',
                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        rating,
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      if (distance.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          "·  $distance away",
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Highlight Headline
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Text(
            opt.headline.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),

        // Reasoning details
        Expanded(
          child: Text(
            opt.reasoning,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tradeoff Warnings
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7C2D12).withOpacity(0.15), // Deep Amber-Rust tint
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFF97316), size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  opt.tradeoff,
                  style: const TextStyle(
                    color: Color(0xFFFDBA74),
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
