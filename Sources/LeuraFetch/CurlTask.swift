import Foundation

class CurlTask {

  struct Header {
    let key: String
    let value: String
  }

  private static func parseOutput(data: NSData) -> (headers: [Header], body: String) {
    // Normalise newlines in the response
    let response = NSString(data: data, encoding: NSUTF8StringEncoding)!.stringByReplacingOccurrencesOfString("\r\n", withString: "\n")
    // Split by double-newline, so the first element is the header, and all subsequent elements are body
    var components = response.componentsSeparatedByString("\n\n")
    // Remove the header and split it into lines
    var headerLines = components.removeFirst().componentsSeparatedByString("\n")
    // Header block: first line is the HTTP line
    let httpLine = headerLines.removeFirst()
    // All subsequent lines should be split by ": " to get header key and value
    let headers = headerLines.map({ $0.componentsSeparatedByString(": ") }).map({ Header(key: $0.first!, value: $0.last!) })
    // Now whatever remains of components is the body
    let body = components.joinWithSeparator("\n\n")
    return (headers: headers, body: body)
  }

  static func get(url: String) -> (headers: [Header], body: String) {
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = "/usr/bin/curl"
    task.arguments = ["-i", url]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let output = parseOutput(pipe.fileHandleForReading.readDataToEndOfFile())
    return output
  }

}
