import PackageDescription

let package = Package(
  name: "LeurasOldNews",
  targets: [
    Target(
      name: "leurasoldnews",
      dependencies: [
        .Target(name: "LeuraBuild"),
        .Target(name: "LeuraFetch"),
      ]
    ),
    Target(
      name: "LeuraBuild",
      dependencies: [
        .Target(name: "Farkdown"),
      ]
    ),
    Target(
      name: "LeuraFetch"
    ),
    Target(
      name: "Farkdown"
    ),
  ],
  dependencies: [
    .Package(url: "https://github.com/Swiftline/Swiftline.git", majorVersion: 0, minor: 4),
    .Package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", versions: "2.3.3" ..< Version.max),
    .Package(url: "https://github.com/kylef/PathKit.git", majorVersion: 0, minor: 6),
    .Package(url: "https://github.com/kylef/Stencil.git", majorVersion: 0, minor: 5),
    // .Package(url: "https://github.com/daltoniam/SwiftHTTP", majorVersion: 1),
    .Package(url: "https://github.com/johnlui/Pitaya.git", versions: "1.3.4" ..< Version.max),
  ]
)
