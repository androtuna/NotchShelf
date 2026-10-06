<div align="center">

<img src="icon.png" alt="NotchShelf Icon" width="128" height="128" />

# NotchShelf

**An elegant, native macOS client for [Audiobookshelf](https://www.audiobookshelf.org/) living right inside your MacBook notch and menu bar.**

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg?logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg?logo=swift)](https://swift.org)
[![XcodeGen](https://img.shields.io/badge/Project-XcodeGen-black.svg?logo=xcode)](https://github.com/yonaskolb/XcodeGen)
[![Audiobookshelf](https://img.shields.io/badge/Compatible-Audiobookshelf-red.svg)](https://www.audiobookshelf.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-34%20Passing-brightgreen.svg)](Tests)

[English](#english) • [Türkçe](#türkçe)

---

</div>

<a name="english"></a>
## 🎧 Overview

**NotchShelf** transforms your MacBook's notch into a functional, beautiful audiobook companion. Built specifically for [Audiobookshelf](https://www.audiobookshelf.org/) self-hosted servers, NotchShelf provides instant access to your audiobook library, player controls, and progress sync without cluttering your desktop.

Move your cursor to the notch to reveal the interactive mini player, or click the menu bar icon to browse libraries, search books, and manage settings.

---

## ✨ Features

- **🎯 Interactive Notch HUD**:
  - Hover over the MacBook notch to reveal player status, book title, author, elapsed/remaining time, and scrub bar.
  - Native physical notch detection (`MacBook Pro 14"/16"`, `MacBook Air 13"/15"`).
  - Automatic simulated notch fallback for notchless Macs and external displays.
- **📚 Complete Library Access**:
  - Browse your Audiobookshelf libraries and collections.
  - Search books by title or author with instant filtering.
  - View high-resolution cover artwork.
- **⚡ Bi-Directional Progress Sync**:
  - Automatically reports playback progress to your Audiobookshelf server.
  - Seamlessly resume playback from where you left off on phone, tablet, or web.
- **🔒 Privacy & Keychain Security**:
  - API tokens and credentials are encrypted strictly inside Apple's native **macOS Keychain**.
  - Zero analytics, zero trackers, zero data collection (`PrivacyInfo.xcprivacy` compliant).
  - Sandboxed architecture (`com.apple.security.app-sandbox`).
  - Supports self-signed certificates and custom CA servers (ideal for homelab setups).
- **🎛️ Native Controls & System Integration**:
  - System Media Keys & macOS Now Playing widget integration.
  - Menu bar popover with quick playback controls and volume.
  - Notifications when an audiobook finishes.
  - Launch at login option.
- **🌍 Multi-Language Support**:
  - Full localization in **English** and **Turkish (Türkçe)** with dynamic runtime language switching.

---

## 💻 System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or later
- **Hardware**: Any Apple Silicon (M1/M2/M3/M4) or Intel Mac
- **Server**: A running [Audiobookshelf](https://www.audiobookshelf.org/) server instance (v2.x+)

---

## 🚀 Installation

### Option 1: Download Pre-built DMG (Recommended)
1. Head over to the [Releases](https://github.com/androtuna/NotchShelf/releases) page.
2. Download the latest `NotchShelf-x.x.x.dmg`.
3. Open the `.dmg` file and drag **NotchShelf.app** into your **Applications** folder.
4. Launch **NotchShelf**, enter your Audiobookshelf server URL and login credentials.

### Option 2: Build from Source
Ensure you have Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:

```bash
# Clone the repository
git clone https://github.com/androtuna/NotchShelf.git
cd NotchShelf

# Install XcodeGen if you haven't already
brew install xcodegen

# Generate Xcode project and build
make project
make build

# Or generate a DMG image directly
make dmg
```

The resulting binary will be in `build/dist/Build/Products/Release/NotchShelf.app` and the disk image in `build/artifacts/NotchShelf-x.x.x.dmg`.

---

## 🛠️ Development & Makefile Commands

NotchShelf uses `XcodeGen` to keep project configuration clean and free of Git merge conflicts (`project.yml` is the single source of truth).

| Command | Description |
|---|---|
| `make project` | Generates `NotchShelf.xcodeproj` from `project.yml` |
| `make test` | Runs the full XCTest unit test suite |
| `make build` | Compiles the release binary (ad-hoc signed for local testing) |
| `make dmg` | Packages the application into a distribution `.dmg` image |
| `make release` | Runs the full notarization and release pipeline (Apple Dev ID) |
| `make clean` | Cleans build caches and generated project files |

---

## 📁 Architecture

```
NotchShelf/
├── Notch/          # Notch detector, HUD window & interactive hover UI
├── MenuBar/        # Status item controller, popover & menu icon
├── Features/
│   ├── Player/     # AVPlayer management, NowPlaying & scrub controls
│   ├── Library/    # Book catalog, search & cover loaders
│   ├── Server/     # Server connection & authentication flows
│   ├── Settings/   # User preferences & language options
│   └── Onboarding/ # First-time server setup screen
├── Networking/     # Audiobookshelf REST API client, models & SSL trust
├── Storage/        # KeychainStore & UserDefaults Preferences
└── Utils/          # Localizations, formatters, animations, notifications
```

---

<a name="türkçe"></a>
## 🇹🇷 Türkçe Açıklama

**NotchShelf**, MacBook çentiğinizi (Notch) ve menü çubuğunuzu şık bir sesli kitap kontrol merkezine dönüştüren yerel bir macOS uygulamasıdır. Kendi sunucunuzdaki [Audiobookshelf](https://www.audiobookshelf.org/) kitaplığınıza masaüstünüzü kalabalıklaştırmadan tek tıkla veya imlecinizi çentiğe getirerek erişebilirsiniz.

### Öne Çıkan Özellikler:
- **Çentik HUD**: İmleci MacBook çentiğinin üzerine getirdiğinizde açılan, kitap adı, yazar, kapak görseli ve ilerleme çubuğu barındıran animasyonlu mini oynatıcı.
- **Evrensel Uyum**: Fiziksel çentikli MacBook'larda (`Pro 14"/16"`, `Air 13"/15"`) tam oturur; çentiksiz Mac'lerde veya harici ekranlarda otomatik simüle çentik sunar.
- **Otomatik Senkronizasyon**: Dinleme konumunuzu anlık olarak Audiobookshelf sunucunuzla eşitler; telefon veya web üzerinden kaldığınız yerden devam edebilirsiniz.
- **Tam Güvenlik & Gizlilik**: Şifreler ve API anahtarları yalnızca macOS Keychain üzerinde saklanır. Telemetri veya veri toplama yoktur.
- **Gelişmiş Ağ Desteği**: Homelab ortamları için kendi kendine imzalanmış (self-signed) SSL sertifikalarını destekler.
- **Sistem Entegrasyonu**: Klavye medya tuşları, macOS Now Playing entegrasyonu, kitap bitiş bildirimleri ve başlangıçta otomatik çalışma.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
