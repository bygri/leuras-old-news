import Foundation


protocol Storable {

  static var classKey: String { get }
  var key: String { get }

}
func ==(lhs: Storable, rhs: Storable) -> Bool {
  return lhs.key == rhs.key
}


extension Article: Storable {
  static let classKey = "article"
}
extension Publication: Storable {
  static let classKey = "publication"
}
extension Tag: Storable {
  static let classKey = "tag"
}
extension YearSummary: Storable {
  static let classKey = "yearsummary"
}


private let _instance = Store()

class Store {

  private var objects: [String: Storable] = [:]

  static func instance() -> Store {
    return _instance
  }

  private init() { }

  func save(object: Storable) {
    let hash = object.dynamicType.classKey + object.key
    objects[hash] = object

  }

  func get<T:Storable>(type: T.Type, withKey key: String) throws -> T {
    let hash = type.classKey + key
    guard let object = objects[hash] as? T else {
      throw Error.Store(message: "Missing object with hash \(hash)")
    }
    return object
  }

  func all<T:Storable>(type: T.Type) -> [T] {
    return objects.values.flatMap { $0 as? T }
  }

//  func filter<T:Storable>(type: T.Type, filter: @noescape _ throws -> Bool) -> [T] {
//    return all(type).filter(filter)
//  }

}
