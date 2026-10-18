import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swordtrack/providers/model_providers.dart';

/// Home screen — quick actions + recent notes
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final service = ref.read(modelServiceProvider);
    final ready = await service.isModelReady();
    if (mounted) setState(() => _modelReady = ready);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SwordTrack'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: _modelReady ? Colors.green : Colors.orange),
            tooltip: _modelReady ? 'Model loaded' : 'Model loading…',
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(ready: _modelReady),
            const SizedBox(height: 24),
            const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ActionGrid(),
            const Spacer(),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool ready;
  const _StatusCard({required this.ready});

  @override
  Widget build(BuildContext context) {
    final color = ready ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'On-device model ready' : 'Loading on-device model…',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text('Qwen2.5-0.5B · handwriting + STEM recognition',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          if (!ready) const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionTile(icon: Icons.edit_note, title: 'New Note', subtitle: 'Infinite canvas', route: '/canvas'),
      _ActionTile(icon: Icons.calculate, title: 'Math Solver', subtitle: 'Handwritten → graph', route: '/canvas'),
      _ActionTile(icon: Icons.science_outlined, title: 'Chemistry', subtitle: 'Molecule → 3D model', route: '/canvas'),
      _ActionTile(icon: Icons.architecture, title: 'CAD Sketch', subtitle: 'Multi-view → CadQuery', route: '/cad'),
    ];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => actions[i],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.route});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'SwordTrack v1.0 · Handwriting-first STEM notebook',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    );
  }
}
