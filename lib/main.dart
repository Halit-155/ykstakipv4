import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Veri kaydı için gerekli

// ============================================================
// 1. AYARLAR VE TEMA
// ============================================================

// ⚠️ BURAYA KENDİ GEMINI API KEY'İNİZİ YAZIN
const String _apiKey = "BURAYA_API_KEY_YAZIN"; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VeriDeposu.init(); // Uygulama başlamadan verileri yükle
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eğitim Asistanı',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// 2. MODELLER (JSON Dönüşümleri Eklendi)
// ============================================================

class Ogrenci { 
  String id, tcNo, sifre, ad, sinif, fotoUrl, hedefUniversite, hedefBolum; 
  int puan, girisSayisi, hedefPuan; 
  String? atananOgretmenId;
  int gunlukSeri;

  Ogrenci({
    required this.id, 
    this.tcNo="", 
    this.sifre="123456", 
    required this.ad, 
    required this.sinif, 
    this.puan=0, 
    this.girisSayisi=0, 
    this.atananOgretmenId, 
    this.fotoUrl="", 
    this.hedefUniversite="Hedef Yok", 
    this.hedefBolum="", 
    this.hedefPuan=0,
    this.gunlukSeri = 0
  });

  // JSON'a Çevirme (Kaydetme için)
  Map<String, dynamic> toJson() => {
    'id': id, 'tcNo': tcNo, 'sifre': sifre, 'ad': ad, 'sinif': sinif,
    'puan': puan, 'girisSayisi': girisSayisi, 'hedefPuan': hedefPuan,
    'fotoUrl': fotoUrl, 'hedefUniversite': hedefUniversite, 
    'hedefBolum': hedefBolum, 'gunlukSeri': gunlukSeri
  };

  // JSON'dan Okuma (Yükleme için)
  factory Ogrenci.fromJson(Map<String, dynamic> json) => Ogrenci(
    id: json['id'], tcNo: json['tcNo'], sifre: json['sifre'], ad: json['ad'],
    sinif: json['sinif'], puan: json['puan'], girisSayisi: json['girisSayisi'],
    hedefPuan: json['hedefPuan'], fotoUrl: json['fotoUrl'],
    hedefUniversite: json['hedefUniversite'], hedefBolum: json['hedefBolum'],
    gunlukSeri: json['gunlukSeri'] ?? 0
  );
}

class Ogretmen { 
  String id, tcNo, sifre, ad, brans; 
  int girisSayisi; 
  Ogretmen({required this.id, this.tcNo="", this.sifre="123456", required this.ad, required this.brans, this.girisSayisi=0}); 
}

class Gorev { 
  int hafta; 
  String gun, saat, ders, konu, aciklama; 
  bool yapildi; 
  Gorev({required this.hafta, required this.gun, required this.saat, required this.ders, required this.konu, this.aciklama="", this.yapildi=false}); 

  Map<String, dynamic> toJson() => {
    'hafta': hafta, 'gun': gun, 'saat': saat, 'ders': ders, 
    'konu': konu, 'aciklama': aciklama, 'yapildi': yapildi
  };

  factory Gorev.fromJson(Map<String, dynamic> json) => Gorev(
    hafta: json['hafta'], gun: json['gun'], saat: json['saat'], 
    ders: json['ders'], konu: json['konu'], aciklama: json['aciklama'], 
    yapildi: json['yapildi']
  );
}

class DenemeSonucu { 
  String ogrenciId, tur; 
  DateTime tarih; 
  double toplamNet; 
  Map<String, double> dersNetleri; 
  DenemeSonucu({required this.ogrenciId, required this.tur, required this.tarih, required this.toplamNet, required this.dersNetleri}); 
  
  Map<String, dynamic> toJson() => {
    'ogrenciId': ogrenciId, 'tur': tur, 'tarih': tarih.toIso8601String(),
    'toplamNet': toplamNet, 'dersNetleri': dersNetleri
  };

  factory DenemeSonucu.fromJson(Map<String, dynamic> json) => DenemeSonucu(
    ogrenciId: json['ogrenciId'], tur: json['tur'], tarih: DateTime.parse(json['tarih']),
    toplamNet: json['toplamNet'], 
    dersNetleri: Map<String, double>.from(json['dersNetleri'])
  );
}

class SoruCozumKaydi { 
  String ogrenciId, ders, konu; 
  int dogru, yanlis; 
  DateTime tarih; 
  SoruCozumKaydi({required this.ogrenciId, required this.ders, required this.konu, required this.dogru, required this.yanlis, required this.tarih}); 

  Map<String, dynamic> toJson() => {
    'ogrenciId': ogrenciId, 'ders': ders, 'konu': konu, 
    'dogru': dogru, 'yanlis': yanlis, 'tarih': tarih.toIso8601String()
  };

  factory SoruCozumKaydi.fromJson(Map<String, dynamic> json) => SoruCozumKaydi(
    ogrenciId: json['ogrenciId'], ders: json['ders'], konu: json['konu'],
    dogru: json['dogru'], yanlis: json['yanlis'], tarih: DateTime.parse(json['tarih'])
  );
}

class Rozet { 
  String id, ad, aciklama, kategori; 
  int puanDegeri, hedefSayi, mevcutSayi; 
  IconData ikon; 
  Color renk; 
  bool kazanildi; 
  Rozet({required this.id, required this.ad, required this.aciklama, required this.kategori, required this.puanDegeri, required this.ikon, required this.renk, required this.hedefSayi, required this.mevcutSayi, this.kazanildi=false}); 
  
  // Rozet durumunu kaydetmek için
  Map<String, dynamic> toStateJson() => {'id': id, 'mevcutSayi': mevcutSayi, 'kazanildi': kazanildi};
}

class KonuDetay { String ad; int agirlik; KonuDetay(this.ad, this.agirlik); }
class PdfDeneme { String baslik; DateTime tarih; String dosyaYolu; PdfDeneme(this.baslik, this.tarih, this.dosyaYolu); }
class OkulDersi { String ad; double yazili1, yazili2, performans; OkulDersi({required this.ad, this.yazili1=0, this.yazili2=0, this.performans=0}); double get ortalama { int b=0; if(yazili1>0)b++; if(yazili2>0)b++; if(performans>0)b++; return b==0?0:(yazili1+yazili2+performans)/b; } }
class KayitliProgramGecmisi { DateTime tarih; String tur; List<Gorev> programVerisi; KayitliProgramGecmisi({required this.tarih, required this.tur, required this.programVerisi}); }
class DersGiris { String n; int soruSayisi; TextEditingController d=TextEditingController(), y=TextEditingController(); double net=0; DersGiris(this.n, this.soruSayisi); }
class Mesaj { String text; bool isUser; Mesaj({required this.text, required this.isUser}); }

// ============================================================
// 3. VERİ DEPOSU VE MÜFREDAT
// ============================================================

class VeriDeposu {
  static late SharedPreferences _prefs; // Veritabanı
  static List<Gorev> kayitliProgram = [];
  static List<DenemeSonucu> denemeListesi = [];
  static List<PdfDeneme> kurumsalDenemeler = [];
  static List<KayitliProgramGecmisi> programArsivi = [];
  static List<SoruCozumKaydi> soruCozumListesi = [];
  static Map<String, bool> tamamlananKonular = {};
  static List<Rozet> tumRozetler = [];
  static List<Mesaj> mesajlar = [];

  static const List<String> aktiviteler = [
    "Konu Çalışma", "Soru Çözümü", "Tekrar", "Deneme", "Video İzle", "Konu + Soru", "Özet Çıkarma", "Fasikül Bitirme", "MEB Kitabı Okuma"
  ];
  
  static const List<String> calismaStilleri = [
    "30+5 (30 Dk Ders, 5 Dk Mola)",
    "35+5 (35 Dk Ders, 5 Dk Mola)",
    "40+5 (40 Dk Ders, 5 Dk Mola)",
    "45+5 (45 Dk Ders, 5 Dk Mola)",
    "50+5 (50 Dk Ders, 5 Dk Mola)",
    "60+10 (60 Dk Ders, 10 Dk Mola)",
    "Pomodoro (25+5+25+5+25+30)"
  ];

  static List<Ogrenci> ogrenciler = [
    Ogrenci(id: "101", tcNo: "11111111111", sifre: "123456", ad: "Ahmet Yılmaz", sinif: "12-A", puan: 1250, atananOgretmenId: "t1", fotoUrl: "", girisSayisi: 45, hedefUniversite: "Boğaziçi", hedefBolum: "Bilgisayar", hedefPuan: 520, gunlukSeri: 5),
    Ogrenci(id: "102", tcNo: "22222222222", sifre: "123456", ad: "Ayşe Demir", sinif: "12-B", puan: 2400, atananOgretmenId: "t1", fotoUrl: "", girisSayisi: 82, hedefUniversite: "İstanbul", hedefBolum: "Hukuk", hedefPuan: 460, gunlukSeri: 12),
  ];
  static List<Ogretmen> ogretmenler = [
    Ogretmen(id: "t1", tcNo: "33333333333", sifre: "123456", ad: "Mustafa Hoca", brans: "Matematik"),
    Ogretmen(id: "t2", tcNo: "44444444444", sifre: "123456", ad: "Elif Hoca", brans: "Edebiyat"),
  ];
  static List<OkulDersi> okulNotlari = [ OkulDersi(ad: "Matematik", yazili1: 60), ];
  static List<Gorev> odevler = [
    Gorev(hafta: 1, gun: "Pazartesi", saat: "19:00", ders: "Matematik", konu: "Fonksiyonlar", aciklama: "Öğretmen Ödevi: 50 soru çöz", yapildi: false)
  ];

