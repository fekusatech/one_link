
← Kembali ke pemilih aplikasi
Go REST API — Dokumentasi Referensi
Referensi lengkap semua endpoint REST API ini (Fiber v3 + GORM + MySQL), dikelompokkan per domain. Untuk alur bisnis detail per fitur, lihat dokumen terpisah yang sudah ada di folder ini: sso-integration.md, my-statistic.md, cro-assignation.md, self-claim.md.

Ada juga Swagger UI otomatis (di-generate dari komentar @Summary/@Router di controller via swag init) yang jalan di /docs ketika APP_ENV != prod — tapi baru ~163 dari ~290 route yang punya anotasi swagger, jadi tidak lengkap. Dokumen ini mencakup semuanya, hasil baca langsung dari kode router.

Ringkasan arsitektur
Framework: Fiber v3, middleware stack global (lihat src/main.go): request logger → Helmet (CrossOriginResourcePolicy: cross-origin, supaya Grees/CRM/TMS di subdomain lain bisa fetch API ini) → compress → CORS (origin dari env CORS_ALLOW_ORIGINS, AllowCredentials: true karena auth pakai cookie) → recover.
Database: MySQL via GORM. Tabel-tabel "shared" penting (apps, app_access, app_access_delegates, t_system_settings, live_chat_messages) sengaja tidak didaftarkan di database.AutoMigrate — schema-nya di-import manual lewat file SQL di migrations/.
Swagger meta: judul "Go REST API", @BasePath /, @securityDefinitions.apikey BearerAuth (header Authorization) — meski di praktiknya auth beneran pakai cookie httpOnly, bukan Bearer token (lihat di bawah).
Autentikasi & Otorisasi
Token & cookie
Login (POST /api-auth/login) mengembalikan access token (cookie auth_token, umur JWT_ACCESS_EXP_MINUTES menit) dan refresh token (cookie refresh_token, umur JWT_REFRESH_EXP_DAYS hari, juga disimpan di DB lewat TokenService.SaveToken untuk revocation). Keduanya JWT, claim type membedakan access/refresh, claim sub = user ID, dan access token juga membawa daftar nama group (role) user.
POST /api-auth/refresh baca refresh_token, validasi ke DB (belum revoked, belum expired), terbitkan access token baru.
POST /api-auth/logout revoke refresh token yang aktif.
GET /api-auth/validate dan GET /api-auth/me baca cookie auth_token langsung di handler (bukan lewat middleware Auth()) — jadi keduanya tidak muncul di grup route mana pun, tapi tetap butuh token valid.
Route yang butuh login pakai middleware middleware.Auth(): ambil cookie auth_token, verifikasi JWT, taruh user_id dan roles (nama group) di fiber.Ctx.Locals. Kalau tidak ada/invalid token → 401.
Permission (RBAC)
Model: user → s_users_groups → group → s_group_permissions → s_permission (kolom SLUG, mis. crm-read-visit-planner, tms-update-pickup).
Middleware middleware.RequirePermission(db, "slug-a", "slug-b", ...): cek user_id dari Locals, query EXISTS user punya salah satu slug tsb (OR, bukan AND) → kalau tidak, 403 Insufficient permissions.
Slug crm-manage-permissions dan tms-manage-permissions dipakai sebagai penanda "admin global" di beberapa tempat (RBAC routes, delegate app_access, live chat admin) — bukan slug RBAC biasa per-fitur.
Beberapa endpoint admin (App Access) tidak pakai RequirePermission di level route, tapi cek izin di dalam handler sendiri (CanManageApp/IsGlobalAdmin) karena target permission-nya dinamis (tergantung app di query/body, bukan diketahui saat route didaftarkan) — ditandai "in-handler" di tabel di bawah.
Delegasi akses per-app
Selain permission global, ada mekanisme delegate: seorang admin bisa mendelegasikan hak kelola satu app tertentu (grant/revoke akses, ubah base URL) ke role (group) atau user tertentu, tanpa memberi mereka crm-manage-permissions/tms-manage-permissions penuh. Lihat tabel app_access_delegates dan AppAccessService.CanManageApp.

Konvensi umum
Response envelope — semua endpoint sukses/gagal balas bentuk yang sama (src/response/response.go):

{ "status": "success", "code": 200, "message": "Success", "data": { ... }, "timestamp": "..." }
Gagal: "status": "error", data biasanya kosong, code = HTTP status.

Pagination — endpoint yang di-paginate (list dengan page/limit) balas data + pagination:

{ "data": [...], "pagination": { "current_page": 1, "per_page": 20, "total_records": 42, "total_pages": 3, "has_next": true, "has_prev": false } }
Prefix route (bukan aturan ketat, tapi pola yang dipakai konsisten):

