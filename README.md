# robloxgame1

Rojo tabanli bir Roblox **av simulatoru**. Klasik dongu hazir ve calisir
durumda:

> kus vur -> canta dolar -> satis padine yuru -> para kazan -> tufek/canta yukselt -> rebirth

Kod tarafinda hicbir sey Studio'da elle olusturulmus nesnelere bagimli degil;
sahne bos olsa bile sunucu gerekli placeholder parcalarini kendisi kurar.

---

## Kurulum

### 1. Araclari kur

Toolchain [Rokit](https://github.com/rojo-rbx/rokit) ile pinlenmis durumda:

```bash
rokit install
```

Rokit yoksa araclari tek tek de kurabilirsin (Rojo, StyLua, Selene, Wally).
Rojo'nun Studio eklentisini de kurmayi unutma:

```bash
rojo plugin install
```

### 2. Studio'yu bagla

```bash
rojo serve
```

Studio'da bos bir Baseplate ac, Plugins sekmesindeki **Rojo** butonuna bas ve
**Connect** de. Artik bu depodaki her dosya degisikligi Studio'ya aninda yansir.

Alternatif olarak dosyadan bir place uretebilirsin:

```bash
rojo build default.project.json --output game.rbxlx
```

### 3. Veri kaydini ac

Studio'da: **File > Game Settings > Security > Enable Studio Access to API
Services** acik olmali. Kapali birakirsan oyun yine calisir ama ilerleme
kaydedilmez (`DataService` otomatik olarak bellek ici gecici profile duser ve
Output'a uyari basar).

---

## Proje yapisi

```
src/
  shared/          -> ReplicatedStorage.Shared  (iki taraf da erisir)
    Config.luau      Tum denge degerleri: araclar, cantalar, rebirth, fiyatlar
    Remotes.luau     RemoteEvent tanimlari tek yerde
    Format.luau      1500 -> "1.5K" sayi kisaltma
    Signal.luau      Hafif olay nesnesi (BindableEvent'siz)
    Types.luau       Paylasilan Luau tipleri

  server/          -> ServerScriptService.Server (Script + alt moduller)
    init.server.luau   Servisleri sirayla baslatan bootstrap
    DataService        DataStore + oturum kilidi + autosave + reconcile
    EconomyService     Para, canta doluluğu, satis, carpanlar
    CollectService     Atis istegi + nisan/menzil + anti-exploit dogrulamalari
    BirdService        Av alaninda ucusan kuslar, vurulanin yerine yenisi
    ShopService        Arac / canta satin alma
    RebirthService     Rebirth dongusu
    WorldService       Av alani + satis padi (CollectionService etiketli)
    ToolVisualService  ToolIndex'i elde gorunen bir tufege cevirir
    NetworkService     Client'a durum fotografi gonderir
    LeaderstatsService Oyuncu listesi tablosu

  client/          -> StarterPlayerScripts.Client (LocalScript + alt moduller)
    init.client.luau   Kontrolcuyu sirayla baslatan bootstrap
    StateController    Sunucudan gelen durumu tutar, degisimi yayinlar
    HudController      Para/canta/carpan gostergesi, butonlar, bildirimler
    ShopController     Magaza paneli
    CollectController  Girdi (fare / dokunma / ButtonR2)
    Create.luau        Instance olusturma yardimcisi
    Theme.luau         Renk ve olcu paleti
```

---

## Mimari kurallari

**Sunucu otoritedir.** Client hicbir zaman para, kaynak veya sahiplik
hesaplamaz. `Collect` remote'u parametresiz calisir: "ates ettim" der; hangi
kusun vuruldugunu, menzil ve nisan konisini, kazancin ne oldugunu sunucu
belirler. Client hedef bilgisi gondermez, dolayisiyla "her atis isabet"
exploit'i mumkun degil. `BuyTool`/`BuyBackpack` bir index alir
ama sunucu o index'i sinir, sira ve fiyat acisindan yeniden dogrular.

**Tek yazma noktasi.** Profile yapilan her degisiklik `DataService:Update()`
uzerinden gecer:

```lua
DataService:Update(player, function(profile)
    profile.Coins += 100
end)
```

Bu, `ProfileChanged` sinyalini atesler; leaderstats ve client arayuzu
kendiliginden guncellenir. Baska yerde manuel senkronizasyon kodu yazman
gerekmez.

**Denge tek dosyada.** Fiyat, guc, kapasite, rebirth egrisi — hepsi
`src/shared/Config.luau` icinde. Yeni bir arac eklemek icin listeye bir satir
eklemen yeterli; magaza arayuzu kendini otomatik olusturur.

**Dunya etiketle bulunur.** `WorldService`, parcalari isimle degil
`CollectionService` etiketiyle arar. Kendi haritani yaptiginda:

1. Studio'da **View > Tag Editor** ac.
2. Toplama alanina `CollectZone`, satis padine `SellPad` etiketini ver.
3. `Config.World.CreatePlaceholders` degerini `false` yap.

Birden fazla alan/pad destekleniyor.

---

## Av dongusu

`BirdService` av alaninin uzerinde `Config.Birds.Count` kadar kusu daire
cizerek ucurur. Kuslar tamamen sunucuda hareket eder (govde `Anchored`,
konumu her `Heartbeat`'te sunucu yazar).

Ates edince `CollectService`:

1. Cooldown ve av alani sinirini dogrular,
2. Namlu ucundan bakip menzil (`Config.Collect.Range`) ve nisan konisi
   (`Config.Collect.AimTolerance`) icindeki en iyi hizalanmis kusu secer,
3. Kusu dusurur ve tufegin `Power` degeri kadar kaynagi cantaya ekler.

Nisan yonu `HumanoidRootPart`'in bakis yonunden okunur — karakter kameranin
baktigi yone doner. Dikey aci serbesttir: kuslar yukarida ucar, oyuncunun
havaya nisan almasi gerekmez. Isabet yoksa sadece iz efekti cikar, kazanc
olmaz.

Vurulan kus `Config.Birds.RespawnDelay` sonra yenisiyle degisir; havadaki kus
sayisi sabit kalir.

---

## Tufek modelleri

`ToolVisualService`, profildeki `ToolIndex` her degistiginde (ve her respawn'da)
karaktere ilgili tufegi takar. Model bulunamazsa basit bir placeholder tufek
uretir (dipcik + govde + namlu), yani bos sahnede de elinde bir sey gorunur.

Kendi modelini koymak icin:

1. `ServerStorage` altina **ToolModels** adinda bir `Folder` ac.
2. Icine bir **Tool** koy; adi `Config.Tools` icindeki `Name` ile ayni olsun
   (veya girdiye `Model = "BaskaAd"` yaz).
3. Tool'un `Handle` adinda bir parcasi olmali — Roblox ele bunu takar.
   Handle'in uzun eksenini namlu yonunde (Z) uzat: `CollectService` namlu
   ucunu `Handle.CFrame.LookVector` uzerinden hesaplar.

Placeholder uretimini tamamen kapatmak icin
`Config.ToolVisual.CreatePlaceholders = false` yap.

Gorsel katman otoriter degildir: kus basina kazanc `Config.Tools[i].Power`'dan
okunur, elde ne gorundugunden bagimsizdir. Servis hic calismasa da oyun aynen
calisir.

---

## Yeni veri alani ekleme

`Config.DefaultProfile` icine alani ekle — hepsi bu. Eski kayitlar yuklenirken
`reconcile` fonksiyonu eksik alanlari varsayilanla doldurur, tipi bozulmus veya
artik semada olmayan alanlari atar. Veri kaybi olmadan alan ekleyip
cikarabilirsin.

Semayi geri donulmez sekilde degistirdiysen `Config.Data.StoreName` degerini
`PlayerData_v2` yap (dikkat: bu tum ilerlemeyi sifirlar).

---

## Gelistirme komutlari

```bash
rojo serve                    # Studio ile canli senkron
rojo build -o game.rbxlx      # Dosyadan place uret
stylua src                    # Formatla
selene src                    # Lint (once: selene generate-roblox-std)
wally install                 # Bagimlilik kur (su an bagimlilik yok)
```

`.github/workflows/ci.yml` her push'ta lint + format + build calistirir.

---

## Sonraki adimlar

Iskelette bilerek yer almayan, oyunu "gercek" yapan parcalar:

- **Pet sistemi**: ikinci bir carpan katmani. `Config` icine `Pets` listesi ve
  profile `EquippedPets` alani eklemek yeterli baslangic.
- **Gamepass / Developer Product**: `MarketplaceService` ile 2x para, otomatik
  toplama, VIP alan. `ProcessReceipt` mutlaka `DataService` ile ayni oturum
  kilidini kullanmali.
- **Bolgeler (areas)**: yuksek seviye av alanlari, rebirth veya para ile
  acilan kapilar. `WorldService`'e `RequiredRebirths` etiketi eklenebilir.
- **Sunucu disi olay**: gunluk odul, saatlik boss.

Bunlardan birini eklememi istersen soyle yeter.
