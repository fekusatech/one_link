import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/tms/driver_score_model.dart';
import '../../services/tms/driver_score_service.dart';

class DriverScoreScreen extends StatefulWidget {
  const DriverScoreScreen({super.key});

  @override
  State<DriverScoreScreen> createState() => _DriverScoreScreenState();
}

class _DriverScoreScreenState extends State<DriverScoreScreen> {
  DriverScoreData? _scoreData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScoreData();
  }

  Future<void> _loadScoreData() async {
    setState(() => _isLoading = true);
    final data = await DriverScoreService.instance.getMyScore();
    if (mounted) {
      setState(() {
        _scoreData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Penilaian & Rating Driver'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _loadScoreData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(_scoreData!),
                  const SizedBox(height: 16),
                  _buildMetricsGrid(_scoreData!),
                  const SizedBox(height: 16),
                  _buildBadgesSection(_scoreData!),
                  const SizedBox(height: 16),
                  _buildIncidentsSection(_scoreData!),
                  const SizedBox(height: 16),
                  _buildTipsSection(_scoreData!),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(DriverScoreData score) {
    final scoreColor = score.overallScore >= 90
        ? AppColors.success
        : score.overallScore >= 75
            ? AppColors.accentOrange
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4D3E), Color(0xFF2E7D5B)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.driverName,
                      style: AppTextStyles.h5.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        score.grade,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Circular Score Gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: score.overallScore / 100.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.overallScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat('⭐ Rating', '${score.ratingStars} / 5.0'),
              _headerStat('🚚 Perjalanan', '${score.totalTrips} SJ'),
              _headerStat('🛣️ Total Jarak', '${score.totalKmDriven.toStringAsFixed(0)} KM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(DriverScoreData score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Indikator Keselamatan Berkendara',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.speed_rounded,
                title: 'Kecepatan Aman',
                value: '${score.speedSafetyRate}%',
                subtitle: 'Di bawah 80 km/h',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                icon: Icons.airline_seat_recline_normal_rounded,
                title: 'Pengereman Halus',
                value: '${score.smoothBrakingRate}%',
                subtitle: 'Bebas rem mendadak',
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.alt_route_rounded,
                title: 'Kepatuhan Rute',
                value: '${score.routeComplianceRate}%',
                subtitle: 'Sesuai rute TMS',
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                icon: Icons.warning_amber_rounded,
                title: 'Insiden Lapangan',
                value: '${score.incidentsCount}',
                subtitle: 'Catatan peringatan',
                color: score.incidentsCount == 0 ? AppColors.success : AppColors.accentOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(DriverScoreData score) {
    if (score.badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lencana & Penghargaan Safety',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: score.badges.length,
            itemBuilder: (context, index) {
              final badge = score.badges[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            badge.title,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            badge.description,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentsSection(DriverScoreData score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catatan Kejadian Berkendara',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (score.incidents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'Bebas insiden. Mengemudi sangat aman!',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
                ),
              ],
            ),
          )
        else
          ...score.incidents.map((incident) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      incident.severity == 'high'
                          ? Icons.error_outline
                          : Icons.info_outline,
                      color: incident.severity == 'high'
                          ? AppColors.error
                          : AppColors.accentOrange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incident.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            incident.detail,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      incident.timeAgo,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildTipsSection(DriverScoreData score) {
    if (score.tips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Tips Mengemudi Aman Hari Ini',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...score.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                  Expanded(
                    child: Text(
                      tip,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
