import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/geu/crm_permission_service.dart';
import '../../services/geu/gps_service.dart';
import '../../services/geu/visit_planner_service.dart';

class ScanProspectScreen extends StatefulWidget {
  const ScanProspectScreen({super.key});
  @override
  State<ScanProspectScreen> createState() => _ScanProspectScreenState();
}

class _ScanProspectScreenState extends State<ScanProspectScreen> {
  final _keyword = TextEditingController();
  List<ScanJob> _jobs = const [];
  List<String> _topKeywords = const [];
  ScanQuota? _quota;
  int _radius = 1000;
  bool _requirePhone = false, _loading = true, _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        VisitPlannerService.getScanJobs(),
        VisitPlannerService.getTopScanKeywords(),
        VisitPlannerService.getMyScanQuota(),
      ]);
      final jobs = result[0] as List<ScanJob>;
      if (mounted)
        setState(() {
          _jobs = jobs;
          _topKeywords = result[1] as List<String>;
          _quota = result[2] as ScanQuota;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  Future<void> _scan() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      setState(() => _error = 'Masukkan kata kunci prospek terlebih dahulu.');
      return;
    }
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      if ((_quota?.remaining ?? 1) <= 0) {
        throw VisitPlannerException(
          'Kuota scan habis. Selesaikan mission yang masih pending terlebih dahulu.',
        );
      }
      if (!await CrmPermissionService.ensureLocation(context))
        throw GpsException('Izin lokasi diperlukan untuk scan prospek.');
      final fix = await GpsService.getCurrentFix();
      final jobId = await VisitPlannerService.createScanJob(
        keyword: keyword,
        latitude: fix.latitude,
        longitude: fix.longitude,
        radiusMeters: _radius,
        minRating: 0,
        requirePhone: _requirePhone,
      );
      final saved = await VisitPlannerService.runProspectScan(
        jobId: jobId,
        keyword: keyword,
        latitude: fix.latitude,
        longitude: fix.longitude,
        radiusMeters: _radius,
        requirePhone: _requirePhone,
      );
      if (!mounted) return;
      _keyword.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$saved prospek baru tersimpan.')));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Scan Prospek'),
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Riset area',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cari calon supplier di sekitar lokasi Anda. Hasil tersimpan sebagai prospek untuk dimasukkan ke Mission.',
          ),
          const SizedBox(height: 16),
          if (_quota != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radar_outlined, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kuota scan tersedia: ${_quota!.remaining} dari ${_quota!.quota}',
                    ),
                  ),
                  Text(
                    '${_quota!.pending} pending',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_topKeywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Pencarian populer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _topKeywords
                  .take(6)
                  .map(
                    (keyword) => ActionChip(
                      label: Text(keyword),
                      onPressed: _scanning
                          ? null
                          : () => setState(() => _keyword.text = keyword),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _keyword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _scanning ? null : _scan(),
            decoration: const InputDecoration(
              labelText: 'Kata kunci *',
              hintText: 'Contoh: restoran, hotel, katering',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _radius,
            decoration: const InputDecoration(
              labelText: 'Radius pencarian',
              border: OutlineInputBorder(),
            ),
            items: const [500, 1000, 2000, 5000]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('$value meter'),
                  ),
                )
                .toList(),
            onChanged: _scanning
                ? null
                : (value) => setState(() => _radius = value ?? 1000),
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wajib ada nomor telepon'),
            subtitle: const Text('Hanya simpan prospek yang memiliki kontak'),
            value: _requirePhone,
            onChanged: _scanning
                ? null
                : (value) => setState(() => _requirePhone = value),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.radar_outlined),
              label: Text(_scanning ? 'Memindai area…' : 'Mulai scan'),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Riwayat scan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Belum ada scan.')),
            )
          else
            ..._jobs.map(_jobCard),
        ],
      ),
    ),
  );

  Widget _jobCard(ScanJob job) {
    final color = switch (job.status) {
      'done' => AppColors.success,
      'failed' => AppColors.error,
      'running' => AppColors.accentOrange,
      _ => AppColors.info,
    };
    final label = switch (job.status) {
      'done' => 'Selesai',
      'failed' => 'Gagal',
      'running' => 'Diproses',
      _ => 'Menunggu',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.keyword,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${job.radius} m · Ditemukan ${job.found} · Disimpan ${job.saved}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (job.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${job.createdAt!.day.toString().padLeft(2, '0')}/${job.createdAt!.month.toString().padLeft(2, '0')} ${job.createdAt!.hour.toString().padLeft(2, '0')}:${job.createdAt!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (job.status == 'done')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showProspects(job),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Lihat prospek'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProspects(ScanJob job) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProspectListSheet(job: job),
  );
}

class _ProspectListSheet extends StatefulWidget {
  final ScanJob job;
  const _ProspectListSheet({required this.job});
  @override
  State<_ProspectListSheet> createState() => _ProspectListSheetState();
}

class _ProspectListSheetState extends State<_ProspectListSheet> {
  List<ScannedProspect>? _items;
  String? _error;
  final Set<int> _adding = {}, _added = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await VisitPlannerService.getScannedProspects(widget.job);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _add(ScannedProspect item) async {
    setState(() => _adding.add(item.id));
    try {
      await VisitPlannerService.addScannedProspectToMission(item.id);
      if (mounted) setState(() => _added.add(item.id));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _adding.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.of(context).size.height * .78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prospek: ${widget.job.keyword}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _items == null
                  ? (_error == null
                        ? const Center(child: CircularProgressIndicator())
                        : Center(child: Text(_error!)))
                  : _items!.isEmpty
                  ? const Center(
                      child: Text('Belum ada prospek dari scan ini.'),
                    )
                  : ListView.separated(
                      itemCount: _items!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = _items![index];
                        final unavailable =
                            item.status == 'VISITED' ||
                            item.status == 'SKIPPED' ||
                            _added.contains(item.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              item.address,
                              if (item.phone.isNotEmpty) item.phone,
                            ].where((value) => value.isNotEmpty).join('\n'),
                          ),
                          isThreeLine: item.phone.isNotEmpty,
                          trailing: unavailable
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                )
                              : FilledButton(
                                  onPressed: _adding.contains(item.id)
                                      ? null
                                      : () => _add(item),
                                  child: _adding.contains(item.id)
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('+ Mission'),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
