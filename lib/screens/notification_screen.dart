import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'Penjemputan Selesai',
        'message': 'Penjemputan di RM. Ayam Goreng Berkah telah selesai',
        'time': '2 jam lalu',
        'type': 'success',
        'read': false,
      },
      {
        'title': 'Jadwal Baru',
        'message': 'Anda memiliki jadwal penjemputan besok pukul 10:00',
        'time': '5 jam lalu',
        'type': 'info',
        'read': false,
      },
      {
        'title': 'Pengingat',
        'message': 'Jangan lupa penjemputan di Warung Sari Rasa pukul 14:30',
        'time': '1 hari lalu',
        'type': 'warning',
        'read': true,
      },
      {
        'title': 'Target Tercapai',
        'message': 'Selamat! Anda telah mencapai target 500L minggu ini',
        'time': '2 hari lalu',
        'type': 'success',
        'read': true,
      },
      {
        'title': 'Lokasi Baru',
        'message': 'Ada lokasi penjemputan baru di dekat Anda',
        'time': '3 hari lalu',
        'type': 'info',
        'read': true,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Notifikasi',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Mark all as read
            },
            child: Text(
              'Tandai Semua',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final isRead = notification['read'] as bool;

          IconData icon;
          Color iconColor;

          switch (notification['type']) {
            case 'success':
              icon = Icons.check_circle;
              iconColor = AppColors.success;
              break;
            case 'warning':
              icon = Icons.warning;
              iconColor = AppColors.warning;
              break;
            case 'info':
            default:
              icon = Icons.info;
              iconColor = AppColors.info;
              break;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isRead
                  ? AppColors.white
                  : AppColors.primaryGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead
                    ? AppColors.grey.withOpacity(0.2)
                    : AppColors.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      notification['title'] as String,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    notification['message'] as String,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(
                        notification['time'] as String,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
