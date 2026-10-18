import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/cad/cad_feature.dart';
import '../../services/api/cad_api_client.dart';
import 'cad_widgets.dart';

/// Orthographic view slots students fill from technical-drawing class.
const kCadViewLabels = ['front', 'top', 'side', 'iso', 'back', 'bottom'];

/// CAD screen — upload multi-view drawing photos, get editable CadQuery.
class CadScreen extends ConsumerStatefulWidget {
  const CadScreen({super.key});

  @override
  ConsumerState<CadScreen> createState() => _CadScreenState();
}

class _CadScreenState extends ConsumerState<CadScreen> {
  final _picker = ImagePicker();
  final Map<String, Uint8List> _views = {};
  String? _code;
  bool _working = false;
  bool? _executeOk;
  String? _error;
  BackendHealth? _health;

  @override
  void initState() {
    super.initState();
    _refreshHealth();
  }

  Future<void> _refreshHealth() async {
    try {
      final h = await ref.read(cadApiClientProvider).health();
      if (mounted) setState(() => _health = h);
    } catch (_) {
      if (mounted) setState(() => _health = null);
    }
  }

  Future<void> _pick(String label) async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _views[label] = bytes;
      _code = null;
      _executeOk = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    if (_views.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
      _code = null;
      _executeOk = null;
    });
    try {
      final feature = ref.read(cadFeatureProvider);
      final code = await feature.sketchToCad(
        _views.values.toList(),
        labels: _views.keys.toList(),
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        if (code == null) {
          _error = 'Backend unreachable — start backend/ first.';
        } else {
          _code = code;
        }
      });
    } catch (e) {
      if (mounted) setState(() {
        _working = false;
        _error = 'Generation failed: $e';
      });
    }
  }

  Future<void> _validate() async {
    if (_code == null) return;
    setState(() => _working = true);
    try {
      final ok = await ref.read(cadApiClientProvider).execute(_code!);
      if (mounted) setState(() {
        _working = false;
        _executeOk = ok;
      });
    } catch (_) {
      if (mounted) setState(() {
        _working = false;
        _executeOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _health?.ready ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAD Sketch to Code'),
        actions: [
          IconButton(
            icon: Icon(Icons.cloud_outlined,
                color: ready ? Colors.green : Colors.orange),
            tooltip: _health == null ? 'Backend offline' : _health!.device,
            onPressed: _refreshHealth,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Photograph orthographic projections (1-8 views).',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: kCadViewLabels.length,
            itemBuilder: (context, i) {
              final label = kCadViewLabels[i];
              final bytes = _views[label];
              return ViewSlot(
                label: label,
                bytes: bytes,
                onTap: () => _pick(label),
                onClear: bytes == null
                    ? null
                    : () => setState(() => _views.remove(label)),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_views.isEmpty || _working) ? null : _generate,
            icon: _working
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.architecture),
            label: Text(_working ? 'Generating...' : 'Generate CadQuery'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_code != null)
            CodePanel(
              code: _code!,
              executeOk: _executeOk,
              working: _working,
              onValidate: _validate,
            ),
        ],
      ),
    );
  }
}