  // --- TAM MÜFREDAT ---
  static final Map<String, List<KonuDetay>> dersKonuAgirliklari = {
    // TYT
    "TYT Türkçe": [KonuDetay("Sözcükte Anlam", 3), KonuDetay("Cümlede Anlam", 3), KonuDetay("Paragraf", 25), KonuDetay("Ses Bilgisi", 1), KonuDetay("Yazım Kuralları", 2), KonuDetay("Noktalama İşaretleri", 2), KonuDetay("Sözcükte Yapı", 1), KonuDetay("İsimler", 1), KonuDetay("Sıfatlar", 1), KonuDetay("Zamirler", 1), KonuDetay("Zarflar", 1), KonuDetay("Edat-Bağlaç-Ünlem", 1), KonuDetay("Fiiller", 1), KonuDetay("Ek Fiil", 1), KonuDetay("Fiilimsi", 1), KonuDetay("Fiil Çatısı", 1), KonuDetay("Cümlenin Ögeleri", 1), KonuDetay("Cümle Türleri", 1), KonuDetay("Anlatım Bozuklukları", 1)],
    "TYT Matematik": [KonuDetay("Temel Kavramlar", 2), KonuDetay("Sayı Basamakları", 1), KonuDetay("Bölme ve Bölünebilme", 1), KonuDetay("EBOB - EKOK", 1), KonuDetay("Rasyonel Sayılar", 1), KonuDetay("Basit Eşitsizlikler", 1), KonuDetay("Mutlak Değer", 1), KonuDetay("Üslü Sayılar", 1), KonuDetay("Köklü Sayılar", 1), KonuDetay("Çarpanlara Ayırma", 1), KonuDetay("Oran Orantı", 1), KonuDetay("Denklem Çözme", 1), KonuDetay("Sayı Problemleri", 4), KonuDetay("Kesir Problemleri", 1), KonuDetay("Yaş Problemleri", 1), KonuDetay("İşçi Problemleri", 1), KonuDetay("Hareket Problemleri", 1), KonuDetay("Yüzde Kar Zarar Problemleri", 2), KonuDetay("Karışım Problemleri", 1), KonuDetay("Grafik Problemleri", 1), KonuDetay("Rutin Olmayan Problemler", 1), KonuDetay("Kümeler", 1), KonuDetay("Mantık", 1), KonuDetay("Fonksiyonlar", 2), KonuDetay("Polinomlar", 1), KonuDetay("2. Dereceden Denklemler", 1), KonuDetay("Karmaşık Sayılar", 1), KonuDetay("Permütasyon", 1), KonuDetay("Kombinasyon", 1), KonuDetay("Binom", 1), KonuDetay("Olasılık", 1), KonuDetay("Veri İstatistik", 1)],
    "TYT Geometri": [KonuDetay("Doğruda Açılar", 1), KonuDetay("Üçgende Açılar", 1), KonuDetay("Dik ve Özel Üçgenler", 1), KonuDetay("İkizkenar ve Eşkenar Üçgen", 1), KonuDetay("Açıortay", 1), KonuDetay("Kenarortay", 1), KonuDetay("Eşlik ve Benzerlik", 1), KonuDetay("Üçgende Alan", 1), KonuDetay("Açı-Kenar Bağıntıları", 1), KonuDetay("Çokgenler", 1), KonuDetay("Dörtgenler", 1), KonuDetay("Yamuk", 1), KonuDetay("Paralelkenar", 1), KonuDetay("Eşkenar Dörtgen", 1), KonuDetay("Dikdörtgen", 1), KonuDetay("Kare", 1), KonuDetay("Yamuk", 1), KonuDetay("Çember ve Daire", 2), KonuDetay("Analitik Geometri", 1), KonuDetay("Katı Cisimler", 2)],
    "TYT Fizik": [KonuDetay("Fizik Bilimine Giriş", 1), KonuDetay("Madde ve Özellikleri", 1), KonuDetay("Hareket ve Kuvvet", 2), KonuDetay("İş, Güç ve Enerji", 1), KonuDetay("Isı, Sıcaklık ve Genleşme", 1), KonuDetay("Elektrostatik", 1), KonuDetay("Elektrik ve Manyetizma", 1), KonuDetay("Basınç ve Kaldırma Kuvveti", 1), KonuDetay("Dalgalar", 1), KonuDetay("Optik", 2)],
    "TYT Kimya": [KonuDetay("Kimya Bilimi", 1), KonuDetay("Atom ve Periyodik Sistem", 1), KonuDetay("Kimyasal Türler Arası Etkileşimler", 1), KonuDetay("Maddenin Halleri", 1), KonuDetay("Doğa ve Kimya", 1), KonuDetay("Kimyanın Temel Kanunları", 1), KonuDetay("Kimyasal Hesaplamalar", 1), KonuDetay("Karışımlar", 1), KonuDetay("Asitler, Bazlar ve Tuzlar", 1), KonuDetay("Kimya Her Yerde", 1)],
    "TYT Biyoloji": [KonuDetay("Yaşam Bilimi Biyoloji", 1), KonuDetay("Canlıların Ortak Özellikleri", 1), KonuDetay("Canlıların Temel Bileşenleri", 1), KonuDetay("Hücre", 1), KonuDetay("Canlıların Sınıflandırılması", 1), KonuDetay("Ekoloji", 1), KonuDetay("Hücre Bölünmeleri", 1), KonuDetay("Üreme", 1), KonuDetay("Kalıtım", 1)],
    "TYT Tarih": [KonuDetay("Tarih Bilimi", 1), KonuDetay("İlk Çağ Uygarlıkları", 1), KonuDetay("İslamiyet Öncesi Türk Tarihi", 1), KonuDetay("İslam Tarihi ve Uygarlığı", 1), KonuDetay("Türk İslam Devletleri", 1), KonuDetay("Türkiye Tarihi", 1), KonuDetay("Beylikten Devlete Osmanlı", 1), KonuDetay("Dünya Gücü Osmanlı", 1), KonuDetay("Osmanlı Kültür ve Medeniyeti", 1), KonuDetay("Yeni Çağ'da Avrupa", 1), KonuDetay("Yakın Çağ'da Avrupa", 1), KonuDetay("En Uzun Yüzyıl", 1), KonuDetay("20. yy Başlarında Osmanlı", 1), KonuDetay("1. Dünya Savaşı", 1), KonuDetay("Kurtuluş Savaşı Hazırlık", 1), KonuDetay("Kurtuluş Savaşı Cepheler", 1), KonuDetay("İlke ve İnkılaplar", 1), KonuDetay("Dış Politika", 1)],
    "TYT Coğrafya": [KonuDetay("Doğa ve İnsan", 1), KonuDetay("Dünya'nın Şekli ve Hareketleri", 1), KonuDetay("Coğrafi Konum", 1), KonuDetay("Harita Bilgisi", 1), KonuDetay("Atmosfer ve İklim", 1), KonuDetay("Sıcaklık", 1), KonuDetay("Basınç ve Rüzgarlar", 1), KonuDetay("Nem ve Yağış", 1), KonuDetay("İklim Tipleri", 1), KonuDetay("İç ve Dış Kuvvetler", 1), KonuDetay("Su - Toprak - Bitki", 1), KonuDetay("Nüfus", 1), KonuDetay("Göç", 1), KonuDetay("Yerleşme", 1), KonuDetay("Bölgeler", 1), KonuDetay("Ulaşım Yolları", 1), KonuDetay("Çevre ve İnsan", 1), KonuDetay("Doğal Afetler", 1)],
    "TYT Felsefe": [KonuDetay("Felsefeye Giriş", 1), KonuDetay("Bilgi Felsefesi", 1), KonuDetay("Varlık Felsefesi", 1), KonuDetay("Ahlak Felsefesi", 1), KonuDetay("Sanat Felsefesi", 1), KonuDetay("Din Felsefesi", 1), KonuDetay("Siyaset Felsefesi", 1), KonuDetay("Bilim Felsefesi", 1)],
    "TYT Din": [KonuDetay("İnanç", 1), KonuDetay("İbadet", 1), KonuDetay("Ahlak", 1), KonuDetay("Hz. Muhammed", 1), KonuDetay("Vahiy ve Akıl", 1), KonuDetay("İslam ve Bilim", 1), KonuDetay("Anadolu'da İslam", 1), KonuDetay("İslam Düşüncesinde Yorumlar", 1)],
    
    // AYT
    "AYT Matematik": [KonuDetay("Polinomlar", 1), KonuDetay("2. Dereceden Denklemler", 1), KonuDetay("Karmaşık Sayılar", 1), KonuDetay("Parabol", 1), KonuDetay("Eşitsizlikler", 1), KonuDetay("Logaritma", 2), KonuDetay("Diziler", 1), KonuDetay("Trigonometri", 4), KonuDetay("Limit ve Süreklilik", 2), KonuDetay("Türev", 4), KonuDetay("İntegral", 4)],
    "AYT Fizik": [KonuDetay("Vektörler", 1), KonuDetay("Bağıl Hareket", 1), KonuDetay("Newton'un Hareket Yasaları", 1), KonuDetay("Bir Boyutta Sabit İvmeli Hareket", 1), KonuDetay("Atışlar", 1), KonuDetay("İş Güç Enerji", 1), KonuDetay("İtme ve Momentum", 1), KonuDetay("Tork ve Denge", 1), KonuDetay("Kütle Merkezi", 1), KonuDetay("Basit Makineler", 1), KonuDetay("Elektrik Alan ve Potansiyel", 1), KonuDetay("Paralel Levhalar", 1), KonuDetay("Sığaçlar", 1), KonuDetay("Manyetizma", 2), KonuDetay("Alternatif Akım ve Transformatörler", 1), KonuDetay("Çembersel Hareket", 2), KonuDetay("Basit Harmonik Hareket", 1), KonuDetay("Dalga Mekaniği", 1), KonuDetay("Atom Fiziği", 1), KonuDetay("Modern Fizik", 1)],
    "AYT Kimya": [KonuDetay("Modern Atom Teorisi", 1), KonuDetay("Gazlar", 1), KonuDetay("Sıvı Çözeltiler", 1), KonuDetay("Kimyasal Tepkimelerde Enerji", 1), KonuDetay("Kimyasal Tepkimelerde Hız", 1), KonuDetay("Kimyasal Denge", 2), KonuDetay("Asit-Baz Dengesi", 2), KonuDetay("Çözünürlük Dengesi", 1), KonuDetay("Kimya ve Elektrik", 2), KonuDetay("Karbon Kimyasına Giriş", 1), KonuDetay("Organik Kimya", 4)],
    "AYT Biyoloji": [KonuDetay("Sinir Sistemi", 2), KonuDetay("Endokrin Sistem", 2), KonuDetay("Duyu Organları", 1), KonuDetay("Destek ve Hareket Sistemi", 1), KonuDetay("Sindirim Sistemi", 1), KonuDetay("Dolaşım Sistemi", 1), KonuDetay("Solunum Sistemi", 1), KonuDetay("Üriner Sistem", 1), KonuDetay("Üreme Sistemi ve Embriyonik Gelişim", 1), KonuDetay("Komünite ve Popülasyon Ekolojisi", 1), KonuDetay("Nükleik Asitler", 1), KonuDetay("Protein Sentezi", 1), KonuDetay("Canlılarda Enerji Dönüşümleri", 2), KonuDetay("Bitki Biyolojisi", 2), KonuDetay("Canlılar ve Çevre", 1)],
    "AYT Edebiyat": [KonuDetay("Güzel Sanatlar ve Edebiyat", 1), KonuDetay("Şiir Bilgisi", 3), KonuDetay("Edebi Sanatlar", 1), KonuDetay("Olay Çevresinde Oluşan Metinler", 1), KonuDetay("Öğretici Metinler", 1), KonuDetay("İslamiyet Öncesi Türk Edebiyatı", 1), KonuDetay("Geçiş Dönemi Eserleri", 1), KonuDetay("Halk Edebiyatı", 2), KonuDetay("Divan Edebiyatı", 4), KonuDetay("Tanzimat Edebiyatı", 2), KonuDetay("Servet-i Fünun Edebiyatı", 2), KonuDetay("Fecr-i Ati Edebiyatı", 1), KonuDetay("Milli Edebiyat", 2), KonuDetay("Cumhuriyet Dönemi Edebiyatı", 5), KonuDetay("Edebi Akımlar", 1)],
    "AYT Tarih-1": [KonuDetay("Tarih Bilimi", 1), KonuDetay("İlk Çağ Uygarlıkları", 1), KonuDetay("İslamiyet Öncesi Türk Tarihi", 1), KonuDetay("İslam Tarihi", 1), KonuDetay("Türk İslam Tarihi", 1), KonuDetay("Osmanlı Tarihi", 2), KonuDetay("Milli Mücadele", 2), KonuDetay("Atatürkçülük", 1)],
    "AYT Coğrafya-1": [KonuDetay("Biyoçeşitlilik", 1), KonuDetay("Ekosistem", 1), KonuDetay("Nüfus Politikaları", 1), KonuDetay("Yerleşmeler", 1), KonuDetay("Ekonomik Faaliyetler", 1), KonuDetay("Türkiye Ekonomisi", 1), KonuDetay("Bölgeler ve Ülkeler", 1), KonuDetay("Çevre ve Toplum", 1)],
    "AYT Tarih-2": [KonuDetay("Tarih ve Zaman", 1), KonuDetay("İlk ve Orta Çağlarda Türk Dünyası", 1), KonuDetay("İslam Medeniyetinin Doğuşu", 1), KonuDetay("Türklerin İslamiyet'i Kabulü", 1), KonuDetay("Yerleşme ve Devletleşme Sürecinde Selçuklu", 1), KonuDetay("Beylikten Devlete Osmanlı", 1), KonuDetay("Dünya Gücü Osmanlı", 1), KonuDetay("Değişim Çağında Avrupa ve Osmanlı", 1), KonuDetay("Uluslararası İlişkilerde Denge Stratejisi", 1), KonuDetay("Devrimler Çağında Değişen Devlet-Toplum", 1), KonuDetay("Sermaye ve Emek", 1), KonuDetay("XIX. ve XX. Yüzyılda Değişen Gündelik Hayat", 1), KonuDetay("XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya", 1), KonuDetay("Milli Mücadele", 1), KonuDetay("Atatürkçülük ve Türk İnkılabı", 1), KonuDetay("İki Savaş Arasındaki Dönemde Türkiye ve Dünya", 1), KonuDetay("II. Dünya Savaşı Sürecinde Türkiye ve Dünya", 1), KonuDetay("II. Dünya Savaşı Sonrasında Türkiye ve Dünya", 1), KonuDetay("Toplumsal Devrim Çağında Dünya ve Türkiye", 1), KonuDetay("XXI. Yüzyılın Eşiğinde Türkiye ve Dünya", 1)],
    "AYT Coğrafya-2": [KonuDetay("Ekosistemlerin İşleyişi", 1), KonuDetay("Nüfus Politikaları", 1), KonuDetay("Yerleşmeler", 1), KonuDetay("Ekonomik Faaliyetler ve Doğal Kaynaklar", 1), KonuDetay("Türkiye'de Ekonomi", 1), KonuDetay("Türkiye'nin İşlevsel Bölgeleri ve Kalkınma Projeleri", 1), KonuDetay("Hizmet Sektörü ve Ulaşım", 1), KonuDetay("Küresel Ticaret", 1), KonuDetay("Bölgeler ve Ülkeler", 1), KonuDetay("Çevre ve Toplum", 1)],
    "AYT Felsefe Grubu": [KonuDetay("Mantığa Giriş", 1), KonuDetay("Klasik Mantık", 1), KonuDetay("Mantık ve Dil", 1), KonuDetay("Sembolik Mantık", 1), KonuDetay("Psikoloji Bilimini Tanıyalım", 1), KonuDetay("Psikolojinin Temel Süreçleri", 1), KonuDetay("Öğrenme Bellek Düşünme", 1), KonuDetay("Ruh Sağlığının Temelleri", 1), KonuDetay("Sosyolojiye Giriş", 1), KonuDetay("Birey ve Toplum", 1), KonuDetay("Toplumsal Yapı", 1), KonuDetay("Toplumsal Değişme ve Gelişme", 1), KonuDetay("Toplum ve Kültür", 1), KonuDetay("Toplumsal Kurumlar", 1)],
    "AYT Din Kültürü": [KonuDetay("Dünya ve Ahiret", 1), KonuDetay("Kur'an'a Göre Hz. Muhammed", 1), KonuDetay("Kur'an'da Bazı Kavramlar", 1), KonuDetay("İnançla İlgili Meseleler", 1), KonuDetay("Yahudilik ve Hristiyanlık", 1), KonuDetay("İslam ve Bilim", 1), KonuDetay("Anadolu'da İslam", 1), KonuDetay("İslam Düşüncesinde Tasavvufi Yorumlar", 1), KonuDetay("Güncel Dini Meseleler", 1), KonuDetay("Hint ve Çin Dinleri", 1)]
  };

