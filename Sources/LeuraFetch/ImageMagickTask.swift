import Foundation

class ImageMagickTask {

  static func convert(args: [String]) {
    let task = NSTask.launchedTaskWithLaunchPath("/usr/local/bin/convert", arguments: args)
    task.waitUntilExit()
  }

}
