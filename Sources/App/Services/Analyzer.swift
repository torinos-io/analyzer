import Vapor
import Foundation

struct AnalyzerError: Error {
    enum Code: String {
        case unknownFileType
    }

    let code: Code
}

protocol ExecutorCreatorType {
    func create(fileType: Analyzer.FileType) -> ExecutorType
}

struct ExecutorCreator: ExecutorCreatorType {
    func create(fileType: Analyzer.FileType) -> ExecutorType {
        switch fileType {
        case .cocoapods:
            return CocoapodsExecutor()
        case .carthage:
            return CarthageExecutor()
        case .xcproject:
            return XCProjectExecutor()
        }
    }
}

final class Analyzer {
    enum FileType {
        case cocoapods
        case carthage
        case xcproject

        init(_ name: String) throws {
            switch name {
//            case "Podfile":
//                self = .cocoapods
            case "Podfile.lock":
                self = .cocoapods
//            case "Cartfile":
//                self = .carthage
            case "Cartfile.resolved":
                self = .carthage
            default:
                let url = URL(fileURLWithPath: name)
                if url.pathExtension == "pbxproj" {
                    self = .xcproject
                } else {
                    throw AnalyzerError(code: .unknownFileType)
                }
            }
        }
    }

    typealias Input = (name: String, stream: String)
    typealias Output = ExecutorResult

    static let `default` = Analyzer(factory: ExecutorCreator())

    fileprivate let executorFactory: ExecutorCreatorType

    init(factory: ExecutorCreatorType) {
        self.executorFactory = factory
    }

    func execute(input: Input) throws -> Output {
        return try executorFactory.create(fileType: try FileType(input.name)).handle(input.stream)
    }
}
