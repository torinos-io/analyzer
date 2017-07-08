import Foundation
import Yaml
import JSON

struct ExecutorError: Error {
    enum Code: String {
        case parseFail
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
        notImplement()
    }
}

struct XCProjectExecutor: ExecutorType {
    func handle(_ stream: String) throws -> ExecutorResult {
        notImplement()
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
            let object = value.enumerated().flatMap { (offset, element) -> [String: StructuredData]? in
                guard let key = element.key.toString() else { return nil }
                return [key: element.value.toJSON().wrapped]
            }
            return JSON(.object(object[0]))
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
