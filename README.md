# Ender-OS

**Oyun ve yazılım geliştirme odaklı, tamamen özelleştirilebilir, hafif ve atomik Linux işletim sistemi.**  
*Fedora 45 Atomic (`bootc`) tabanlı • Hyprland & KDE Plasma 6 • AMD / Intel / NVIDIA Open*

[![CI Validation](https://github.com/EnderkingTR/Ender-OS/actions/workflows/ci.yml/badge.svg)](https://github.com/EnderkingTR/Ender-OS/actions/workflows/ci.yml)
[![Build OCI Images](https://github.com/EnderkingTR/Ender-OS/actions/workflows/build-images.yml/badge.svg)](https://github.com/EnderkingTR/Ender-OS/actions/workflows/build-images.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

## Neden Ender-OS?

Ender-OS, klasik bozulabilen paket yığınları yerine SteamOS ve Universal Blue/Bazzite yaklaşımını takip eden **imaj tabanlı (`bootc`)** modern bir Linux masaüstü işletim sistemidir:

- **Atomik Güncellemeler & Tek Komutla Geri Alma:** Sistem güncellemeleri arka planda hazırlanır; sorun çıkarsa `ender-ctl rollback` ile önceki çalışan sürüme dönülür.
- **Hafif Çekirdek + İzole Yazılım Ortamları:** Host sistemi yormadan `Podman` ve `Distrobox` üzerinde Rust, Web, Python, C/C++ ve Arch Linux konteyner yığınları saniyeler içinde oluşturulur.
- **Kutudan Çıktığı Gibi Oyun Performansı:** Steam, Lutris, Gamescope, GameMode, MangoHud (64+32-bit), Vulkan, NTSYNC, ZRAM, düşük gecikmeli PipeWire ve oyun odaklı `sysctl`/I/O ayarları hazır gelir.
- **Canlı Tema ve Profil Motoru:** `ender-ctl` ile `gaming`, `balanced`, `dev`, `powersave` profilleri ve `ender-obsidian`, `ender-nordic`, `ender-crimson` temaları arasında anlık geçiş yapılır.

---

## Resmi Sürümler (Editions)

| Sürüm | Masaüstü Ortamı | GPU Desteği | OCI İmaj Adresi |
| :--- | :--- | :--- | :--- |
| **`ender-os-hyprland`** | Hyprland (Wayland) | AMD & Intel (Mesa/Vulkan) | `ghcr.io/enderkingtr/ender-os-hyprland:latest` |
| **`ender-os-hyprland-nvidia`** | Hyprland (Wayland) | NVIDIA Open (RTX 20xx+) | `ghcr.io/enderkingtr/ender-os-hyprland-nvidia:latest` |
| **`ender-os-plasma`** | KDE Plasma 6 (HDR/VRR) | AMD & Intel (Mesa/Vulkan) | `ghcr.io/enderkingtr/ender-os-plasma:latest` |
| **`ender-os-plasma-nvidia`** | KDE Plasma 6 (HDR/VRR) | NVIDIA Open (RTX 20xx+) | `ghcr.io/enderkingtr/ender-os-plasma-nvidia:latest` |

> Ayrıntılı katman diyagramı ve teknik kararlar için [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) belgesine göz atın.

---

## Hızlı Başlangıç

### 1. Mevcut Bir Fedora Atomic / Universal Blue Sisteminden Geçiş

```bash
# Örnek: Hyprland (AMD/Intel) sürümüne geçiş
sudo bootc switch ghcr.io/enderkingtr/ender-os-hyprland:latest

# Örnek: KDE Plasma 6 (NVIDIA Open) sürümüne geçiş
sudo bootc switch ghcr.io/enderkingtr/ender-os-plasma-nvidia:latest
```

Ardından sistemi yeniden başlatın.

### 2. Kurulum ISO'su Üretme

GitHub Actions üzerinde **Actions -> Build Ender-OS ISO & VM Disks -> Run workflow** adımından istediğiniz sürüm için `anaconda-iso` veya `qcow2` çıktısı üretebilirsiniz.

### 3. `ender-ctl` ile Günlük Yönetim

```bash
# Sistem, GPU, aktif profil ve tema durumunu görüntüle
ender-ctl status

# Sistem sağlığını ve oyun/dev bileşenlerini denetle
ender-ctl doctor

# Performans profilini değiştir (gaming, balanced, dev, powersave)
ender-ctl profile set gaming

# Canlı temayı değiştir (ender-obsidian, ender-nordic, ender-crimson)
ender-ctl theme set ender-nordic

# İzole geliştirici ortamı (Distrobox) oluştur ve içine gir
ender-ctl devbox list
ender-ctl devbox create rust
ender-ctl devbox enter ender-rust

# Önerilen oyun Flatpak araçlarını (ProtonUp-Qt, Heroic, Bottles vb.) kur
ender-ctl gaming setup --group gaming

# Sistemi güncelle veya önceki sürüme geri al
ender-ctl update
ender-ctl rollback
```

Hyprland oturumunda hızlı kısayollar:
- `Super + Return`: Kitty terminal
- `Super + Space`: Rofi uygulama başlatıcı
- `Super + G`: Gaming Mode aç/kapat
- `Super + T`: Canlı tema seçici

---

## Yerel Geliştirme ve Doğrulama

```bash
# Depo doğrulama, birim testler ve ShellCheck kontrollerini çalıştır
just lint

# İstediğiniz sürümü yerelde derleyin (Podman gerektirir)
just build hyprland
just build plasma-nvidia

# Yerel imajdan kurulum ISO'su üretin
just build-iso hyprland
```

---

## Bakımcı (Maintainer) Kurulum Notları

1. **GHCR İzinleri:** GitHub depo ayarlarından **Settings -> Actions -> General -> Workflow permissions** altında *Read and write permissions* yetkisinin etkin olduğundan emin olun. İlk push sonrası GHCR paket görünürlüğünü `Public` yapın.
2. **Cosign İmaj İmzalama (Opsiyonel ama Önerilen):**
   ```bash
   COSIGN_PASSWORD="" cosign generate-key-pair
   ```
   Oluşan `cosign.key` içeriğini GitHub repo ayarlarında **`COSIGN_PRIVATE_KEY`** secret olarak ekleyin; `cosign.pub` dosyasını repoya dahil edebilirsiniz. `COSIGN_PRIVATE_KEY` tanımlı değilken `build-images.yml` yine de imajları başarıyla derler ve yükler, yalnızca imzalama adımını atlar.
