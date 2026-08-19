# 🔍 Authentication Debug Guide

## Overview
Sistem debug untuk melihat response JSON dari login/authentication yang disimpan di file `auth.json`.

## Cara Kerja
1. **Auto Save**: Setiap kali login berhasil, response JSON otomatis disimpan ke file `auth.json`
2. **File Location**: File disimpan di Application Documents Directory
3. **Debug Mode Only**: Fitur debug hanya muncul di debug build, tidak di production

## Cara Menggunakan

### 1. Login Normal
- Login menggunakan nomor HP + OTP seperti biasa
- Response JSON otomatis disimpan ke `auth.json`

### 2. View Auth Response - Method 1: Debug Button
- Di halaman **OTP Screen**, ada tombol "🔍 Debug: View Auth Response"
- Tombol ini hanya muncul di debug mode
- Klik untuk melihat response JSON dalam dialog

### 3. View Auth Response - Method 2: Floating Action Button
- Di halaman **Role Selection** dan **Dashboard**, ada floating action button hijau dengan icon bug
- Klik untuk melihat response JSON dalam dialog
- FAB hanya muncul di debug mode

### 4. View Auth Response - Method 3: Console
- Panggil `GlobalDebugUtils.printAuthToConsole()` dari code
- Response akan dicetak ke console/log

## Informasi yang Ditampilkan

### File Information:
- ✅/❌ File status (ditemukan atau tidak)
- 📄 File path lengkap
- 📊 File size dalam bytes
- 🕐 Timestamp terakhir dimodifikasi

### Response Content:
- 📋 Complete JSON response dari login API
- 🕐 Timestamp kapan response disimpan
- 📱 App version

## Contoh Response Structure
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": 128,
      "name": "User Name",
      "email": "user@example.com",
      "phone": "081234567890",
      "company": "Company Name",
      "groups": [...]
    },
    "auth": {
      "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...",
      "expires_at": "2025-12-26T10:30:00Z"
    }
  },
  "saved_at": "2025-12-19T15:45:30.123Z",
  "app_version": "1.0.0"
}
```

## Features

### 🔍 View Response
- Pretty-printed JSON dengan indentasi
- Scrollable untuk response yang panjang
- File info detail

### 🗑️ Clear File
- Tombol "Clear" untuk menghapus file `auth.json`
- Konfirmasi dengan snackbar

### 📱 Production Safety
- Semua fitur debug otomatis hilang di production build
- File tetap disimpan untuk debugging lokal

## File Location
- **Android**: `/data/data/com.example.one_link/app_flutter/auth.json`
- **iOS**: `Documents/auth.json`
- **Desktop**: `Documents/auth.json`

## API Integration Points
Response disimpan di method:
- `AuthService.verifyOtp()` - setelah OTP berhasil diverifikasi

## Debugging Tips
1. Setiap login baru akan overwrite `auth.json`
2. Gunakan console output untuk debugging cepat
3. File tersimpan persistent sampai di-clear atau app di-uninstall
4. Periksa file size untuk memastikan response tersimpan lengkap

## Security Note
⚠️ **File `auth.json` berisi token authentication!**
- Hanya untuk debugging di development
- Jangan share file ini
- Production build tidak menampilkan fitur debug

## Troubleshooting

### File Tidak Ditemukan
- Login ulang untuk generate file baru
- Pastikan permission untuk write ke storage

### Response Kosong
- Cek console log untuk error
- Pastikan API response berhasil (status 200)
- Cek network connection

### Debug Button Tidak Muncul
- Pastikan running di debug mode (bukan release build)
- Check import `GlobalDebugUtils` sudah benar