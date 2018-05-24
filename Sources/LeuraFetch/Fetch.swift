import Foundation
import Swiftline
import SwiftyJSON
import SWXMLHash

/**
  This fetches a Trove issue.
*/

private enum Zoom: Int {
  case Level2 = 2
  case Level4 = 4
  case Level5 = 5
  case Level6 = 6
  case Level7 = 7
  static func defaultZoom() -> Zoom {
    return Zoom.Level7
  }
}

private enum Trove {
  case Issue(id: Int)
  case Page(id: Int)
  case ImageInfo(pageId: Int)
  case ImageTile(pageId: Int, zoomLevel: Zoom, x: Int, y: Int)

  var url: String {
    switch self {
    case Issue(let id):
      return "http://trove.nla.gov.au/newspaper/issue/\(id)"
    case Page(let id):
      return "http://trove.nla.gov.au/newspaper/page/\(id)"
    case ImageInfo(let pageId):
      return "http://trove.nla.gov.au/newspaper/image/info/\(pageId)"
    case ImageTile(let pageId, let zoomLevel, let x, let y):
      return "http://trove.nla.gov.au/ndp/imageservice/nla.news-page\(pageId)/tile\(zoomLevel.rawValue)-\(x)-\(y)"
    }
  }
}

private struct Issue {
  let id: Int
  let pageIds: [Int]
  let title: String
  let dateString: String
}
private struct Page {
  let id: Int
  let issueId: Int
  let articles: [Article]
  let image: ImageInfo
}
private struct ImageInfo {
  let tileSize: Int
  let colMin: Int
  let colMax: Int
  let rowMin: Int
  let rowMax: Int
  let width: Int
  let height: Int
  let xOffset: Int
  let yOffset: Int

  func offsetForX(x: Int) -> Int {
    return x * tileSize - xOffset
  }
  func offsetForY(y: Int) -> Int {
    return y * tileSize - yOffset
  }
}
private struct Article {
  let id: Int
  let title: String
}

private func findNDPStartingUriInString(body: String) -> String {
  var startingUri: NSString?
  let scanner = NSScanner(string: body)
  scanner.scanUpToString("startingUri = \"", intoString: nil)
  scanner.scanString("startingUri = \"", intoString: nil)
  scanner.scanUpToString("\";", intoString: &startingUri)
  return startingUri as! String
}

