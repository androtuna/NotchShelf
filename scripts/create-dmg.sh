#!/usr/bin/env bash
# NotchShelf DMG oluşturucu: .app paketini alır ve dağıtıma hazır bir .dmg üretir.
#
# Kullanım:
#   ./scripts/create-dmg.sh [yol/NotchShelf.app] [çıktı/dizini]
#
# Parametre verilmezse varsayılan olarak:
#   APP: build/dist/Build/Products/Release/NotchShelf.app
#   ARTIFACTS: build/artifacts
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_ROOT="$(pwd)"
APP_PATH="${1:-build/dist/Build/Products/Release/NotchShelf.app}"
ARTIFACTS_DIR="${2:-build/artifacts}"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mHATA:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ ! -d "$APP_PATH" ]]; then
  # Eğer derlenmemişse Release konfigürasyonunu derlemeyi dene
  say "$APP_PATH bulunamadı, derleniyor..."
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --quiet
  fi
  xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf -configuration Release \
    -derivedDataPath build/dist CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual \
    clean build -quiet
fi

[[ -d "$APP_PATH" ]] || die "Uygulama bulunamadı: $APP_PATH"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || die "Info.plist bulunamadı: $INFO_PLIST"

APP_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO_PLIST" 2>/dev/null || echo "NotchShelf")"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")"

VOLUME_NAME="${APP_NAME} ${VERSION}"
DMG_FILENAME="${APP_NAME}-${VERSION}.dmg"
mkdir -p "$ARTIFACTS_DIR"
DMG_PATH="${ARTIFACTS_DIR}/${DMG_FILENAME}"

say "DMG Hazırlanıyor: $DMG_FILENAME (Sürüm: $VERSION, Build: $BUILD)"

STAGING_DIR="$(mktemp -d -t "notchshelf-dmg-XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT INT TERM

# 1. Uygulama paketini kopyala
say "Uygulama kopyalanıyor..."
cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"

# 2. Applications kısayolu oluştur
say "Applications sembolik bağı ekleniyor..."
ln -s /Applications "$STAGING_DIR/Applications"

# 3. İkon dosyası varsa disk bölümüne volume icon olarak yerleştir
ICNS_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
if [[ -f "$ICNS_PATH" ]]; then
  cp "$ICNS_PATH" "$STAGING_DIR/.VolumeIcon.icns"
fi

# 4. Geçici DMG oluştur veya doğrudan UDZO formatında sıkıştır
say "DMG paketi oluşturuluyor (UDZO - zlib sıkıştırma)..."
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

# 5. İsteğe bağlı imzalama (Developer ID varsa)
if [[ -n "${IDENTITY:-}" ]] && [[ "$IDENTITY" != "-" ]]; then
  say "DMG imzalanıyor ($IDENTITY)..."
  codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH" || true
fi

DMG_SIZE="$(du -sh "$DMG_PATH" | awk '{print $1}')"
say "DMG Başarıyla Oluşturuldu!"
printf '  Konum: %s\n  Boyut: %s\n' "$DMG_PATH" "$DMG_SIZE"
