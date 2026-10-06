import XCTest

final class FormattersTests: XCTestCase {
    func testTimeCoversZeroNegativeAndRollover() {
        XCTAssertEqual(Formatters.time(0), "0:00")
        XCTAssertEqual(Formatters.time(-30), "0:00")
        XCTAssertEqual(Formatters.time(.nan), "0:00")
        XCTAssertEqual(Formatters.time(9.4), "0:09")
        XCTAssertEqual(Formatters.time(125), "2:05")
        XCTAssertEqual(Formatters.time(3661), "1:01:01")
    }

    func testDurationLabelUsesLocalizedUnits() {
        XCTAssertEqual(Formatters.durationLabel(0), "—")
        XCTAssertEqual(Formatters.durationLabel(120), LF("%d dk", 2))
        XCTAssertEqual(Formatters.durationLabel(6325), LF("%d sa %d dk", 1, 45))
    }

    func testRelativeDescriptionBuckets() {
        XCTAssertEqual(Date(timeIntervalSinceNow: -1).relativeDescription, L("şimdi"))
        XCTAssertEqual(Date(timeIntervalSinceNow: -31).relativeDescription, LF("%d sn önce", 31))
        XCTAssertEqual(Date(timeIntervalSinceNow: -130).relativeDescription, LF("%d dk önce", 2))
        XCTAssertEqual(Date(timeIntervalSinceNow: -7300).relativeDescription, LF("%d sa önce", 2))
    }

    func testBookFallsBackToLocalizedUnknownMetadata() {
        let known = Book(item: Fixture.firstItem)
        XCTAssertEqual(known.title, "Dune")
        XCTAssertEqual(known.author, "Frank Herbert")

        let empty = Book(item: Fixture.untitledItem)
        XCTAssertEqual(empty.id, "it2")
        XCTAssertEqual(empty.title, L("Bilinmeyen başlık"))
        XCTAssertEqual(empty.author, L("Bilinmeyen yazar"))
    }
}
