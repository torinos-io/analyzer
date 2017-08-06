import Vapor
import JSON

extension Droplet {
    func setupRoutes() throws {
        let analyzeController = AnalyzeController(drop: self)
        put("analyze", handler: analyzeController.execute)

        // response to requests to /info domain
        // with a description of the request
        get("info") { req in
            return req.description
        }

        get("description") { req in return req.description }
        
        try resource("posts", PostController.self)
    }
}
