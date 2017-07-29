import Vapor
import HTTP

final class AnalyzeController {
    func execute(_ request: Request) throws -> ResponseRepresentable {
        guard let json = (request.body.bytes.flatMap { try? JSON(bytes: $0) }) else {
            return Response(status: .badRequest)
        }
        guard let accessToken: String = try? json.get("access_token") else {
            return Response(status: .badRequest)
        }
        guard let targetFiles: JSON = try? json.get("target_files") else {
            return Response(status: .badRequest)
        }
        let inputsOrNil = targetFiles.pathIndexableObject?.map { (key, value) -> Analyzer.Input in
            let string = value.bytes?.base64Decoded.makeString()
                return (key, string ?? "")
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
            return self.handlError(error)
        }
    }

    private func handlError(_ error: Error) -> Response {
        switch error {
        case let error as AnalyzerError:
            debugPrint(#file, #line, error)
            return Response(status: .badRequest)
        case let error as ExecutorError:
            debugPrint(#file, #line, error)
            return Response(status: .badRequest)
        default:
            return Response(status: .internalServerError)
        }
    }
}