  // VERİTABANI YÜKLEME (INIT)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if(_prefs.containsKey('ogrenciler')) {
       var list = jsonDecode(_prefs.getString('ogrenciler')!);
       ogrenciler = (list as List).map((e) => Ogrenci.fromJson(e)).toList();
    }
    if(_prefs.containsKey('gorevler')) {
       var list = jsonDecode(_prefs.getString('gorevler')!);
       kayitliProgram = (list as List).map((e) => Gorev.fromJson(e)).toList();
    }
    if(_prefs.containsKey('denemeler')) {
       var list = jsonDecode(_prefs.getString('denemeler')!);
       denemeListesi = (list as List).map((e) => DenemeSonucu.fromJson(e)).toList();
    }
    if(_prefs.containsKey('cozulenSorular')) {
       var list = jsonDecode(_prefs.getString('cozulenSorular')!);
       soruCozumListesi = (list as List).map((e) => SoruCozumKaydi.fromJson(e)).toList();
    }
    if(_prefs.containsKey('bitenKonular')) {
       tamamlananKonular = Map<String, bool>.from(jsonDecode(_prefs.getString('bitenKonular')!));
    }
    baslat();
    // Rozet Durumlarını Yükle
    if(_prefs.containsKey('rozetler')) {
       var savedBadges = jsonDecode(_prefs.getString('rozetler')!) as List;
       for(var s in savedBadges) {
         try {
           var r = tumRozetler.firstWhere((e) => e.id == s['id']);
           r.kazanildi = s['kazanildi'];
           r.mevcutSayi = s['mevcutSayi'];
         } catch(e) {}
       }
    }
  }

  // Veri Kaydetme
  static Future<void> _kaydet() async {
    await _prefs.setString('ogrenciler', jsonEncode(ogrenciler.map((e) => e.toJson()).toList()));
    await _prefs.setString('gorevler', jsonEncode(kayitliProgram.map((e) => e.toJson()).toList()));
    await _prefs.setString('denemeler', jsonEncode(denemeListesi.map((e) => e.toJson()).toList()));
    await _prefs.setString('cozulenSorular', jsonEncode(soruCozumListesi.map((e) => e.toJson()).toList()));
    await _prefs.setString('bitenKonular', jsonEncode(tamamlananKonular));
    await _prefs.setString('rozetler', jsonEncode(tumRozetler.map((e) => e.toStateJson()).toList()));
  }

  static void baslat() {
    if (tumRozetler.isNotEmpty) return;
    kurumsalDenemeler.add(PdfDeneme("Türkiye Geneli TYT-1", DateTime.now().subtract(const Duration(days: 5)), "dosya.pdf"));
    
    tumRozetler.addAll([
      Rozet(id: "soru_100", ad: "Isınma Turu", aciklama: "100 Soru barajı!", kategori: "Soru", puanDegeri: 50, ikon: Icons.directions_run, renk: Colors.lime, hedefSayi: 100, mevcutSayi: 0),
      Rozet(id: "soru_500", ad: "Soru Avcısı", aciklama: "500 Soru!", kategori: "Soru", puanDegeri: 150, ikon: Icons.my_location, renk: Colors.cyan, hedefSayi: 500, mevcutSayi: 0),
      Rozet(id: "soru_1000", ad: "Problem Çözücü", aciklama: "1000 Soru!", kategori: "Soru", puanDegeri: 300, ikon: Icons.psychology, renk: Colors.orange, hedefSayi: 1000, mevcutSayi: 0),
      Rozet(id: "soru_5000", ad: "YKS Makinesi", aciklama: "5000 Soru!", kategori: "Soru", puanDegeri: 1000, ikon: Icons.smart_toy, renk: Colors.purple, hedefSayi: 5000, mevcutSayi: 0),
      Rozet(id: "konu_10", ad: "Çırak", aciklama: "10 Konu bitti.", kategori: "Konu", puanDegeri: 100, ikon: Icons.construction, renk: Colors.lightGreen, hedefSayi: 10, mevcutSayi: 0),
      Rozet(id: "deneme_5", ad: "Tecrübeli", aciklama: "5 Deneme.", kategori: "Deneme", puanDegeri: 150, ikon: Icons.history_edu, renk: Colors.orangeAccent, hedefSayi: 5, mevcutSayi: 0),
      Rozet(id: "puan_5000", ad: "Yıldız", aciklama: "5000 XP.", kategori: "Seviye", puanDegeri: 0, ikon: Icons.star, renk: Colors.amber, hedefSayi: 5000, mevcutSayi: 0),
    ]);
  }

  static int get seviye => (ogrenciler[0].puan / 1000).floor() + 1;
  static double get seviyeYuzdesi => (ogrenciler[0].puan % 1000) / 1000;

  static void soruEkle(SoruCozumKaydi k) {
    soruCozumListesi.add(k);
    puanEkle(k.ogrenciId, (k.dogru + k.yanlis) ~/ 5);
    _rozetKontrol();
    _kaydet();
  }

  static void puanEkle(String id, int p) {
    var o = ogrenciler.firstWhere((e) => e.id == id, orElse: () => ogrenciler[0]);
    o.puan += p;
    _rozetKontrol(); 
    _kaydet();
  }

  static void _rozetKontrol() {
    int topSoru = soruCozumListesi.fold(0, (sum, item) => sum + item.dogru + item.yanlis);
    int bitenKonu = tamamlananKonular.length;
    int denemeSayisi = denemeListesi.length;
    int toplamPuan = ogrenciler[0].puan;

    for (var r in tumRozetler) {
      if (r.kategori == "Soru") r.mevcutSayi = topSoru;
      if (r.kategori == "Konu") r.mevcutSayi = bitenKonu;
      if (r.kategori == "Deneme") r.mevcutSayi = denemeSayisi;
      if (r.kategori == "Seviye") r.mevcutSayi = toplamPuan;
      
      if (!r.kazanildi && r.mevcutSayi >= r.hedefSayi) {
        r.kazanildi = true;
      }
    }
  }
  
  static void konuDurumDegistir(String k, bool v) { 
    tamamlananKonular[k] = v; 
    if(v) puanEkle("101", 10); 
    _kaydet();
  }
  
  static void kullaniciSil(String id, bool isOgrenci) { 
    if(isOgrenci) ogrenciler.removeWhere((e)=>e.id==id); 
    else ogretmenler.removeWhere((e)=>e.id==id); 
    _kaydet();
  }
  
  static void denemeEkle(DenemeSonucu d) { denemeListesi.add(d); puanEkle(d.ogrenciId, 50); _kaydet(); }
  static void dersEkle(OkulDersi d) { okulNotlari.add(d); _kaydet(); }

  static void programiKaydet(List<Gorev> program, String tur) {
    kayitliProgram = List.from(program);
    programArsivi.add(KayitliProgramGecmisi(tarih: DateTime.now(), tur: tur, programVerisi: List.from(program)));
    puanEkle("101", 100);
    _kaydet();
  }
  
  static dynamic girisKontrol(String k, String s) {
    if(k=="ogrenci1" && s=="1234") return Ogrenci(id: "101", ad: "Ahmet Yılmaz", sinif: "12-A", puan: 1250);
    if(k=="ogretmen1" && s=="1234") return Ogretmen(id: "t1", ad: "Mehmet Hoca", brans: "Matematik");
    return null;
  }

  static void girisSayaciArtir(String id, bool isOgrenci) { 
     if(isOgrenci) ogrenciler.firstWhere((e)=>e.id==id).girisSayisi++; 
     else ogretmenler.firstWhere((e)=>e.id==id).girisSayisi++;
     _kaydet();
  }
}

