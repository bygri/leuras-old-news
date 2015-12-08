#!/usr/bin/swift
import AppKit

if Process.arguments.count != 3 {
    print("Usage: ./import.swift [troveId] [sequenceLetter]")
    exit(1)
}
// Determine the 'key'
let troveId = Process.arguments[1]
let sequenceLetter = Process.arguments[2]
let key = "\(troveId)\(sequenceLetter)"
let date: String = {
   let df = NSDateFormatter()
   df.dateFormat = "yyyy-MM-dd"
   return df.stringFromDate(NSDate())
}()
// Set paths
let fm = NSFileManager.defaultManager()
let importPathURL = NSURL.fileURLWithPath("import", isDirectory: true)
let articlesPathURL = NSURL.fileURLWithPath("articles", isDirectory: true)
let imagesPathURL = NSURL.fileURLWithPath("article-img", isDirectory: true)
// Convert the first PNG in the import folder into a JPEG named correctly, then open it in Preview.
guard let
    directoryContents = try? fm.contentsOfDirectoryAtURL(importPathURL, includingPropertiesForKeys: [], options: .SkipsHiddenFiles),
    pngFileName = directoryContents.flatMap({ $0.lastPathComponent }).filter({ $0.hasSuffix(".png") }).first
else {
    print("Could not fetch the PNG file.")
    exit(2)
}
NSTask.launchedTaskWithLaunchPath("/usr/bin/sips", arguments: ["-s", "format", "jpeg", "-s", "formatOptions", "normal", "import/\(pngFileName)", "--out", "import/\(key).jpg"]).waitUntilExit()
NSWorkspace.sharedWorkspace().openURL(importPathURL.URLByAppendingPathComponent("\(key).jpg"))
// Now prepare a new pre-filled text file and open it in Chocolat.
let contentsTemplate = [
"title       :\n",
"key         : \(key)\n",
"category    :\n",
"date_updated: \(date)\n",
"precis      :\n",
"\n",
"tags:\n",
"    -\n",
"\n",
"insertions:\n",
"    - date       : 1890-\n",
"      publication: KatoombaTimes\n",
"      page       :\n",
"      trove_id   : \(troveId)\n",
].reduce("", combine: +)
do {
    try contentsTemplate.writeToURL(
        importPathURL.URLByAppendingPathComponent("\(key).txt"),
        atomically: false,
        encoding: NSUTF8StringEncoding
    )
} catch {
    print("Creating template file failed.")
    exit(4)
}
NSTask.launchedTaskWithLaunchPath("/usr/local/bin/choc", arguments: ["import/\(key).txt"])
// Wait until complete...
print("Press [Enter] when editing is complete, or Ctrl-C to cancel.")
NSFileHandle.fileHandleWithStandardInput().availableData
// Now move the edited files over and delete the source PNG file.
do {
    try fm.moveItemAtURL(
        NSURL(string: "\(key).txt", relativeToURL: importPathURL)!,
        toURL: NSURL(string: "\(key).txt", relativeToURL: articlesPathURL)!
    )
    try fm.moveItemAtURL(
        NSURL(string: "\(key).jpg", relativeToURL: importPathURL)!,
        toURL: NSURL(string: "\(key).jpg", relativeToURL: imagesPathURL)!
    )
    try fm.removeItemAtURL(
        NSURL(string: pngFileName, relativeToURL: importPathURL)!
    )
} catch {
    print("Moving and deleting files failed")
    exit(3)
}
print("Done")
