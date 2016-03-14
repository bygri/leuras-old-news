import Foundation
import SwiftyJSON
import PathKit


enum Error: ErrorType {

  case ParseKey(url: NSURL)
  case DecodeJSON(type: Any, key: String, json: JSON)
  case URL(url: NSURL, message: String)
  case Path(path: PathKit.Path, message: String)
  case StringDataConversion(string: String?, data: NSData?)
  case Content(message: String)
  case Store(message: String)
  case Render(message: String)

}