// --- AI SERVİSİ ---
class GeminiServisi {
  static Future<String> generateText(String prompt) async {
    if (_apiKey.isEmpty || _apiKey == "BURAYA_API_KEY_YAZIN") return "Lütfen API Key giriniz.";
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey');
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'];
      }
      return "Hata: ${response.statusCode}";
    } catch (e) { return "Bağlantı hatası: $e"; }
  }
  
  static Future<String> soruCoz(File image) async {
    if (_apiKey.isEmpty || _apiKey == "BURAYA_API_KEY_YAZIN") return "Lütfen API Key giriniz.";
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey');
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
        "contents": [{
          "parts": [
            {"text": "Sen uzman bir öğretmensin. Bu soruyu analiz et ve adım adım, anlaşılır şekilde çöz."},
            {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}
          ]
        }]
      }));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'];
      }
      return "Hata: ${response.statusCode}";
    } catch (e) { return "Hata: $e"; }
  }

  // --- PROGRAM OLUŞTURMA İÇİN YENİ METOT ---
  static Future<List<Gorev>> programOlustur(String sinif, String alan, String stil, int gunlukSaat, String zayifDersler) async {
    if (_apiKey.isEmpty || _apiKey == "AIzaSyDR2SXYCEX7VyIHLjcIVhzSDX3NpErAVDU") return [];
    
    // AI'a gönderilecek detaylı prompt
    String prompt = """
    Sen uzman bir YKS rehberlik koçusun. Aşağıdaki öğrenci profiline göre 1 haftalık (Pazartesi-Pazar) ders çalışma programı hazırla.
    
    Öğrenci Profili:
    - Sınıf: $sinif
    - Alan: $alan
    - Çalışma Stili: $stil
    - Günlük Ortalama Çalışma Süresi: $gunlukSaat saat
    - Zayıf Olduğu Konular: $zayifDersler (Bu konulara ağırlık ver)
    
    Lütfen yanıtı SADECE aşağıdaki JSON formatında ver, başka hiçbir metin yazma:
    [
      {"gun": "Pazartesi", "saat": "09:00 - 09:40", "ders": "Matematik", "konu": "Trigonometri", "aciklama": "Konu çalışması"},
      {"gun": "Pazartesi", "saat": "10:00 - 10:40", "ders": "Fizik", "konu": "Vektörler", "aciklama": "Soru çözümü"}
      ... (tüm hafta için devam et)
    ]
    """;

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey');
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({"contents": [{"parts": [{"text": prompt}]}]}));
      
      if (response.statusCode == 200) {
        String hamVeri = jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'];
        
        // Markdown temizliği (```json ... ```)
        hamVeri = hamVeri.replaceAll("```json", "").replaceAll("```", "").trim();
        
        List<dynamic> jsonList = jsonDecode(hamVeri);
        List<Gorev> program = [];
        
        for (var item in jsonList) {
          program.add(Gorev(
            hafta: 1, 
            gun: item['gun'], 
            saat: item['saat'], 
            ders: item['ders'], 
            konu: item['konu'], 
            aciklama: item['aciklama']
          ));
        }
        return program;
      }
    } catch (e) {
      print("AI Hatası: $e");
    }
    return []; // Hata durumunda boş dön
  }
}

