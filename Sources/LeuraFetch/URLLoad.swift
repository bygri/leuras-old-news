import Foundation

/* This is only going to work on OSX */

class URLLoad {

  struct Header {
    let key: String
    let value: String
  }

  static func get(url: String) -> (headers: [Header], body: String) {
    let (headers, data) = getData(url)
    guard let body = NSString(data: data, encoding: NSUTF8StringEncoding) else {
      print("Error")
      return (headers: [], body: "")
    }
    return (headers: headers, body: body as String)
  }

  static func getData(url: String) -> (headers: [Header], body: NSData) {
    let session = NSURLSession.sharedSession()
    var complete: Bool = false
    var headers: [Header] = []
    var body: NSData! = nil
    let task = session.dataTaskWithURL(NSURL(string: url)!) { data, response, error in
      guard let response = response as? NSHTTPURLResponse, data = data else {
        print("Error: \(error)")
        complete = true
        return
      }
      body = data
      for (key, value) in response.allHeaderFields {
        headers.append(Header(key: key as! String, value: value as! String))
      }
      complete = true
    }
    task.resume()
    while !complete {}
    return (headers: headers, body: body)
  }

}
