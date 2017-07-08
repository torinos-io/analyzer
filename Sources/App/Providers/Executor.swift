import Foundation
import Yaml

struct ExecutorError: Error {
    enum Code: String {
        case parseFail
    }

    let code: Code
}

struct ExecutorResult {
    let raw: [String: Any]
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

        let dependencies = hash.dictionary

        return ExecutorResult()
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
