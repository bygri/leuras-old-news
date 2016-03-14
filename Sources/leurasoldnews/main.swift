import Foundation
import Swiftline
import LeuraBuild

switch Args.parsed.parameters.first {
  case .Some("build"):
    LeuraBuild.build()
  default:
    print("Leura's Old News")
    print("Usage: leurasoldnews [flags] command")
    print("BUILD command")
    print("Flags: todo")
}
