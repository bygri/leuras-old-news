import Foundation
import SwiftyJSON
import PathKit


struct Article {

  enum Category: String {
    case Jottings = "Jottings"
    case Article = "Article"
    case Advertising = "Advertising"
    case Letter = "Letter"
    case Official = "Official"
    case Editorial = "Editorial"
  }

  let key: String
  let title: String
  let imageSourcePath: Path?
  let category: Category
  let dateUpdated: NSDate
  let precis: String
  let tagKeys: [String]
  let insertions: [Insertion]
  let firstInsertion: Insertion
  let fullText: String?

  struct Insertion {

    let date: NSDate
    let publicationKey: String
    let page: Int
    let troveId: Int

    init(json: JSON) throws {
      guard let
        dateString = json["date"].string,
        date = DateFormatter.instance.dateFromString(dateString),
        publicationKey = json["publication"].string,
        page = json["page"].int,
        troveId = json["trove_id"].int
      else {
        throw Error.DecodeJSON(type: self.dynamicType, key: "nil", json: json)
      }
      self.date = date
      self.publicationKey = publicationKey
      // check it exists
      try Store.instance().get(Publication.self, withKey: publicationKey)
      self.page = page
      self.troveId = troveId
    }

  }

}
extension Article.Insertion: Equatable { }
func ==(lhs: Article.Insertion, rhs: Article.Insertion) -> Bool {
  return lhs.date == rhs.date && lhs.publicationKey == rhs.publicationKey && lhs.page == rhs.page
}


struct Publication {

  let key: String
  let title: String
  let imageSourcePath: Path?

}


struct Tag {

  enum Category: String {
    case Place = "Place"
    case Person = "Person"
    case Event = "Event"
    case Business = "Business"
    case Group = "Group"
    case Other = "Other"
  }

  let key: String
  let title: String
  let imageSourcePath: Path?
  let category: Category
  let precis: String?
  let comment: String?

}


struct YearSummary {

  let key: String
  let year: Int
  let body: String
  let imageSourcePath: Path?

}
