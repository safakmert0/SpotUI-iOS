import Foundation

/// Simple singleton DI container. Register and resolve dependencies by type.
final class Container {
    static let shared = Container()

    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]
    private let lock = NSLock()

    private init() {}

    func register<T>(_ type: T.Type, _ factory: @autoclosure @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        factories[key] = factory
        lock.unlock()
    }

    func register<T>(_ type: T.Type, singleton: @autoclosure @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        factories[key] = { [weak self] in
            guard let self else { return singleton() }
            let s = singleton()
            self.singletons[key] = s
            self.factories[key] = { s }
            return s
        }
        lock.unlock()
    }

    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        if let existing = singletons[key] as? T { return existing }
        guard let factory = factories[key] else {
            fatalError("No registration for \(key)")
        }
        return factory() as! T
    }
}

@propertyWrapper
struct Inject<T> {
    let wrappedValue: T

    init() {
        self.wrappedValue = Container.shared.resolve(T.self)
    }
}
