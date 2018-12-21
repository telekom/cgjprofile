import Foundation
import Security
import Utility

public struct Mobileprovision {
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
}

public class PrettyProvision {

    var mobileprovision : Mobileprovision
    
    public var formatter : DateFormatter = { let new = DateFormatter(); new.dateStyle = .short; new.timeStyle = .short; return new}()
    
    
    required public init(_ mobileprovision : Mobileprovision) {
        self.mobileprovision = mobileprovision
    }
    
    // Again: No clue why I must specify Foundation
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
            let decodedProvision = try cgjprofileTool.decodeCMS(data:data)
            let plist = try cgjprofileTool.decodePlist (data: decodedProvision)
            if let mobileprovision = Mobileprovision(plist) {
                self.init (mobileprovision)
            }
            else {
                return nil
            }
        }
        catch {
            return nil
        }
    }
    
    public func print(format: String = "%u %t %N") {

        fputs (parsedOutput(format)+"\n", stdout)
    }

    public func parsedOutput(_ format : String) -> String {
        var output = ""
        var index = format.startIndex
        while (index < format.endIndex) {
            var result : String
            (result, index) = parseNonFormatString(fromString: format, startIndex: index)
            output.append(result)
            guard index < format.endIndex else {
                break
            }
            (result, index) = parseFormat(fromString: format, startIndex:index)
            output.append(result)
        }
        return output
    }
    
    func parseNonFormatString(fromString string : String, startIndex : String.Index) -> (String, String.Index) {
        var index = startIndex
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
    
    func parseFormat(fromString string : String, startIndex : String.Index) -> (String, String.Index) {
        var index = startIndex
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
            index = string.index(after: index)
            return ("%", index)
        }
        else {
            var number : Int = 0
            (number, index) = parseInteger(fromString: string, startIndex: index)
            guard index < string.endIndex else {
                return ("", index)
            }
            input = string[index]
            var value = self.value(forFormat: input)
            if number > value.count {
                let padding = number - value.count
                for _ in 0 ..< padding {
                    value.append(" ")
                }
            }
            index = string.index(after: index)
            return (value, index)
        }
    }

    func value(forFormat input: Character) -> String {
        switch input {
        case "e":
            return formatter.string(from: mobileprovision.ExpirationDate)
        case "c":
            return formatter.string(from: mobileprovision.CreationDate)
        case "u":
            return mobileprovision.UUID
        case "a":
            return mobileprovision.AppIDName
        case "t":
            return mobileprovision.TeamName
        case "n":
            return mobileprovision.Name
        default:
            return ""
        }
    }
    
    func parseInteger(fromString string : String, startIndex : String.Index) -> (Int, String.Index) {
        var numberString : String = ""
        var index = startIndex
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
        self.arguments = Array(arguments.dropFirst()) // Don't include the command name
    }
    
    // No clue why I have to specify Foundation here
    func workingURLs (paths : [String]? = nil) -> [Foundation.URL] {
        if let paths = paths {
            return paths.map {
                URL(fileURLWithPath: $0)
            }
        }
        else {
            let fm = FileManager.default
            let librayURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            let profilesURL = librayURL.appendingPathComponent("MobileDevice/Provisioning Profiles")
            return try! FileManager.default.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        }
    }
    
    public func run() throws {
        let parser = ArgumentParser(usage: "[--format=\"format string\" [path]", overview: "Lists all mobileprovision files, or a single one")
        
        let formatOption: OptionArgument<String> = parser.add(option: "--format", shortName: "-f", kind: String.self, usage: "Optional format String\n      %e  ExpirationDate\n      %c  CreationDate\n      %u  UUID\n      %a  AppIDName\n      %t  TeamName\n      %n  Name")

        let pathsOption = parser.add(positional: "path", kind: [String].self, optional:true, usage:"Optional paths to mobileprovision files")

        let parsedArguments = try parser.parse(arguments)
        
        let workingPaths = workingURLs(paths: parsedArguments.get(pathsOption))
        var format : String!
        format = parsedArguments.get(formatOption)
        if format == nil {
            format = "%u %t %n"
        }
        
        for url in workingPaths {
            if let provision = PrettyProvision(url: url) {
                provision.print(format: format)
            }
            else {
                let output = "Error decoding \(url)"
                fputs(output, stderr)
            }
        }
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

