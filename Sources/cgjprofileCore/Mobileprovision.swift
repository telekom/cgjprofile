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
            let expDate = self.ExpirationDate
            return Mobileprovision.daysToExpiration(for: expDate)
        }
    }
    
    public static func daysToExpiration(for expDate : Date) -> Int {
        let cal = Calendar.current
        let components = cal.dateComponents([Calendar.Component.day], from: Date(), to: expDate)
        return components.day ?? 0

    }
    
    enum X509Info {
        case subject
        case text
        case enddate
    }
    
    enum X509Error : Error {
        case unableToDecodeItem
    }
    
    static func certificateDisplayName (data: Data) -> String {
        let string = self.decodeX509(data: data, info: .subject) // Similar
        // "subject= /UID=PSCLSRMK6B/CN=iPhone Developer: Hansjoachim Lunze (Q42TB976Y7)/OU=C66ZVPVD5D/O=Deutsche Telekom AG/C=DE\n"
        
        var commonName : String = "-"
        var organizationalUnit : String = "-"
        var organization : String = "-"
        
        for item in string.components(separatedBy: "/") { // Different
            let keyValue = item.split(around: "=") // Same
            if let value = keyValue.1 { // Different
                switch keyValue.0 {
                case "CN":
                    commonName = value
                case "OU":
                    organizationalUnit = value
                case "O":
                    organization = value
                default:
                    continue
                }
            }
        }
        return "\(commonName) \(organizationalUnit) \(organization)"
    }
    
    static func certificateEnddate (data: Data) throws -> Date {
        
//        if let certificate = SecCertificateCreateWithData(nil, data as CFData) {
//        
//            var error: Unmanaged<CFError>?
//        guard let dict = SecCertificateCopyValues(certificate, nil, &error) else {
//            throw error!.takeRetainedValue() as Error
//        }

        let string = self.decodeX509(data: data, info: .enddate)
        let item = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let keyValue = item.split(around: "=")
        if keyValue.0 == "notAfter", let dateString = keyValue.1 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d HH:mm:ss yyyy zzz"
            dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        throw X509Error.unableToDecodeItem
    }
    
    static func decodeX509 (data: Data, info: X509Info = .subject) -> String {
        
        var typeArgument = "-"
        switch info {
        case .subject:
            typeArgument.append("subject")
        case .text:
            typeArgument.append("text")
        case .enddate:
            typeArgument.append("enddate")
        }
        var outstr = ""
        let task = Process()
        task.launchPath = "/usr/bin/openssl"
        task.arguments = ["x509", "-noout", "-inform", "DER", typeArgument]
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
        return outstr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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


