import Foundation
import Yaml
import JSON
import AEXML

struct ExecutorError: Error {
    enum Code: String {
        case parseFail
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
        let hash = try { () -> Yaml in
            do {
                return try Yaml.load(stream)
            } catch {
                debugPrint(error)
                throw ExecutorError(code: .parseFail)
            }
        }()

        let json = hash.toJSON()
        debugPrint(json)

        return ExecutorResult(json: json)
    }
}

struct CarthageExecutor: ExecutorType {
    func handle(_ stream: String) throws -> ExecutorResult {
        let lines = stream.components(separatedBy: "\n")
        let value: [String: StructuredData] = lines.flatMap { (line) -> [String: Any]? in
                let words = line.components(separatedBy: " ")
                guard let key = words.second else { return nil }
                guard let value = words.third else { return nil }
                return [key: value]
            }
            .toDictionary()
            .valueMap {
                .string($0)
            }
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
        debugPrint(xml)

        // TODO: get swift version from project file

        return ExecutorResult(json: JSON(.object([
                "swift_version": .number(.double(2.3))
            ])))
    }
}

private extension Yaml {
    func toJSON() -> JSON {
        switch self {
        case .null:
            return JSON(.null)
        case .bool(let value):
            return JSON(.bool(value))
        case .int(let value):
            return JSON(.number(.int(value)))
        case .double(let value):
            return JSON(.number(.double(value)))
        case .string(let value):
            return JSON(.string(value))
        case .array(let value):
            return JSON(.array(value.map { $0.toJSON().wrapped }))
        case .dictionary(let value):
            let object: [String: StructuredData] = value
                .enumerated()
                .flatMap { (offset, element) -> [String: StructuredData]? in
                    guard let key = element.key.toString() else { return nil }
                    return [key: element.value.toJSON().wrapped]
                }
                .toDictionary()
            return JSON(.object(object))
        }
    }

    func toString() -> String? {
        switch self {
        case .null:
            return nil
        case .bool(let value):
            return value.string
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .string(let value):
            return value
        case .array(_):
            return nil
        case .dictionary(_):
            return nil
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
