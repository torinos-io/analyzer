extension Dictionary {
    func valueMap<T>(transform: @escaping (Value) -> T) -> [Key: T] {
        var newValue = [Key: T]()
        self.forEach {
            newValue[$0.key] = transform($0.value)
        }
        return newValue
    }

    func merge(_ b: [Key: Value]) -> [Key: Value] {
        var newValue = self
        b.forEach {
            newValue[$0] = $1
        }
        return newValue
    }

    func components(separatedBy f: (Value) -> Bool) -> ([Key: Value], [Key: Value]) {
        var a = [Key: Value]()
        var b = [Key: Value]()

        forEach {
            if f($0.value) {
                a[$0.key] = $0.value
            } else {
                b[$0.key] = $0.value
            }
        }

        return (a, b)
    }
}
