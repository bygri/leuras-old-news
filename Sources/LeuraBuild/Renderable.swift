import Foundation
import PathKit


protocol Renderable {

  var htmlPath: Path { get }
  var imageSourcePath: Path? { get }
  var imagePath: Path { get }

}


extension Article: Renderable {

  var htmlPath: Path { get {
    let dateString = DateFormatter.instance.stringFromDate(firstInsertion.date, withStyle: .ShortStyle)
    return Path("\(firstInsertion.publicationKey)/\(dateString)/\(key).html")
  } }

  var imagePath: Path { get {
    let dateString = DateFormatter.instance.stringFromDate(firstInsertion.date, withStyle: .ShortStyle)
    return Path("\(firstInsertion.publicationKey)/\(dateString)/\(key).jpg")
  } }

}


extension Publication: Renderable {

  var htmlPath: Path {
    get { return Path("\(key)/index.html") }
  }

  var imagePath: Path {
    get { return Path("\(key)/image.jpg") }
  }

}


extension Tag: Renderable {

  var htmlPath: Path {
    get { return Path("\(key).html") }
  }

  var imagePath: Path {
    get { return Path("\(key).jpg") }
  }

}

/*
extension YearSummary: Renderable {

  var htmlPath: Path {
    get { return Path("\(key)/index.html")}
  }

  var imagePath: Path {
    get { return Path("\(key)/image.jpg") }
  }

}
*/