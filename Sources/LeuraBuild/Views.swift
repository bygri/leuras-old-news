import Foundation
import PathKit
import Stencil
import Farkdown


// Views are responsible for taking an object and returning a Context, a Template name, and input/output files.


protocol View {

  var templateName: String { get }
  var context: Context { get }

  // where to save the rendered HTML
  var htmlPath: Path { get }
  // things to copy such as images
  var resources: [(source: Path, dest: Path)] { get }

}


class ArticleDetailView: View {

  let templateName = "article.html"
  let context: Context

  let htmlPath: Path
  var resources: [(source: Path, dest: Path)] = []

  init(article: Article, store: Store) throws {
    htmlPath = article.htmlPath
    if let source = article.imageSourcePath {
      resources.append((source: source, dest: article.imagePath))
    }
    // This is made more complicated because Swift doesn't compile with seriously-nested dictionaries.
    // Straight-forward stuff
    let firstInsertionPublication = try store.get(Publication.self, withKey: article.firstInsertion.publicationKey)
    var contextDict: [String: Any] = [
      "article": article,
      "article__title": article.title,
      "article__precis": article.precis,
      "article__url": article.url,
      // "article__imageURL": article.imageURL, // can't include nils here because Stencil considers them 'true'
      // "article__fullText": article.fullText,
      "firstInsertion__date": article.firstInsertion.date,
      "firstInsertion__page": article.firstInsertion.page,
      "firstInsertion__troveId": article.firstInsertion.troveId,
      "firstInsertion__publication": firstInsertionPublication,
      "firstInsertion__publication__url": firstInsertionPublication.url,
      "firstInsertion__publication__title": firstInsertionPublication.title,
    ]
    if let value = article.imageURL {
      contextDict["article__imageURL"] = value
    }
    if let value = article.fullText {
      contextDict["article__fullText"] = value
    }
    // First (and later) insertions
    var reprintInsertions: [[String: Any]] = []
    for i in article.insertions.dropFirst() {
      reprintInsertions.append([
        "date": i.date,
        "page": i.page,
        "troveId": i.troveId,
        "publication__title": try store.get(Publication.self, withKey: i.publicationKey).title
      ])
    }
    contextDict["reprintInsertions"] = reprintInsertions
    // Tags
    var tags: [[String: Any]] = []
    for tag in try article.tagKeys.map({ try Store.instance().get(Tag.self, withKey: $0) }) {
      tags.append([
        "url": tag.url,
        "category": tag.category,
        "title": tag.title,
      ])
    }
    contextDict["tags"] = tags
    context = Context(dictionary: contextDict)
  }

}


class TagDetailView: View {
  let templateName = "tag.html"
  let context: Context

  let htmlPath: Path
  var resources: [(source: Path, dest: Path)] = []

  init(tag: Tag, store: Store) throws {
    htmlPath = tag.htmlPath
    var contextDict: [String: Any] = [
      "tag__title": tag.title,
      "tag__precis": tag.precis,
    ]
    // Add articles
    let articles = store.all(Article.self).filter({
      $0.tagKeys.contains({ $0 == tag.key })
    }).sort({
      $0.firstInsertion.date.timeIntervalSinceReferenceDate < $1.firstInsertion.date.timeIntervalSinceReferenceDate
    })
    var articleDicts: [[String: Any]] = []
    for article in articles {
      var d: [String: Any] = [
        "url": article.url,
        "firstInsertion__date": article.firstInsertion.date,
        "firstInsertion__page": article.firstInsertion.page,
        "firstInsertion__publication__title": try store.get(Publication.self, withKey: article.firstInsertion.publicationKey).title,
        "title": article.title,
        "category": article.category.rawValue,
        "precis": article.precis,
      ]
      switch article.insertions.count {
      case 1: d["reprintCountString"] = "Reprinted once."
      case let x where x > 1: d["reprintCountString"] = "Reprinted \(x) times."
      default: break
      }
      articleDicts.append(d)
    }
    contextDict["articles"] = articleDicts
    context = Context(dictionary: contextDict)
  }
}


class PublicationDetailView: View {
  let templateName = "publication.html"
  let context: Context

