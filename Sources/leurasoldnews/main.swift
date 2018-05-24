import Foundation
import Swiftline
import LeuraBuild
import LeuraFetch
import LeuraServe

switch Args.parsed.parameters.first {
  case .Some("fetch"):
    LeuraFetch.fetch()
  case .Some("serve"):
    LeuraServe.serve()
  case .Some("build"):
    LeuraBuild.build()
  case .Some("fetchserve"):
    LeuraFetch.fetch()
    LeuraServe.serve()
  default:
    print("Leura's Old News")
    print("Usage: leurasoldnews [flags] command")
    print("fetch ISSUEID")
    print("serve ISSUEID")
    print("build")
}
