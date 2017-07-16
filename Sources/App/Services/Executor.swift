import Foundation
import Yams
import JSON
import AEXML

struct ExecutorError: Error {
    enum Code: String {
        case parseFail
        case invalidFormat
        case readXmlFail
    }

    let code: Code
}

struct ExecutorResult {
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
        do {
            let json: JSON = try JSON(structured).get(type(of: self).key)
            debugPrint(#file, #line, json)
            return ExecutorResult(json: json)
        } catch {
            throw ExecutorError(code: .invalidFormat)
        }
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
                return [key: value]
            }
            .toDictionary()
            .valueMap {
                .string($0)
            }
        debugPrint(#file, #line, value)
        return ExecutorResult(json: JSON(.object(value)))
    }
}

struct XCProjectExecutor: ExecutorType {
    func handle(_ stream: String) throws -> ExecutorResult {
        let xml = try { () -> AEXMLDocument in
            do {
                return try AEXMLDocument(xml: stream)
            } catch {
                debugPrint(error)
                throw ExecutorError(code: .readXmlFail)
            }
        }()
        debugPrint(#file, #line, xml)

        // TODO: get swift version from project file

        return ExecutorResult(json: JSON(.object([
                "swift_version": .number(.double(2.3))
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

private extension Array {
    var second: Element? {
        guard self.count > 2 else { return nil }
        return self[1]
    }
    var third: Element? {
        guard self.count > 3 else { return nil }
        return self[2]
    }
}

private extension Array {
    func toDictionary<Key, Value>() -> [Key: Value] {
        let elements = self.flatMap { $0 as? [Key: Value] }
        guard elements.count > 0 else { return [:] }
        return elements.reduce([:], { (result, element) -> [Key: Value] in
            var newValue = [Key: Value]()
            element.enumerated().forEach {
                newValue[$1.key] = $1.value
            }
            return result.merge(newValue)
        })
    }
}

private extension Dictionary {
    func valueMap<T>(transform: @escaping (Value) -> T) -> [Key: T] {
        var newValue = [Key: T]()
        self.forEach {
            newValue[$0.key] = transform($0.value)
        }
        return newValue
    }

    func merge(_ b: [Key: Value]) -> [Key: Value] {
        var newValue = self
        b.forEach {
            newValue[$0] = $1
        }
        return newValue
    }
}
