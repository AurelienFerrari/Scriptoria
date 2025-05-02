import 'package:flutter/material.dart';

class DocumentListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String lastModified;
  final VoidCallback onTap;

  const DocumentListItem({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.lastModified,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lastModified),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}