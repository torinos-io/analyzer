extension Array {
    var second: Element? {
        guard self.count >= 2 else { return nil }
        return self[1]
    }
    var third: Element? {
        guard self.count >= 3 else { return nil }
        return self[2]
    }
}

extension Array {
    func toDictionary<Key, Value>() -> [Key: Value] {
        let elements = self.flatMap { $0 as? [Key: Value] }
        guard elements.count > 0 else { return [:] }
        return elements.reduce([:], { (result, element) -> [Key: Value] in
            var newValue = [Key: Value]()
            element.enumerated().forEach {
                newValue[$1.key] = $1.value
            }
            return result.merge(newValue)
        })
    }

    func components(separatedBy f: (Element) -> Bool) -> ([Element], [Element]) {
        var a = [Element]()
        var b = [Element]()

        forEach {
            if f($0) {
                a.append($0)
            } else {
                b.append($0)
            }
        }

        return (a, b)
    }
}
