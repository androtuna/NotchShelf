#!/usr/bin/env bash
# NotchShelf dağıtım build'i: imzala -> doğrula -> zip -> notarize -> staple.
#
# Gereksinimler (bu makinede bir kez):
#   1. Xcode > Settings > Accounts > Team > "Developer ID Application" sertifikası
#   2. xcrun notarytool store-credentials notchshelf \
#        --apple-id you@example.com --team-id XXXXXXXXXX \
#        password <app-specific-password>
#      (App Store Connect API key için: --key/--key-id/--issuer)
#
# Kullanım:
#   ./scripts/release.sh
#   DEVELOPMENT_TEAM=XXXXXXXXXX KEYCHAIN_PROFILE=notchshelf ./scripts/release.sh
#   MARKETING_VERSION=0.2.0 CURRENT_PROJECT_VERSION=7 ./scripts/release.sh   # sürüm override
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="NotchShelf.xcodeproj"
SCHEME="NotchShelf"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="build/dist"
ARTIFACTS="build/artifacts"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notchshelf}"
IDENTITY="${IDENTITY:-Developer ID Application}"
TEAM_ARGS=()
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  TEAM_ARGS=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi
# Sürüm override: project.yml sabit kalır, sürüm build sırasında verilir.
VERSION_ARGS=()
if [[ -n "${MARKETING_VERSION:-}" ]]; then
  VERSION_ARGS+=("MARKETING_VERSION=$MARKETING_VERSION")
fi
if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
  VERSION_ARGS+=("CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION")
fi

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31mHATA:\033[0m %s\n' "$*" >&2; exit 1; }

say "Ön kontroller"
# `pipefail` altında `cmd | grep -q` SIGPIPE ile sahte başarısızlık üretir;
# kontroller string üzerinde yapılıyor.
identities="$(security find-identity -v -p codesigning)"
if [[ "$identities" != *"$IDENTITY"* ]]; then
  die "'$IDENTITY' sertifikası yok. Xcode > Settings > Accounts > Team > Manage Certificates > + ile ekleyin."
fi

profile_rc=0
profile_out="$(xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" 2>&1)" || profile_rc=$?
if [[ $profile_rc -ne 0 ]]; then
  if [[ "$profile_out" == *"No Keychain password item found"* ]]; then
    die "Notary profili '$KEYCHAIN_PROFILE' keychain'de yok. store-credentials komutunu script başındaki açıklamadan kendi terminalinde çalıştırın (anahtarı sohbete/commite koymayın)."
  fi
  # Genelde "A required agreement is missing or has expired" veya ağ hatası olur.
  die "Notary profili çağrı yapılamadı (rc=$profile_rc): $profile_out"
fi

