import Foundation
import Security

extension String {
    func safeStartIndex (index : String.Index?) -> String.Index {
        if let index = index {
            return index
        }
        else {
            return self.startIndex
        }
    }
}

public struct Mobileprovision {
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
    
    func prettyPrint(format: String = "%u %T %N") {
        
        var (output, index) = parseNonFormatString(fromString: format)
        fputs(output, stdout)
        var input = format[index]
        if input == "%" {
            fputs ("%", stdout)
        }
        else {
            let (number, index) = parseInteger(fromString: format, startIndex: index)
            guard index < format.endIndex else {
                return
            }
            input = format[index]
            switch input {
            case "u":
                fputs (self.UUID, stdout)
            default:
                break
            }
        }
    }
    
    func parseNonFormatString(fromString string : String, startIndex : String.Index? = nil) -> (String, String.Index) {
        var index = string.safeStartIndex(index: startIndex)
        var output = "";

        guard index < string.endIndex else {
            return (output, index)
        }
        var input = string[index]
        while input != "%" {
            output.append(input)
            index = string.index(after: index)
            guard index < string.endIndex else {
                break
            }
            input = string[index]
        }
        return (output, index)
    }
    
    func parseFormat(fromString string : String, startIndex : String.Index? = nil) -> (String, String.Index) {
        var index = string.safeStartIndex(index: startIndex)
        guard index < string.endIndex else {
            return ("", index)
        }
        var input = string[index]
        guard input == "%" else {
            return ("", index)
        }
        index = string.index(after: index)
        guard index < string.endIndex else {
            return ("", index)
        }
        input = string[index]

        if input == "%" {
            return ("%", index)
        }
        else {
            return ("noimp", index)
        }
    }
    
    func parseInteger(fromString string : String, startIndex : String.Index? = nil) -> (Int, String.Index) {
        var numberString : String = ""
        var index = string.safeStartIndex(index: startIndex)
        guard index < string.endIndex else {
            return (0, index)
        }
        var input = string[index]
        while "0123456789".contains(input) {
            numberString.append(input)
            index = string.index(after: index)
            guard index < string.endIndex else {
                break
            }
            input = string[index]
        }
        let number = Int(numberString)
        return (number ?? 0, index)
    }
}

public final class cgjprofileTool {
    private let arguments: [String]

    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = arguments
    }

    public func run() throws {
        print("Hello world")
    }
    
    enum CMSError : Error {
        case create
        case update
        case finalize
        case copyContent
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

