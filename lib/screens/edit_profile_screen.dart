import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/geu/geu_api_client.dart';
import '../services/geu/geu_auth_service.dart';
import '../services/user_storage.dart';
import '../services/persistent_auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  File? _avatarFile;
  String? _currentAvatarPath;

  bool _isLoading = false;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await UserStorage.getUser();
      final persistentData = await PersistentAuthService.instance.getUserData();

      String name = user?['name']?.toString() ?? persistentData['userName']?.toString() ?? '';
      String email = user?['email']?.toString() ?? persistentData['userEmail']?.toString() ?? '';
      String phone = user?['phone']?.toString() ?? persistentData['userPhone']?.toString() ?? '';
      String nik = user?['nik']?.toString() ?? '';
      String alamat = user?['alamat']?.toString() ?? user?['address']?.toString() ?? '';
      String? avatar = user?['avatar_path'] as String? ?? user?['avatar'] as String?;

      // Default fallback for real developer account if local storage missing
      if (email.toLowerCase().contains('santosofebrikukuh')) {
        if (phone.isEmpty) phone = '082140647578';
        if (nik.isEmpty) nik = 'GEU001';
        if (avatar == null || avatar.isEmpty) avatar = 'fd4d5ecdbc6531836babd22f5eee0a70.png';
      }

      setState(() {
        _nameController.text = name;
        _nikController.text = nik;
        _emailController.text = email;
        _phoneController.text = phone;
        _addressController.text = alamat;
        _currentAvatarPath = avatar;
        _isDataLoaded = true;
      });

      // Login only caches {id, name, email, groups, roles} — never the
      // avatar — so a freshly logged-in user has no local avatar to show
      // here until this syncs it from the Go API (see profile_screen.dart's
      // own call to the same method for why the legacy PHP fetch was
      // replaced).
      final serverAvatar = await GeuAuthService.syncAvatar();
      if (serverAvatar != null && mounted) {
        setState(() {
          _currentAvatarPath = serverAvatar;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ubah Foto Profil',
                  style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                  title: const Text('Ambil Foto Kamera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final rawBytes = await File(picked.path).readAsBytes();

      // Compress photo into WebP format
      final webpBytes = await FlutterImageCompress.compressWithList(
        rawBytes,
        format: CompressFormat.webp,
        quality: 80,
        minWidth: 800,
        minHeight: 800,
      );

      final tempDir = await getTemporaryDirectory();
      final webpFile = File('${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.webp');
      await webpFile.writeAsBytes(webpBytes);

      setState(() {
        _avatarFile = webpFile;
        _currentAvatarPath = webpFile.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diproses! Klik Simpan untuk memperbarui.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses foto: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await UserStorage.getUser();
      final token = await UserStorage.getToken();

      if (currentUser != null && token != null) {
        String? avatarData;
        if (_avatarFile != null && _avatarFile!.existsSync()) {
          final bytes = await _avatarFile!.readAsBytes();
          avatarData = 'data:image/webp;base64,${base64Encode(bytes)}';
        } else if (_currentAvatarPath != null) {
          avatarData = _currentAvatarPath;
        }

        final updatedUser = {
          ...currentUser,
          'name': _nameController.text.trim(),
          'nik': _nikController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'alamat': _addressController.text.trim(),
          if (avatarData != null) 'avatar_path': avatarData,
          if (avatarData != null) 'avatar': avatarData,
        };

        await UserStorage.saveUser(user: updatedUser, token: token);

        // Sync with ERP MySQL database via Go REST API
        try {
          final dio = await GeuApiClient.instance;
          final res = await dio.put(
            '/api-auth/profile',
            data: {
              'name': _nameController.text.trim(),
              'nik': _nikController.text.trim(),
              'phone': _phoneController.text.trim(),
              'alamat': _addressController.text.trim(),
              if (avatarData != null) 'avatar': avatarData,
            },
          );

          if (res.data != null && res.data['data'] is Map && res.data['data']['avatar'] != null) {
            final savedAvatarName = res.data['data']['avatar'].toString();
            updatedUser['avatar'] = savedAvatarName;
            updatedUser['avatar_path'] = savedAvatarName;
            await UserStorage.saveUser(user: updatedUser, token: token);
          }
        } catch (e) {
          print('API profile sync warning: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informasi pribadi berhasil diperbarui.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAvatarImage() {
    if (_avatarFile != null) {
      return ClipOval(
        child: Image.file(_avatarFile!, fit: BoxFit.cover, width: 100, height: 100),
      );
    }

    if (_currentAvatarPath != null && _currentAvatarPath!.isNotEmpty) {
      final path = _currentAvatarPath!;

      // 1. Base64 Data URI image
      if (path.startsWith('data:image/')) {
        try {
          final bytes = base64Decode(path.split(',').last);
          return ClipOval(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: 100,
              height: 100,
              errorBuilder: (_, _, _) => const Icon(Icons.person, size: 50, color: AppColors.primaryGreen),
            ),
          );
        } catch (_) {}
      }

      // 1. Direct Cloudflare R2 or HTTP/HTTPS CDN URL
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            path,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
            errorBuilder: (_, _, _) => const Icon(Icons.person, size: 50, color: AppColors.primaryGreen),
          ),
        );
      }

      // 2. Local device file path
      if (File(path).existsSync()) {
        return ClipOval(
          child: Image.file(File(path), fit: BoxFit.cover, width: 100, height: 100),
        );
      }

      final filename = path.contains('/') ? path.split('/').last : path;
      final avatarUrl = 'https://geu.fekusa.com/filemanager/avatar/$filename';

      return ClipOval(
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, _, _) => const Icon(Icons.person, size: 50, color: AppColors.primaryGreen),
        ),
      );
    }

    return const Icon(
      Icons.person,
      size: 50,
      color: AppColors.primaryGreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Informasi Pribadi',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Simpan',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _isLoading ? AppColors.grey : AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: !_isDataLoaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Profile Photo Avatar Circle
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primaryGreen, width: 2),
                              ),
                              child: _buildAvatarImage(),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _showPhotoSourceBottomSheet,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Real Form Fields matching s_users table
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Nama Lengkap',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama lengkap wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: _nikController,
                            label: 'NIK / Kode User',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Terdaftar',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: true,
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Nomor HP / WhatsApp',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nomor HP wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Alamat Domisili',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save Button
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppColors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Simpan Perubahan',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.grey),
            hintText: 'Masukkan $label',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
            filled: true,
            fillColor: readOnly ? AppColors.backgroundGrey : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
