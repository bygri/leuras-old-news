import Foundation


protocol Routable {
  var url: String { get }
  var imageURL: String? { get }
}


extension Article: Routable {

  var url: String { get {
    return "/" + htmlPath.description
  } }

  var imageURL: String? { get {
    if imageSourcePath == nil { return nil }
    return "/" + imagePath.description
  } }

}


extension Publication: Routable {

  var url: String { get {
    return "/\(key)/"
  } }

  var imageURL: String? { get {
    if imageSourcePath == nil { return nil }
    return "/\(key)/image.jpg"
  } }

}


extension Tag: Routable {

  var url: String { get {
    return "/\(key).html"
  } }

  var imageURL: String? { get {
    if imageSourcePath == nil { return nil }
    return "/\(key).jpg"
  } }

}


extension YearSummary: Routable {

  var url: String { get {
    return "/\(key)/"
  } }

  var imageURL: String? { get {
    if imageSourcePath == nil { return nil }
    return "/\(key)/image.jpg"
  } }

}
