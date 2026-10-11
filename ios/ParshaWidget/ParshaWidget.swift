import SwiftUI
import WidgetKit

// The home-screen widget: this week's parsha, its progress and today's
// reading (docs/DESIGN_SYSTEM.md §6.30), as the Android widget shows it.
//
// The app sends a timeline (lib/services/home_widget_sync.dart): an entry for
// each day from today through next week's Shabbat, every string already in
// the app's language, saved in the App Group the two targets share. The
// widget's own timeline turns to each day's entry at the app's day boundary,
// 3 a.m., and at the times an entry gives (candle-lighting, nightfall),
// without the app running.

/// Where the app saves the timeline (kWidgetAppGroup and kWidgetTimelineKey).
private let appGroup = "group.org.shnayimmikra.app"
private let timelineKey = "parsha_widget"

/// The app's day turns at 3 a.m. (rolloverDate in lib/app/providers.dart).
private let dayStartsAtHour = 3

// MARK: - The timeline the app sends

struct WidgetTimeline: Decodable {
  struct Week: Decodable {
    /// The parsha's Hebrew name, and its transliteration.
    let he: String
    let name: String
    /// How a screen reader names it, in the app's language.
    let say: String
    /// "2 of 7 aliyot", and the rings' label in words.
    let progress: String
    let sayProgress: String
    /// How many of the seven aliyot each reading has covered.
    let m1: Int
    let m2: Int
    let t: Int
    /// Where Today's button continues; nil once the week is complete.
    let next: String?
  }

  struct Day: Decodable {
    /// The day the app keeps, as yyyy-MM-dd.
    let date: String
    /// When the entry gives way to the next, in milliseconds since 1970.
    let until: Double?
    let week: Int
    let kind: String
    let eyebrow: String
    /// The day's reading, or on a day of rest its greeting.
    let line: String

    /// Shabbat and Yom Tov ask nothing of the reader, as Today rests.
    var rests: Bool { kind == "shabbat" || kind == "yomTov" }
    var end: Date? { until.map { Date(timeIntervalSince1970: $0 / 1000) } }
  }

  let rtl: Bool
  let open: String
  let continueLink: String
  let stale: String
  let weeks: [Week]
  let days: [Day]

  enum CodingKeys: String, CodingKey {
    case rtl, open, stale, weeks, days
    case continueLink = "continue"
  }

  /// The timeline the app last saved, if it can be read.
  static func load() -> WidgetTimeline? {
    guard let json = UserDefaults(suiteName: appGroup)?.string(forKey: timelineKey),
      let data = json.data(using: .utf8),
      let timeline = try? JSONDecoder().decode(WidgetTimeline.self, from: data),
      !timeline.days.isEmpty,
      timeline.days.allSatisfy({ timeline.weeks.indices.contains($0.week) })
    else { return nil }
    return timeline
  }

  /// The entry for [date]: the first of the day the app keeps that has not
  /// ended, or the next day's once they all have. Nil once the timeline is
  /// over.
  func day(at date: Date) -> Day? {
    let today = appDate(date)
    return days.first { day in
      day.date > today || (day.date == today && (day.end.map { date < $0 } ?? true))
    }
  }

  /// Every moment after [now] at which the entry may change: each day
  /// boundary through the day after the last (when the widget says to open
  /// the app), and each time an entry gives.
  func changes(after now: Date) -> [Date] {
    guard let last = days.last?.date else { return [] }
    let calendar = Calendar.current
    var changes = Set<Date>()
    // A few seconds after the hour, as the app's own day turns.
    if var boundary = calendar.date(bySettingHour: dayStartsAtHour, minute: 0, second: 5, of: now) {
      if boundary <= now, let next = calendar.date(byAdding: .day, value: 1, to: boundary) {
        boundary = next
      }
      for _ in 0..<45 {
        changes.insert(boundary)
        guard appDate(boundary) <= last, let next = calendar.date(byAdding: .day, value: 1, to: boundary) else {
          break
        }
        boundary = next
      }
    }
    for day in days {
      if let end = day.end, end > now { changes.insert(end) }
    }
    return changes.sorted()
  }
}

/// The day the app keeps at [date], as yyyy-MM-dd.
private func appDate(_ date: Date) -> String {
  let shifted = date.addingTimeInterval(-Double(dayStartsAtHour) * 3600)
  let parts = Calendar.current.dateComponents([.year, .month, .day], from: shifted)
  return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
}

// MARK: - Entries

struct ParshaEntry: TimelineEntry {
  let date: Date
  /// Nil before the app has sent anything.
  let timeline: WidgetTimeline?
  /// Nil once the timeline is over.
  let day: WidgetTimeline.Day?

  init(date: Date, timeline: WidgetTimeline?) {
    self.date = date
    self.timeline = timeline
    self.day = timeline?.day(at: date)
  }
}

