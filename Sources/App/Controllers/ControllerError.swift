struct ControllerError: Error {
    enum Code: String {
        case parameter
    }

    let code: Code
}
