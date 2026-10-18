import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled thumbnail slot for one orthographic view photo.
class ViewSlot extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const ViewSlot(
      {super.key, required this.label, this.bytes,
       required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: bytes == null ? Colors.white24 : Colors.green),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.memory(bytes!, fit: BoxFit.cover),
              )
            else
              const Center(
                child: Icon(Icons.add_a_photo_outlined, color: Colors.grey),
              ),
            Positioned(
              left: 6,
              bottom: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: const TextStyle(fontSize: 11)),
              ),
            ),
            if (onClear != null)
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.cancel, size: 18, color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Panel showing generated CadQuery with copy + validate actions.
class CodePanel extends StatelessWidget {
  final String code;
  final bool? executeOk;
  final bool working;
  final VoidCallback onValidate;
  const CodePanel({super.key, required this.code, this.executeOk,
    required this.working, required this.onValidate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('CadQuery code',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied')),
                );
              },
            ),
            TextButton.icon(
              onPressed: working ? null : onValidate,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Validate'),
            ),
          ],
        ),
        if (executeOk != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              executeOk! ? 'Code executes OK' : 'Validation failed',
              style: TextStyle(
                color: executeOk! ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}
