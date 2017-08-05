import Foundation
import Yams
import JSON

struct ExecutorError: Error {
    enum Code: String {
        case parseFail
        case invalidFormat
        case readXmlFail
    }

    let code: Code
}

struct ExecutorResult {
    let fileType: Analyzer.FileType
    let json: JSON
}

protocol ExecutorType {
    func handle(_ stream: String) throws -> ExecutorResult
}

struct CocoapodsExecutor: ExecutorType {
    private static let key = "PODS"

    func handle(_ stream: String) throws -> ExecutorResult {
        let yamlOrNil = try { () -> Any? in
            do {
                return try Yams.load(yaml: stream)
            } catch {
                debugPrint(error)
                throw ExecutorError(code: .parseFail)
            }
        }()
        guard let yaml = yamlOrNil, let structured = try? StructuredData(foundationJSON: yaml) else {
            throw ExecutorError(code: .parseFail)
        }
        guard let json: JSON = try? JSON(structured).get(type(of: self).key) else {
            throw ExecutorError(code: .invalidFormat)
        }
        debugPrint(#file, #line, json)
        let keysOrNil: [String]? = json.array?.flatMap {
            switch $0.wrapped.foundationJSON {
            case let object as [String: Any]:
                return object.keys.first
            case let string as String:
                return string
            default:
                return nil
            }
        }
        guard let keys = keysOrNil else {
            throw ExecutorError(code: .invalidFormat)
        }
        let value: [String: StructuredData] = keys.flatMap { (key) -> [String: Any]? in
                let words = key.components(separatedBy: " ")
                debugPrint(#file, #line, key)
                guard let key = words.first else { return nil }
                guard let value = words.second else { return nil }
                return [key: removeUnnecessaryChar(value)]
            }
            .toDictionary()
            .valueMap {
                .string($0)
            }
        debugPrint(#file, #line, value)
        return ExecutorResult(fileType: .cocoapods, json: JSON(.object(value)))
    }

    func removeUnnecessaryChar(_ original: String) -> String {
        return original.replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }
}

struct CarthageExecutor: ExecutorType {
    func handle(_ stream: String) throws -> ExecutorResult {
        let lines = stream.components(separatedBy: "\n")
        let value: [String: StructuredData] = lines.flatMap { (line) -> [String: Any]? in
                let words = line.components(separatedBy: " ")
                debugPrint(#file, #line, words)
                guard let key = words.second else { return nil }
                guard let value = words.third else { return nil }
                return [removeUnnecessaryChar(key): removeUnnecessaryChar(value)]
            }
            .toDictionary()
            .valueMap {
                .string($0)
            }
        debugPrint(#file, #line, value)
        return ExecutorResult(fileType: .carthage, json: JSON(.object(value)))
    }

    func removeUnnecessaryChar(_ original: String) -> String {
        return original.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }
}

struct XCProjectExecutor: ExecutorType {
    private typealias XCObject = [String: Any]
    func handle(_ stream: String) throws -> ExecutorResult {
        guard let _ = try? DataFile().write(stream.makeBytes(), to: "/tmp/project.pbxproj") else {
            throw ExecutorError(code: .invalidFormat)
        }
        guard let url = URL(string: "/tmp/project.pbxproj") else {
            throw ExecutorError(code: .parseFail)
        }

        guard let stream = InputStream(fileAtPath: url.absoluteString) else {
            throw ExecutorError(code: .parseFail)
        }
        stream.open()
        defer { stream.close() }
        var format: PropertyListSerialization.PropertyListFormat = PropertyListSerialization.PropertyListFormat.binary
        let obj = try PropertyListSerialization.propertyList(
            with: stream,
            options: PropertyListSerialization.MutabilityOptions(),
            format: &format)
        guard let xcodeProject = obj as? XCObject else {
            throw ExecutorError(code: .parseFail)
        }

        debugPrint(#file, #line, xcodeProject)

        guard let projectId = xcodeProject["rootObject"] as? String else {
            throw ExecutorError(code: .invalidFormat)
        }
        debugPrint(#file, #line, projectId)
        guard let objects = xcodeProject["objects"] as? XCObject else {
            throw ExecutorError(code: .invalidFormat)
        }
        debugPrint(#file, #line, objects)
        guard let project = objects[projectId] as? XCObject else {
            throw ExecutorError(code: .invalidFormat)
        }
        guard let configurationListId = project["buildConfigurationList"] as? String else {
            debugPrint(#file, #line)
            throw ExecutorError(code: .invalidFormat)
        }
        debugPrint(#file, #line, configurationListId)
        guard let buildConfigurationList = objects[configurationListId] as? XCObject else {
            throw ExecutorError(code: .invalidFormat)
        }
        guard let buildConfigurations = buildConfigurationList["buildConfigurations"] as? [String] else {
            throw ExecutorError(code: .invalidFormat)
        }
        guard let releasedId = buildConfigurations.last else {
            throw ExecutorError(code: .invalidFormat)
        }
        debugPrint(#file, #line, releasedId)
        guard let buildConfiguration = objects[releasedId] as? XCObject else {
            throw ExecutorError(code: .invalidFormat)
        }
        guard let buildSettings = buildConfiguration["buildSettings"] as? XCObject else {
            throw ExecutorError(code: .invalidFormat)
        }
        guard let version = buildSettings["SWIFT_VERSION"] as? String else {
            throw ExecutorError(code: .invalidFormat)
        }
        debugPrint(#file, #line, version)

        return ExecutorResult(fileType: .xcproject, json: JSON(.object([
                "swift_version": .string(version)
            ])))
    }
}

// From: https://github.com/vapor/json/blob/master/Sources/JSON/JSON%2BParse.swift#L39
extension StructuredData {
    /// Attempt to initialize a node with a foundation object.
    ///
    /// - parameter any: the object to create a node from
    /// - throws: if fails to create node.
    internal init(foundationJSON: Any) throws {
        switch foundationJSON {
            // If we're coming from foundation, it will be an `NSNumber`.
        //This represents double, integer, and boolean.
        case let number as Double:
            // When coming from ObjC Any, this will represent all Integer types and boolean
            self = .number(Number(number))
        // Here to catch 'Any' type, but MUST come AFTER 'Double' check for JSON fuzziness
        case let bool as Bool:
            self = .bool(bool)
        case let int as Int:
            self = .number(Number(int))
        case let uint as UInt:
            self = .number(Number(uint))
        case let string as String:
            self = .string(string)
        case let object as [String : Any]:
            self = try StructuredData(foundationJSON: object)
        case let array as [Any]:
            self = try .array(array.map(StructuredData.init))
        case _ as NSNull:
            self = .null
        case let data as Data:
            self = .bytes(data.makeBytes())
        case let bytes as NSData:
            var raw = [UInt8](repeating: 0, count: bytes.length)
            bytes.getBytes(&raw, length: bytes.length)
            self = .bytes(raw)
        case let date as Date:
            self = .date(date)
        case let date as NSDate:
            let date = Date(timeIntervalSince1970: date.timeIntervalSince1970)
            self = .date(date)
        default:
            self = .null
        }
    }

    /// Initialize a node with a foundation dictionary
    /// - parameter any: the dictionary to initialize with
    internal init(foundationJSON: [String: Any]) throws {
        var mutable: [String: StructuredData] = [:]
        try foundationJSON.forEach { key, val in
            mutable[key] = try StructuredData(foundationJSON: val)
        }
        self = .object(mutable)
    }

    /// Initialize a node with a json array
    /// - parameter any: the array to initialize with
    internal init(foundationJSON: [Any]) throws {
        let array = try foundationJSON.map(StructuredData.init)
        self = .array(array)
    }

    /// Creates a FoundationJSON representation of the
    /// data for serialization w/ JSONSerialization
    internal var foundationJSON: Any {
        switch self {
        case .array(let values):
            return values.map { $0.foundationJSON }
        case .bool(let value):
            return value
        case .bytes(let bytes):
            return bytes.base64Encoded.makeString()
        case .null:
            return NSNull()
        case .number(let number):
            switch number {
            case .double(let value):
                return value
            case .int(let value):
                return value
            case .uint(let value):
                return value
            }
        case .object(let values):
            var dictionary: [String: Any] = [:]
            for (key, value) in values {
                dictionary[key] = value.foundationJSON
            }
            return dictionary
        case .string(let value):
            return value
        case .date(let date):
            let string = Date.outgoingDateFormatter.string(from: date)
            return string
        }
    }
}