extension WidgetTimeline {
  /// A reader partway through Bereshit, for the widget gallery and the
  /// placeholder, in the device's language.
  static var sample: WidgetTimeline {
    WidgetTimeline(
      rtl: Bundle.main.preferredLocalizations.first == "he",
      open: "",
      continueLink: "",
      stale: "",
      weeks: [
        Week(
          he: "בְּרֵאשִׁית",
          name: "Bereshit",
          say: NSLocalizedString("preview.say", comment: "The parsha's name, as a screen reader says it"),
          progress: NSLocalizedString("preview.progress", comment: "How many aliyot are read"),
          sayProgress: NSLocalizedString("preview.sayProgress", comment: "The readings' progress in words"),
          m1: 3,
          m2: 3,
          t: 2,
          next: NSLocalizedString("preview.continue", comment: "Where the reading continues")
        )
      ],
      days: [
        Day(
          date: appDate(Date()),
          until: nil,
          week: 0,
          kind: "weekday",
          eyebrow: NSLocalizedString("preview.eyebrow", comment: "The eyebrow: Parshat HaShavua"),
          line: NSLocalizedString("preview.today", comment: "Today's reading")
        )
      ]
    )
  }
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ParshaEntry {
    ParshaEntry(date: Date(), timeline: WidgetTimeline.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (ParshaEntry) -> Void) {
    // The gallery asks before the app has sent anything.
    let timeline = WidgetTimeline.load() ?? (context.isPreview ? WidgetTimeline.sample : nil)
    completion(ParshaEntry(date: Date(), timeline: timeline))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ParshaEntry>) -> Void) {
    let now = Date()
    let timeline = WidgetTimeline.load()
    let changes = timeline?.changes(after: now) ?? []
    let entries = ([now] + changes).map { ParshaEntry(date: $0, timeline: timeline) }
    // After the last change there is nothing more to show until the app
    // sends a new timeline, which reloads the widget.
    completion(Timeline(entries: entries, policy: changes.isEmpty ? .never : .atEnd))
  }
}

// MARK: - The widget

/// The app's display serifs (docs/DESIGN_SYSTEM.md §4), bundled with the
/// extension: Frank Ruhl Libre for Hebrew and EB Garamond for Latin. They
/// scale with the reader's text size.
private enum Serif {
  static func hebrew(_ size: CGFloat, semibold: Bool = false) -> Font {
    .custom(semibold ? "FrankRuhlLibre-SemiBold" : "FrankRuhlLibre-Medium", size: size)
  }

  static func latin(_ size: CGFloat, semibold: Bool = false) -> Font {
    .custom(semibold ? "EBGaramond-SemiBold" : "EBGaramond-Medium", size: size)
  }
}

private extension Color {
  static let paper = Color("WidgetPaper")
  static let hairline = Color("WidgetHairline")
  static let ink = Color("WidgetInk")
  static let inkMuted = Color("WidgetInkMuted")
  static let techelet = Color("WidgetTechelet")
  static let gold = Color("WidgetGold")
  static let mikra1 = Color("WidgetMikra1")
  static let mikra2 = Color("WidgetMikra2")
  static let targum = Color("WidgetTargum")
  static let track = Color("WidgetTrack")
}

