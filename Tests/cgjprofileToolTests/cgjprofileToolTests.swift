import Foundation
import XCTest
@testable import cgjprofileCore

class cgjprofileToolTests: XCTestCase {
    
    var provisionData : Data!
    var url : URL!
    var tool = cgjprofileTool()
    var mobileprovision : Mobileprovision!
    
    override func setUp() {
        super.setUp()
        url = URL(string: "file:///Users/below/Library/MobileDevice/Provisioning%20Profiles/351d20ea-a4c6-4e3d-ad00-1e275cbfead1.mobileprovision")
        provisionData = try! Data(contentsOf: url)
        let decodedProvision = try! cgjprofileTool.decodeCMS(data:provisionData)
        let plist = try! cgjprofileTool.decodePlist (data: decodedProvision)
        mobileprovision = Mobileprovision(plist)

        
    }
    override func tearDown() {
        super.tearDown()
    }
    func testURL () throws {
        XCTAssertNotNil(url, "URL was nil: \(url)")
    }
    func testProfileExists() throws {
        XCTAssertNotNil(mobileprovision)
    }

    func testNonFormatStringFoo() throws {
        XCTAssertEqual("foo", mobileprovision.parseNonFormatString(fromString:"foo%").0)
    }

    func testNonFormatStringBar() throws {
        XCTAssertEqual("bar", mobileprovision.parseNonFormatString(fromString:"bar").0)
    }

    func testNonFormatStringEmpty() throws {
        XCTAssertEqual("", mobileprovision.parseNonFormatString(fromString:"").0)
    }
    
    func testFormatPercent () throws {
        
    }
    
    func testNumberParser42() throws {
        let result = mobileprovision.parseInteger(fromString:"42")
        XCTAssertEqual(42, result.0)
    }

    func testNumberParser0() throws {
        XCTAssertEqual(0, mobileprovision.parseInteger(fromString:"").0)
    }

    func testNumberParser1() throws {
        XCTAssertEqual(1, mobileprovision.parseInteger(fromString:"1").0)
    }
    
    func testProfile() throws {
        XCTAssertNotNil(mobileprovision)
    }
}
