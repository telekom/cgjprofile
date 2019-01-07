/*
 * MIT License
 *
 * Copyright (c) 2019 Deutsche Telekom AG
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

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
        let decodedProvision = try! Mobileprovision.decodeCMS(data:provisionData)
        let plist = try! Mobileprovision.decodePlist (data: decodedProvision)
        mobileprovision = PrettyProvision(plist)
        prettyprovision = mobileprovision as? PrettyProvision
        
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
        XCTAssertEqual(-967, days)
    }
    
    struct SecItemStructure {
        var localizedLabel : String // "localized label"
        var value : Any
        var type : String
        var label : String
    }
    
    func testCertificateEndDate() throws {
        if let cert = prettyprovision.DeveloperCertificates.first {
            
            let secCert = SecCertificateCreateWithData(nil, cert as CFData)
            XCTAssertNotNil(secCert)
            
        
        var dc = DateComponents()
        dc.year = 2016
        dc.month = 1
        dc.day = 8
        dc.hour = 16
        dc.minute = 54
        dc.second = 40
        let testDate = Calendar.autoupdatingCurrent.date(from: dc)
        
        var enddate : Date!
            XCTAssertNoThrow(enddate = try Mobileprovision.certificateEnddate(data: cert))
        
        XCTAssertEqual(enddate, testDate)
        var error: Unmanaged<CFError>?
            guard let dict = SecCertificateCopyValues(secCert!,[kSecOIDX509V1ValidityNotAfter] as CFArray,&error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        if let info = dict as? [String:[String:Any]] {
            for key in info.keys {
                if let item = info[key]
                {
                    if let label = item[kSecPropertyKeyLabel as String] as? String, let localizedLabel = item[kSecPropertyKeyLocalizedLabel as String] as? String, let type = item[kSecPropertyKeyType as String] as? String, var value = item[kSecPropertyKeyValue as String] {
                        
                        if type == "section" || type == "data" {
                            value = "** Something **"
                        }
                        if label == "Not Valid After", let interval = value as? NSNumber {
                            let dInterval = interval.doubleValue
                            let date = Date(timeIntervalSinceReferenceDate: dInterval)
                            XCTAssertEqual(enddate, date)
                            let df = DateFormatter()
                            df.dateStyle = .medium
                            df.timeStyle = .medium
                            let dateString = df.string(from: date)
                            value = dateString
                        }
                        
                        print ("\(localizedLabel) (\(label)): \(value) (\(type))")
                    }
                }
            }
        }
    }
        else {
            XCTFail()
        }
    }
    
    func testCertificateName() throws {
        if let cert = prettyprovision.DeveloperCertificates.first {
            
            let certName = try Mobileprovision.certificateDisplayName(data: cert)
            
            XCTAssertNotNil(certName)
            
            var keychainErr = noErr;
            // Set up the keychain search dictionary:
            var certificateQuery : [String: Any] = [:]
            // This keychain item is a generic password.
            certificateQuery[kSecClass as String] = kSecClassIdentity
            certificateQuery[ kSecReturnRef as String] = kCFBooleanTrue
            certificateQuery[kSecMatchLimit as String] = kSecMatchLimitAll
            
            //Initialize the dictionary used to hold return data from the keychain:
            var outArray : AnyObject?
            // If the keychain item exists, return the attributes of the item:
            keychainErr = SecItemCopyMatching(certificateQuery as CFDictionary, &outArray)
            XCTAssert(keychainErr == noErr)
            let certArray = outArray as? [SecIdentity]
            XCTAssertNotNil(certArray)
            let first = certArray!.first!
            var cert : SecCertificate?
            var result = withUnsafeMutablePointer(to: &cert) { (c) -> OSStatus in
                return SecIdentityCopyCertificate(first, c)
            }
            XCTAssert(result == noErr)
            var cfString : CFString?
            result = withUnsafeMutablePointer(to: &cfString) { (cfs) -> OSStatus in
                return SecCertificateCopyCommonName(cert!, cfs)
            }
            XCTAssert(result == noErr)
            print (cfString as String? ?? "SNIETZ")
        }
        else {
            XCTFail()
        }
    }
}
