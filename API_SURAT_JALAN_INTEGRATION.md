# Integrasi API Surat Jalan - Dashboard One Link

## Overview
Fitur ini mengintegrasikan API surat jalan dari ERP system ke dalam dashboard aplikasi One Link. Data surat jalan ditampilkan sebagai list marking/order dengan UI yang menarik dan informatif.

## API Endpoint
```
GET http://erp.test/api/surat_jalan?user_id=128
```

### Parameters
- `user_id`: ID pengguna yang login (hardcoded: 128)
- `status`: (optional) Filter berdasarkan status
- `date`: (optional) Filter berdasarkan tanggal (format: YYYY-MM-DD)

## Implementation Details

### 1. Model Data (`lib/models/surat_jalan.dart`)
- `SuratJalanResponse`: Main response wrapper
- `SuratJalan`: Data surat jalan utama
- `SuratJalanDetail`: Detail item dalam surat jalan
- `Progress`: Progress tracking surat jalan
- `FiltersApplied`: Filter yang diterapkan

### 2. Service Layer (`lib/services/surat_jalan_service.dart`)
- HTTP client untuk API calls
- Error handling (network, timeout, parsing)
- Helper functions untuk formatting
- Automatic retry mechanism

### 3. UI Components (`lib/screens/dashboard_screen.dart`)

#### Features Implemented:
- **Loading State**: Circular progress indicator saat memuat data
- **Error Handling**: Error widget dengan tombol retry
- **Empty State**: Widget khusus saat tidak ada data
- **Statistics Cards**: 
  - Tugas Hari Ini (total surat jalan)
  - Total Minyak (akumulasi liter)
  - Selesai (count status 'done')

#### Surat Jalan Card Components:
- **Header**: Kode surat jalan dengan status badge
- **Supplier Info**: Nama supplier dengan icon business
- **Driver & Vehicle**: Nama driver dan plat nomor
- **Quantity & Price**: Total liter dan harga dengan formatting currency
- **Progress Bar**: Visual progress indicator (0-100%)
- **Date**: Tanggal formatted

#### Interactive Elements:
- **Refresh Button**: Manual refresh data dari API
- **Map Integration**: Marker berdasarkan koordinat GPS gudang
- **Quick Actions**: Refresh data dan lihat semua

## Status Colors
- **Green**: Status 'done' (selesai)
- **Orange**: Status 'pickup' (sedang pickup)
- **Red**: Status lainnya (pending, cancelled)

## Data Mapping

### API Response → UI Display
```json
{
  "kode": "GEU-SR-25-LZB0034",           // → Card header
  "supplier_names": "Indri Pandanlandung", // → Supplier info
  "driver_name": "Sampurno",             // → Driver info
  "plat": "N 8392 EO (MLG)",             // → Vehicle info
  "total_liter": "19",                   // → Quantity display
  "total_harga": "123500",               // → Price (formatted as Rp)
  "progress.percentage": 100,            // → Progress bar
  "status": "done",                      // → Status badge
  "tanggal_formatted": "02 Dec 2025"    // → Date display
}
```

## Error Handling
1. **Network Error**: "No internet connection" message
2. **Timeout Error**: "Request timeout" with retry option
3. **Server Error**: HTTP status code with error message
4. **Parsing Error**: "Invalid data format" message
5. **General Error**: Fallback error message

## Currency Formatting
- Format: "Rp 1,234,567"
- Automatic thousands separator
- Zero decimal places

## Map Integration
- Markers created from `gudang_gps` coordinates
- Color coding berdasarkan status surat jalan
- Info window dengan supplier name dan quantity

## Performance Considerations
- Data loaded otomatis saat screen init
- Manual refresh tersedia via button
- Efficient list rendering dengan ListView.builder
- Local state management untuk UI responsiveness

## Future Enhancements
1. Pull-to-refresh gesture
2. Filter by status/date
3. Detail page untuk setiap surat jalan
4. Real-time updates via websocket
5. Offline mode dengan local storage
6. Export functionality

## Dependencies
```yaml
dependencies:
  http: ^1.6.0                    # HTTP client
  google_maps_flutter: ^2.14.0   # Map integration
```

## Usage Example
```dart
// Auto-load pada startup
await SuratJalanService.getTodaySuratJalan('128');

// Manual refresh
await SuratJalanService.getSuratJalan(
  userId: '128',
  status: 'done',
  date: '2025-12-02'
);
```

## Testing
- Test dengan data dari API response yang diberikan
- Handle edge cases (empty data, network error)
- Responsive design untuk berbagai screen size