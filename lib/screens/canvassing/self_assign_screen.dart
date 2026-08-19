import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/geu/geu_auth_service.dart';
import '../../services/geu/self_assign_service.dart';

class SelfAssignScreen extends StatefulWidget {
  /// When true, renders just the content (no Scaffold/AppBar) so this can be
  /// embedded as a tab inside TasksHubScreen.
  final bool embedded;

  const SelfAssignScreen({super.key, this.embedded = false});

  @override
  State<SelfAssignScreen> createState() => _SelfAssignScreenState();
}

class _SelfAssignScreenState extends State<SelfAssignScreen> {
  GeuUser? _user;
  String _mode = 'cro-ro';
  List<SelfAssignSupplier> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _user = await GeuAuthService.getCachedUser();
    final canCro = _user?.hasPermission('crm-self-assign-cro') ?? false;
    final canRo = _user?.hasPermission('crm-self-assign-ro') ?? false;
    _mode = canCro && canRo
        ? 'cro-ro'
        : canCro
        ? 'cro'
        : canRo
        ? 'ro'
        : 'cro-ro';
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SelfAssignService.suppliers(mode: _mode);
      if (mounted) setState(() => _items = data.suppliers);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmClaim(SelfAssignSupplier supplier) async {
    final role = _mode == 'cro' ? 'cro' : 'ro';
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Klaim supplier?'),
        content: Text('Klaim ${supplier.name} sebagai ${role.toUpperCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Klaim'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await SelfAssignService.claim(supplierId: supplier.id, role: role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${supplier.name} berhasil diklaim.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Klaim gagal: $e. Daftar diperbarui.'),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCro = _user?.hasPermission('crm-self-assign-cro') ?? false;
    final canRo = _user?.hasPermission('crm-self-assign-ro') ?? false;
    final modes = <String>[
      'cro-ro',
      if (canCro) 'cro',
      if (canRo) 'ro',
      if (canRo) 'revisit',
    ];
    final body = Column(
      children: [
        if (_user != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: modes
                  .map(
                    (mode) => ButtonSegment(
                      value: mode,
                      label: Text(
                        mode == 'cro-ro'
                            ? 'CRO/RO'
                            : mode == 'revisit'
                            ? 'Revisit'
                            : mode.toUpperCase(),
                      ),
                    ),
                  )
                  .toList(),
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() => _mode = value.first);
                _load();
              },
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!),
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final supplier = _items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: ListTile(
                          title: Text(supplier.name),
                          subtitle: Text(
                            '${supplier.code} • ${supplier.city}\n${supplier.type}',
                          ),
                          isThreeLine: true,
                          trailing: FilledButton(
                            onPressed: () => _confirmClaim(supplier),
                            child: const Text('Klaim'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks & Self-Assign')),
      body: body,
    );
  }
}