Prefix	Isi
/api-auth/*	Login, session, SSO handoff, daftar app milik user
/api-admin/*	Operasi admin: app access, RBAC, live-chat settings/history
/api-crm/*	Fitur CRM (chat, assignment, task, pickup, dashboard)
/api-tms/*	Fitur TMS (fleet, pickup, surat jalan, mapping, dll)
/api/*	Fitur cross-cutting (supplier, warehouse, work order, visit planner, live-chat widget, settings, karyawan, fleet master, ro-gudang)
/ajax/*	Satu endpoint lawas (dropdown kategori)
/health	Health check, tanpa auth
/docs	Swagger UI (hanya kalau APP_ENV != prod)
/filemanager/*	Static file server (ERP file manager)
Auth (/api-auth)
Method	Path	Handler	Guard	Purpose
POST	/api-auth/login	AuthController.Login	tanpa auth	Login email/password, set cookie auth_token + refresh_token
POST	/api-auth/logout	AuthController.Logout	butuh cookie refresh_token	Revoke refresh token aktif
POST	/api-auth/refresh	AuthController.Refresh	butuh cookie refresh_token	Terbitkan access token baru
GET	/api-auth/validate	AuthController.Validate	butuh cookie auth_token (cek manual di handler)	Cek validitas access token
GET	/api-auth/me	AuthController.Me	butuh cookie auth_token (cek manual di handler)	Profil user login (termasuk groups + permissions)
GET	/api-auth/sso/code	AuthController.IssueSSOCode	middleware.Auth()	Terbitkan kode SSO sekali-pakai (60 detik) ke redirect_uri — lihat sso-integration.md
POST	/api-auth/sso/exchange	AuthController.ExchangeSSOCode	tanpa auth (kode sekali-pakai jadi otentikasinya)	App lain tukar kode SSO jadi profil user (server-to-server)
GET	/api-auth/apps	AppAccessController.MyApps	middleware.Auth()	Daftar app yang boleh diakses user login (dipakai halaman pemilih app)
Health
Method	Path	Handler	Guard	Purpose
GET	/health	HealthCheck	tanpa auth	Health check
Admin — App Access (/api-admin)
AppAccessRoutes sengaja tidak pakai adminGuard statis di level grup — izin dicek per-app di dalam handler (lihat "Delegasi akses" di atas).

Method	Path	Handler	Guard	Purpose
GET	/api-admin/app-access/users	ListUsers	auth + CanManageApp(app) (in-handler)	List user + status akses ke suatu app (paginated, searchable)
POST	/api-admin/app-access	GrantAccess	auth + CanManageApp(app) (in-handler)	Beri akses user ke suatu app
DELETE	/api-admin/app-access	RevokeAccess	auth + CanManageApp(app) (in-handler)	Cabut akses user dari suatu app
GET	/api-admin/app-access/delegates	ListDelegates	auth + IsGlobalAdmin (in-handler)	List delegate (user/group) pengelola suatu app
POST	/api-admin/app-access/delegates	AddDelegate	auth + IsGlobalAdmin (in-handler)	Tambah delegate pengelola suatu app
DELETE	/api-admin/app-access/delegates/:id	RemoveDelegate	auth + IsGlobalAdmin (in-handler)	Hapus delegate
POST	/api-admin/users/:id/ban	BanUser	auth + IsGlobalAdmin (in-handler)	Ban akun user
POST	/api-admin/users/:id/unban	UnbanUser	auth + IsGlobalAdmin (in-handler)	Buka ban akun user
GET	/api-admin/apps	ListApps	auth (in-handler: cuma balikin app yang caller boleh kelola, 403 kalau kosong)	List kartu app yang boleh dikelola caller
POST	/api-admin/apps	CreateApp	auth + IsGlobalAdmin (in-handler)	Tambah kartu app baru (SSO beneran atau sekadar "coming soon")
PUT	/api-admin/apps/:id	UpdateApp	auth + CanManageApp(id) (in-handler)	Update kartu app (nama, tag, deskripsi, base URL, maintenance, visibility)
Admin — RBAC (/api-admin)
Semua route di bawah pakai RequirePermission(db, "crm-manage-permissions", "tms-manage-permissions") (OR).

Method	Path	Handler	Purpose
GET	/api-admin/menus	ListMenus	List menu tree CRM
GET	/api-admin/tms/menus	ListTMSMenus	List menu tree TMS
GET	/api-admin/all/menus	ListAllMenus	Menu tree gabungan CRM+TMS
GET	/api-admin/permissions	ListPermissions	List permission CRM
GET	/api-admin/tms/permissions	ListTMSPermissions	List permission TMS (paginated)
GET	/api-admin/all/permissions	ListAllPermissions	List permission gabungan (paginated)
POST	/api-admin/permissions	CreatePermission	Buat permission baru di bawah menu
PUT	/api-admin/permissions/:id	UpdatePermission	Update nama/slug/menu/urutan permission
DELETE	/api-admin/permissions/:id	DeletePermission	Hapus permission
GET	/api-admin/groups	ListGroups	List group/role (paginated)
GET	/api-admin/groups/:id/permissions	GetGroupPermissions	Permission yang dimiliki suatu group
PUT	/api-admin/groups/:id/permissions	SetGroupPermissions	Ganti seluruh set permission suatu group
Admin — Live Chat (/api-admin/live-chat, /api/live-chat)
Widget "lapor kendala app" di halaman One Login. Endpoint admin pakai RequirePermission(db, "crm-manage-permissions", "tms-manage-permissions"); endpoint publik cuma butuh login.

Method	Path	Handler	Guard	Purpose
GET	/api/live-chat/settings	GetSettings	auth	Cek widget live chat aktif/tidak
POST	/api/live-chat/messages	SendMessage	auth	Kirim pesan (langsung dibalas kalengan, dua-duanya dipersist)
GET	/api-admin/live-chat/messages	ListHistory	auth + admin	Histori percakapan (paginated, searchable per nama/email)
PUT	/api-admin/live-chat/settings	UpdateSettings	auth + admin	Aktif/nonaktifkan widget
Shared / cross-cutting (/api/*)
Fleets — master data (/api/fleets)
Method	Path	Handler	Guard	Purpose
GET	/api/fleets	List	auth	List armada
GET	/api/fleets/:id	GetByID	auth	Detail armada
POST	/api/fleets	Create	auth + tms-create-master-fleet	Tambah armada
PUT	/api/fleets/:id	Update	auth + tms-update-master-fleet	Update armada
DELETE	/api/fleets/:id	Delete	auth + tms-delete-master-fleet	Hapus armada
Karyawan (/api/karyawan)
Method	Path	Handler	Guard	Purpose
GET	/api/karyawan	List	auth	List karyawan (paginated/searchable/filter status aktif)
Settings (/api/settings)
Method	Path	Handler	Guard	Purpose
GET	/api/settings/r2	GetR2Config	auth	Ambil konfigurasi Cloudflare R2
PUT	/api/settings/r2	SetR2Config	auth	Ubah konfigurasi R2
GET	/api/settings/:key	GetByKey	auth	Ambil satu nilai setting by key
Catatan: PUT /api/settings/r2 cuma butuh login, tidak ada guard admin — beda dengan live-chat settings yang sudah admin-gated. Perlu ditinjau kalau mau disamakan standarnya.
Suppliers (/api/suppliers)
Method	Path	Handler	Guard	Purpose
GET	/api/suppliers/dropdowns	GetSupplierDropdowns	auth	Opsi dropdown form supplier
GET	/api/suppliers/dashboard-stats	SupplierDashboardStats	auth	Statistik dashboard supplier (filter PIC opsional)
GET	/api/suppliers/generate-code/:jenis	GenerateSupplierCode	auth	Generate kode supplier berikutnya per jenis
GET	/api/suppliers/search-cities	SearchAllCities	auth	Cari kota lintas provinsi
GET	/api/suppliers/cities-by-ids	GetCitiesByIds	auth	Ambil banyak kota by list ID
GET	/api/suppliers/cities/:province_id	GetCities	auth	Kota dalam satu provinsi (searchable)
GET	/api/suppliers/districts/:city_id	GetDistricts	auth	Kecamatan dalam satu kota
GET	/api/suppliers/villages/:district_id	GetVillages	auth	Kelurahan dalam satu kecamatan
POST	/api/suppliers/validate-account	ValidateSupplierAccount	auth	Validasi rekening via BIFast
GET	/api/suppliers/nearest-gudang	GetNearestGudang	auth	Gudang terdekat dari koordinat GPS
GET	/api/suppliers/employees	GetEmployees	auth	List karyawan untuk pemilihan PIC (paginated, searchable)
GET	/api/suppliers/pending-edits	ListPendingEdits	auth	List permintaan edit supplier yang menunggu approval
GET	/api/suppliers/distribution/cities	GetCityDistribution	auth	Distribusi supplier aktif per kota
GET	/api/suppliers/distribution/cities/:kota_id/kecamatans	GetKecamatanDistribution	auth	Distribusi per kecamatan dalam satu kota
GET	/api/suppliers/distribution/cities/:kota_id	GetSuppliersByCity	auth	Supplier aktif di satu kota
GET	/api/suppliers/distribution/map	GetSupplierMap	auth	Titik peta supplier (filter funnel-stage & zona)
GET	/api/suppliers	ListSuppliers	auth	List supplier (paginated, filter jenis/kota/status/tanggal)
GET	/api/suppliers/:id	GetSupplier	auth	Detail supplier
POST	/api/suppliers	CreateSupplier	auth	Buat supplier
PUT	/api/suppliers/:id/toggle-status	ToggleSupplierStatus	auth	Toggle status aktif/nonaktif
PUT	/api/suppliers/:id/approve-edit/:edit_id	ApproveSupplierEdit	auth	Setujui permintaan edit
PUT	/api/suppliers/:id/reject-edit/:edit_id	RejectSupplierEdit	auth	Tolak permintaan edit
PUT	/api/suppliers/:id	UpdateSupplier	auth (role "Developer"/"Super User" bypass alur approval, dicek in-handler)	Update supplier (biasanya lewat alur approval)
DELETE	/api/suppliers/:id	DeleteSupplier	auth	Hapus supplier (soft delete)
Warehouses (/api/warehouses)
Method	Path	Handler	Guard	Purpose
GET	/api/warehouses	List	auth	List gudang (paginated, searchable, filter tipe)
GET	/api/warehouses/:id	GetByID	auth	Detail gudang
POST	/api/warehouses	Create	auth + tms-create-master-gudang	Tambah gudang
PUT	/api/warehouses/:id	Update	auth + tms-update-master-gudang	Update gudang
DELETE	/api/warehouses/:id	Delete	auth + tms-delete-master-gudang	Hapus gudang
Work Orders (/api/work-orders)
Method	Path	Handler	Guard	Purpose
GET	/api/work-orders/statuses	ListStatuses	auth	List status work order
GET	/api/work-orders	ListWO	auth	List WO (paginated, filter tanggal/supplier/status/tipe/PIC)
GET	/api/work-orders/:id	GetWO	auth	Detail WO
POST	/api/work-orders	CreateWO	auth + (tms-create-work-order OR crm-create-work-order)	Buat WO
PUT	/api/work-orders/:id	UpdateWO	auth + (tms-update-work-order OR crm-update-work-order)	Update WO
DELETE	/api/work-orders/:id	DeleteWO	auth + (tms-delete-work-order OR crm-delete-work-order)	Hapus WO (soft delete)
Follow Work Orders (/api/follow-work-orders)
Method	Path	Handler	Guard	Purpose
GET	/api/follow-work-orders	ListFWO	auth	List follow-WO (paginated, filter WO induk/tanggal)
GET	/api/follow-work-orders/:id	GetFWO	auth	Detail follow-WO
POST	/api/follow-work-orders	CreateFWO	auth	Buat follow-WO
PUT	/api/follow-work-orders/:id	UpdateFWO	auth	Update follow-WO
DELETE	/api/follow-work-orders/:id	DeleteFWO	auth	Hapus follow-WO (soft delete)
RO ↔ Gudang mapping (/api/master-data/ro-gudang)
Method	Path	Handler	Guard	Purpose
GET	/api/master-data/ro-gudang/	List	auth	List assignment RO ↔ gudang
GET	/api/master-data/ro-gudang/ro-users	ListROUsers	auth	List user RO yang bisa di-assign
GET	/api/master-data/ro-gudang/gudang	ListGudang	auth	List gudang yang tersedia
POST	/api/master-data/ro-gudang/	Create	auth + crm-manage-ro-area	Sync/assign RO ke satu atau lebih gudang
DELETE	/api/master-data/ro-gudang/:id	Delete	auth + crm-manage-ro-area	Hapus satu assignment
DELETE	/api/master-data/ro-gudang/ro-user/:roUserId	DeleteByRoUser	auth + crm-manage-ro-area	Hapus semua assignment gudang milik satu user RO
Visit Planner (/api/visit-planner)
Guard: vpReadGuard = crm-read-visit-planner, vpWriteGuard = (crm-create-visit-planner OR crm-update-visit-planner), monitorGuard = crm-manage-scan-monitor. Semua di bawah middleware.Auth().

Method	Path	Handler	Guard	Purpose
GET	/mission/today	GetTodaysMission	read	Misi kunjungan hari ini
GET	/mission/history	GetMissionHistory	read	Histori misi
POST	/mission/add	AddToMission	write	Tambah target ke misi
POST	/mission/add-scanned	AddScannedPlaceToMission	write	Tambah lokasi hasil scan ke misi
POST	/mission/add-poi	AddPoiToMission	write	Tambah POI ke misi
POST	/mission/remove	RemoveFromMission	write	Hapus dari misi
POST	/mission/status	UpdateMissionStatus	write	Update status misi
GET	/suppliers/nearby	GetNearbySuppliers	read	Supplier terdekat
GET	/suppliers/by-city	GetSuppliersByCity	read	Supplier per kota
GET	/scanned-places	GetScannedPlaces	read	List lokasi hasil scan
POST	/prospect/register	RegisterProspect	write	Daftarkan prospek baru
POST	/work-order/store	StoreWorkOrder	write	Simpan WO dari kunjungan
POST	/scan/trigger	TriggerScan	write	Trigger scan lokasi
POST	/scan/save-batch	SaveScannedPlacesBatch	write	Simpan batch hasil scan
GET	/wo-statuses	GetWoStatuses	read	List status WO
POST	/upload-photo	UploadPhoto	write	Upload foto kunjungan
POST	/scan/jobs	CreateScanJob	write	Buat job scan
GET	/scan/jobs	GetMyScanJobs	read	List job scan milik user
GET	/scan/jobs/keywords/top	GetTopKeywords	read	Top keyword pencarian scan
PATCH	/scan/jobs/:id	UpdateScanJob	write	Update job scan
GET	/scan/monitor	GetScanMonitor	read	Monitor scan (ringkasan)
GET	/scan/monitor/ro-activity	GetRoActivity	monitor	Aktivitas RO (khusus monitor)
GET	/scan/token-stats	GetTokenStats	read	Statistik token/kuota scan
PUT	/scan/quota/:ro_id	SetScanQuota	monitor	Set kuota scan untuk satu RO
GET	/scan/my-quota	GetMyQuota	read	Kuota scan milik user login
POST	/gps	SaveGps	auth saja (tanpa read/write guard)	Simpan titik GPS
POST	/gps/offline	SetOffline	auth saja	Tandai user offline
GET	/kabupaten/:id	GetKabupatenName	read	Nama kabupaten by ID
POST	/scanned-places/:id/resolve-address	ResolveScannedPlaceAddress	read	Resolve alamat dari lokasi scan
GET	/scanned-places/:id/visit-photos	GetScannedPlaceVisitPhotos	read	Foto kunjungan pada satu lokasi scan
Ajax legacy (/ajax)
Method	Path	Handler	Guard	Purpose
POST	/ajax/get_all_kategori_source	Controller.GetAllKategoriSource	tanpa auth	Dropdown kategori source (endpoint gaya lama)
CRM (/api-crm)
Chat Bot (/api-crm/chat-sessions)
Method	Path	Handler	Guard	Purpose
GET	/api-crm/chat-sessions/	ListSessions	crm-read-chat	List sesi chat
GET	/api-crm/chat-sessions/detail/:session_id	Detail	crm-read-chat	Detail sesi
GET	/api-crm/chat-sessions/:session_id/messages	Messages	crm-read-chat	Pesan dalam sesi
POST	/api-crm/chat-sessions/:session_id/assign	AssignAgent	crm-create-chat	Assign agent ke sesi
POST	/api-crm/chat-sessions/:session_id/auto-assign	AutoAssign	crm-create-chat	Auto-assign agent paling longgar
PUT	/api-crm/chat-sessions/:session_id/status	UpdateStatus	crm-create-chat	Update status sesi
POST	/api-crm/chat-sessions/sync	Sync	crm-create-chat	Sync sesi dari bot
PUT	/api-crm/chat-sessions/delivery-status	DeliveryStatus	crm-create-chat	Update status delivery pesan
GET	/api-crm/chat-sessions/agents/available	AvailableAgent	crm-read-chat	Agent yang tersedia
GET	/api-crm/chat-sessions/stats	Stats	crm-read-chat	Statistik dashboard chat
GET	/api-crm/chat-sessions/datatables	Datatables	crm-read-chat	Server-side DataTables sesi chat
CRO Assignment — Point of Origin (/api-crm/point-of-origin)
Method	Path	Handler	Guard	Purpose
GET	/api-crm/point-of-origin/	ListSuppliers	crm-read-assignation	List supplier POO
GET	/api-crm/point-of-origin/assign	Assign	crm-read-assignation	Preview assignment supplier ke user CRO
POST	/api-crm/point-of-origin/assign	CommitAssign	crm-update-assignation	Commit assignment ke DB
GET	/api-crm/point-of-origin/cro-users	GetCroUsers	crm-read-assignation	List user CRO
GET	/api-crm/point-of-origin/assigned-suppliers	ListAssignedSuppliers	crm-read-assignation	Supplier yang sudah di-assign ke user login
ROE Assignment (/api-crm/point-of-origin)
Method	Path	Handler	Guard	Purpose
GET	/api-crm/point-of-origin/roe-users	GetRoeUsers	crm-read-assignation	List user ROE
GET	/api-crm/point-of-origin/roe-eligible-suppliers	GetEligibleSuppliers	crm-read-assignation	Supplier eligible untuk ROE (paginated, searchable, filter gudang)
GET	/api-crm/point-of-origin/roe-assigned-suppliers	GetMyAssignments	crm-read-assignation	Supplier ROE milik user login
POST	/api-crm/point-of-origin/assign-roe	Assign	crm-update-assignation	Assign supplier ke user ROE
PATCH	/api-crm/point-of-origin/roe-assigned-suppliers/:supplierID/complete	CompleteAssignment	crm-update-assignation	Tandai assignment ROE selesai
Self Assign (/api-crm/self-assign)
Method	Path	Handler	Guard	Purpose
GET	/api-crm/self-assign/suppliers	ListInactiveSuppliers	crm-read-self-assign	Supplier tidak aktif yang bisa di-self-assign
GET	/api-crm/self-assign/suppliers-revisit	ListInactiveForRevisit	crm-self-assign-ro	Supplier tidak aktif ditandai revisit RO
GET	/api-crm/self-assign/suppliers-cro	ListActiveForCro	crm-self-assign-cro	Supplier aktif untuk self-assign CRO
GET	/api-crm/self-assign/suppliers-ro	ListActiveForRo	crm-self-assign-ro	Supplier aktif untuk self-assign RO
GET	/api-crm/self-assign/suppliers-ro-area	ListActiveForRoByArea	crm-self-assign-ro	Sama, difilter area gudang user login
POST	/api-crm/self-assign/claim	ClaimSupplier	crm-update-self-assign	Klaim (self-assign) supplier sebagai CRO/RO
POST	/api-crm/self-assign/escalate	EscalateClaim	crm-update-self-assign	Eskalasi klaim (rekomendasi revisit/hapus)
GET	/api-crm/self-assign/my-claims	ListMyClaims	crm-read-self-assign	Supplier yang diklaim user login
Task (/api-crm/tasks)
Method	Path	Handler	Guard	Purpose
GET	/api-crm/tasks/batches/	ListBatches	crm-read-task	List batch assignment
GET	/api-crm/tasks/batches/:id	GetBatchDetail	crm-read-task	Detail batch + item
GET	/api-crm/tasks/roe-batches/	ListRoeBatches	crm-read-task	List batch assignment ROE
GET	/api-crm/tasks/roe-batches/:id	GetRoeBatchDetail	crm-read-task	Detail batch ROE + item
GET	/api-crm/tasks/items	ListItems	crm-read-task	List item task (view CRO)
GET	/api-crm/tasks/roe-items	ListRoeItems	crm-read-task	List item task ROE
Pickup CRM (/api-crm/pickups)
Method	Path	Handler	Guard	Purpose
GET	/api-crm/pickups/	List	crm-read-pickup	List pickup
GET	/api-crm/pickups/:id	GetByID	crm-read-pickup	Detail pickup
POST	/api-crm/pickups/	Create	crm-create-pickup	Buat pickup (selaras ERP)
PATCH	/api-crm/pickups/:id/basic	UpdateBasic	crm-update-pickup	Update field dasar pickup langsung (tanpa approval)
POST	/api-crm/pickups/:id/change-request	SubmitChangeRequest	crm-update-pickup	Ajukan perubahan/hapus (butuh approval)
POST	/api-crm/pickups/check-supplier-rekening	CheckSupplierRekening	auth	Validasi rekening supplier via BIFast
Sales Visit (/api/visits)
Method	Path	Handler	Guard	Purpose
GET	/api/visits/status	GetVisitStatus	crm-read-visit-planner	Status check-in aktif user login
POST	/api/visits/checkin	Checkin	crm-read-visit-planner + crm-create-visit-planner	Check-in di lokasi supplier (validasi jarak GPS)
POST	/api/visits/checkout	Checkout	crm-read-visit-planner + crm-create-visit-planner	Check-out, opsional kaitkan WO
GET	/api/visits/history	GetVisitHistory	crm-read-visit-planner	Histori kunjungan (paginated)
GET	/api/visits/stats	GetVisitStats	crm-read-visit-planner	Statistik kunjungan user login
CRM Dashboard — My Statistic (/api-crm/dashboard/my-statistic)
Semua auth saja (tidak ada permission slug tambahan) — lihat my-statistic.md untuk detail formula per kartu.

Method	Path	Handler	Purpose
GET	/overview	GetOverview	Ringkasan dashboard
GET	/assignment-performance	GetAssignmentPerformance	Performa assignment
GET	/new-supplier	GetNewSupplier	Jumlah supplier baru (role-based)
GET	/existing-supplier	GetExistingSupplier	Jumlah supplier existing (role-based)
GET	/poo-closed	GetPooClosed	Jumlah POO closed (WO status A1)
GET	/daily-activity	GetDailyActivity	Aktivitas harian (WO/PO)
GET	/acquisition-detail	GetAcquisitionDetail	Detail akuisisi per bulan
GET	/acquisition	GetAcquisition	Amount/volume/AAC akuisisi
GET	/target-achievement	GetTargetAchievement	Capaian target
GET	/activity-summary	GetActivitySummary	Ringkasan aktivitas
GET	/export	ExportReport	Export laporan
CRM Dashboard — Analytics (/api-crm/dashboard/analytics)
Method	Path	Handler	Guard	Purpose
GET	/sourcing	GetSourcingAnalytics	auth	Analitik sourcing
GET	/poo-supplier	GetPooSupplierAnalytics	auth	Analitik POO & supplier
GET	/funnel	GetFunnelAnalytics	auth	Analitik funnel
GET	/geographic	GetGeographicAnalysis	auth	Analisis geografis
GET	/team-performance	GetTeamPerformance	auth	Performa tim
GET	/export	ExportReport	auth	Export laporan analitik
TMS (/api-tms)
Fleet Transaction (/api-tms/fleets)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/fleets/reminders	GetReminders	auth	Reminder servis/pajak/KIR armada
GET	/api-tms/fleets/:id/services	ListServices	auth	List servis armada
POST	/api-tms/fleets/:id/services	CreateService	tms-create-master-fleet	Tambah servis
PUT	/api-tms/fleets/:fleet_id/services/:service_id	UpdateService	tms-update-master-fleet	Update servis
DELETE	/api-tms/fleets/:fleet_id/services/:service_id	DeleteService	tms-delete-master-fleet	Hapus servis
GET	/api-tms/fleets/:id/taxes	ListPajak	auth	List pajak armada
POST	/api-tms/fleets/:id/taxes	CreatePajak	tms-create-master-fleet	Tambah pajak
PUT	/api-tms/fleets/:fleet_id/taxes/:pajak_id	UpdatePajak	tms-update-master-fleet	Update pajak
DELETE	/api-tms/fleets/:fleet_id/taxes/:pajak_id	DeletePajak	tms-delete-master-fleet	Hapus pajak
GET	/api-tms/fleets/:id/kirs	ListKIR	auth	List KIR armada
POST	/api-tms/fleets/:id/kirs	CreateKIR	tms-create-master-fleet	Tambah KIR
PUT	/api-tms/fleets/:fleet_id/kirs/:kir_id	UpdateKIR	tms-update-master-fleet	Update KIR
DELETE	/api-tms/fleets/:fleet_id/kirs/:kir_id	DeleteKIR	tms-delete-master-fleet	Hapus KIR
Service Item (/api-tms/service-items)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/service-items	List	auth	List item servis
POST	/api-tms/service-items	Create	tms-create-master-fleet	Tambah item servis
PUT	/api-tms/service-items/:id	Update	tms-update-master-fleet	Update item servis
DELETE	/api-tms/service-items/:id	Delete	tms-delete-master-fleet	Hapus item servis
Pickup TMS (/api-tms/pickups)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/pickups	List	auth	List pickup
GET	/api-tms/pickups/drivers	ListDrivers	auth	List driver pickup
GET	/api-tms/pickups/logistic-suggestions	GetLogisticSuggestions	auth	Saran armada/driver untuk pickup
GET	/api-tms/pickups/work-orders	ListAvailableWorkOrders	auth	WO yang eligible untuk pickup
GET	/api-tms/pickups/:id	GetByID	auth	Detail pickup
POST	/api-tms/pickups	Create	tms-create-pickup	Buat pickup
PUT	/api-tms/pickups/:id/logistic	UpdateLogistic	tms-update-pickup	Update assignment armada/driver
PATCH	/api-tms/pickups/:id/basic	UpdateBasic	tms-update-pickup	Update field dasar pickup
POST	/api-tms/pickups/:id/change-request	SubmitChangeRequest	tms-update-pickup	Ajukan perubahan pickup
DELETE	/api-tms/pickups/:id	Delete	tms-delete-pickup	Ajukan hapus pickup
POST	/api-tms/pickups/:id/approve	Approve	auth	Setujui pickup
POST	/api-tms/pickups/:id/reject	Reject	auth	Tolak pickup
Surat Jalan (/api-tms/surat-jalan)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/surat-jalan	List	auth	List Surat Jalan
GET	/api-tms/surat-jalan/:id	GetByID	auth	Detail Surat Jalan
GET	/api-tms/surat-jalan/detail/:detailId/photos	GetDetailPhotos	auth	Foto detail SJ
POST	/api-tms/surat-jalan/detail/:detailId/photos	UploadDetailPhoto	tms-update-surat-jalan	Upload foto detail SJ
POST	/api-tms/surat-jalan/detail/:detailId/gps	SaveDetailGPS	tms-update-surat-jalan	Simpan GPS detail SJ
POST	/api-tms/surat-jalan/detail/:detailId/ttd	SaveDetailTTD	tms-update-surat-jalan	Simpan tanda tangan detail SJ
POST	/api-tms/surat-jalan/detail/:detailId/gps/delete	RequestDeleteDetailGPS	tms-update-surat-jalan	Ajukan hapus GPS
POST	/api-tms/surat-jalan/detail/:detailId/gps/delete/approve	ApproveDeleteDetailGPS	tms-update-surat-jalan	Setujui hapus GPS
POST	/api-tms/surat-jalan/detail/:detailId/gps/delete/reject	RejectDeleteDetailGPS	tms-update-surat-jalan	Tolak hapus GPS
POST	/api-tms/surat-jalan/detail/:detailId/ttd/delete	RequestDeleteDetailTTD	tms-update-surat-jalan	Ajukan hapus TTD
POST	/api-tms/surat-jalan/detail/:detailId/ttd/delete/approve	ApproveDeleteDetailTTD	tms-update-surat-jalan	Setujui hapus TTD
POST	/api-tms/surat-jalan/detail/:detailId/ttd/delete/reject	RejectDeleteDetailTTD	tms-update-surat-jalan	Tolak hapus TTD
POST	/api-tms/surat-jalan/detail/photo/:photoId/delete	RequestDeleteDetailPhoto	tms-update-surat-jalan	Ajukan hapus foto
POST	/api-tms/surat-jalan/detail/photo/:photoId/delete/approve	ApproveDeleteDetailPhoto	tms-update-surat-jalan	Setujui hapus foto
POST	/api-tms/surat-jalan/detail/photo/:photoId/delete/reject	RejectDeleteDetailPhoto	tms-update-surat-jalan	Tolak hapus foto
PUT	/api-tms/surat-jalan/detail/:detailId/status	UpdateDetailStatus	tms-update-surat-jalan	Update status detail SJ
POST	/api-tms/surat-jalan	Create	tms-create-surat-jalan	Buat SJ (convert dari Pickup)
PUT	/api-tms/surat-jalan/:id	Update	tms-update-surat-jalan	Update SJ
DELETE	/api-tms/surat-jalan/:id	Delete	tms-delete-surat-jalan	Hapus (rollback) SJ
Enums (/api-tms/enums)
Didaftarkan di file router yang sama dengan Surat Jalan.

Method	Path	Handler	Guard	Purpose
GET	/api-tms/enums/:table/:column	GetValues	auth	Ambil nilai enum sebuah kolom tabel
Dashboard TMS
Method	Path	Handler	Guard	Purpose
GET	/api-tms/dashboard/stats	GetDashboardStats	auth	Statistik dashboard TMS (dipakai kartu resume TMS di One Login)
Notification (/api-tms/notifications)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/notifications	GetInbox	auth	Inbox notifikasi user login
PATCH	/api-tms/notifications/read-all	MarkAllAsRead	auth	Tandai semua terbaca
PATCH	/api-tms/notifications/:id/read	MarkAsRead	auth	Tandai satu terbaca
Movement (/api-tms/movements)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/movements	List	auth	List movement (scope user/global tergantung permission)
GET	/api-tms/movements/:id	GetByID	auth	Detail movement + kalkulasi biaya + settlement
POST	/api-tms/movements/:id/settlements/bulk	SaveSettlementBulk	tms-update-movement	Simpan draft settlement bulk
POST	/api-tms/movements/:id/settlements/submit	SubmitSettlementBulk	tms-update-movement	Submit settlement bulk untuk approval
DELETE	/api-tms/movements/settlements/attachments/:id/photo	DeleteSettlementAttachmentPhoto	tms-delete-movement	Hapus foto lampiran settlement
DELETE	/api-tms/movements/settlements/attachments/:id/row	DeleteSettlementAttachmentRow	tms-delete-movement	Hapus baris lampiran settlement
Settlement Mapping (/api-tms/settlement-mapping)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/settlement-mapping	List	tms-read-settlement-pickup	List kalkulasi biaya + settlement
GET	/api-tms/settlement-mapping/:id	GetByID	tms-read-settlement-pickup	Detail settlement mapping
POST	/api-tms/settlement-mapping/:id/settlements/bulk	SaveSettlementBulk	tms-update-settlement-pickup	Simpan settlement (draft)
POST	/api-tms/settlement-mapping/:id/settlements/submit	SubmitSettlementBulk	tms-update-settlement-pickup	Simpan & submit settlement
POST	/api-tms/settlement-mapping/:id/non-receipt-approval	ApproveNonReceipt	tms-approve-settlement-pickup	Approve/reject settlement non-receipt
DELETE	/api-tms/settlement-mapping/settlements/attachments/:id/photo/:type	DeleteSettlementAttachmentPhoto	tms-delete-settlement-pickup	Hapus foto lampiran
Tracking (/api-tms/tracking)
Method	Path	Handler	Guard	Purpose
POST	/api-tms/tracking/update	UpdateLocation	tms-update-tracking	Update lokasi GPS user (tracking berkelanjutan)
GET	/api-tms/tracking/live	GetLiveTracking	auth	Lokasi live semua user aktif
GET	/api-tms/tracking/history	GetRouteHistory	auth	Histori rute GPS user tertentu per tanggal
Zona (/api-tms/zona)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/zona/list	GetList	auth	List zona per kota
GET	/api-tms/zona/list-by-gudang	GetByGudang	auth	List zona per gudang
POST	/api-tms/zona/list-by-kota-ids	GetByKotaIDs	auth	List zona untuk beberapa kota sekaligus
GET	/api-tms/zona/list-all	GetAll	auth	Semua zona (paginated)
GET	/api-tms/zona/detect	Detect	auth	Deteksi zona dari titik GPS + gudang
POST	/api-tms/zona/create	Create	tms-create-pickup	Buat zona baru
PUT	/api-tms/zona/update/:id	Update	tms-update-pickup	Update zona
DELETE	/api-tms/zona/delete/:id	Delete	tms-delete-pickup	Hapus zona
Mapping / Routing (/api-tms/mapping)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/mapping/data	GetData	tms-read-mapping	Data peta (filter tanggal/gudang/driver/status)
GET	/api-tms/mapping/statistics	GetStatistics	tms-read-mapping	Statistik mapping
POST	/api-tms/mapping/calculate-route	CalculateRoute	tms-read-mapping	Hitung rute
POST	/api-tms/mapping/routes	SaveRoute	tms-create-mapping	Simpan rute
GET	/api-tms/mapping/routes	GetSavedRoutes	tms-read-mapping	List rute tersimpan
GET	/api-tms/mapping/routes/:id	GetRouteDetails	tms-read-mapping	Detail rute
DELETE	/api-tms/mapping/routes/:id	DeleteRoute	tms-delete-mapping	Hapus rute
POST	/api-tms/mapping/routes/:id/pickups	AppendPickupToRoute	tms-update-mapping	Tambah waypoint pickup ke rute
DELETE	/api-tms/mapping/routes/:id/pickups	RemovePickupFromRoute	tms-update-mapping	Hapus waypoint pickup dari rute
GET	/api-tms/mapping/routes/:id/available-pickups	GetAvailablePickups	tms-read-mapping	Pickup yang bisa ditambahkan ke rute
PATCH	/api-tms/mapping/routes/:id/distance	UpdateRouteDistance	tms-update-mapping	Update jarak rute
GET	/api-tms/mapping/cost-calculations	GetCostCalculations	tms-read-mapping	List kalkulasi biaya
POST	/api-tms/mapping/cost-calculations	SaveCostCalculation	tms-create-mapping	Simpan kalkulasi biaya baru
GET	/api-tms/mapping/cost-calculations/:id	GetCostCalculationDetail	tms-read-mapping	Detail kalkulasi biaya
PUT	/api-tms/mapping/cost-calculations/:id	UpdateCostCalculation	tms-update-mapping	Update kalkulasi biaya
DELETE	/api-tms/mapping/cost-calculations/:id	DeleteCostCalculation	tms-delete-mapping	Hapus kalkulasi biaya
GET	/api-tms/mapping/bbm-prices	GetBbmPrices	tms-read-mapping	Harga BBM
PUT	/api-tms/mapping/bbm-prices	UpdateBbmPrices	tms-update-mapping-bbm	Update harga BBM
GET	/api-tms/mapping/cost-templates	GetCostTemplates	tms-read-mapping	Template kalkulasi biaya
GET	/api-tms/mapping/gudang-balance	GetGudangBalance	tms-read-mapping	Saldo biaya per gudang (read-only)
Other Cost (/api-tms/other-costs)
Method	Path	Handler	Guard	Purpose
GET	/api-tms/other-costs	List	tms-read-other-cost-warehouse	List permintaan biaya lain-lain
GET	/api-tms/other-costs/:id	GetByID	tms-read-other-cost-warehouse	Detail permintaan
POST	/api-tms/other-costs	Create	tms-create-other-cost-warehouse	Buat permintaan
PUT	/api-tms/other-costs/:id	Update	tms-update-other-cost-warehouse	Update permintaan
DELETE	/api-tms/other-costs/:id	Delete	tms-delete-other-cost-warehouse	Hapus permintaan
POST	/api-tms/other-costs/:id/request-finish	RequestFinish	tms-update-other-cost-warehouse	Tandai selesai, kirim ke Finance
POST	/api-tms/other-costs/:id/realizations	CreateRealization	tms-update-other-cost-warehouse	Buat realisasi (settlement)
PUT	/api-tms/other-costs/realizations/:id	UpdateRealization	tms-update-other-cost-warehouse	Update realisasi
Migrasi database
Tabel-tabel "shared" (app registry, app access, delegate, system settings, live chat) sengaja tidak ikut database.AutoMigrate — DDL + seed-nya hidup sebagai file SQL bernomor urut di migrations/ (001_rbac_crm.sql s.d. 010_apps_visibility_and_live_chat.sql saat dokumen ini ditulis), diimport manual ke database. Kalau menambah tabel baru dengan pola serupa, ikuti konvensi ini — bukan didaftarkan ke AutoMigrate.