  let htmlPath: Path
  var resources: [(source: Path, dest: Path)] = []

  init(publication: Publication, store: Store) throws {
    htmlPath = publication.htmlPath
    var contextDict: [String: Any] = [
      "publication__title": publication.title,
    ]
    // Add insertions
    var insertionDicts: [[String: Any]] = []
    for article in store.all(Article.self) {
      for insertion in article.insertions.filter({ $0.publicationKey == publication.key }) {
        var d: [String: Any] = [
          "date": insertion.date,
          "article__url": article.url,
          "article__title": article.title,
          "article__category": article.category.rawValue,
          "publication__title": try store.get(Publication.self, withKey: insertion.publicationKey).title,
          "page": insertion.page,
          "article__precis": article.precis,
        ]
        if insertion != article.firstInsertion {
          d["is_reprint"] = true
        }
        insertionDicts.append(d)
      }
    }
    insertionDicts.sortInPlace({ ($0["date"] as! NSDate).timeIntervalSinceReferenceDate < ($1["date"] as! NSDate).timeIntervalSinceReferenceDate })
    contextDict["insertions"] = insertionDicts
    context = Context(dictionary: contextDict)
  }
}


class YearSummaryView: View {
  let templateName = "year.html"
  let context: Context

  let htmlPath: Path
  var resources: [(source: Path, dest: Path)] = []

  init(yearSummary: YearSummary, store: Store) {
    htmlPath = Path("\(yearSummary.key)/index.html")
    context = Context(dictionary: [
      "summary": [
        "year": yearSummary.key,
        "body": yearSummary.body,
      ]
    ])
  }
}


class Http404View: View {
  let templateName = "404error.html"
  let context = Context(dictionary: [:])

  let htmlPath = Path("404error.html")
  var resources: [(source: Path, dest: Path)] = []

  init() { }
}


class IndexView: View {

  let templateName = "index.html"
  let context: Context

  let htmlPath = Path("index.html")
  var resources: [(source: Path, dest: Path)] = []

