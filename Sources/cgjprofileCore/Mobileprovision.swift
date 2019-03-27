/*
 * cgjprofile :- A tool to analyze the validity of iOS mobileprovision
 *               files and associated certificates
 * Copyright (c) 2019, Alexander von Below, Deutsche Telekom AG
 * contact: opensource@telekom.de
 * This file is distributed under the conditions of the MIT license.
 * For details see the file LICENSE on the toplevel.
 */

import Foundation

// There do not seem to be constants anywere in xOS:
// https://opensource.apple.com/source/kext_tools/kext_tools-425.1.3/security.c

let kSecOIDUserID          = "0.9.2342.19200300.100.1.1"
let kSecOIDCommonName             = "2.5.4.3"
let kSecOIDCountryName            = "2.5.4.6"
let kSecOIDOriganziationName      = "2.5.4.10"
let kSecOIDOrganizationalUnitName = "2.5.4.11"

enum X509Error : Error {
    case unableToDecodeItem
    case unableToReadKeychain
}

public class Mobileprovision {

    enum CMSError : Error {
        case create
        case update
        case finalize
        case copyContent
    }

    var name : String
    var expirationDate : Date
    var entitlements : [String:Any]
    var creationDate : Date
    var appIDName : String
    var uuid : String
    var teamName : String
    var platform : [String]?
    var applicationIdentifierPrefix : [String]
    var developerCertificates : [SecCertificate]
    var teamIdentifier : [String]
    var timeToLive : Int
    var version : Int
    
    public init? (_ plist : [String:Any]) {
        guard let uuidvalue = plist["UUID"] as? String else { return nil }
        uuid = uuidvalue
        
        guard let expDatevalue = plist["ExpirationDate"] as? Date else { return nil }
        expirationDate = expDatevalue
        
        if let value = plist["Entitlements"] as? [String:Any] {
            entitlements = value
        } else { return nil}
        if let value = plist["CreationDate"] as? Date {
            creationDate = value
        } else { return nil}
        if let value = plist["AppIDName"] as? String {
            appIDName = value
        } else { return nil}
        if let value = plist["TeamName"] as? String {
            teamName = value
        } else { return nil}
        if let value = plist["ApplicationIdentifierPrefix"] as? [String] {
            applicationIdentifierPrefix = value
        } else { return nil}
        if let certdata = plist["DeveloperCertificates"] as? [Data] {
            // openssl x509 -noout -inform DER -subject
            developerCertificates = certdata.compactMap({ (data) -> SecCertificate? in
                let certificate = SecCertificateCreateWithData(nil, data as CFData)
                return certificate
            })
        } else { return nil}
        if let value = plist["TeamIdentifier"] as? [String] {
            teamIdentifier = value
        } else { return nil}
        if let value = plist["TimeToLive"] as? Int {
            timeToLive = value
        } else { return nil}
        if let value = plist["Version"] as? Int {
            version = value
        } else { return nil}
        platform = plist["Platform"] as? [String]
        name = plist["Name"] as! String
    }
    
    // No clue why I must specify Foundation
    public convenience init?(url : Foundation.URL) {
        do {
            let provisionData = try Data(contentsOf: url)
            self.init(data: provisionData)
        }
        catch {
            return nil
        }
    }
    
    public convenience init?(data : Data) {
        do {
            let decodedProvision = try Mobileprovision.decodeCMS(data:data)
            let plist = try Mobileprovision.decodePlist (data: decodedProvision)
            self.init (plist)
        }
        catch {
            return nil
        }
    }
    
    public var daysToExpiration : Int {
        get {
            let expDate = self.expirationDate
            return Mobileprovision.daysToExpiration(for: expDate)
        }
    }
    
    public static func daysToExpiration(for expDate : Date) -> Int {
        let cal = Calendar.current
        let components = cal.dateComponents([Calendar.Component.day], from: Date(), to: expDate)
        return components.day ?? 0

    }
    
