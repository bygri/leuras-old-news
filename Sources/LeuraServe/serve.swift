import Foundation
import Swifter
import Swiftline
import SwiftyJSON
import PathKit

private struct Issue {
  let id: Int
  let pageIds: [Int]
  let title: String
  let dateString: String
}
private struct Article {
  let id: Int
  let title: String
}

public func serve() {
  print("Leura's Old News server".style.Bold.foreground.Green)
  let params = Args.parsed.parameters
  if params.count != 2 {
    print("Fail: An issue ID must be supplied.")
    exit(1)
  }
  guard let param = params.last, issueId = Int(param) where issueId > 0 else {
    print("Fail: Bad issue ID supplied.")
    exit(2)
  }
  print("Serving issue with ID \(issueId)".style.Bold)
  // First, let's make sure that the issue exists in the 'fetch' directory.
  let issuePath = Path("fetch/\(issueId)/")
  if !issuePath.exists {
    print("Fail: Issue path \(issuePath) does not exist.")
  }
  // Now get the Issue data
  let issue: Issue = {
    let jsonData = try! (issuePath + Path("issue.json")).read()
    let json = JSON(data: jsonData)
    let pageIds = json["pageIds"].map { $0.1.intValue }
    return Issue(id: json["id"].intValue, pageIds: pageIds,
      title: json["title"].stringValue, dateString: json["date"].stringValue)
  }()
  // Now get the list of all valid page IDs
  // Flat map so we only get page JSONs not the issue JSON
  // let pageIds = issuePath.glob("*.json").flatMap { Int($0.lastComponentWithoutExtension) }
  let pageIds = issue.pageIds

  // Prepare the server
  let server = HttpServer()
  let port: UInt16 = 8080
  try! server.start(port)

  /*** View definitions ***/

  // Root - list available pages
  server["/"] = { request in
    var htmlString = "<html><head></head><body><h1>Pages in issue \(issueId)</h1><ul>"
    for id in pageIds {
      htmlString += "<li><a href='/page/\(id)'>\(id)</a></li>"
    }
    htmlString += "</ul></body></html>"
    return .OK(.Html(htmlString))
  }

  // Page - show images and list articles
  server["/page/:pageId"] = { request in
    guard let
      string = request.params[":pageId"],
      pageId = Int(string) where pageIds.contains(pageId) else
    {
      return .OK(.Html("Bad page id. Params: \(request.params)"))
    }

    // Load the article JSON
    let jsonData = try! (issuePath + Path("\(pageId).json")).read()
    let articleJson = JSON(data: jsonData)
    let articles = articleJson.map {
      Article(id: $0.1["id"].intValue, title: $0.1["title"].stringValue)
    }
    // Here we go with the HTML
    var htmlString = "<html><head><meta name='viewport' content='width=device-width, initial-scale=1, , maximum-scale=1, user-scalable=no'>"
    htmlString += "<script src='/static/js/jquery.min.js'></script>"
    htmlString += "<script src='/static/js/jquery.Jcrop.min.js'></script>"
    htmlString += "<script src='/static/js/serve.js'></script>"
    htmlString += "<link rel='stylesheet' href='/static/css/serve.css'>"
    htmlString += "<link rel='stylesheet' href='/static/css/jquery.Jcrop.css'>"
    htmlString += "</head><body>\n"

    // Sidebar
    htmlString += "<div class='sidebar'>\n"
    htmlString += "  <ul class='sidebar-list'>\n"

    // Heading
    htmlString += "  <li class='item header'>\n"
    htmlString += "    <strong>Katoomba Times</strong><br>\n"
    htmlString += "    \(issue.dateString) &mdash; Page 3\n"
    htmlString += "  </li>\n"

    // Articles list
    for article in articles {
      htmlString += "  <li class='item article beginCrop' data-id='\(article.id)'>\n"
      htmlString += "    \(article.title)\n"
      htmlString += "  </li>\n"
    }

    // Crop mode controls
    htmlString += "  <li class='item article-header header'><strong>ARTICLE-NAME</strong></li>\n"
    htmlString += "  <li class='item' id='cropRegions'>No regions defined</li>\n"
    htmlString += "  <li class='item button' id='pauseButton'>PAUSE</li>\n"
    htmlString += "  <li class='item button' id='resumeButton'>RESUME</li>\n"
    htmlString += "  <li class='item button' id='cancelButton' style='color: red'>CANCEL</li>\n"
    htmlString += "  <li class='item button' id='addCropRegionButton'>ADD CROP REGION</li>\n"
    htmlString += "  <li class='item button' id='finishButton'>FINALISE</li>\n"

    // End sidebar
    htmlString += "  </ul>\n"
    htmlString += "</div>\n"

    // Image
    htmlString += "<div class='article-image'>\n"
    htmlString += "  <img src='/image/\(pageId).jpg' id='pageImage'>\n"
    htmlString += "</div>\n"

    htmlString += "</body></html>"
    return .OK(.Html(htmlString))
  }

  // Image - serve image files directly
  server["/image/:path"] = HttpHandlers.directory(String(issuePath))

  // Static - serve static files
  server["/static/:path"] = HttpHandlers.directory("resources/static/")

  // Start server
  print(" - server running on port \(port)")
  print(" - use Ctrl-C to close")
  NSRunLoop.mainRunLoop().run()
}
