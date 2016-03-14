import Foundation

/*
 There's no simple farking Markdown processor in Swift at the moment so this'll cover us until there is.

 Things to implement:
 - Strip newlines unless they are paragraph breaks
 - # to <h1>
 - ## to <h2>
 - > to <blockquote>-p
 - Unprefixed blocks to <p>
 - **xxx** inside blocks to <strong> and </strong>

 let md = Farkdown(string:"# Hello Markdown")
 let document = md.document()
 print(document)
*/

public class Farkdown {

  internal let string: String

  public init(string: String) {
    self.string = string
  }

  public func document() -> String {
    // Convert to a series of paragraphs.
    var paragraphs = string.componentsSeparatedByString("\n\n")
    // Now add surrounding HTML tags
    paragraphs = paragraphs.map {
      if $0.hasPrefix("##") {
        return "<h2>" + $0.substringFromIndex($0.startIndex.advancedBy(3)).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) + "</h2>"
      } else if $0.hasPrefix("#") {
        return "<h1>" + $0.substringFromIndex($0.startIndex.advancedBy(2)).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) + "</h1>"
      } else if $0.hasPrefix("> ") {
        // strip "> " from beginning of each line
        let s = $0.substringFromIndex($0.startIndex.advancedBy(2)).stringByReplacingOccurrencesOfString("\n> ", withString: "\n")
        return "<blockquote><p>" + s.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) + "</p></blockquote>"
      }
      return "<p>" + $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) + "</p>"
    }
    // Bolding things between **
    paragraphs = paragraphs.map {
      var paragraph: String = ""
      var outString: NSString?
      let scanner = NSScanner(string: $0)

      while true {
        // Look for first **, storing what we find as we go
        scanner.scanUpToString("**", intoString: &outString)
        scanner.scanString("**", intoString: nil)
        paragraph += outString as! String
        outString = ""
        // If we are at end of string, return what we've got.
        if scanner.atEnd {
          return paragraph
        }
        // We have now entered STRONG territory.
        paragraph += "<strong>"
        // Look for next **, storing what we find as we go
        scanner.scanUpToString("**", intoString: &outString)
        scanner.scanString("**", intoString: nil)
        paragraph += outString as! String
        outString = ""
        // If we are at end of string, return what we've got.
        if scanner.atEnd {
          return paragraph
        }
        // We have now left STRONG territory.
        paragraph += "</strong>"
      }
    }
    // Recombine it all
    return paragraphs.joinWithSeparator("\n")
  }

}