// ============================================================
// 3. EKRANLAR
// ============================================================

// --- GİRİŞ EKRANI ---
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _k=TextEditingController(text: "ogrenci1"), _s=TextEditingController(text: "1234");
  late TabController _tc;
  @override void initState(){ super.initState(); _tc = TabController(length: 3, vsync: this); VeriDeposu.baslat(); }
  
  void _login() {
    var user = VeriDeposu.girisKontrol(_k.text, _s.text);
    if(user != null) {
      if(user is Ogrenci) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>OgrenciPaneli(aktifOgrenci: user)));
      else if(user is Ogretmen) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>const Scaffold(body: Center(child: Text("Öğretmen Paneli")))));
    } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Giriş"))); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple.shade200, Colors.purple.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(child: Card(margin: const EdgeInsets.all(32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.school, size: 80, color: Colors.deepPurple),
          // Standart Font Kullanımı (Google Fonts kaldırıldı)
          const Text("Eğitim Asistanı", style: TextStyle(fontSize: 28, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TabBar(controller: _tc, labelColor: Colors.purple, unselectedLabelColor: Colors.grey, tabs: const [Tab(text: "Öğrenci"), Tab(text: "Öğretmen"), Tab(text: "Yönetici")]),
          const SizedBox(height: 20),
          TextField(controller: _k, decoration: const InputDecoration(labelText: "Kullanıcı Adı", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _s, obscureText: true, decoration: const InputDecoration(labelText: "Şifre", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _login, child: const Text("GİRİŞ YAP")))
        ])))),
    );
  }
}

// --- ÖĞRENCİ PANELİ ---
class OgrenciPaneli extends StatelessWidget {
  final Ogrenci aktifOgrenci;
  const OgrenciPaneli({super.key, required this.aktifOgrenci});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hoşgeldin ${aktifOgrenci.ad}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.withAlpha(26), 
        elevation: 0,
        foregroundColor: Colors.deepPurple,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: ()=>Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>const LoginPage())))],
      ),
      body: Column(
        children: [
          // ÜST BİLGİ KARTI (GAMIFICATION)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.indigoAccent]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Seviye ${VeriDeposu.seviye}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 150,
                      child: LinearProgressIndicator(value: VeriDeposu.seviyeYuzdesi, backgroundColor: Colors.white24, color: Colors.amberAccent),
                    ),
                    const SizedBox(height: 5),
                    Text("${aktifOgrenci.puan} XP", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
                    Text("${aktifOgrenci.gunlukSeri} Gün Seri", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  ],
                )
              ],
            ),
          ),
          // MENÜLER
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildMenuCard(context, "Programım", Icons.schedule, const TumProgramEkrani(), Colors.blueAccent, Colors.lightBlueAccent),
                _buildMenuCard(context, "Soru Üreteci", Icons.psychology, const SoruUretecEkrani(), Colors.deepOrange, Colors.orangeAccent),
                _buildMenuCard(context, "Sihirbaz (Manuel/AI)", Icons.auto_awesome, const ProgramSecimEkrani(), Colors.orangeAccent, Colors.yellowAccent),
                _buildMenuCard(context, "Deneme Ekle", Icons.add_chart, DenemeEkleEkrani(ogrenciId: aktifOgrenci.id), Colors.green, Colors.lightGreenAccent),
                _buildMenuCard(context, "Denemelerim", Icons.assessment, DenemeListesiEkrani(ogrenciId: aktifOgrenci.id), Colors.redAccent, Colors.pinkAccent),
                _buildMenuCard(context, "Grafik", Icons.show_chart, BasariGrafigiEkrani(ogrenciId: aktifOgrenci.id), Colors.purpleAccent, Colors.deepPurpleAccent),
                _buildMenuCard(context, "Konu Takip", Icons.check_circle_outline, const KonuTakipEkrani(), Colors.teal, Colors.cyanAccent),
                _buildMenuCard(context, "Soru Takip", Icons.format_list_numbered, SoruTakipEkrani(ogrenciId: aktifOgrenci.id), Colors.indigo, Colors.blue),
                _buildMenuCard(context, "AI Asistan", Icons.chat, const YapayZekaSohbetEkrani(), Colors.cyan, Colors.lightBlue),
                _buildMenuCard(context, "Notlarım", Icons.notes, const OkulSinavlariEkrani(), Colors.brown, Colors.orange),
                _buildMenuCard(context, "Ödevlerim", Icons.assignment, const OdevlerEkrani(), Colors.pink, Colors.red),
                _buildMenuCard(context, "Soru Çöz (Vision)", Icons.camera_alt, const SoruCozumEkrani(), Colors.amber, Colors.yellow),
                _buildMenuCard(context, "Kronometre", Icons.timer, const KronometreEkrani(), Colors.lightBlue, Colors.cyan),
                _buildMenuCard(context, "Rozetlerim", Icons.emoji_events, RozetlerEkrani(ogrenci: aktifOgrenci), Colors.yellow.shade700, Colors.amberAccent),
                _buildMenuCard(context, "Günlük Takip", Icons.today, const GunlukTakipEkrani(), Colors.teal, Colors.greenAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Widget page, Color startColor, Color endColor) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => page)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [startColor.withAlpha(204), endColor.withAlpha(204)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PROGRAM SEÇİM EKRANI ---
class ProgramSecimEkrani extends StatelessWidget {
  const ProgramSecimEkrani({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Program Oluştur")),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ManuelProgramSihirbazi())),
              child: Container(margin: const EdgeInsets.all(10), height: 200, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit, size: 50, color: Colors.white), Text("MANUEL", style: TextStyle(color: Colors.white, fontSize: 20))])),
            )),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProgramSihirbaziEkrani(mod: "AI"))),
              child: Container(margin: const EdgeInsets.all(10), height: 200, decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(20)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome, size: 50, color: Colors.white), Text("YAPAY ZEKA", style: TextStyle(color: Colors.white, fontSize: 20))])),
            )),
          ],
        ),
      ),
    );
  }
}

class SoruUretecEkrani extends StatefulWidget { const SoruUretecEkrani({super.key}); @override State<SoruUretecEkrani> createState() => _SUEState(); }
class _SUEState extends State<SoruUretecEkrani> {
  String? ders, konu, zorluk; String soru = ""; bool loading = false;
  Future<void> _uret() async {
    if(ders==null || konu==null) return;
    setState(()=>loading=true);
    String p = "$ders dersi $konu konusunda ${zorluk ?? 'orta'} seviye bir adet çoktan seçmeli YKS sorusu yaz. Şıkları ve cevabı da ver.";
    String s = await GeminiServisi.generateText(p);
    setState(() { soru = s; loading=false; });
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Soru Üreteci")), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      DropdownButtonFormField(value: ders, hint: const Text("Ders"), items: VeriDeposu.dersKonuAgirliklari.keys.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState((){ders=v; konu=null;})),
      if(ders!=null) DropdownButtonFormField(value: konu, hint: const Text("Konu"), items: VeriDeposu.dersKonuAgirliklari[ders]!.map((e)=>DropdownMenuItem(value: e.ad, child: Text(e.ad))).toList(), onChanged: (v)=>setState(()=>konu=v)),
      DropdownButtonFormField(value: zorluk, hint: const Text("Zorluk"), items: ["Kolay","Orta","Zor"].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>zorluk=v)),
      const SizedBox(height: 20), ElevatedButton(onPressed: loading?null:_uret, child: loading?const CircularProgressIndicator():const Text("SORU ÜRET")),
      const SizedBox(height: 20), Expanded(child: SingleChildScrollView(child: Text(soru)))
    ])));
  }
}

class OdevlerEkrani extends StatelessWidget { const OdevlerEkrani({super.key, this.ogrenciId}); final String? ogrenciId;
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Ödevlerim")), body: ListView.builder(itemCount: VeriDeposu.odevler.length, itemBuilder: (c,i){ var o = VeriDeposu.odevler[i]; return Card(child: ListTile(title: Text(o.ders), subtitle: Text("${o.konu}\n${o.aciklama}"), trailing: const Icon(Icons.assignment)));}));
  }
}

class YapayZekaSohbetEkrani extends StatefulWidget { const YapayZekaSohbetEkrani({super.key}); @override State<YapayZekaSohbetEkrani> createState() => _YZSEState(); }
class _YZSEState extends State<YapayZekaSohbetEkrani> {
  final TextEditingController _c = TextEditingController();
  void _send() async { if(_c.text.isEmpty)return; String t = _c.text; setState((){VeriDeposu.mesajlar.add(Mesaj(text: t, isUser: true)); _c.clear();}); 
    String r = await GeminiServisi.generateText("Sen bir rehber öğretmenisin. Soru: $t");
    setState(()=>VeriDeposu.mesajlar.add(Mesaj(text: r, isUser: false)));
  }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("AI Asistan")), body: Column(children: [Expanded(child: ListView.builder(itemCount: VeriDeposu.mesajlar.length, itemBuilder: (c,i)=>Align(alignment: VeriDeposu.mesajlar[i].isUser?Alignment.centerRight:Alignment.centerLeft, child: Container(margin:const EdgeInsets.all(8), padding:const EdgeInsets.all(12), decoration: BoxDecoration(color: VeriDeposu.mesajlar[i].isUser?Colors.blue[100]:Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: Text(VeriDeposu.mesajlar[i].text))))), Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [Expanded(child: TextField(controller: _c)), IconButton(icon: const Icon(Icons.send), onPressed: _send)]))])); }
}