    static func identifyCertificates () throws -> [String : SecCertificate] {
        // Set up the keychain search dictionary:
        var certificateQuery : [String: Any] = [:]
        // This keychain item is a generic password.
        certificateQuery[kSecClass as String] = kSecClassIdentity
        certificateQuery[kSecReturnRef as String] = kCFBooleanTrue
        certificateQuery[kSecMatchLimit as String] = kSecMatchLimitAll
        
        //Initialize the dictionary used to hold return data from the keychain:
        var outArray : AnyObject?
        // If the keychain item exists, return the attributes of the item:
        guard SecItemCopyMatching(certificateQuery as CFDictionary, &outArray) == noErr else {
            throw X509Error.unableToReadKeychain
        }
        let identArray = outArray as! [SecIdentity]
        
        let certDict = try identArray.reduce([String:SecCertificate]()) { (dict, identity) -> [String:SecCertificate] in
            var dict = dict
            var certOptional : SecCertificate?
            guard withUnsafeMutablePointer(to: &certOptional, { (c) -> OSStatus in
                return SecIdentityCopyCertificate(identity, c)
            }) == noErr else {
                throw X509Error.unableToReadKeychain
            }
            guard let cert = certOptional else {
                throw X509Error.unableToReadKeychain
            }
            let name = try cert.displayName()
            dict[name] = cert
            return dict
        }
        return certDict
    }
    
    public static func decodeCMS (data : Data) throws -> Data {
        var decoder : CMSDecoder?
        guard CMSDecoderCreate(&decoder) == noErr, let cmsDecoder = decoder else {
            throw CMSError.create
        }
        
        guard data.withUnsafeBytes({ (bytes) -> OSStatus in
            CMSDecoderUpdateMessage(cmsDecoder, bytes, data.count)
        }) == noErr else {
            throw CMSError.update
        }
        
        guard CMSDecoderFinalizeMessage(cmsDecoder) == noErr else {
            throw CMSError.finalize
        }
        
        var output : CFData?
        guard CMSDecoderCopyContent(cmsDecoder, &output) == noErr else {
            throw CMSError.copyContent
        }
        
        return output! as Data
    }
    
    public static func decodePlist (data : Data) throws -> [String:Any] {
        return try PropertyListSerialization.propertyList(from:data, options: [], format: nil) as! [String:Any]
    }

}

extension SecCertificate {
    func displayName () throws -> String {
        
        var commonName : String = "-"
        var organizationalUnit : String = "-"
        var organization : String = "-"
        
        var error: Unmanaged<CFError>?
        guard let info = SecCertificateCopyValues(self, [kSecOIDX509V1SubjectName, kSecOIDX509V1SubjectNameStd, kSecOIDX509V1SubjectNameCStruct] as CFArray, &error) as? [CFString:[CFString:Any]] else {
            throw error!.takeRetainedValue() as Error
        }
        
        guard let subjectName = info[kSecOIDX509V1SubjectName]?[kSecPropertyKeyValue] as? [[CFString : String]] else {
            throw X509Error.unableToDecodeItem
        }
        
        for item in subjectName {
            
            guard let value = item[kSecPropertyKeyValue] else {
                throw X509Error.unableToDecodeItem
            }
            switch item[kSecPropertyKeyLabel] {
            case kSecOIDCommonName:
                commonName = value
            case kSecOIDOriganziationName:
                organization = value
            case kSecOIDOrganizationalUnitName:
                organizationalUnit = value
            case kSecOIDUserID, kSecOIDCountryName:
                continue
            default:
                continue
            }
        }
        return "\(commonName) \(organizationalUnit) \(organization)"
    }
    
    func enddate () throws -> Date {
        
        var error: Unmanaged<CFError>?
        guard let info = SecCertificateCopyValues(self, [kSecOIDX509V1ValidityNotAfter] as CFArray, &error) as? [CFString:[CFString:Any]] else {
            throw error!.takeRetainedValue() as Error
        }
        
        guard let value = info[kSecOIDX509V1ValidityNotAfter]?[kSecPropertyKeyValue] as? NSNumber else {
            throw X509Error.unableToDecodeItem
        }
        
        let date = Date(timeIntervalSinceReferenceDate: value.doubleValue)
        return date
    }
}
