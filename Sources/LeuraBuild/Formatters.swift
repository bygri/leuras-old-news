import Foundation


class DateFormatter {

  static let instance = DateFormatter()

  private let dateFormatter: NSDateFormatter

  private init() {
    dateFormatter = NSDateFormatter()
    dateFormatter.locale = NSLocale(localeIdentifier: "en_AU")
    dateFormatter.timeZone = NSTimeZone(name: "Australia/Sydney")
  }

  func stringFromDate(date: NSDate, withStyle style: NSDateFormatterStyle) -> String {
    switch style {
    case .NoStyle:
      dateFormatter.dateFormat = ""
    case .ShortStyle:
      dateFormatter.dateFormat = "yyyy-MM-dd"
      return dateFormatter.stringFromDate(date)
    case .MediumStyle:
      dateFormatter.dateFormat = "d MMM yyyy"
    case .LongStyle:
      dateFormatter.dateFormat = "d MMMM yyyy"
    case .FullStyle:
      dateFormatter.dateFormat = "EEEE d MMMM yyyy"
    }
    return dateFormatter.stringFromDate(date)
  }

  func dateFromString(string: String) -> NSDate? {
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.dateFromString(string)
  }

}
