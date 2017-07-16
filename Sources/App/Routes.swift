import Vapor
import JSON

extension Droplet {
    func setupRoutes() throws {
        put("analyze") { req in
            guard let json = (req.body.bytes.flatMap { try? JSON(bytes: $0) }) else {
                return Response(status: .badRequest)
            }
            debugPrint(json)
            let inputsOrNil = json.pathIndexableObject?.map { (key, value) -> Analyzer.Input in
                    return (key, value.string ?? "")
                }
            guard let inputs = inputsOrNil else {
                return Response(status: .badRequest)
            }
            debugPrint(inputs)
            do {
                let result = try inputs.map { try Analyzer.default.execute(input: (name: $0.0, stream: $0.1)) }.flatMap { $0.json }
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
