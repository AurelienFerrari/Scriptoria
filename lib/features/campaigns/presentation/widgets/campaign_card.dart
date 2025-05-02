import 'package:flutter/material.dart';

class CampaignCard extends StatelessWidget {
  final String title;
  final String lastUpdate;
  final String imageUrl;
  final VoidCallback onTap;
  final Widget? actionButton;

  const CampaignCard({
    Key? key,
    required this.title,
    required this.lastUpdate,
    required this.imageUrl,
    required this.onTap,
    this.actionButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1F2E),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MJ: $lastUpdate',
                      style: TextStyle(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              if (actionButton != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 0,
                    maxWidth: 120,
                    minHeight: 36,
                    maxHeight: 36,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: actionButton!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}