// --- DİĞER MODÜLLER ---

class TumProgramEkrani extends StatefulWidget { const TumProgramEkrani({super.key}); @override State<TumProgramEkrani> createState() => _TPEState(); }
class _TPEState extends State<TumProgramEkrani> with SingleTickerProviderStateMixin {
  late TabController _tc; int hSayisi=1;
  @override void initState(){ super.initState(); if(VeriDeposu.kayitliProgram.isNotEmpty) hSayisi=VeriDeposu.kayitliProgram.map((e)=>e.hafta).reduce(max); _tc=TabController(length: hSayisi, vsync: this); }
  void _edit(Gorev g) {
    String? d=VeriDeposu.dersKonuAgirliklari.containsKey(g.ders)?g.ders:null, k=g.konu, a=g.aciklama;
    showDialog(context: context, builder: (c)=>StatefulBuilder(builder: (c,st)=>AlertDialog(title: const Text("Düzenle"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(isExpanded: true, value: d, hint: const Text("Ders"), items: VeriDeposu.dersKonuAgirliklari.keys.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>st((){d=v; k=null;})),
      if(d!=null) DropdownButton<String>(isExpanded: true, value: (VeriDeposu.dersKonuAgirliklari[d]!.any((x)=>x.ad==k))?k:null, hint: const Text("Konu"), items: VeriDeposu.dersKonuAgirliklari[d]!.map((e)=>DropdownMenuItem(value: e.ad, child: Text(e.ad))).toList(), onChanged: (v)=>st(()=>k=v)),
      DropdownButton<String>(isExpanded: true, value: VeriDeposu.aktiviteler.contains(a)?a:null, hint: const Text("Aktivite"), items: VeriDeposu.aktiviteler.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>st(()=>a=v))
    ]), actions: [TextButton(onPressed: (){setState((){if(d!=null)g.ders=d!; if(k!=null)g.konu=k!; if(a!=null)g.aciklama=a!;}); Navigator.pop(c);}, child: const Text("KAYDET"))])));
  }
  void _pdfKaydet() { showDialog(context: context, builder: (c)=>const AlertDialog(title: Text("PDF Hazır"), content: Text("Program PDF olarak indirildi."))); }
  @override Widget build(BuildContext context) { 
    if(VeriDeposu.kayitliProgram.isEmpty) return Scaffold(appBar: AppBar(title: const Text("Program")), body: const Center(child: Text("Henüz program yok.")));
    // ESKİ GÖRSEL SİSTEM GERİ GETİRİLDİ (ExpansionTile)
    return Scaffold(
      appBar: AppBar(title: const Text("Programım"), actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _pdfKaydet), IconButton(icon: const Icon(Icons.save), onPressed: ()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kaydedildi"))))], bottom: TabBar(controller: _tc, isScrollable: true, tabs: List.generate(hSayisi, (i)=>Tab(text: "${i+1}.H")))), 
      body: TabBarView(controller: _tc, children: List.generate(hSayisi, (i){
        int hafta=i+1; var p=VeriDeposu.kayitliProgram.where((x)=>x.hafta==hafta).toList(); List<String> gunler=["Pazartesi","Salı","Çarşamba","Perşembe","Cuma","Cumartesi","Pazar"];
        
        return ListView(children: gunler.map((g){
          var gunlukDersler = p.where((x)=>x.gun==g).toList();
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ExpansionTile(
              title: Text(g, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              subtitle: Text("${gunlukDersler.length} Etüt"),
              children: gunlukDersler.map((d)=>ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.blue),
                title: Text(d.ders),
                subtitle: Text("${d.saat} - ${d.konu}"),
                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: ()=>_edit(d)),
              )).toList()
            ),
          );
        }).toList());
      })));
  }
}

class ManuelProgramSihirbazi extends StatefulWidget { const ManuelProgramSihirbazi({super.key}); @override State<ManuelProgramSihirbazi> createState() => _MPSState(); }
class _MPSState extends State<ManuelProgramSihirbazi> {
  int _step = 0; String sinif = "12", alan = "Sayısal", stil = "30+5 (30 Dk Ders, 5 Dk Mola)";
  TimeOfDay basla = const TimeOfDay(hour: 18, minute: 0), bitis = const TimeOfDay(hour: 22, minute: 0);
  List<String> tatiller = []; Map<String, bool> dersler = {};
  @override void initState() { super.initState(); _dersleriYenile(); }
  
  // DERS LİSTESİNİ GÜNCELLEME (HATA ÇÖZÜLDÜ)
  void _dersleriYenile() { 
    dersler.clear(); 
    VeriDeposu.dersKonuAgirliklari.forEach((k, v) { 
      bool ekle = false; 
      // Basit filtreleme mantığı
      if (k.startsWith("TYT")) ekle = true; 
      else if (sinif != "9" && sinif != "10") { // 11, 12, Mezun için AYT
         if (alan == "Sayısal" && (k.contains("Matematik") || k.contains("Fizik") || k.contains("Kimya") || k.contains("Biyoloji"))) ekle = true;
         if (alan == "Eşit Ağırlık" && (k.contains("Matematik") || k.contains("Edebiyat") || k.contains("Tarih") || k.contains("Coğrafya"))) ekle = true;
         if (alan == "Sözel" && (k.contains("Edebiyat") || k.contains("Tarih") || k.contains("Coğrafya") || k.contains("Felsefe") || k.contains("Din"))) ekle = true;
      }
      if (ekle) dersler[k] = true; // Varsayılan olarak SEÇİLİ
    });
    setState(() {}); // UI Güncelle
  }
  
  void _olustur() {
    List<String> secilen = []; dersler.forEach((k, v) { if (v) secilen.add(k); }); 
    if(secilen.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen en az bir ders seçin!"))); return;} 
    secilen.shuffle();
    
    // Süre Hesapla
    int dersSuresi = 30; int molaSuresi = 5; 
    if (stil.contains("35")) { dersSuresi=35; } else if (stil.contains("40")) { dersSuresi=40; } else if (stil.contains("45")) { dersSuresi=45; } else if (stil.contains("50")) { dersSuresi=50; } else if (stil.contains("60")) { dersSuresi=60; molaSuresi=10; } else if (stil.contains("Pomodoro")) { dersSuresi=25; molaSuresi=5; }
    
    int toplamDk = (bitis.hour * 60 + bitis.minute) - (basla.hour * 60 + basla.minute); 
    int blok = toplamDk ~/ (dersSuresi + molaSuresi); if (blok < 1) blok = 1;
    
    List<Gorev> program = []; 
    List<String> gunler = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]; 
    int idx = 0;
    
    for (int h = 1; h <= 1; h++) { // 1 haftalık örnek
       for (var gun in gunler) { 
         if (tatiller.contains(gun)) continue; 
         for (int i = 0; i < blok; i++) { 
           String d = secilen[idx % secilen.length]; idx++; 
           int s = (basla.hour * 60 + basla.minute) + (i * (dersSuresi + molaSuresi)); 
           int e = s + dersSuresi; 
           String ss = "${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')} - ${(e ~/ 60).toString().padLeft(2, '0')}:${(e % 60).toString().padLeft(2, '0')}"; 
           program.add(Gorev(hafta: h, gun: gun, saat: ss, ders: d, konu: "Konu Seç", aciklama: "Çalışma")); 
         } 
       } 
    }
    VeriDeposu.programiKaydet(program, "Manuel Program"); 
    Navigator.pop(context); 
    Navigator.push(context, MaterialPageRoute(builder: (c) => TumProgramEkrani())); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Programınız Oluşturuldu!"), backgroundColor: Colors.green));
  }
  
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Manuel Program Hazırlama")), body: Stepper(currentStep: _step, onStepContinue: () { if (_step < 2) setState(() => _step++); else _olustur(); }, onStepCancel: () { if (_step > 0) setState(() => _step--); }, steps: [
      Step(title: const Text("Sınıf & Alan"), content: Column(children: [DropdownButtonFormField(value: sinif, items: ["9", "10", "11", "12", "Mezun"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { setState(() => sinif = v!); _dersleriYenile(); }), if (sinif != "9" && sinif != "10") DropdownButtonFormField(value: alan, items: ["Sayısal", "Sözel", "Eşit Ağırlık", "Dil"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { setState(() => alan = v!); _dersleriYenile(); })])),
      Step(title: const Text("Zamanlama"), content: Column(children: [DropdownButtonFormField(value: stil, items: VeriDeposu.calismaStilleri.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) { setState(() => stil = v!); }), Row(children: [TextButton(onPressed: () async { var t = await showTimePicker(context: context, initialTime: basla); if (t != null) setState(() => basla = t); }, child: Text("Başla: ${basla.format(context)}")), TextButton(onPressed: () async { var t = await showTimePicker(context: context, initialTime: bitis); if (t != null) setState(() => bitis = t); }, child: Text("Bitir: ${bitis.format(context)}"))])])),
      Step(title: const Text("Tatil Günleri"), content: Wrap(spacing: 5, children: ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"].map((g) => FilterChip(label: Text(g), selected: tatiller.contains(g), onSelected: (v) => setState(() { v ? tatiller.add(g) : tatiller.remove(g); }))).toList())),
      Step(title: const Text("Dersleri Seçin"), content: SizedBox(height: 300, child: ListView(children: dersler.keys.map((k) => CheckboxListTile(title: Text(k), value: dersler[k], onChanged: (v) => setState(() => dersler[k] = v!))).toList())))
    ])); }
}

