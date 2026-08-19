# GPS Tracking Testing Guide - One Link App

## ✅ BUILD SUCCESSFUL!
App berhasil dibuild dan diinstall ke Android emulator `emulator-5554`

## 🧪 Testing Checklist

### 1. Dashboard Integration Test
- [ ] Buka aplikasi One Link di emulator
- [ ] Navigate ke Sales Dashboard 
- [ ] Verify LocationTrackingWidget terlihat di dashboard
- [ ] Check status tracking (Aktif/Nonaktif)
- [ ] Test toggle switch functionality

### 2. Settings Screen Test  
- [ ] Tap tombol "Pengaturan" di LocationTrackingWidget
- [ ] Verify Location Tracking Settings screen terbuka
- [ ] Test toggle tracking on/off
- [ ] Check consent management flow
- [ ] Access privacy policy dari settings

### 3. Privacy & Compliance Test
- [ ] Open Privacy Policy screen
- [ ] Verify konten dalam Bahasa Indonesia
- [ ] Check semua sections: Data Usage, Security, Retention, etc.
- [ ] Test back navigation

### 4. Permission Flow Test
- [ ] Enable GPS tracking dari settings
- [ ] Verify permission request dialog muncul
- [ ] Grant location permissions
- [ ] Check consent confirmation

### 5. GPS Simulation Test (Emulator)
- [ ] Buka emulator Extended Controls (⋯ button)  
- [ ] Go to Location tab
- [ ] Set custom GPS coordinates
- [ ] Simulate movement dengan different coordinates
- [ ] Monitor location updates di app

### 6. API Integration Test
- [ ] Enable GPS tracking
- [ ] Monitor network calls via Chrome DevTools/Charles Proxy
- [ ] Verify API calls ke: `https://greenenergiutama.co.id/driver_tracking/save_location`
- [ ] Check payload contains: karyawan_id, coordinates, device_info, battery_level

### 7. Background Service Test
- [ ] Enable GPS tracking  
- [ ] Minimize app (background mode)
- [ ] Verify foreground notification shows "GPS Tracking Aktif"
- [ ] Check location updates continue di background
- [ ] Return to app → verify tracking masih aktif

### 8. Battery Optimization Test  
- [ ] Enable GPS tracking
- [ ] Monitor battery usage di Android settings
- [ ] Check tracking interval efficiency
- [ ] Verify battery level included di API payload

### 9. Error Handling Test
- [ ] Turn off GPS/Location services
- [ ] Try enable tracking → verify error dialog
- [ ] Turn off internet connection
- [ ] Verify offline sync functionality
- [ ] Test permission denied scenarios

### 10. Full Integration Test
- [ ] Login dengan user driver role
- [ ] Enable GPS tracking
- [ ] Navigate through different screens  
- [ ] Verify tracking persists across screens
- [ ] Test location updates sent to server
- [ ] Verify user consent saved properly

## 📍 Emulator GPS Testing Steps

### Method 1: Manual Coordinates
1. Open emulator extended controls (⋯)
2. Go to Location → Single Points
3. Set coordinates: 
   - Jakarta: -6.2088, 106.8456
   - Bandung: -6.9175, 107.6191
   - Surabaya: -7.2575, 112.7521
4. Click "Send" to update GPS position

### Method 2: GPX Route Simulation  
1. Create GPX file dengan multiple coordinates
2. Load GPX di emulator Location → Routes
3. Play route untuk simulate realistic movement
4. Monitor API calls dengan changing coordinates

### Method 3: Real-time Coordinate Control
1. Use emulator Location → Single Points
2. Manually change coordinates setiap 30 detik
3. Verify app detects location changes
4. Check API payload updates accordingly

## 🔧 Debugging Tools

### Android Debug Bridge (ADB)
```bash
# Monitor app logs
adb logcat | grep OneLink

# Check GPS status
adb shell dumpsys location

# Monitor network activity  
adb shell netstat
```

### Chrome DevTools (for Web debugging)
```bash
# If testing web version
flutter run -d chrome
# Open Chrome DevTools → Network tab
# Monitor API calls to tracking endpoint
```

## ✅ Success Criteria

### GPS Tracking System PASSED if:
- ✅ LocationTrackingWidget appears in dashboard
- ✅ Settings screen opens and functions properly  
- ✅ Privacy policy displays correctly
- ✅ GPS permissions requested and granted
- ✅ Location updates detected dan displayed
- ✅ API calls sent to correct endpoint
- ✅ Device info included in payload
- ✅ Background tracking works dengan notification
- ✅ User consent properly managed
- ✅ Error handling works for edge cases

## 🎯 Expected Results

**GPS Tracking System Integration**: ✅ COMPLETE
**Android Build**: ✅ SUCCESSFUL  
**Emulator Install**: ✅ SUCCESSFUL
**Ready for Testing**: ✅ YES

**Next**: Perform manual testing pada Android emulator untuk verify semua GPS tracking functionality bekerja sesuai specifications.