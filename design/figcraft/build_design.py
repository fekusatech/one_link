"""Rebuild the editable review board through FigCraft's local command channel."""
import sys,json
from pathlib import Path
from figcraft_control import cmd,call,ROOT
cmd('file.new',{'name':'One Link · Mobile redesign'})
G='#1B4D3E'; O='#E87C1E'; W='#FFFFFF'; BG='#FAFAFA'; SOFT='#F5F5F5'; B='#E0E0E0'; T='#212121'; M='#424242'
steps=[]; frames={}; links=[]
def add(typ,name,x,y,w,h,parent=None,**props):
 key='n'+str(len(steps)); p=dict(type=typ,name=name,x=x,y=y,width=w,height=h,select=False,props=props)
 if parent:p['parent']={'$ref':parent}
 steps.append({'command':'node.create','as':key,'params':p});return key
def rect(p,x,y,w,h,fill=W,r=0,name='Surface',stroke=None):
 props=dict(fill=fill,cornerRadius=r)
 if stroke:props.update(stroke=stroke,strokeWeight=1)
 return add('rectangle',name,x,y,w,h,p,**props)
def txt(p,x,y,text,size=14,color=T,weight='Regular',w=342,h=None):
 return add('text',text,x,y,w,h or size*1.5,p,characters=text,fontFamily='Arial',fontStyle=weight,fontSize=size,lineHeight='130%',fill=color,textAutoResize='none')
def line(p,y):rect(p,24,y,342,1,B)
def button(p,y,label,dest=None,fill=G,x=24,w=342):
 a=add('frame',label,x,y,w,52,p,fill=fill,cornerRadius=12)
 txt(a,12,15,label,15,T if fill==O else (G if fill==SOFT else W),'Bold',w-24)
 if dest:links.append((a,dest))
 return a
def smalllink(p,x,y,label,dest,w=100):
 a=add('frame',label,x,y,w,44,p,fill='none');txt(a,0,12,label,13,G,'Bold',w);links.append((a,dest));return a
def icon(p,x,y,kind,color=G):
 paths={'home':'M2 11 L12 2 L22 11 M5 9 V22 H19 V9 M10 22 V14 H14 V22','visit':'M12 23 C8 18 3 13 3 9 A9 9 0 0 1 21 9 C21 13 16 18 12 23 M9 9 A3 3 0 1 0 15 9 A3 3 0 1 0 9 9','task':'M8 5 H22 M8 12 H22 M8 19 H22 M1 5 L3 7 L6 2 M1 12 L3 14 L6 9 M1 19 L3 21 L6 16','history':'M3 7 A10 10 0 1 1 2 14 M3 1 V7 H9 M12 6 V12 L17 15','profile':'M7 6 A5 5 0 1 0 17 6 A5 5 0 1 0 7 6 M2 24 V22 C2 12 22 12 22 22 V24','back':'M17 3 L7 12 L17 21','plus':'M12 2 V22 M2 12 H22','truck':'M1 5 H14 V18 H1 Z M14 10 H19 L23 15 V18 H14 M4 18 A3 3 0 1 0 10 18 M16 18 A3 3 0 1 0 22 18'}
 add('vector',kind,x,y,24,24,p,path=paths[kind],fill='none',stroke=color,strokeWeight=1.7,strokeCap='round',strokeJoin='round')
def nav(p,active='Beranda',driver=False):
 rect(p,0,752,390,92,W);rect(p,0,752,390,1,B)
 labels=['Beranda','Visit','Tugas','Riwayat','Profil'] if not driver else ['Beranda','Peta','Riwayat','Profil']
 targets=['home','visit','tasks','history','profile'] if not driver else ['driver','visit','history','profile']
 kinds=['home','visit','task','history','profile'] if not driver else ['home','visit','history','profile']
 step=390/len(labels)
 for i,(label,dest,k) in enumerate(zip(labels,targets,kinds)):
  a=add('frame','Nav '+label,i*step,760,step,60,p,fill='none')
  if label==active:rect(a,step/2-20,0,40,3,O,1)
  icon(a,step/2-12,10,k,G if label==active else M)
  tx=txt(a,0,37,label,11,G if label==active else M,'Bold' if label==active else 'Regular',step);steps[-1]['params']['props']['textAlign']='center'
  links.append((a,dest))
 rect(p,143,830,104,4,T,2)