class ProgramSihirbaziEkrani extends StatefulWidget { const ProgramSihirbaziEkrani({super.key, this.mod = "Genel"}); final String mod; @override State<ProgramSihirbaziEkrani> createState() => _PSEState(); }
class _PSEState extends State<ProgramSihirbaziEkrani> {
  // YENİ AI SİHİRBAZI - SORU SORARAK PROGRAM OLUŞTURMA
  final _formKey = GlobalKey<FormState>();
  String sinif="12", alan="Sayısal", hedef="Tıp Fakültesi", zayif="Matematik", saat="5";
  bool loading = false;

  void _olusturAI() async {
    if(!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(()=>loading=true);

    List<Gorev> program = await GeminiServisi.programOlustur(sinif, alan, "30+5", int.parse(saat), zayif);
    
    setState(()=>loading=false);
    
    if(program.isNotEmpty) {
      VeriDeposu.programiKaydet(program, "AI Program");
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (c)=>TumProgramEkrani()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI program oluşturamadı. Tekrar deneyin.")));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Program Sihirbazı")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.psychology, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 10),
              const Text("Bana hedeflerinden bahset, sana en uygun programı hazırlayayım!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              DropdownButtonFormField(value: sinif, decoration: const InputDecoration(labelText: "Sınıfın"), items: ["9","10","11","12","Mezun"].map((s)=>DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v)=>setState(()=>sinif=v!)),
              const SizedBox(height: 10),
              DropdownButtonFormField(value: alan, decoration: const InputDecoration(labelText: "Alan"), items: ["Sayısal","Sözel","Eşit Ağırlık","Dil"].map((s)=>DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v)=>setState(()=>alan=v!)),
              const SizedBox(height: 10),
              TextFormField(decoration: const InputDecoration(labelText: "Hedefin (Bölüm/Üni)"), initialValue: hedef, onSaved: (v)=>hedef=v!),
              const SizedBox(height: 10),
              TextFormField(decoration: const InputDecoration(labelText: "En Zayıf Olduğun Dersler"), initialValue: zayif, onSaved: (v)=>zayif=v!),
              const SizedBox(height: 10),
              TextFormField(decoration: const InputDecoration(labelText: "Günlük Kaç Saat Çalışabilirsin?"), initialValue: saat, keyboardType: TextInputType.number, onSaved: (v)=>saat=v!),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading?null:_olusturAI, child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("PROGRAMI OLUŞTUR", style: TextStyle(fontSize: 18))))
            ],
          ),
        ),
      ),
    );
  }
}

class DenemeEkleEkrani extends StatefulWidget { final String ogrenciId; const DenemeEkleEkrani({super.key, required this.ogrenciId}); @override State<DenemeEkleEkrani> createState() => _DEEState(); }
class _DEEState extends State<DenemeEkleEkrani> {
  // TYT
  List<DersGiris> tytDersleri = [
    DersGiris("TYT Türkçe", 40), DersGiris("TYT Sosyal - Tarih", 5), DersGiris("TYT Sosyal - Coğrafya", 5), DersGiris("TYT Sosyal - Felsefe", 5), DersGiris("TYT Sosyal - Din", 5),
    DersGiris("TYT Matematik", 40), DersGiris("TYT Fen - Fizik", 7), DersGiris("TYT Fen - Kimya", 7), DersGiris("TYT Fen - Biyoloji", 6)
  ];
  // AYT
  List<DersGiris> aytDersleri = [
    DersGiris("AYT Matematik", 40), DersGiris("AYT Fizik", 14), DersGiris("AYT Kimya", 13), DersGiris("AYT Biyoloji", 13),
    DersGiris("AYT Edebiyat", 24), DersGiris("AYT Tarih-1", 10), DersGiris("AYT Coğrafya-1", 6),
    DersGiris("AYT Tarih-2", 11), DersGiris("AYT Coğrafya-2", 11), DersGiris("AYT Felsefe Gr", 12), DersGiris("AYT Din", 6)
  ];

