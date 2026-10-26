import XCTest
@testable import Clearview

final class GeometryTests: XCTestCase {
    func testAspectFitLetterboxesAWideSourceInATallBox() {
        let fit = Geometry.aspectFit(CGSize(width: 200, height: 100), in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(fit, CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    func testAspectFitPillarboxesATallSourceInAWideBox() {
        let fit = Geometry.aspectFit(CGSize(width: 100, height: 200), in: CGRect(x: 10, y: 0, width: 200, height: 100))
        XCTAssertEqual(fit, CGRect(x: 85, y: 0, width: 50, height: 100))
    }

    func testAspectFitOfEmptySourceIsEmpty() {
        XCTAssertEqual(Geometry.aspectFit(.zero, in: CGRect(x: 0, y: 0, width: 10, height: 10)), .zero)
    }

    func testNormalizeAndDenormalizeRoundTrip() {
        let rect = CGRect(x: 20, y: 10, width: 200, height: 100)
        let p = Geometry.normalize(CGPoint(x: 70, y: 35), in: rect)
        XCTAssertEqual(p, CGPoint(x: 0.25, y: 0.25))
        XCTAssertEqual(Geometry.denormalize(p, in: rect), CGPoint(x: 70, y: 35))
    }

    func testNormalizeClampsPointsOutsideTheImage() {
        let p = Geometry.normalize(CGPoint(x: -50, y: 500), in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(p, CGPoint(x: 0, y: 1))
    }
}
