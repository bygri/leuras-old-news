import Foundation
import SwiftyJSON
import PathKit


/**
  This object may be imported from the filesystem.
*/
protocol Importable {

  init(key: String, json: JSON, body: String?, imagePath: Path?) throws

}


extension Article: Importable {
  init(key: String, json: JSON, body: String?, imagePath: Path?) throws {
    self.key = key
    self.fullText = body
    self.imageSourcePath = imagePath
    guard let
      title = json["title"].string,
      categoryString = json["category"].string,
      category = Category(rawValue: categoryString),
      dateUpdatedString = json["date_updated"].string,
      dateUpdated = DateFormatter.instance.dateFromString(dateUpdatedString),
      precis = json["precis"].string
    else {
      throw Error.DecodeJSON(type: self.dynamicType, key: key, json: json)
    }
    self.title = title
    self.category = category
    self.precis = precis
    self.dateUpdated = dateUpdated
    self.tagKeys = json["tags"].map { $1.stringValue }
    self.insertions = try json["insertions"].map { try Insertion(json: $1) }
    self.firstInsertion = self.insertions.sort({ $0.date.timeIntervalSinceReferenceDate < $1.date.timeIntervalSinceReferenceDate }).first!
  }
}

extension Publication: Importable {

  init(key: String, json: JSON, body: String?, imagePath: Path?) throws {
    self.key = key
    guard let
      title = json["title"].string
    else {
      throw Error.DecodeJSON(type: self.dynamicType, key: key, json: json)
    }
    self.title = title
    self.imageSourcePath = imagePath
  }

}

extension Tag: Importable {

  init(key: String, json: JSON, body: String?, imagePath: Path?) throws {
    self.key = key
    guard let
      title = json["title"].string,
      categoryString = json["category"].string,
      category = Category(rawValue: categoryString)
    else { throw Error.DecodeJSON(type: self.dynamicType, key: key, json: json) }
    self.title = title
    self.category = category
    self.precis = json["precis"].string
    self.comment = body
    self.imageSourcePath = imagePath
  }

}

extension YearSummary: Importable {

  init(key: String, json: JSON, body: String?, imagePath: Path?) throws {
    self.key = key
    guard let year = Int(key) else { throw Error.Content(message: "Year key is not an Int") }
    self.year = year
    self.imageSourcePath = imagePath
    guard let body = body else { throw Error.Content(message: "No body for year") }
    self.body = body
  }

}


extension Importable {

  static func importAllFromDirectory(path: Path, withExtension ext: String) throws -> [Self] {
    if !path.exists { throw Error.Path(path: path.absolute(), message: "Path does not exist") }
    let paths = path.filter { $0.`extension` == ext }
    return try paths.map { try importFileFromPath($0) }
  }

  static func importFileFromPath(path: Path) throws -> Self {
    // Key: get the filename, without the ".json" extension.
    let key = path.lastComponentWithoutExtension
    // Image path: get the full path, remove ".json", add ".jpg" and check if exists.
    var imagePath: Path? = path.parent() + "\(key).jpg"
    if !imagePath!.exists { imagePath = nil }
    // Parse file contents
    let (json, body) = try parseJsonIshData(try path.read())
    return try self.init(key: key, json: json, body: body, imagePath: imagePath)
  }

  static func parseJsonIshData(data: NSData) throws -> (json: JSON, body: String?) {
    // Convert to a String and get a Scanner
    guard let string = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else { throw Error.StringDataConversion(string: nil, data: data) }
    let scanner = NSScanner(string: string)
    var jsonString: NSString? = ""
    var body: String?
    // First, pull out JSON, which will always be present
    scanner.scanUpToString("----", intoString: &jsonString)
    guard let jsonData = jsonString?.dataUsingEncoding(NSUTF8StringEncoding) else { throw Error.StringDataConversion(string: jsonString as? String, data: nil) }
    // If there is more to the string, then scan the Body too
    if !scanner.atEnd {
      var bodyString: NSString? = ""
      scanner.scanString("----", intoString: nil)
      scanner.scanUpToString("", intoString: &bodyString) // this will scan to end
      body = bodyString as? String
    }
    return (JSON(data: jsonData), body)
  }

}
