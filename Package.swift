import PackageDescription

let package = Package(
  name: "LeurasOldNews",
  targets: [
    Target(
      name: "leurasoldnews",
      dependencies: [
        .Target(name: "LeuraBuild"),
        .Target(name: "LeuraFetch"),
        .Target(name: "LeuraServe"),
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
      name: "LeuraServe"
    ),
    Target(
      name: "Farkdown"
    ),
  ],
  dependencies: [
    .Package(url: "https://github.com/Swiftline/Swiftline.git", majorVersion: 0, minor: 4),
    .Package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", majorVersion: 2, minor: 3),
    .Package(url: "https://github.com/kylef/PathKit.git", majorVersion: 0, minor: 6),
    .Package(url: "https://github.com/kylef/Stencil.git", majorVersion: 0, minor: 5),
    .Package(url: "https://github.com/johnlui/Pitaya.git", majorVersion: 1, minor: 3),
    .Package(url: "https://github.com/drmohundro/SWXMLHash", majorVersion: 2, minor: 1),
    // .Package(url: "https://github.com/qutheory/vapor", majorVersion: 0, minor: 2),
    // .Package(url: "https://github.com/crossroadlabs/Express", majorVersion: 0, minor: 3),
    .Package(url: "https://github.com/httpswift/swifter", "1.1.2"),
  ]
)