def screen(key,title,index,sub='Sales / CRO',back=False):
 x=(index%4)*446; y=(index//4)*940
 f=add('frame',title,x,y,390,844,None,fill=BG,cornerRadius=24,clip=True);frames[key]=f
 txt(f,24,14,'9:41',12,T,'Bold');txt(f,298,14,'LTE   100%',11,T,w=80)
 if back:
  a=add('frame','Kembali',16,49,44,44,f,fill='none');icon(a,10,10,'back');links.append((a,'home'));txt(f,68,55,title,22,G,'Bold',298)
 else:
  txt(f,24,51,'ONE LINK',13,G,'Bold');txt(f,24,77,title,28,G,'Bold')
 txt(f,24,114,sub+'  ·  Prototipe / data contoh',11,M)
 return f
# Sales home
p=screen('home','Siap untuk hari ini.',0)
rect(p,24,148,342,244,G,18)
txt(p,44,168,'Kunjungan hari ini',14,W);txt(p,44,194,'2 dari 5 selesai',28,W,'Bold',300)
rect(p,44,243,302,4,W,2);rect(p,44,243,121,4,O,2)
txt(p,44,264,'TUJUAN BERIKUTNYA',11,W,'Bold');txt(p,44,286,'Supplier Contoh A',20,W,'Bold',300)
button(p,326,'Lanjutkan kunjungan','visit',O,44,302)
txt(p,24,416,'Ringkasan supplier',18,T,'Bold')
for x,n,l in [(24,'128','Terdaftar'),(147,'96','Aktif'),(270,'04','Baru bulan ini')]:
 txt(p,x,452,n,30,G,'Bold',100);txt(p,x,491,l,12,M,w=110)
line(p,525);txt(p,24,548,'Akses kerja',18,T,'Bold')
for y,l,s,d in [(581,'Supplier','Cari & kelola data supplier','suppliers'),(650,'Work Order','Pantau permintaan pickup','orders')]:
 a=add('frame',l,24,y,342,62,p,fill=W,cornerRadius=10,stroke=B,strokeWeight=1);txt(a,16,9,l,16,T,'Bold');txt(a,16,32,s,12,M);txt(a,310,19,'›',20,G,w=20);links.append((a,d))
nav(p)
# Visit planner
p=screen('visit','Visit hari ini',1,sub='Mission aktif')
rect(p,24,148,342,58,SOFT,10);txt(p,40,161,'2 / 5 dikunjungi',17,G,'Bold');txt(p,232,165,'GPS aktif',13,G,w=120)
txt(p,24,229,'Urutan kunjungan',19,T,'Bold');txt(p,24,257,'Kamis, 12 November 2026',13,M)
for y,n,name,meta,status in [(302,'03','Supplier Contoh A','Lowokwaru · Belum dikunjungi','Berikutnya'),(433,'04','Supplier Contoh B','Blimbing · Belum dikunjungi','Menunggu'),(548,'05','Supplier Contoh C','Klojen · Belum dikunjungi','Menunggu')]:
 rect(p,24,y,342,111,W,12,stroke=G if n=='03' else B);rect(p,40,y+16,36,36,O if n=='03' else SOFT,8);txt(p,48,y+23,n,15,T,'Bold',28)
 txt(p,88,y+16,name,17,T,'Bold',260);txt(p,88,y+44,meta,12,M,w=270);txt(p,88,y+75,status,12,G,'Bold')
button(p,682,'Buka detail kunjungan','detail');nav(p,'Visit')
# Task list
p=screen('tasks','Tugas',2)
rect(p,24,148,342,48,SOFT,10);rect(p,28,152,166,40,G,8);txt(p,62,163,'Tugas Saya',14,W,'Bold',140);txt(p,220,163,'Self Assign',14,M,w=130)
a=add('frame','Self Assign concept',198,152,164,40,p,fill='none');links.append((a,'states'))
txt(p,24,222,'Perlu ditindaklanjuti',19,T,'Bold');txt(p,24,251,'3 tugas contoh · Prioritas hari ini',13,M)
for y,title,desc,tag in [(294,'Hubungi supplier','Konfirmasi jadwal pickup','Belum selesai'),(420,'Kunjungan ulang','Supplier Contoh B · Blimbing','Belum selesai'),(546,'Lengkapi data supplier','Supplier Contoh C · Klojen','Belum selesai')]:
 a=add('frame',title,24,y,342,110,p,fill=W,cornerRadius=12,stroke=B,strokeWeight=1);rect(a,0,15,3,35,O,1);txt(a,18,15,title,18,T,'Bold');txt(a,18,45,desc,13,M);txt(a,18,76,tag,12,G,'Bold');links.append((a,'detail'))
nav(p,'Tugas')
# Supplier directory
p=screen('suppliers','Supplier',3,back=True)
rect(p,24,148,342,52,W,10,stroke=B);txt(p,40,165,'Cari nama atau kode supplier',14,M)
smalllink(p,24,205,'Status: Semua','states',130);smalllink(p,190,205,'Kategori: Semua','states',150)
txt(p,24,260,'Daftar supplier',19,T,'Bold');txt(p,24,290,'Contoh tampilan hasil pencarian',12,M)
for y,name,code,area in [(324,'Supplier Contoh A','SUP-DEMO-001','Lowokwaru'),(438,'Supplier Contoh B','SUP-DEMO-002','Blimbing'),(552,'Supplier Contoh C','SUP-DEMO-003','Klojen')]:
 a=add('frame',name,24,y,342,98,p,fill=W,cornerRadius=10,stroke=B,strokeWeight=1);txt(a,16,14,name,17,T,'Bold');txt(a,16,42,code+' · '+area,12,M);txt(a,16,67,'Aktif',12,G,'Bold');txt(a,310,36,'›',20,G,w=20);links.append((a,'detail'))
button(p,680,'Tambah supplier · konsep formulir','states');nav(p)
# detail
p=screen('detail','Detail kunjungan',4,sub='Visit / Supplier',back=True)
txt(p,24,158,'Supplier Contoh A',26,G,'Bold');txt(p,24,198,'SUP-DEMO-001 · Lowokwaru, Malang',13,M)
rect(p,24,238,342,74,SOFT,12);txt(p,40,252,'Belum check-in',17,G,'Bold');txt(p,40,280,'Pastikan lokasi GPS dan foto tersedia.',12,M)
txt(p,24,341,'Informasi kunjungan',18,T,'Bold')
for y,label,val in [(386,'Alamat contoh','Jl. Contoh No. 12, Malang'),(458,'Kontak','Nama kontak contoh'),(530,'Catatan','Konfirmasi rencana pengambilan.')]:
 txt(p,24,y,label,12,M);txt(p,24,y+24,val,16,T,'Regular');line(p,y+59)
txt(p,24,629,'Aksi di bawah membuka contoh state UI.',12,M)
button(p,680,'Check-in · lihat contoh state','states');nav(p,'Visit')
# orders
p=screen('orders','Work Order',5,sub='Permintaan pickup',back=True)
rect(p,24,148,342,52,W,10,stroke=B);txt(p,40,165,'Cari nomor WO atau supplier',14,M)
smalllink(p,24,206,'Filter: Semua status','states',180)
for y,no,name,status in [(266,'WO-DEMO-001','Supplier Contoh A','Menunggu'),(396,'WO-DEMO-002','Supplier Contoh B','Diproses'),(526,'WO-DEMO-003','Supplier Contoh C','Selesai')]:
 a=add('frame',no,24,y,342,112,p,fill=W,cornerRadius=12,stroke=B,strokeWeight=1);txt(a,16,14,no,12,M);txt(a,16,39,name,18,T,'Bold');txt(a,16,77,status,13,G,'Bold');txt(a,258,77,'Detail ›',13,G,'Bold',80);links.append((a,'states'))
button(p,680,'Buat Work Order · konsep','states');nav(p)
# Profile
p=screen('profile','Profil',6)
txt(p,24,155,'Pengguna contoh',27,G,'Bold');txt(p,24,198,'Sales / CRO',14,M)
for y,label,sub,d in [(249,'Informasi akun','Nama, kontak, dan peran','states'),(344,'Tracking System','Informasi GPS dan izin perangkat','states'),(439,'Tentang aplikasi','One Link · PT Green Energi Utama','states')]:
 a=add('frame',label,24,y,342,78,p,fill=W,cornerRadius=10,stroke=B,strokeWeight=1);txt(a,16,14,label,17,T,'Bold');txt(a,16,44,sub,12,M);links.append((a,d))
nav(p,'Profil')
# History
p=screen('history','Riwayat kunjungan',7)
txt(p,24,154,'Kamis, 12 November',20,T,'Bold');txt(p,24,184,'2 kunjungan selesai · data contoh',13,M)
for y,t,name in [(240,'08.30 - 09.05','Supplier Contoh D'),(384,'09.20 - 09.40','Supplier Contoh E')]:
 rect(p,24,y,342,120,W,12,stroke=B);txt(p,40,y+16,t,13,G,'Bold');txt(p,40,y+45,name,20,T,'Bold');txt(p,40,y+80,'Check-in dan check-out selesai',13,M)
button(p,565,'Lihat contoh kondisi tanpa riwayat','states',SOFT);nav(p,'Riwayat')
# states
p=screen('states','Kondisi & interaksi',9,sub='Spesifikasi UI',back=True)
rect(p,24,150,342,120,W,12,stroke=B);txt(p,40,165,'Memuat supplier…',17,G,'Bold')
rect(p,40,203,205,12,B,4);rect(p,40,225,278,10,SOFT,4);rect(p,40,244,160,10,SOFT,4)
rect(p,24,286,342,134,W,12,stroke=B);txt(p,40,301,'Supplier tidak ditemukan',17,G,'Bold');txt(p,40,331,'Coba nama lain atau hapus filter.',13,M)
smalllink(p,40,362,'Reset filter','suppliers',160)
rect(p,24,436,342,134,W,12,stroke=B);txt(p,40,451,'Koneksi terputus',17,G,'Bold');txt(p,40,481,'Data belum dimuat. Periksa koneksi.',13,M)
smalllink(p,40,512,'Coba lagi','tasks',160)
txt(p,24,594,'Batas prototipe',17,T,'Bold');txt(p,24,626,'Pencarian, filter, formulir, GPS, dan check-in\ndijelaskan sebagai konsep; tidak mengirim data.',13,M,h=56)
button(p,698,'Kembali ke Beranda','home')
# Foundations
p=screen('system','Fondasi desain',10,sub='Token dari AppColors')
for y,c,n in [(154,G,'Primary green · #1B4D3E'),(223,O,'Accent orange · #E87C1E'),(292,BG,'Background · #FAFAFA')]:
 rect(p,24,y,48,48,c,10,stroke=B);txt(p,88,y+14,n,14,T,'Bold',278)
txt(p,24,371,'Satu prioritas per layar.',25,G,'Bold');txt(p,24,419,'Arial untuk file desain yang portabel.\nImplementasi Flutter mengikuti font platform.',14,M,h=50)
line(p,485);txt(p,24,508,'24 px margin · 8 px ritme dasar',16,T,'Bold');txt(p,24,545,'Target sentuh minimal 48 px.\nRadius 10–12 px kontrol, 16–18 px prioritas.\nOranye menandai progres dan aksi penting.',14,M,h=80)
txt(p,24,650,'ENERGY 1 / RHYTHM 2 / MOTION 1',12,G,'Bold');txt(p,24,682,'Wireflow dengan layer native yang bisa diedit.',12,M)
# Resolve forward references after all frames exist
for src,dst in links:
 steps.append({'command':'proto.interaction.add','params':{'id':{'$ref':src},'dest':{'$ref':frames[dst]},'transition':{'type':'instant'}}})
steps.append({'command':'proto.flow.add','params':{'start':{'$ref':frames['home']},'name':'Sales / CRO'}})
steps.append({'command':'proto.settings','params':{'width':390,'height':844,'background':BG}})
(ROOT/'build-commands.json').write_text(json.dumps(steps,indent=2))
result=cmd('command.batch',{'commands':steps,'label':'One Link mobile redesign'})
(ROOT/'build-result.json').write_text(json.dumps(result))
cmd('page.rename',{'name':'Mobile redesign · Review 01'})
cmd('file.saveAs',{'path':str(ROOT/'one-link-redesign.figcraft')})
doc=call('document.inspect',{'depth':1});(ROOT/'inspection.json').write_text(json.dumps(doc,indent=2))
print('Artboards:',len(frames),'commands:',len(steps),'links:',len(links))
cmd('view.zoomFit')
