import Foundation
import Swiftline
import SwiftyJSON
import Stencil
import PathKit


/**
  This kicks off the Leura's Old News build system.
  We load a lot of JSON files and export HTML files.

  Flags:
    -r    resource path, defaults to 'resources'
    -o    output path, defaults to 'www'

*/
public func build() {

  print("Leura's Old News compiler".style.Bold.foreground.Green)

  // Get some base things set up
  let args = Args.parsed.flags
  let resourcePath = Path(args["r"] ?? "resources")
  let paths = (
    articles: resourcePath + Path("articles"),
    publications: resourcePath + Path("publications"),
    tags: resourcePath + Path("tags"),
    years: resourcePath + Path("years"),
    templates: resourcePath + Path("templates"),
    staticFiles: resourcePath + Path("static"),
    output: Path(args["o"] ?? "www")
  )

  do {
    let store = Store.instance()

    // Load and parse model objects from the filesystem.
    print("Loading Data".foreground.Yellow)
    for obj in try Publication.importAllFromDirectory(paths.publications, withExtension: "json") { store.save(obj) }
    print(" - \(store.all(Publication.self).count) Publications loaded")
    for obj in try Tag.importAllFromDirectory(paths.tags, withExtension: "json") { store.save(obj) }
    print(" - \(store.all(Tag.self).count) Tags loaded")
    for obj in try Article.importAllFromDirectory(paths.articles, withExtension: "json") { store.save(obj) }
    print(" - \(store.all(Article.self).count) Articles loaded")
    for obj in try YearSummary.importAllFromDirectory(paths.years, withExtension: "json") { store.save(obj) }
    print(" - \(store.all(YearSummary.self).count) Year Summaries loaded" )

    // Prepare the Output directory
    print("Building HTML".foreground.Yellow)
    print(" - copying static files")
    // Remove the old directory, and replace it with the contents of the Static directory
    let _ = try? paths.output.delete()
    try paths.staticFiles.copy(paths.output)

    // Now build these model objects into HTML.
    let renderer = try PageRenderer(templatesPath: paths.templates, outputPath: paths.output)
    print(" - building article pages")
    for obj in store.all(Article.self) {
      try renderer.render(try ArticleDetailView(article: obj, store: store))
    }
    print(" - building publication pages")
    for obj in store.all(Publication.self) {
      try renderer.render(try PublicationDetailView(publication: obj, store: store))
    }
    print(" - building tag pages")
    for obj in store.all(Tag.self) {
      try renderer.render(try TagDetailView(tag: obj, store: store))
    }
    print(" - building year pages")
    for obj in store.all(YearSummary.self) {
      try renderer.render(YearSummaryView(yearSummary: obj, store: store))
    }
    // Build other things
    print(" - building index page")
    try renderer.render(try IndexView(store: store))
    print(" - building recent articles page")
    try renderer.render(try RecentArticlesView(store: store))
    print(" - building articles to transcribe page")
    try renderer.render(try ArticlesToTranscribeView(store: store))
    print(" - building HTTP 404 page")
    try renderer.render(Http404View())
    // Natural ending point.
    exit(0)

  } catch Error.ParseKey(let url) {
    print("ParseKeyError: Failed to parse key from url \(url)")
  } catch Error.DecodeJSON(let type, let key, let json) {
    print("DecodeJSONError: Failed to decode \(type) with key \(key) from JSON: \(json)")
  } catch Error.URL(let url, let message) {
    print("URLError: \(message) at \(url)")
  } catch Error.Path(let path, let message) {
    print("PathError: \(message) at \(path)")
  } catch Error.StringDataConversion(let string, let data) {
    if let data = data {
      print("StringDataConversionError: Error retrieving String from \(data)")
    } else if let string = string {
      print("StringDataConversionError: Error retrieving Data from \(string)")
    } else {
      print("StringDataConversionError: Both String and Data are nil")
    }
  } catch Error.Content(let message) {
    print("ContentError: \(message)")
  } catch Error.Store(let message) {
    print("StoreError: \(message)")
  } catch Error.Render(let message) {
    print("RenderError: \(message)")
  } catch let error {
    print("Error: Something failed and we don't know what: \(error)")
  }
  // If we made it to here, something is wrong.
  exit(1)

}
