import Vapor
import JSON

extension Droplet {
    func setupRoutes() throws {
        // input:
        // {
        //     "access_token": "",
        //     "target_files": {
        //         "Podfile.lock": ... ,
        //         "Carthage.resolved": ... ,
        //         "test.pbxproj": .. ,
        //     }
        // }
        put("analyze") { req in
            guard let json = (req.body.bytes.flatMap { try? JSON(bytes: $0) }) else {
                return Response(status: .badRequest)
            }
            debugPrint(json)
            guard let accessToken: String = try? json.get("access_token") else {
                return Response(status: .badRequest)
            }
            guard let targetFiles: JSON = try? json.get("target_files") else {
                return Response(status: .badRequest)
            }
            let inputsOrNil = targetFiles.pathIndexableObject?.map { (key, value) -> Analyzer.Input in
                    return (key, value.string ?? "")
                }
            guard let inputs = inputsOrNil else {
                return Response(status: .badRequest)
            }
            do {
                let result = try inputs.map { (input) -> Analyzer.Output in
                        debugPrint(#file, #line, input.name)
                        return try Analyzer.default.execute(input: (name: input.name, stream: input.stream))
                    }
                    .flatMap { $0.json }
                return JSON(result)
            } catch {
                guard let error = error as? AnalyzerError else {
                    return Response(status: .internalServerError)
                }
                switch error.code {
                case .unknownFileType:
                    return Response(status: .badRequest)
                }
            }
        }

        // response to requests to /info domain
        // with a description of the request
        get("info") { req in
            return req.description
        }

        get("description") { req in return req.description }
        
        try resource("posts", PostController.self)
    }
}