  double _netHesapla(List<DersGiris> liste) {
    double toplam = 0;
    for(var d in liste) {
      double dogru = double.tryParse(d.d.text) ?? 0;
      double yanlis = double.tryParse(d.y.text) ?? 0;
      if(dogru + yanlis > d.soruSayisi) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${d.n} dersinde soru sayısı (${d.soruSayisi}) aşıldı!"), backgroundColor: Colors.red));
         return -1; 
      }
      d.net = dogru - (yanlis / 4);
      toplam += d.net;
    }
    return toplam;
  }

  void _kaydet(String tur, List<DersGiris> liste) {
    double toplamNet = _netHesapla(liste);
    if(toplamNet == -1) return; 

    Map<String, double> detaylar = { for(var item in liste) item.n : item.net };
    
    VeriDeposu.denemeEkle(DenemeSonucu(
      ogrenciId: widget.ogrenciId, 
      tur: tur, 
      tarih: DateTime.now(), 
      toplamNet: toplamNet, 
      dersNetleri: detaylar
    ));
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$tur Denemesi Eklendi. Net: ${toplamNet.toStringAsFixed(2)}"), backgroundColor: Colors.green));
  }

  @override Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text("Deneme Ekle"), bottom: const TabBar(tabs: [Tab(text: "TYT"), Tab(text: "AYT")])),
        body: TabBarView(children: [
          _buildForm("TYT", tytDersleri),
          _buildForm("AYT", aytDersleri)
        ]),
      ),
    );
  }

  Widget _buildForm(String tur, List<DersGiris> dersler) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: dersler.length,
            itemBuilder: (c, i) {
              var d = dersler[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text("${d.n} (${d.soruSayisi})", style: const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: TextField(controller: d.d, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "D", isDense: true))),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: TextField(controller: d.y, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Y", isDense: true))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(onPressed: () => _kaydet(tur, dersler), child: Text("$tur KAYDET", style: const TextStyle(fontSize: 18))),
          ),
        )
      ],
    );
  }
}
class OkulSinavlariEkrani extends StatefulWidget { const OkulSinavlariEkrani({super.key}); @override State<OkulSinavlariEkrani> createState() => _OSEState(); } class _OSEState extends State<OkulSinavlariEkrani> { void _ekle(){ final c1=TextEditingController(); final c2=TextEditingController(); final c3=TextEditingController(); final c4=TextEditingController(); showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Ekle"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: c1, decoration: const InputDecoration(labelText: "Ders")), TextField(controller: c2, decoration: const InputDecoration(labelText: "Y1")), TextField(controller: c3, decoration: const InputDecoration(labelText: "Y2")), TextField(controller: c4, decoration: const InputDecoration(labelText: "Perf"))]), actions: [TextButton(onPressed: (){VeriDeposu.dersEkle(OkulDersi(ad: c1.text, yazili1: double.tryParse(c2.text)??0, yazili2: double.tryParse(c3.text)??0, performans: double.tryParse(c4.text)??0)); setState((){}); Navigator.pop(c);}, child: const Text("OK"))]));} @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Notlar")), body: ListView.builder(itemCount: VeriDeposu.okulNotlari.length, itemBuilder: (c,i){var d=VeriDeposu.okulNotlari[i]; return ListTile(title: Text(d.ad), trailing: CircleAvatar(child: Text(d.ortalama.toStringAsFixed(0))));}), floatingActionButton: FloatingActionButton(onPressed: _ekle, child: const Icon(Icons.add))); } }
class KronometreEkrani extends StatefulWidget { const KronometreEkrani({super.key}); @override State<KronometreEkrani> createState() => _KREState(); } class _KREState extends State<KronometreEkrani> { Timer? _t; int _s=0; bool _run=false; @override void dispose(){_t?.cancel(); super.dispose();} void _toggle(){if(_run)_t?.cancel(); else _t=Timer.periodic(const Duration(seconds:1), (t)=>setState(()=>_s++)); setState(()=>_run=!_run);} @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Sayaç")), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text("${_s~/60}:${(_s%60).toString().padLeft(2,'0')}", style: const TextStyle(fontSize: 80)), IconButton(icon: Icon(_run?Icons.pause:Icons.play_arrow, size: 60), onPressed: _toggle)]))); } }
class BasariGrafigiEkrani extends StatelessWidget { final String ogrenciId; const BasariGrafigiEkrani({super.key, required this.ogrenciId}); @override Widget build(BuildContext context) { var l=VeriDeposu.denemeListesi.where((d)=>d.ogrenciId==ogrenciId).toList(); return Scaffold(appBar: AppBar(title: const Text("Grafik")), body: l.isEmpty?const Center(child: Text("Veri Yok")):CustomPaint(size: Size.infinite, painter: ChartPainter(l))); } }
class ChartPainter extends CustomPainter { final List<DenemeSonucu> d; ChartPainter(this.d); @override void paint(Canvas c, Size s) { Paint p=Paint()..color=Colors.blue..strokeWidth=3..style=PaintingStyle.stroke; Path t=Path(); for(int i=0;i<d.length;i++){ double x=i*(s.width/(d.length>1?d.length-1:1)); double y=s.height-(d[i].toplamNet/120*s.height); if(i==0)t.moveTo(x,y); else t.lineTo(x,y); c.drawCircle(Offset(x,y),5,Paint()..color=Colors.red); } c.drawPath(t,p); } @override bool shouldRepaint(covariant CustomPainter old)=>true; }
class DenemeListesiEkrani extends StatelessWidget { final String? ogrenciId; const DenemeListesiEkrani({super.key, this.ogrenciId}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Denemeler")), body: ListView.builder(itemCount: VeriDeposu.denemeListesi.length, itemBuilder: (c,i)=>ListTile(title: Text(VeriDeposu.denemeListesi[i].tur), subtitle: Text("Net: ${VeriDeposu.denemeListesi[i].toplamNet}")))); } }
class RozetlerEkrani extends StatelessWidget { final Ogrenci ogrenci; const RozetlerEkrani({super.key, required this.ogrenci}); @override Widget build(BuildContext context) { 
    var s = VeriDeposu.tumRozetler.where((r) => r.kategori == "Soru").toList();
    var k = VeriDeposu.tumRozetler.where((r) => r.kategori == "Konu").toList();
    var d = VeriDeposu.tumRozetler.where((r) => r.kategori == "Deneme").toList();
    var v = VeriDeposu.tumRozetler.where((r) => r.kategori == "Seviye").toList();
    var siraliOgrenciler = List<Ogrenci>.from(VeriDeposu.ogrenciler);
    siraliOgrenciler.sort((a, b) => b.puan.compareTo(a.puan));

    return DefaultTabController(length: 2, child: Scaffold(appBar: AppBar(title: const Text("Rozetler & Liderlik"), bottom: const TabBar(tabs: [Tab(text: "Koleksiyonum"), Tab(text: "Liderlik Tablosu")])), body: TabBarView(children: [
      ListView(children: [
        _buildSection("🏆 Seviye", v), _buildSection("🎯 Soru", s), _buildSection("📚 Konu", k), _buildSection("📝 Deneme", d)
      ]),
      ListView.builder(itemCount: siraliOgrenciler.length, itemBuilder: (c,i){ var o = siraliOgrenciler[i]; return Card(color: o.id==ogrenci.id?Colors.green[50]:Colors.white, child: ListTile(leading: CircleAvatar(child: Text("${i+1}")), title: Text(o.ad), trailing: Text("${o.puan} XP"))); })
    ]))); 
  }
  Widget _buildSection(String t, List<Rozet> l) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(8.0), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), ...l.map((r)=>ListTile(leading: CircleAvatar(backgroundColor: r.kazanildi?r.renk.withOpacity(0.2):Colors.grey[200], child: Icon(r.ikon, color: r.kazanildi?r.renk:Colors.grey)), title: Text(r.ad), subtitle: LinearProgressIndicator(value: min(1.0, r.mevcutSayi/r.hedefSayi)), trailing: r.kazanildi?const Icon(Icons.check, color: Colors.green):const Icon(Icons.lock, color: Colors.grey)))] );
  }
}
class YoneticiPaneli extends StatelessWidget { const YoneticiPaneli({super.key}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Yönetici")), body: ListView(children: VeriDeposu.ogrenciler.map((o)=>ListTile(title: Text(o.ad), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: ()=>VeriDeposu.kullaniciSil(o.id, true)))).toList())); } }
class OgretmenPaneli extends StatelessWidget { final String aktifOgretmenId; const OgretmenPaneli({super.key, required this.aktifOgretmenId}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Öğretmen")), body: ListView(children: VeriDeposu.ogrenciler.map((o)=>ListTile(title: Text(o.ad), onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (c)=>OgretmenOgrenciDetayEkrani(ogrenci: o))))).toList())); } }
class OgretmenOgrenciDetayEkrani extends StatelessWidget { final Ogrenci ogrenci; const OgretmenOgrenciDetayEkrani({super.key, required this.ogrenci}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: Text(ogrenci.ad)), body: Center(child: Text("Detaylar..."))); } }
class KonuTakipEkrani extends StatefulWidget { final bool readOnly; const KonuTakipEkrani({super.key, this.readOnly=false}); @override State<KonuTakipEkrani> createState() => _KTE(); } class _KTE extends State<KonuTakipEkrani> { @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Konular")), body: ListView(children: VeriDeposu.dersKonuAgirliklari.keys.map((d)=>ExpansionTile(title: Text(d), children: VeriDeposu.dersKonuAgirliklari[d]!.map((k)=>CheckboxListTile(title: Text(k.ad), value: VeriDeposu.tamamlananKonular["$d - ${k.ad}"]??false, onChanged: widget.readOnly?null:(v)=>setState(()=>VeriDeposu.konuDurumDegistir("$d - ${k.ad}", v!)))).toList())).toList())); } }
class SoruTakipEkrani extends StatefulWidget { final String ogrenciId; const SoruTakipEkrani({super.key, required this.ogrenciId}); @override State<SoruTakipEkrani> createState() => _STE(); } class _STE extends State<SoruTakipEkrani> { String? d, k; final c1=TextEditingController(), c2=TextEditingController(); 
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Soru Takip")), body: Padding(padding: const EdgeInsets.all(10), child: Column(children: [DropdownButton<String>(isExpanded: true, value: d, hint: const Text("Ders"), items: VeriDeposu.dersKonuAgirliklari.keys.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState((){d=v; k=null;})), if(d!=null) DropdownButton<String>(isExpanded: true, value: k, hint: const Text("Konu"), items: VeriDeposu.dersKonuAgirliklari[d]!.map((e)=>DropdownMenuItem(value: e.ad, child: Text(e.ad))).toList(), onChanged: (v)=>setState(()=>k=v)), Row(children: [Expanded(child: TextField(controller: c1, decoration: const InputDecoration(labelText: "Doğru"))), const SizedBox(width: 10), Expanded(child: TextField(controller: c2, decoration: const InputDecoration(labelText: "Yanlış")))]), ElevatedButton(onPressed: (){VeriDeposu.soruEkle(SoruCozumKaydi(ogrenciId: widget.ogrenciId, ders: d!, konu: k!, dogru: int.parse(c1.text), yanlis: int.parse(c2.text), tarih: DateTime.now())); setState((){});}, child: const Text("EKLE")), Expanded(child: ListView.builder(itemCount: VeriDeposu.soruCozumListesi.where((x)=>x.ogrenciId==widget.ogrenciId).length, itemBuilder: (c,i)=>ListTile(title: Text(VeriDeposu.soruCozumListesi[i].konu), trailing: Text("D:${VeriDeposu.soruCozumListesi[i].dogru} Y:${VeriDeposu.soruCozumListesi[i].yanlis}"))))]))); } }
class SoruCozumEkrani extends StatefulWidget { const SoruCozumEkrani({super.key}); @override State<SoruCozumEkrani> createState() => _SCEState(); }
class _SCEState extends State<SoruCozumEkrani> {
  File? _image; String _cozum=""; bool _loading=false; final ImagePicker _picker = ImagePicker();
  Future<void> _foto(ImageSource s) async { final f = await _picker.pickImage(source: s); if(f!=null) setState(()=>_image=File(f.path)); }
  Future<void> _coz() async { if(_image==null)return; setState(()=>_loading=true); String c = await GeminiServisi.soruCoz(_image!); setState((){_cozum=c; _loading=false;}); }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("AI Soru Çöz")), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    if(_image!=null) Image.file(_image!, height: 200),
    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton.icon(onPressed: ()=>_foto(ImageSource.camera), icon: const Icon(Icons.camera), label: const Text("Kamera")), ElevatedButton.icon(onPressed: ()=>_foto(ImageSource.gallery), icon: const Icon(Icons.image), label: const Text("Galeri"))]),
    const SizedBox(height: 10), ElevatedButton(onPressed: _loading?null:_coz, child: _loading ? const CircularProgressIndicator() : const Text("ÇÖZ")),
    if(_cozum.isNotEmpty) Container(margin: const EdgeInsets.only(top:20), padding: const EdgeInsets.all(10), color: Colors.green[50], child: Text(_cozum))
  ]))); }
}
// --- GÜNLÜK TAKİP EKRANI ---
class GunlukTakipEkrani extends StatefulWidget { const GunlukTakipEkrani({super.key}); @override State<GunlukTakipEkrani> createState() => _GTEState(); }
class _GTEState extends State<GunlukTakipEkrani> { 
  int h=1, maxH=1; 
  String bugun = ["Pazartesi","Salı","Çarşamba","Perşembe","Cuma","Cumartesi","Pazar"][DateTime.now().weekday-1];
  @override void initState(){super.initState(); if(VeriDeposu.kayitliProgram.isNotEmpty) maxH=VeriDeposu.kayitliProgram.map((e)=>e.hafta).reduce(max); } 
  @override Widget build(BuildContext context) { 
    var list = VeriDeposu.kayitliProgram.where((x)=>x.hafta==h && x.gun==bugun).toList(); 
    return Scaffold(appBar: AppBar(title: Text("Bugün: $bugun")), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8.0), child: DropdownButton<int>(value: h, items: List.generate(maxH, (i)=>DropdownMenuItem(value: i+1, child: Text("${i+1}. Hafta"))), onChanged: (v)=>setState(()=>h=v!))),
      Expanded(child: list.isEmpty ? const Center(child: Text("Bugün ders yok.")) : ListView.builder(itemCount: list.length, itemBuilder: (c,i){ var g=list[i]; return CheckboxListTile(title: Text(g.ders), subtitle: Text(g.konu), value: g.yapildi, onChanged: (v)=>setState(()=>g.yapildi=v!)); }))
    ])); 
  } 
}