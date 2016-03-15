import Foundation
import Swiftline
import SwiftyJSON

/**
  This fetches a Trove article.
*/

enum Zoom: Int {
  case Level4 = 4
  case Level5 = 5
  case Level6 = 6
  case Level7 = 7
}

enum Trove {
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

struct Issue {
  let id: Int
  let pageIds: [Int]
}
struct Page {
  let id: Int
  // let startingUri: String
}

func findNDPStartingUriInString(body: String) -> String {
  var startingUri: NSString?
  let scanner = NSScanner(string: body)
  scanner.scanUpToString("startingUri = \"", intoString: nil)
  scanner.scanString("startingUri = \"", intoString: nil)
  scanner.scanUpToString("\";", intoString: &startingUri)
  return startingUri as! String
}

// func fetchPage(id: Int) -> Page {
  // let (_, body) = CurlTask.get(firstPageURL)
  // let s = findNDPStartingUriInString(body)
  // return Page(id: id, startingUri: s)
// }

func fetchIssue(id: Int) -> Issue {
  // mockup bit
  // return Issue(id: 1881662, pageIds: [21704646, 21704647, 21704648, 21704649])
  /*
  This is reasonably complicated.
  1) Fetch the Issue HTML. We will be 302 Redirected to the first Page HTML.
  2) Use the first Page HTML to find out my ndp:// info uri.
  3) Use the ndp:// info uri to fetch my Issue Info json.
  4) Parse the ids of each Page out of this json and return them.
  This function works but not very nicely at all.
  */
  // Get the Issue and see where we are redirected to
  let (headers, _) = CurlTask.get(Trove.Issue(id: id).url)
  let firstPageURL = headers.filter({ $0.key == "Location" }).first!.value
  // Now fetch the Page and find out what the 'startingUri' is
  let (_, body) = CurlTask.get(firstPageURL)
  let s = findNDPStartingUriInString(body)
  // Now fetch the Issue Data and find out all the Pages
  // This is the startingUri but up two levels
  var issueDataUriComponents = s.componentsSeparatedByString("/")
  issueDataUriComponents.removeLast()
  issueDataUriComponents.removeLast()
  let issueDataUri = issueDataUriComponents.joinWithSeparator("/")
  let (_, issueDataBody) = CurlTask.get("http://trove.nla.gov.au/newspaper/browse?uri="+issueDataUri)
  let json = JSON(data: issueDataBody.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
  var pageIds: [Int] = []
  for (_, pageJson) in json["skos:narrower"] {
    let idString = pageJson["ndp:uri"].stringValue.componentsSeparatedByString("/").last!
    pageIds.append(Int(idString)!)
  }
  return Issue(id: id, pageIds: pageIds)
}

func fetchPage(id: Int) -> Page {
  /*
  1) Fetch the Page HTML. Find out my ndp:// url.
  2) Fetch Article NDP json and parse the articles from it.
  3) Fetch ImageInfo. Find out image bounds and counts from it.
  4) Fetch all ImageTiles and stitch them.
  */

  return Page(id: id)
}


public func fetch() {
  print("Leura's Old News fetcher".style.Bold.foreground.Green)
  print("Fetching issue with ID \(1881662)")
  let issue = fetchIssue(1881662)
  print("Pages for issue \(issue.id) are \(issue.pageIds)")
  for pageId in issue.pageIds {
    fetchPage(pageId)
  }
}
