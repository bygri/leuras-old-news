import Foundation
import PathKit
import Stencil
import Farkdown


/*private class SetNode: NodeType {
  private let vars: [String: Any]

  class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    var vars: [String: Any] = [:]
    for item in token.components().dropFirst() {
      let components = item.componentsSeparatedByString("=")
      guard components.count == 2 else {
        throw TemplateSyntaxError("'set' tags require the format `var1=value var2=value2`.")
      }
      let (key, value) = (components[0], components[1])
      // Value handling
      switch value {
      case "nil", "None":
        vars[key] = nil
      case let x where x.hasPrefix("\""):
        vars[key] = value.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString:"\""))
      default:
        vars[key] = value
      }
    }
    return SetNode(vars: vars)
  }

  init(vars: [String: Any]) {
    self.vars = vars
  }

  func render(context: Context) throws -> String {
    for (key, value) in vars {
      context[key] = value
    }
    return "i wass here"
  }
}*/


private class DateHeaderNode: NodeType {
  private let variable: Variable
  private let tagName: String

  class func parse(parser:TokenParser, token:Token) throws -> NodeType {
    let components = token.components()
    guard components.count == 3 else {
      throw TemplateSyntaxError("'dateHeader' tags require the format `variable tagName`.")
    }
    return DateHeaderNode(variable: Variable(components[1]), tagName: components[2])
  }

  init(variable: Variable, tagName: String) {
    self.variable = variable
    self.tagName = tagName
  }

  func render(context: Context) throws -> String {
    // print it IF there is no last date OR the current date is different to the last date
    let lastDate = context["lastDate"] as? NSDate
    guard let currentDate = try variable.resolve(context) as? NSDate else { return "PROBLEM" }
    // context.push(["lastDate": currentDate])
    context["lastDate"] = currentDate
    context.push([:])
    if let date = lastDate where date == currentDate {
      return ""
    }
    let dateString = DateFormatter.instance.stringFromDate(currentDate, withStyle: .FullStyle)
    return "<\(tagName)>\(dateString)</\(tagName)>"
  }
}


private let namespace: Namespace = {
  let n = Namespace()
  n.registerFilter("dateformat") { value in
    if let date = value as? NSDate {
      return DateFormatter.instance.stringFromDate(date, withStyle: .FullStyle)
    }
    return value
  }
  n.registerFilter("categoryIconClass") { value in
    switch value as? Tag.Category {
    case .Some(.Place):
      return "fa-map-marker"
    case .Some(.Person):
      return "fa-user"
    case .Some(.Event):
      return "fa-calendar-o"
    default:
      return "fa-tag"
    }
  }
  n.registerFilter("markdown") { value in
    if let str = value as? String {
      return Farkdown(string: str).document()
    }
    return value
  }
  n.registerTag("dateHeader", parser: DateHeaderNode.parse)
  return n
}()




class PageRenderer {

  let templatesPath: Path
  let outputPath: Path

  static var templates: [String: Template] = [:]

  init(templatesPath: Path, outputPath: Path) throws {
    self.templatesPath = templatesPath
    self.outputPath = outputPath
  }

  /// Given an initialised View, render and save it.
  func render(view: View) throws {

    // Get the Context from the view
    let context = view.context
    context["loader"] = TemplateLoader(paths: [templatesPath])

    // Get or create the Template and render the Context
    if !self.dynamicType.templates.contains({ $0.0 == view.templateName }) {
      self.dynamicType.templates[view.templateName] = try Template(path: templatesPath + Path(view.templateName))
    }
    let template = self.dynamicType.templates[view.templateName]!
    let rendering = try template.render(context, namespace: namespace)

    // Prepare the destination path and save the rendered HTML to it
    let destinationPath = (outputPath + view.htmlPath)
    try destinationPath.parent().mkpath()
    try destinationPath.write(rendering, encoding: NSUTF8StringEncoding)

    // Include any resources
    for resource in view.resources {
      try resource.source.copy(outputPath + resource.dest)
    }
  }

}
