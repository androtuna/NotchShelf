import XCTest

// Localizable.xcstrings derlenip NotchShelf.app/Contents/Resources/<dil>.lproj
// altına yazılıyor. Kaynak dili Türkçe; EN çevirilerinin anahtarlarla birebir
// eşleşmesini ve yer tutucuların korunmasını burada doğruluyoruz.
final class StringCatalogTests: XCTestCase {
    // Testler host uygulamanın içinde (PlugIns) koşuyor; Bundle.main uygulama
    // değilse test bundle'ından yukarı çıkıp .app'i buluyoruz.
    private var hostApp: Bundle? {
        if Bundle.main.bundleURL.pathExtension == "app",
           Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en") != nil {
            return Bundle.main
        }
        var directory = Bundle(for: StringCatalogTests.self).bundleURL
        for _ in 0..<5 {
            directory = directory.deletingLastPathComponent()
            if directory.pathExtension == "app", let bundle = Bundle(url: directory),
               bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en") != nil {
                return bundle
            }
        }
        return nil
    }

    private func strings(for language: String) throws -> [String: String] {
        guard let bundle = hostApp,
              let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language),
              let data = try? Data(contentsOf: url) else {
            throw XCTSkip("derlenmiş katalog bulunamadı (dil: \(language))")
        }
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: String] else {
            XCTFail("Localizable.strings sözlük olarak okunamadı (\(language))")
            return [:]
        }
        return dictionary
    }

    func testEveryTurkishKeyHasEnglishTranslation() throws {
        let tr = try strings(for: "tr")
        let en = try strings(for: "en")
        XCTAssertFalse(tr.isEmpty, "katalog boş")

        let missing = tr.keys.filter { en[$0] == nil }.sorted()
        XCTAssertTrue(missing.isEmpty, "EN çevirisi eksik anahtarlar: \(missing.prefix(10))")
    }

    func testSourceLanguageValuesMatchTheirKeys() throws {
        let tr = try strings(for: "tr")
        let drifted = tr.filter { $0.key != $0.value }
        XCTAssertTrue(drifted.isEmpty, "kaynak dil değerleri anahtardan saptı: \(drifted.prefix(5))")
    }

    func testPlaceholdersSurviveTranslation() throws {
        let tr = try strings(for: "tr")
        let en = try strings(for: "en")

        for (key, source) in tr {
            guard let translation = en[key] else { continue }
            XCTAssertEqual(
                Self.specifiers(in: source).sorted(),
                Self.specifiers(in: translation).sorted(),
                "yer tutucu uyuşmuyor: \(key)"
            )
        }
    }

    func testKnownTranslationsArePresent() throws {
        let en = try strings(for: "en")
        XCTAssertEqual(en["Oynatıcı"], "Player")
        XCTAssertEqual(en["Kütüphane"], "Library")
        XCTAssertEqual(en["Ayarlar"], "Settings")
        XCTAssertEqual(en["Kitap bitti"], "Book finished")
        XCTAssertEqual(en["Sunucuya bağlı değil"], "Not connected to a server")
    }

    private static func specifiers(in text: String) -> [String] {
        let pattern = "%(?:[0-9]+\\$)?(?:lld|ld|lu|gx|g|d|@|f|%)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var found: [String] = []
        regex.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            guard let match, let range = Range(match.range, in: text) else { return }
            found.append(String(text[range]))
        }
        return found
    }
}