  init(store: Store) throws {
    let allArticles = store.all(Article.self)
    let latestArticle = allArticles.sort({$0.firstInsertion.date.timeIntervalSinceReferenceDate > $1.firstInsertion.date.timeIntervalSinceReferenceDate})[0]

    context = Context(dictionary: [
      "totalArticles": allArticles.count,
      "latestDate": latestArticle.firstInsertion.date,
    ])
    // Recently-updated articles
    var recentArticlesDicts: [[String: Any]] = []
    for article in allArticles.sort({$0.dateUpdated.timeIntervalSinceReferenceDate > $1.dateUpdated.timeIntervalSinceReferenceDate}).prefix(5) {
      recentArticlesDicts.append([
        "url": article.url,
        "firstInsertion__date": article.firstInsertion.date,
        "firstInsertion__page": article.firstInsertion.page,
        "firstInsertion__publication__title": try store.get(Publication.self, withKey: article.firstInsertion.publicationKey).title,
        "title": article.title,
        "category": article.category.rawValue,
        "precis": article.precis,
      ])
    }
    context["recentArticles"] = recentArticlesDicts
    // All years
    var yearDicts: [[String: Any]] = []
    for year in store.all(YearSummary.self).sort({$0.year < $1.year}) {
      yearDicts.append([
        "year": year.year,
      ])
    }
    context["yearSummaries"] = yearDicts
    // All those sodding tags - person
    var personTagsDicts: [[String: Any]] = []
    for tag in store.all(Tag.self).filter({ $0.category == .Person }).sort({ $0.title < $1.title }) {
      var d: [String: Any] = [
        "url": tag.url,
        "title": tag.title,
        "articles__count": allArticles.filter({
          $0.tagKeys.contains({ $0 == tag.key })
        }).count,
      ]
      if let precis = tag.precis { d["precis"] = precis }
      personTagsDicts.append(d)
    }
    context["personTags"] = personTagsDicts
    // place
    var placeTagsDicts: [[String: Any]] = []
    for tag in store.all(Tag.self).filter({ $0.category == .Place }).sort({ $0.title < $1.title }) {
      var d: [String: Any] = [
        "url": tag.url,
        "title": tag.title,
        "articles__count": allArticles.filter({
          $0.tagKeys.contains({ $0 == tag.key })
        }).count,
      ]
      if let precis = tag.precis { d["precis"] = precis }
      placeTagsDicts.append(d)
    }
    context["placeTags"] = placeTagsDicts
    // Event
    var eventTagsDicts: [[String: Any]] = []
    for tag in store.all(Tag.self).filter({ $0.category == .Event }).sort({ $0.title < $1.title }) {
      var d: [String: Any] = [
        "url": tag.url,
        "title": tag.title,
        "articles__count": allArticles.filter({
          $0.tagKeys.contains({ $0 == tag.key })
        }).count,
      ]
      if let precis = tag.precis { d["precis"] = precis }
      eventTagsDicts.append(d)
    }
    context["eventTags"] = eventTagsDicts
    // business
    var businessTagsDicts: [[String: Any]] = []
    for tag in store.all(Tag.self).filter({ $0.category == .Business }).sort({ $0.title < $1.title }) {
      var d: [String: Any] = [
        "url": tag.url,
        "title": tag.title,
        "articles__count": allArticles.filter({
          $0.tagKeys.contains({ $0 == tag.key })
        }).count,
      ]
      if let precis = tag.precis { d["precis"] = precis }
      businessTagsDicts.append(d)
    }
    context["businessTags"] = businessTagsDicts
    // group
    var groupTagsDicts: [[String: Any]] = []
    for tag in store.all(Tag.self).filter({ $0.category == .Group }).sort({ $0.title < $1.title }) {
      var d: [String: Any] = [
        "url": tag.url,
        "title": tag.title,
        "articles__count": allArticles.filter({
          $0.tagKeys.contains({ $0 == tag.key })
        }).count,
      ]
      if let precis = tag.precis { d["precis"] = precis }
      groupTagsDicts.append(d)
    }
    context["groupTags"] = groupTagsDicts
    // publications
    var publicationsDicts: [[String: Any]] = []
    for publication in store.all(Publication.self).sort({ $0.title < $1.title }) {
      publicationsDicts.append([
        "url": publication.url,
        "title": publication.title,
        "articles__count": allArticles.filter({
          $0.firstInsertion.publicationKey == publication.key
        }).count,
      ])
    }
    context["publications"] = publicationsDicts
  }

}


class RecentArticlesView: View {
  let templateName = "recents.html"
  let context: Context

  let htmlPath = Path("recents.html")
  var resources: [(source: Path, dest: Path)] = []

  init(store: Store) throws {
    var articleDicts: [[String: Any]] = []
    for article in store.all(Article.self).sort({$0.dateUpdated.timeIntervalSinceReferenceDate > $1.dateUpdated.timeIntervalSinceReferenceDate}).prefix(30) {
      articleDicts.append([
        "url": article.url,
        "dateUpdated": article.dateUpdated,
        "firstInsertion__date": article.firstInsertion.date,
        "firstInsertion__page": article.firstInsertion.page,
        "firstInsertion__publication__title": try store.get(Publication.self, withKey: article.firstInsertion.publicationKey).title,
        "title": article.title,
        "category": article.category.rawValue,
        "precis": article.precis,
      ])
    }
    context = Context(dictionary: [
      "articles": articleDicts
    ])
  }
}


class ArticlesToTranscribeView: View {
  let templateName = "to_transcribe.html"
  let context: Context

  let htmlPath = Path("to_transcribe.html")
  var resources: [(source: Path, dest: Path)] = []

  init(store: Store) throws {
    var articleDicts: [[String: Any]] = []
    for article in store.all(Article.self).filter({ $0.fullText == nil }) {
      articleDicts.append([
        "url": article.url,
        "firstInsertion__date": article.firstInsertion.date,
        "firstInsertion__page": article.firstInsertion.page,
        "firstInsertion__publication__title": try store.get(Publication.self, withKey: article.firstInsertion.publicationKey).title,
        "title": article.title,
        "category": article.category.rawValue,
        "precis": article.precis,
      ])
    }
    context = Context(dictionary: [
      "articles": articleDicts
    ])
  }
}
