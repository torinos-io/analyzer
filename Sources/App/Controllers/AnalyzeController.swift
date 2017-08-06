import Vapor
import HTTP
import App

final class AnalyzeController {
    fileprivate let drop: Droplet
    init(drop: Droplet) {
        self.drop = drop
    }

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
                let fetched: [Analyzer.Output] = a.map { fetchFromGithub(repo: $0.key) }.map {
                        $0.flatMap { try? Analyzer.default.execute(input: Analyzer.Input(name: $0.name, stream: $0.stream)) }
                    }
                    .reduce([], { (result, value) -> [Analyzer.Output] in
                        result + value
                    })
                debugPrint(#file, #line, fetched)
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

    private func fetchFromGithub(repo: String) -> [(name: String, stream: String)] {
        debugPrint(#file, #line, repo)
        guard let projectName = repo.components(separatedBy: "/").second else { return [] }
        var result = [(name: String, stream: String)]()
        if let cocoapods = try? drop.client.get("https://raw.githubusercontent.com/\(repo)/master/Podfile.lock") {
            debugPrint(#file, #line, cocoapods.status)
            if cocoapods.status == .ok {
                result.append((name: "Podfile.lock", stream: cocoapods.body.bytes?.makeString() ?? ""))
            }
        }
        if let carthage = try? drop.client.get("https://raw.githubusercontent.com/\(repo)/master/Cartfile.resolved") {
            debugPrint(#file, #line, carthage.status)
            if carthage.status == .ok {
                result.append((name: "Cartfile.resolved", stream: carthage.body.bytes?.makeString() ?? ""))
            }
        }
        if let project = try? drop.client.get("https://raw.githubusercontent.com/\(repo)/master/\(projectName).xcodeproj/project.pbxproj") {
            debugPrint(#file, #line, project.status)
            if project.status == .ok {
                result.append((name: "project.pbxproj", stream: project.body.bytes?.makeString() ?? ""))
            }
        }
        return result
    }
}

private extension Body {
    var json: JSON? {
        return bytes.flatMap { try? JSON(bytes: $0) }
    }
}