struct ParshaWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: ParshaEntry

  var body: some View {
    Group {
      if let timeline = entry.timeline {
        parsha(timeline)
          .environment(\.layoutDirection, timeline.rtl ? .rightToLeft : .leftToRight)
          .widgetURL(URL(string: timeline.open))
      } else {
        empty
      }
    }
    .paperBackground()
  }

  /// Before the app has sent anything: its name, and a word to open it.
  private var empty: some View {
    let name = NSLocalizedString("widget.appName", comment: "The app's name")
    let note = NSLocalizedString("widget.empty", comment: "Before the app has been set up")
    let hebrew = Bundle.main.preferredLocalizations.first == "he"
    return VStack(alignment: .leading, spacing: 8) {
      Text(name)
        .font(hebrew ? Serif.hebrew(24) : Serif.latin(22))
        .foregroundColor(.techelet)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      Text(note)
        .font(.system(size: 13))
        .foregroundColor(.inkMuted)
        .lineLimit(3)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: "\(name). \(note)"))
  }

  private func parsha(_ timeline: WidgetTimeline) -> some View {
    // Once its days are over, the last week's parsha, and a word to open
    // the app.
    let day = entry.day
    let shown = day ?? timeline.days[timeline.days.count - 1]
    let week = timeline.weeks[shown.week]
    let reading = day.map { !$0.rests } ?? false
    var spoken = ["\(shown.eyebrow): \(week.say)"]
    if let day = day {
      spoken += day.rests ? [day.line] : [week.sayProgress, day.line]
    } else {
      spoken.append(timeline.stale)
    }
    let label = Text(verbatim: spoken.joined(separator: ". "))

    return Group {
      if family == .systemMedium {
        HStack(alignment: .center, spacing: 16) {
          title(timeline, shown: shown, week: week, bars: reading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
          Rectangle()
            .fill(Color.hairline)
            .frame(width: 1)
            .padding(.vertical, 2)
            .accessibilityHidden(true)
          side(timeline, day: day, week: week)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        VStack(alignment: .leading, spacing: 0) {
          title(timeline, shown: shown, week: week, bars: reading)
          if let day = day, day.rests {
            rest(day.line).padding(.top, 10)
          } else if day == nil {
            note(timeline.stale).padding(.top, 10)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
      }
    }
  }

  /// The eyebrow, the parsha's names, and on a reading day its bars and the
  /// aliyot read.
  private func title(
    _ timeline: WidgetTimeline, shown: WidgetTimeline.Day, week: WidgetTimeline.Week, bars: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Group {
        if timeline.rtl {
          Text(shown.eyebrow).font(Serif.hebrew(14, semibold: true))
        } else {
          // In small capitals, as the app's eyebrows.
          Text(shown.eyebrow).font(Serif.latin(14, semibold: true).smallCaps()).kerning(0.6)
        }
      }
      .foregroundColor(.gold)
      .lineLimit(1)
      .minimumScaleFactor(0.6)

      Text(week.he)
        .font(Serif.hebrew(28))
        .foregroundColor(.techelet)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.top, 2)

      Text(week.name)
        .font(Serif.latin(17))
        .foregroundColor(.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      if bars {
        VStack(spacing: 3) {
          Bar(done: week.m1, color: .mikra1)
          Bar(done: week.m2, color: .mikra2)
          Bar(done: week.t, color: .targum)
        }
        .padding(.top, 10)
        Text(week.progress)
          .font(.system(size: 12))
          .foregroundColor(.inkMuted)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .padding(.top, 4)
      }
    }
  }

  /// Beside the parsha, at the medium size: today's reading and Continue, a
  /// day of rest's greeting, or a note.
  @ViewBuilder
  private func side(_ timeline: WidgetTimeline, day: WidgetTimeline.Day?, week: WidgetTimeline.Week) -> some View {
    if let day = day, day.rests {
      rest(day.line).accessibilityHidden(true)
    } else if let day = day {
      VStack(alignment: .leading, spacing: 6) {
        Text(day.line)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.ink)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
          .accessibilityHidden(true)
        if let next = week.next, let url = URL(string: timeline.continueLink) {
          // A button of its own: the reader, where Today's button continues.
          Link(destination: url) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
              Text(next).lineLimit(2).minimumScaleFactor(0.8)
              Image(systemName: "chevron.forward").font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.techelet)
            .frame(minHeight: 44, alignment: .leading)
          }
        }
      }
    } else {
      note(timeline.stale).accessibilityHidden(true)
    }
  }

  /// The candles, and the day of rest's greeting.
  private func rest(_ greeting: String) -> some View {
    HStack(spacing: 6) {
      Candles().fill(Color.gold).frame(width: 22, height: 22)
      Text(greeting)
        .font(entry.timeline?.rtl == true ? Serif.hebrew(17) : Serif.latin(18))
        .foregroundColor(.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 12))
      .foregroundColor(.inkMuted)
      .lineLimit(3)
  }
}

/// A reading's bar: how many of the seven aliyot it has covered, on the
/// rings' track, filling from the side the app's language starts on.
private struct Bar: View {
  let done: Int
  let color: Color

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.track)
        Capsule().fill(color).frame(width: geometry.size.width * CGFloat(min(max(done, 0), 7)) / 7)
      }
    }
    .frame(height: 4)
  }
}

/// The Shabbat candles (docs/DESIGN_SYSTEM.md §7.6), in a 24-unit box.
private struct Candles: Shape {
  func path(in rect: CGRect) -> Path {
    let s = min(rect.width, rect.height) / 24
    var path = Path()
    for x: CGFloat in [6.5, 14.0] {
      path.addRoundedRect(
        in: CGRect(x: x * s, y: 11 * s, width: 3.5 * s, height: 10 * s),
        cornerSize: CGSize(width: 0.8 * s, height: 0.8 * s))
      let cx = (x + 1.75) * s
      path.move(to: CGPoint(x: cx, y: 3 * s))
      path.addCurve(
        to: CGPoint(x: cx, y: 9.5 * s),
        control1: CGPoint(x: cx + 2.6 * s, y: 5.6 * s),
        control2: CGPoint(x: cx + 2.2 * s, y: 9.5 * s))
      path.addCurve(
        to: CGPoint(x: cx, y: 3 * s),
        control1: CGPoint(x: cx - 2.2 * s, y: 9.5 * s),
        control2: CGPoint(x: cx - 2.6 * s, y: 5.6 * s))
      path.closeSubpath()
    }
    return path.offsetBy(dx: rect.minX, dy: rect.minY)
  }
}

private extension View {
  /// The app's paper behind the widget: from iOS 17 as its container
  /// background, which keeps the system's margins; before it, with the
  /// same 16 points of padding.
  @ViewBuilder
  func paperBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(Color.paper, for: .widget)
    } else {
      padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper)
    }
  }
}

@main
struct ParshaWidget: Widget {
  /// The kind the app reloads (kIOSWidgetKind).
  let kind = "ParshaWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ParshaWidgetView(entry: entry)
    }
    .configurationDisplayName("widget.name")
    .description("widget.description")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