say "Release build ($CONFIGURATION)"
# bash 3.2 + `set -u`: boş dizi açılımı "unbound variable" verir, bu yüzden korumalı form.
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual ENABLE_HARDENED_RUNTIME=YES \
  ${TEAM_ARGS[@]+"${TEAM_ARGS[@]}"} ${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"} \
  clean build -quiet

APP="$DERIVED/Build/Products/$CONFIGURATION/$SCHEME.app"
[[ -d "$APP" ]] || die "Ürün bulunamadı: $APP"
# `defaults read` göreli yolu kabul etmiyor; PlistBuddy hem göreli hem mutlak çalışır.
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")"
say "Sürüm $VERSION ($BUILD)"

say "Bundle hijyeni"
# xcodebuild test, .xctest'i Contents/PlugIns'e ve XCTest framework'lerini
# Contents/Frameworks'e kopyalar; böyle bir bundle notarize edilemez.
if ls "$APP/Contents/PlugIns"/*.xctest >/dev/null 2>&1 \
   || ls "$APP/Contents/Frameworks"/XCTest* "$APP/Contents/Frameworks"/XCUnit* \
        "$APP/Contents/Frameworks"/libXCTest* >/dev/null 2>&1; then
  die "$APP test kalıntısı içeriyor. Temiz bir -derivedDataPath ile tekrar çalıştırın (DERIVED=build/dist2 …)."
fi
say "Test kalıntısı yok"

say "İmza doğrulaması"
codesign --verify --deep --strict --verbose=2 "$APP"
ENT="$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)"
SIG_INFO="$(codesign -dvvv "$APP" 2>&1)"
if [[ "$ENT" == *"get-task-allow"* ]]; then
  die "$CONFIGURATION yapılandırmasında get-task-allow hâlâ var; notarization reddeder."
fi
if [[ "$SIG_INFO" != *"Authority=$IDENTITY"* ]]; then
  die "Göbek yetkisi '$IDENTITY' değil; Gatekeeper/notarization bunu ister."
fi
if [[ "$SIG_INFO" != *"runtime"* ]]; then
  die "hardened runtime bayrağı yok (ENABLE_HARDENED_RUNTIME=YES olmalı)."
fi
if [[ "$SIG_INFO" != *"Timestamp="* ]]; then
  die "secure timestamp yok. Release config OTHER_CODE_SIGN_FLAGS='--timestamp' olmalı; Apple aksi halde submit'i 'signature does not include a secure timestamp' ile reddeder."
fi
printf '%s\n' "$SIG_INFO" | grep -E "^(Timestamp|Signed Time)=|^Authority=|^CodeDirectory|^TeamIdentifier" || true
say "authority + runtime + timestamp: OK"

mkdir -p "$ARTIFACTS"
ZIP="$ARTIFACTS/$SCHEME-$VERSION.zip"
rm -f "$ZIP"
say "Arşivleniyor: $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

say "Notarization (birkaç dakika sürebilir)"
SUBMIT_LOG="$ARTIFACTS/notary-submit.log"
notary_failed() {
  sub_id="$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$SUBMIT_LOG" 2>/dev/null | head -1)"
  printf '\033[31mHATA:\033[0m Notarization başarısız (%s). Tam nedeni için:\n' "$1" >&2
  if [[ -n "$sub_id" ]]; then
    printf '  xcrun notarytool log %s --keychain-profile %s\n' "$sub_id" "$KEYCHAIN_PROFILE" >&2
  else
    printf '  (submission id yok; ham çıktı: %s)\n' "$SUBMIT_LOG" >&2
  fi
  exit 1
}
xcrun notarytool submit "$ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait 2>&1 | tee "$SUBMIT_LOG" \
  || notary_failed "submit sıfır olmayan çıkış döndürdü"
if ! grep -qi "status: accepted" "$SUBMIT_LOG"; then
  notary_failed "yanıtta 'Status: Accepted' yok"
fi
say "Notarization: Accepted"

say "Staple + son değerlendirme"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
# Gatekeeper değerlendirmesi: aynı diskteki imzalı kopya reddedilebilir; asıl
# testi indirme sonrası karantina ile son kullanıcı yapar. Bu yüzden uyarı, hata değil.
if spctl --assess --type execute --verbose=4 "$APP"; then
  say "spctl: kabul edildi"
else
  printf '\033[33mUYARI:\033[0m spctl reddetti; karantina altındaki gerçek bir indirmeyi ayrıca test edin.\n'
fi

STAPLED_ZIP="$ARTIFACTS/$SCHEME-$VERSION-stapled.zip"
rm -f "$STAPLED_ZIP"
ditto -c -k --keepParent "$APP" "$STAPLED_ZIP"

say "DMG paketi oluşturuluyor"
./scripts/create-dmg.sh "$APP" "$ARTIFACTS"
DMG="$ARTIFACTS/$SCHEME-$VERSION.dmg"
if [[ -f "$DMG" ]]; then
  xcrun stapler staple "$DMG" 2>/dev/null || true
fi

say "Tamamlandı"
printf '  Uygulama:   %s\n  Ham zip:    %s\n  Staple zip: %s\n  DMG paketi: %s\n' "$APP" "$ZIP" "$STAPLED_ZIP" "$DMG"

