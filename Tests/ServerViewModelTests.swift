import XCTest

final class ServerViewModelTests: XCTestCase {
    func testMakeURLAddsHTTPSByDefault() {
        XCTAssertEqual(ServerViewModel.makeURL("abs.example.com")?.absoluteString, "https://abs.example.com")
        XCTAssertEqual(ServerViewModel.makeURL("  abs.example.com:7443  ")?.absoluteString, "https://abs.example.com:7443")
    }

    func testMakeURLKeepsExplicitScheme() {
        XCTAssertEqual(ServerViewModel.makeURL("http://192.168.1.5:8000")?.absoluteString, "http://192.168.1.5:8000")
        XCTAssertEqual(ServerViewModel.makeURL("https://abs.example.com/")?.host, "abs.example.com")
    }

    func testMakeURLRejectsUnusableInput() {
        XCTAssertNil(ServerViewModel.makeURL(""))
        XCTAssertNil(ServerViewModel.makeURL("   "))
        XCTAssertNil(ServerViewModel.makeURL("https://"))
        XCTAssertNil(ServerViewModel.makeURL("://host-only"))
        XCTAssertNil(ServerViewModel.makeURL("ftp://abs.example.com"))
    }

    func testDescribeMapsEveryErrorCase() {
        let cases: [(AudiobookshelfError, String)] = [
            (.invalidURL, L("Geçersiz URL")),
            (.missingToken, L("Token eksik")),
            (.unauthorized, L("Kimlik doğrulama reddedildi (401/403)")),
            (.notFound, L("Bulunamadı (404)")),
            (.serverError(status: 503), LF("Sunucu hatası (%d)", 503)),
            (.decoding("boom"), LF("Yanıt çözümlenemedi: %@", "boom")),
            (.transport("zaman aşımı"), LF("Bağlantı hatası: %@", "zaman aşımı")),
        ]
        for (error, expected) in cases {
            XCTAssertEqual(ServerViewModel.describe(error), expected, "\(error) yanlış anlatıldı")
        }
    }

    func testAuthModeLabelsAreLocalizedKeys() {
        XCTAssertEqual(ServerViewModel.AuthMode.credentials.rawValue, "Kullanıcı adı / şifre")
        XCTAssertEqual(ServerViewModel.AuthMode.token.rawValue, "API token")
        XCTAssertEqual(ServerViewModel.AuthMode.allCases.count, 2)
    }
}
