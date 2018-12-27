import Foundation

public class Mobileprovision {

    enum CMSError : Error {
        case create
        case update
        case finalize
        case copyContent
    }

    var Name : String
    var ExpirationDate : Date
    var Entitlements : [String:Any]
    var CreationDate : Date
    var AppIDName : String
    var UUID : String
    var TeamName : String
    var Platform : [String]?
    var ApplicationIdentifierPrefix : [String]
    var DeveloperCertificates : [Data]
    var TeamIdentifier : [String]
    var TimeToLive : Int
    var Version : Int
    
    public init? (_ plist : [String:Any]) {
        guard let uuid = plist["UUID"] as? String else { return nil }
        UUID = uuid
        
        guard let expirationDate = plist["ExpirationDate"] as? Date else { return nil }
        ExpirationDate = expirationDate
        
        if let entitlements = plist["Entitlements"] as? [String:Any] {
            Entitlements = entitlements
        } else { return nil}
        if let creationDate = plist["CreationDate"] as? Date {
            CreationDate = creationDate
        } else { return nil}
        if let appIDName = plist["AppIDName"] as? String {
            AppIDName = appIDName
        } else { return nil}
        if let teamName = plist["TeamName"] as? String {
            TeamName = teamName
        } else { return nil}
        if let applicationIdentifierPrefix = plist["ApplicationIdentifierPrefix"] as? [String] {
            ApplicationIdentifierPrefix = applicationIdentifierPrefix
        } else { return nil}
        if let certs = plist["DeveloperCertificates"] as? [Data] {
            // openssl x509 -noout -inform DER -subject
            DeveloperCertificates = certs
        } else { return nil}
        if let teamIdentifier = plist["TeamIdentifier"] as? [String] {
            TeamIdentifier = teamIdentifier
        } else { return nil}
        if let ttl = plist["TimeToLive"] as? Int {
            TimeToLive = ttl
        } else { return nil}
        if let version = plist["Version"] as? Int {
            Version = version
        } else { return nil}
        Platform = plist["Platform"] as? [String]
        Name = plist["Name"] as! String
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
            let cal = Calendar.current
            let expDate = self.ExpirationDate
            let components = cal.dateComponents([Calendar.Component.day], from: Date(), to: expDate)
            return components.day ?? 0
        }
    }
    
    static func decodeX509 (data: Data) -> String {
        var outstr = ""
        let task = Process()
        task.launchPath = "/usr/bin/openssl"
        task.arguments = ["x509", "-noout", "-inform", "DER", "-subject"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        let inPipe = Pipe()
        task.standardInput = inPipe
        task.launch()
        inPipe.fileHandleForWriting.write(data)
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            outstr = output as String
        }
        task.waitUntilExit()
        return outstr
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


