import Vapor
import HTTP

final class AnalyzeController {
    func execute(_ request: Request) throws -> ResponseRepresentable {

        // input:
        // {
        //     "access_token": "",
        //     "target_files": {
        //         "Podfile.lock": ... ,
        //         "Carthage.resolved": ... ,
        //         "test.pbxproj": .. ,
        //     }
        // }
        typealias Parameter = (accessToken: String, targets: [Analyzer.Input])

        func input(_ request: Request) throws -> Parameter {
            guard let json = request.body.json else {
                throw ControllerError(code: .parameter)
            }
            let (accessTokenOrNil, targetFilesOrNil): (String?, JSON?) = (try? json.get("access_token"), try? json.get("target_files"))
            guard let accessToken = accessTokenOrNil, let targetFiles = targetFilesOrNil else {
                throw ControllerError(code: .parameter)
            }
            let targetsOrNil = targetFiles.pathIndexableObject?
                .map { (key, value) -> Analyzer.Input in
                    let string = value.bytes?.base64Decoded.makeString()
                    return (key, string ?? "")
                }
            guard let targets = targetsOrNil else {
                throw ControllerError(code: .parameter)
            }
            return (accessToken, targets)
        }

        do {
            let inputs = try input(request)
            let result = try inputs.targets
                .map { (input) -> Analyzer.Output in
                    return try Analyzer.default.execute(input: (name: input.name, stream: input.stream))
                }
            return JSON(appendIfNeeded(result).map { $0.json })
        } catch let error as ControllerError {
            debugPrint(#file, #line, error)
            return Response(status: .badRequest)
        } catch let error as AnalyzerError {
            debugPrint(#file, #line, error)
            return Response(status: .badRequest)
        } catch let error as ExecutorError {
            debugPrint(#file, #line, error)
            return Response(status: .badRequest)
        } catch {
            return Response(status: .internalServerError)
        }
    }

    private func appendIfNeeded(_ result: [Analyzer.Output]) -> [Analyzer.Output] {
        let result: [Analyzer.Output] = result.map {
            switch $0.fileType {
            case .cocoapods:
                return $0
            case .carthage:
                guard let (a, b) = $0.json.object?.components(separatedBy: needFetch) else {
                    return $0
                }
                let merged: [String: JSON] = a.merge(b).map {
                    [$0.key: $0.value]
                }
                .toDictionary()
                let value: [String: StructuredData] = merged.valueMap {
                    $0.wrapped
                }
                debugPrint(#file, #line, value)
                return Analyzer.Output(fileType: $0.fileType, json: JSON(.object(value)))
            case .xcproject:
                return $0
            }
        }
        return result
    }

    private func needFetch(_ json: JSON) -> Bool {
        return true
    }
}

private extension Body {
    var json: JSON? {
        return bytes.flatMap { try? JSON(bytes: $0) }
    }
}
