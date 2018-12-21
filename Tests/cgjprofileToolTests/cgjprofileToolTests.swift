import Foundation
import XCTest
@testable import cgjprofileCore

class cgjprofileToolTests: XCTestCase {
    
    var provisionData : Data!
    var url : URL!
    var tool = cgjprofileTool()
    var mobileprovision : Mobileprovision!
    var prettyprovision : PrettyProvision!
    
    override func setUp() {
        super.setUp()
        url = URL(string: "file:///Users/below/Library/MobileDevice/Provisioning%20Profiles/351d20ea-a4c6-4e3d-ad00-1e275cbfead1.mobileprovision")
        provisionData = try! Data(contentsOf: url)
        let decodedProvision = try! cgjprofileTool.decodeCMS(data:provisionData)
        let plist = try! cgjprofileTool.decodePlist (data: decodedProvision)
        mobileprovision = Mobileprovision(plist)
        prettyprovision = PrettyProvision(mobileprovision)
        
    }
    override func tearDown() {
        super.tearDown()
    }
    func testURL () throws {
        XCTAssertNotNil(url, "URL was nil: \(String(describing: url))")
    }
    func testProfileExists() throws {
        XCTAssertNotNil(mobileprovision)
    }

    func testNonFormatStringFoo() throws {
        let testString = "foo"
        XCTAssertEqual(testString, prettyprovision.parseNonFormatString(fromString:"foo%", startIndex:testString.startIndex).0)
    }

    func testNonFormatStringBar() throws {
        let testString = "bar"
        XCTAssertEqual(testString, prettyprovision.parseNonFormatString(fromString:testString, startIndex:testString.startIndex).0)
    }

    func testNonFormatStringEmpty() throws {
        let testString = ""
        XCTAssertEqual(testString, prettyprovision.parseNonFormatString(fromString:testString, startIndex:testString.startIndex).0)
    }
    
    func testFormatPercent () throws {
        let testString = "%%"
        XCTAssertEqual("%", prettyprovision.parseFormat(fromString:testString, startIndex:testString.startIndex).0)
    }
    
    func testCombination () throws {
        let testString = "foo%%"
        var (result, index) = prettyprovision.parseNonFormatString(fromString:testString, startIndex:testString.startIndex)
        XCTAssertEqual(result, "foo")
        (result, index) = prettyprovision.parseFormat(fromString:testString, startIndex:index)
        XCTAssertEqual(result, "%")
    }
    
    func testNumberParser42() throws {
        let testString = "42"
        let result = prettyprovision.parseInteger(fromString:testString, startIndex:testString.startIndex)
        XCTAssertEqual(42, result.0)
    }

    func testNumberParser0() throws {
        let testString = ""
        XCTAssertEqual(0, prettyprovision.parseInteger(fromString:testString, startIndex:testString.startIndex).0)
    }

    func testNumberParser1() throws {
        let testString = "1"
        XCTAssertEqual(1, prettyprovision.parseInteger(fromString:testString, startIndex:testString.startIndex).0)
    }
    
    func testFormatUUID() throws {
        let testString = "%u"
        XCTAssertEqual("351d20ea-a4c6-4e3d-ad00-1e275cbfead1", prettyprovision.parseFormat(fromString:testString, startIndex:testString.startIndex).0)
    }
    
    func testPadding() throws {
        let testString = "%80u"
        XCTAssertEqual(80, prettyprovision.parseFormat(fromString:testString, startIndex:testString.startIndex).0.count)
    }
    
    func testCombinationTwo() throws {
        let testString = "The UDID is %u"
        var (result, index) = prettyprovision.parseNonFormatString(fromString:testString, startIndex:testString.startIndex)
        XCTAssertEqual(result, "The UDID is ")
        (result, index) = prettyprovision.parseFormat(fromString:testString, startIndex: index)
        XCTAssertEqual(result, "351d20ea-a4c6-4e3d-ad00-1e275cbfead1")
    }
    
    func testOutputOne() throws {
        XCTAssertEqual("foo", prettyprovision.parsedOutput("foo"))
    }
    
    func testOutputTwo() throws {
        XCTAssertEqual("foo%", prettyprovision.parsedOutput("foo%%"))
    }
    
    func testCombinationFour() throws {
        let testString = "The UDID is %%%u%%"
        let output = prettyprovision.parsedOutput(testString)
        XCTAssertEqual("The UDID is %351d20ea-a4c6-4e3d-ad00-1e275cbfead1%", output)
    }
    
    func testComplexFormat() throws {
        let format = "%u %t %t"
        let output = prettyprovision.parsedOutput(format)
        XCTAssertEqual("351d20ea-a4c6-4e3d-ad00-1e275cbfead1 Deutsche Telekom AG Deutsche Telekom AG", output)

    }
    func testWorkingURLsPath() throws {
        let urls = cgjprofileTool().workingURLs (paths:["/Users/below/Library/MobileDevice/Provisioning Profiles/351d20ea-a4c6-4e3d-ad00-1e275cbfead1.mobileprovision"])
        XCTAssertEqual(1, urls.count)
    }
    
    func testMobileProvisionDir() throws {
        let urls = cgjprofileTool().workingURLs()
        XCTAssert(urls.count != 0)
    }
    
    func testProfile() throws {
        XCTAssertNotNil(mobileprovision)
    }
    
    func testDefaultFormat() throws {
        let output = prettyprovision.parsedOutput("%u %t %a %n")
        XCTAssertEqual("351d20ea-a4c6-4e3d-ad00-1e275cbfead1 Deutsche Telekom AG Telekom Shop Offer Extension Telekom Shop Offer Extension DEV", output)
    }
    
    func testExpirationDate() throws {
        let days = prettyprovision.daysToExpiration
        XCTAssertEqual(-950, days)
    }
}