private func fetchIssue(id: Int) -> Issue {
  /*
  This is reasonably complicated.
  1) Fetch the Issue HTML. We will be 302 Redirected to the first Page HTML.
  2) Use the first Page HTML to find out my ndp:// info uri.
  3) Use the ndp: info uri to fetch my Issue Info json.
  4) Parse the ids of each Page out of this json and return them.
  This function works but not very nicely at all.
  */
  // Get the Issue and see where we are redirected to
  // This is needed for cURL - not needed for NSURLSession.
  // let (headers, _) = URLLoad.get(Trove.Issue(id: id).url)
  // let firstPageURL = headers.filter({ $0.key == "Location" }).first!.value
  let firstPageURL = Trove.Issue(id: id).url
  // Now fetch the Page and find out what the 'startingUri' is
  let (_, body) = URLLoad.get(firstPageURL)
  let s = findNDPStartingUriInString(body)
  // Now fetch the Issue Data and find out all the Pages
  // This is the startingUri but up two levels
  var issueDataUriComponents = s.componentsSeparatedByString("/")
  issueDataUriComponents.removeLast()
  issueDataUriComponents.removeLast()
  let issueDataUri = issueDataUriComponents.joinWithSeparator("/")
  let (_, issueDataBody) = URLLoad.get("http://trove.nla.gov.au/newspaper/browse?uri="+issueDataUri)
  let json = JSON(data: issueDataBody.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
  let title = json["dc:title"].stringValue.componentsSeparatedByString(" :").first!
  let dateString = json["dc:description"].stringValue
  var pageIds: [Int] = []
  for (_, pageJson) in json["skos:narrower"] {
    let idString = pageJson["ndp:uri"].stringValue.componentsSeparatedByString("/").last!
    pageIds.append(Int(idString)!)
  }
  return Issue(id: id, pageIds: pageIds, title: title, dateString: dateString)
}

private func fetchPage(id: Int, issueId: Int) -> Page {
  /*
  1) Fetch the Page HTML. Find out my ndp: url.
  2) Fetch Article NDP json and parse the articles from it.
  3) Fetch ImageInfo. Find out image bounds and counts from it.
  4) Fetch all ImageTiles and stitch them. (in separate function)
  */
  // Fetch Page HTML
  let (_, pageBody) = URLLoad.get(Trove.Page(id: id).url)
  let articleJsonURL = findNDPStartingUriInString(pageBody)
  // Fetch Article NDP JSON
  let (_, articleJsonBody) = URLLoad.get("http://trove.nla.gov.au/newspaper/browse?uri="+articleJsonURL)
  let json = JSON(data: articleJsonBody.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
  var articles: [Article] = []
  for (_, articleJson) in json["skos:narrower"] {
    let title = articleJson["dc:title"].stringValue
    let id = articleJson["dc:description"]["id"].intValue
    articles.append(Article(id: id, title: title))
  }
  // Fetch ImageInfo.
  let (_, imageInfoBody) = URLLoad.get(Trove.ImageInfo(pageId: id).url)
  let imageInfoXML = SWXMLHash.parse(imageInfoBody)
  let levelXML = try! imageInfoXML["image"]["levels"]["level"].withAttr("id", String(Zoom.defaultZoom().rawValue))
  let imageInfo = ImageInfo(
    tileSize: Int(imageInfoXML["image"]["tilesize"].element!.text!)!,
    colMin: Int(levelXML["colmin"].element!.text!)!,
    colMax: Int(levelXML["colmax"].element!.text!)!,
    rowMin: Int(levelXML["rowmin"].element!.text!)!,
    rowMax: Int(levelXML["rowmax"].element!.text!)!,
    width: Int(levelXML["width"].element!.text!)!,
    height: Int(levelXML["height"].element!.text!)!,
    xOffset: Int(levelXML["xoffset"].element!.text!)!,
    yOffset: Int(levelXML["yoffset"].element!.text!)!
  )
  return Page(id: id, issueId: issueId, articles: articles, image: imageInfo)
}

private func saveIssueJson(issue: Issue) {
  let fm = NSFileManager.defaultManager()
  let path = "fetch/\(issue.id)/"
  try! fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
  let obj = [
    "id": issue.id,
    "pageIds": issue.pageIds,
    "title": issue.title,
    "date": issue.dateString,
  ]
  let json = try! NSJSONSerialization.dataWithJSONObject(obj, options: .PrettyPrinted)
  fm.createFileAtPath(path+"issue.json", contents: json, attributes: nil)
}

private func savePageJson(page: Page) {
  let fm = NSFileManager.defaultManager()
  let path = "fetch/\(page.issueId)/"
  try! fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
  // Save articles into JSON.
  let articles = page.articles.map { ["id": $0.id, "title": $0.title] }
  let json = try! NSJSONSerialization.dataWithJSONObject(articles, options: .PrettyPrinted)
  fm.createFileAtPath(path+"\(page.id).json", contents: json, attributes: nil)
}

private func savePageImage(page: Page) {
  // Fetch all ImageTiles and stitch them.
  // The final image will be saved in "/fetch/ISSUEID/PAGEID.jpg"
  let zoom = Zoom.defaultZoom()
  let image = page.image
  let fm = NSFileManager.defaultManager()
  let path = "fetch/\(page.issueId)/"
  try! fm.createDirectoryAtPath(path+"\(page.id)-tile/", withIntermediateDirectories: true, attributes: nil)
  // Fetch all the tiles and composite them using one big ImageMagick 'convert' operation
  var args = ["-size", "\(image.width)x\(image.height)", "canvas:white"]
  for x in image.colMin ... image.colMax {
    for y in image.rowMin ... image.rowMax {
      print(" - tile \(x),\(y)")
      let (_, tileData) = URLLoad.getData(Trove.ImageTile(pageId: page.id, zoomLevel: zoom, x: x, y: y).url)
      let tilePath = path+"\(page.id)-tile/\(zoom.rawValue)-\(x)-\(y).jpg"
      fm.createFileAtPath(tilePath, contents: tileData, attributes: nil)
      args += ["-page", "+\(image.offsetForX(x))+\(image.offsetForY(y))", tilePath]
    }
  }
  args += ["-layers", "flatten", path+"\(page.id).jpg"]
  ImageMagickTask.convert(args)
  try? fm.removeItemAtPath(path+"\(page.id)-tile")
}


public func fetch() {
  print("Leura's Old News fetcher".style.Bold.foreground.Green)
  let params = Args.parsed.parameters
  if params.count != 2 {
    print("Fail: An issue ID must be supplied.")
    exit(1)
  }
  guard let param = params.last, issueId = Int(param) where issueId > 0 else {
    print("Fail: Bad issue ID supplied.")
    exit(2)
  }
  print("Fetching issue with ID \(issueId)".style.Bold)
  let issue = fetchIssue(issueId)
  saveIssueJson(issue)
  // exit(0)
  print(" - found pages \(issue.pageIds)")
  for pageId in issue.pageIds {
    print("Page \(pageId)".style.Bold)
    let page = fetchPage(pageId, issueId: issue.id)
    savePageJson(page)
    savePageImage(page)
  }
}
