import Foundation
import Swiftline
import LeuraBuild
import LeuraFetch

switch Args.parsed.parameters.first {
  case .Some("build"):
    LeuraBuild.build()
  case .Some("fetch"):
    LeuraFetch.fetch()
  default:
    print("Leura's Old News")
    print("Usage: leurasoldnews [flags] command")
    print("BUILD command")
    print("Flags: todo")
}
