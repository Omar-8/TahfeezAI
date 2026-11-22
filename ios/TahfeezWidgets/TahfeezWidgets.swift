// Tahfeez's home-screen widgets on the iPhone (owner, 2026-11-22): the
// app's own look — its glass, colours and icons, light and dark — and what
// the app wrote for them (`tahfeez.widgets` in the App Group, from
// lib/features/home_widgets), already in its language. Small: minimal;
// medium (and large for the ayah): more. A tap opens the app at the widget's
// screen. The Android ones (TahfeezWidgets.kt) show the same.

import SwiftUI
import UIKit
import WidgetKit

let appGroup = "group.ai.tahfeez.tahfeezAi"

// MARK: - What the app wrote

struct WidgetData {
  let json: [String: Any]

  static func read() -> WidgetData {
    let raw = UserDefaults(suiteName: appGroup)?.string(forKey: "tahfeez.widgets") ?? "{}"
    let object = (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any]
    return WidgetData(json: object ?? [:])
  }

  var rtl: Bool { json["rtl"] as? Bool ?? false }
  var theme: String { json["theme"] as? String ?? "system" }

  /// The app's time format: "12", "24" or "system" (the phone's) — for a
  /// clock, the locale that writes times so.
  var clockLocale: Locale {
    switch json["clock"] as? String {
    case "12": return Locale(identifier: "en_US")
    case "24": return Locale(identifier: "en_GB")
    default: return .current
    }
  }

  func label(_ key: String, _ fallback: String = "") -> String {
    (json["labels"] as? [String: Any])?[key] as? String ?? fallback
  }

  func route(_ kind: String) -> String {
    (json["routes"] as? [String: Any])?[kind] as? String ?? "/home"
  }

  var prayer: [String: Any]? { json["prayer"] as? [String: Any] }
  var ayahs: [[String: Any]] { json["ayahs"] as? [[String: Any]] ?? [] }
  var ayahEpoch: String { json["ayahEpoch"] as? String ?? "2024-01-01" }
  var dates: [[String: Any]] { json["dates"] as? [[String: Any]] ?? [] }
  var reading: [String: Any]? { json["reading"] as? [String: Any] }
  var memorize: [String: Any]? { json["memorize"] as? [String: Any] }
  var khatmah: [String: Any]? { json["khatmah"] as? [String: Any] }
  var until: [String] { json["until"] as? [String] ?? [] }

  /// "ʿAsr in 36 min": the app's words, by the minute.
  func untilText(name: String, at: Date, now: Date) -> String {
    let minutes = max(0, Int(ceil(at.timeIntervalSince(now) / 60)))
    let phrase = until.isEmpty ? "\(minutes)" : until[min(minutes, until.count - 1)]
    return label("nextIn", "%1 %2").replacingOccurrences(of: "%1", with: name)
      .replacingOccurrences(of: "%2", with: phrase)
  }

  /// The entry of [days] for [date]'s day.
  static func day(_ days: [[String: Any]], _ date: Date) -> [String: Any]? {
    let key = isoDate(date)
    return days.first { $0["date"] as? String == key }
  }
}

func isoDate(_ date: Date) -> String {
  let f = DateFormatter()
  f.calendar = Calendar(identifier: .gregorian)
  f.locale = Locale(identifier: "en_US_POSIX")
  f.dateFormat = "yyyy-MM-dd"
  return f.string(from: date)
}

/// The app link a widget opens (`homeWidget`: home_widget knows it as one).
func link(_ route: String) -> URL {
  var c = URLComponents()
  c.scheme = "tahfeezwidget"
  c.host = "open"
  c.queryItems = [URLQueryItem(name: "homeWidget", value: nil), URLQueryItem(name: "route", value: route)]
  return c.url!
}

// MARK: - The app's look

struct Look {
  let dark: Bool
  var text: Color { dark ? Color(hex: 0xECF2EF) : Color(hex: 0x18201D) }
  var muted: Color { dark ? Color(hex: 0xAAB6B0) : Color(hex: 0x58635E) }
  var primary: Color { dark ? Color(hex: 0x68C6A8) : Color(hex: 0x176B5B) }
  var container: Color { dark ? Color(hex: 0x203D34) : Color(hex: 0xC3E2D6) }
  var onContainer: Color { dark ? Color(hex: 0xC3E2D6) : Color(hex: 0x0D3F35) }
  var outline: Color { dark ? Color(hex: 0x5E6B65) : Color(hex: 0xB7C2BC) }
  var tile: Color { dark ? Color(hex: 0x263129).opacity(0.35) : Color.white.opacity(0.92) }

  /// The app's raised glass: paper (or night) fading across, a fine edge.
  var glass: some View {
    LinearGradient(
      colors: dark
        ? [Color(hex: 0x1D2521).opacity(0.85), Color(hex: 0x101513).opacity(0.78)]
        : [Color.white.opacity(0.86), Color(hex: 0xF7F8F4).opacity(0.70)],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// A font by the first of [names] the extension has.
func widgetFont(_ names: [String], _ size: CGFloat) -> Font {
  for n in names where UIFont(name: n, size: size) != nil { return .custom(n, size: size) }
  return .system(size: size)
}

/// The app's icon (its MaterialIcons font, the glyphs the widgets use).
struct AppIcon: View {
  let codepoint: UInt32
  var size: CGFloat = 22
  var body: some View {
    Text(String(UnicodeScalar(codepoint).map(Character.init) ?? " "))
      .font(widgetFont(["MaterialIcons-Regular", "Material Icons"], size))
  }
}

enum Glyph {
  static let explore: UInt32 = 0xf037
  static let athkar: UInt32 = 0xf2f3
  static let habits: UInt32 = 0xf02c
  static let khatmah: UInt32 = 0xeeaf
  static let quran: UInt32 = 0xf1c2
  static let memorize: UInt32 = 0xf33c
  static let ayah: UInt32 = 0xeea9
  static let mosque: UInt32 = 0xf0636
  static let bookmark: UInt32 = 0xe0f4
  static let calendar: UInt32 = 0xf051f
  static let done: UInt32 = 0xf635
  static let open: UInt32 = 0xe504
  static let twilight: UInt32 = 0xf02af
  static let sun: UInt32 = 0xf02ae
  static let moon: UInt32 = 0xe42f
  static let event: UInt32 = 0xf02f

  /// The date card's sun or moon, as the app's SkyTime.
  static func sky(_ date: Date) -> UInt32 {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    let h = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    switch h {
    case 5..<7, 17..<19: return twilight
    case 7..<17: return sun
    default: return moon
    }
  }
}

/// Every widget's frame: the theme (the app's, else the phone's), the
/// direction, the glass.
struct Framed<Content: View>: View {
  let data: WidgetData
  @Environment(\.colorScheme) var scheme
  @ViewBuilder let content: (Look) -> Content

  var body: some View {
    let dark = data.theme == "dark" || (data.theme == "system" && scheme == .dark)
    let look = Look(dark: dark)
    let inner = content(look)
      .environment(\.layoutDirection, data.rtl ? .rightToLeft : .leftToRight)
      .environment(\.colorScheme, dark ? .dark : .light)
    if #available(iOS 17.0, *) {
      inner.containerBackground(for: .widget) { look.glass }
    } else {
      inner.padding(14).background(look.glass)
    }
  }
}

/// A widget's title row: the app's icon and the card's name.
struct Header: View {
  let glyph: UInt32
  let title: String
  let look: Look
  var trailing: String? = nil
  var body: some View {
    HStack(spacing: 6) {
      AppIcon(codepoint: glyph, size: 16).foregroundColor(look.primary)
      Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(look.text).lineLimit(1)
      Spacer(minLength: 0)
      if let trailing { Text(trailing).font(.system(size: 12, weight: .bold)).foregroundColor(look.primary) }
    }
  }
}

// MARK: - Home's parts (the date card, the prayer card, the three buttons)

/// Home's date card: the Hijri day on its glass tile, the Hijri date, today
/// and the time, an event coming, the sun or the moon.
struct DateCard: View {
  let data: WidgetData
  let date: Date
  let look: Look
  var body: some View {
    let today = WidgetData.day(data.dates, date)
    HStack(spacing: 12) {
      // The time on its glass square (owner, 2026-11-22).
      Text(Date(), style: .time).environment(\.locale, data.clockLocale)
        .font(.system(size: 15, weight: .bold)).foregroundColor(look.primary)
        .multilineTextAlignment(.center).minimumScaleFactor(0.6).lineLimit(2)
        .frame(width: 60, height: 56)
        .background(RoundedRectangle(cornerRadius: 16).fill(look.tile))
      VStack(alignment: .leading, spacing: 2) {
        // Today's date first, emphasized; the Hijri date under it (owner,
        // 2026-11-22: flipped, each line's style kept).
        // Today's date first, the Hijri date under it.
        Text(today?["gregorian"] as? String ?? "").font(.system(size: 15, weight: .semibold))
          .foregroundColor(look.text).lineLimit(1)
        Text(today?["hijri"] as? String ?? "").font(.system(size: 13)).foregroundColor(look.muted).lineLimit(1)
        if let event = today?["event"] as? String, !event.isEmpty {
          HStack(spacing: 4) {
            AppIcon(codepoint: Glyph.event, size: 12)
            Text(event).font(.system(size: 12, weight: .semibold)).lineLimit(1)
          }
          .foregroundColor(look.onContainer)
          .padding(.horizontal, 8).padding(.vertical, 2)
          .background(Capsule().fill(look.container))
        }
      }
      Spacer(minLength: 0)
      AppIcon(codepoint: Glyph.sky(date), size: 22).foregroundColor(Color(hex: 0xE0A526))
    }
  }
}

/// The next of the day's times after [date].
func nextPrayer(_ data: WidgetData, after date: Date)
  -> (name: String, shown: String, at: Date, index: Int, dayKey: String)? {
  guard let prayer = data.prayer, let days = prayer["days"] as? [[String: Any]] else { return nil }
  let names = prayer["names"] as? [String] ?? []
  for day in days {
    let at = day["at"] as? [Double] ?? []
    let shown = day["shown"] as? [String] ?? []
    for (k, ms) in at.enumerated() {
      let when = Date(timeIntervalSince1970: ms / 1000)
      if when > date {
        return (k < names.count ? names[k] : "", k < shown.count ? shown[k] : "", when, k,
                day["date"] as? String ?? "")
      }
    }
  }
  return nil
}

/// Home's prayer card: the place, "ʿAsr in 36 min", one row of the day's
/// six times, the next one marked.
struct PrayerCard: View {
  let data: WidgetData
  let date: Date
  let look: Look
  /// Alone: the time and today's date (both calendars); under Home's date
  /// card: the place.
  var header = false
  var body: some View {
    let todayDate = WidgetData.day(data.dates, date)
    if let prayer = data.prayer, let days = prayer["days"] as? [[String: Any]], !days.isEmpty {
      let names = prayer["names"] as? [String] ?? []
      let today = WidgetData.day(days, date) ?? days[0]
      let shown = today["shown"] as? [String] ?? []
      let next = nextPrayer(data, after: date)
      VStack(spacing: 6) {
        HStack(spacing: 6) {
          if header {
            Text(date, style: .time).environment(\.locale, data.clockLocale)
              .font(.system(size: 14, weight: .bold)).foregroundColor(look.primary)
            Text("|").font(.system(size: 13)).foregroundColor(look.outline)
            Text(todayDate?["gregorianShort"] as? String ?? "")
              .font(.system(size: 12, weight: .semibold)).foregroundColor(look.muted).lineLimit(1)
          } else {
            Text(prayer["place"] as? String ?? "").font(.system(size: 14, weight: .semibold))
              .foregroundColor(look.text).lineLimit(1)
          }
          Spacer(minLength: 4)
          if let next {
            Text(data.untilText(name: next.name, at: next.at, now: date))
              .font(.system(size: 13, weight: .bold)).foregroundColor(look.primary).lineLimit(1)
              .minimumScaleFactor(0.7)
          }
        }
        HStack(spacing: 2) {
          ForEach(0..<min(6, names.count), id: \.self) { k in
            let isNext = next?.dayKey == today["date"] as? String && next?.index == k
            VStack(spacing: 1) {
              Text(names[k]).font(.system(size: 11)).foregroundColor(isNext ? look.onContainer : look.muted)
              Text(k < shown.count ? shown[k] : "").font(.system(size: 13, weight: .bold))
                .foregroundColor(isNext ? look.onContainer : look.text)
            }
            .lineLimit(1).minimumScaleFactor(0.55)
            .padding(.vertical, 5).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(isNext ? look.container : look.tile))
          }
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 4) {
        Text(data.label("prayer", NSLocalizedString("widget_prayer", comment: "")))
          .font(.system(size: 14, weight: .semibold)).foregroundColor(look.text)
        Text(data.label("setLocation")).font(.system(size: 13)).foregroundColor(look.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// Home's three buttons, each on its glass.
struct ButtonsRow: View {
  let data: WidgetData
  let look: Look
  var body: some View {
    HStack(spacing: 8) {
      ForEach(
        [("qibla", Glyph.explore, "widget_qibla"), ("athkar", Glyph.athkar, "widget_athkar"),
         ("habits", Glyph.habits, "widget_habits")], id: \.0
      ) { b in
        Link(destination: link(data.route(b.0))) {
          VStack(spacing: 4) {
            AppIcon(codepoint: b.1, size: 24).foregroundColor(look.primary)
            Text(data.label(b.0, NSLocalizedString(b.2, comment: "")))
              .font(.system(size: 13, weight: .bold)).foregroundColor(look.primary).lineLimit(1)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(RoundedRectangle(cornerRadius: 18).fill(look.tile))
        }
      }
    }
  }
}

// MARK: - Timelines

struct DayEntry: TimelineEntry {
  let date: Date
  let data: WidgetData
}

/// Now, then each midnight for a week (the date, the ayah, memorization,
/// the khatmah change by day).
struct DayProvider: TimelineProvider {
  func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date(), data: .read()) }
  func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
    completion(DayEntry(date: Date(), data: .read()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
    let data = WidgetData.read()
    let start = Calendar.current.startOfDay(for: Date())
    var entries = [DayEntry(date: Date(), data: data)]
    for d in 1...7 {
      entries.append(DayEntry(date: Calendar.current.date(byAdding: .day, value: d, to: start)!, data: data))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

/// Now, then each minute for three hours: the next prayer and the minutes
/// to it move on by themselves.
struct PrayerProvider: TimelineProvider {
  func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date(), data: .read()) }
  func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
    completion(DayEntry(date: Date(), data: .read()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
    let data = WidgetData.read()
    let now = Date()
    var entries = [DayEntry(date: now, data: data)]
    // Each minute for the next three hours (the countdown, by the
    // minute), then again.
    let minute = Calendar.current.date(bySetting: .second, value: 0, of: now) ?? now
    for m in 1...180 {
      entries.append(DayEntry(date: minute.addingTimeInterval(Double(m) * 60), data: data))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

// MARK: - Buttons: Qibla, Athkar, Habits, the Qur'an; the three together

struct TileView: View {
  let entry: DayEntry
  let kind: String
  let glyph: UInt32
  let fallback: String
  var body: some View {
    Framed(data: entry.data) { look in
      VStack(spacing: 8) {
        AppIcon(codepoint: glyph, size: 34).foregroundColor(look.primary)
        Text(entry.data.label(kind, fallback)).font(.system(size: 15, weight: .bold))
          .foregroundColor(look.primary).lineLimit(1).minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .widgetURL(link(entry.data.route(kind)))
    }
  }
}

func tileWidget(_ kind: String, _ glyph: UInt32, _ name: String) -> some WidgetConfiguration {
  StaticConfiguration(kind: "Tahfeez" + kind.prefix(1).uppercased() + kind.dropFirst(), provider: DayProvider()) {
    TileView(entry: $0, kind: kind, glyph: glyph, fallback: NSLocalizedString(name, comment: ""))
  }
  .configurationDisplayName(NSLocalizedString(name, comment: ""))
  .supportedFamilies([.systemSmall])
}

struct QiblaWidget: Widget {
  var body: some WidgetConfiguration { tileWidget("qibla", Glyph.explore, "widget_qibla") }
}
struct AthkarWidget: Widget {
  var body: some WidgetConfiguration { tileWidget("athkar", Glyph.athkar, "widget_athkar") }
}
struct HabitsWidget: Widget {
  var body: some WidgetConfiguration { tileWidget("habits", Glyph.habits, "widget_habits") }
}
struct QuranWidget: Widget {
  var body: some WidgetConfiguration { tileWidget("quran", Glyph.quran, "widget_quran") }
}

struct ShortcutsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezShortcuts", provider: DayProvider()) { entry in
      Framed(data: entry.data) { look in ButtonsRow(data: entry.data, look: look) }
    }
    .configurationDisplayName(NSLocalizedString("widget_shortcuts", comment: ""))
    .supportedFamilies([.systemMedium])
  }
}

// MARK: - Prayer times

struct PrayerView: View {
  let entry: DayEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    let data = entry.data
    Framed(data: data) { look in
      Group {
        if family == .systemSmall, let next = nextPrayer(data, after: entry.date) {
          VStack(alignment: .leading, spacing: 4) {
            Text(data.prayer?["place"] as? String ?? "").font(.system(size: 12, weight: .semibold))
              .foregroundColor(look.muted).lineLimit(1)
            Spacer(minLength: 0)
            Text(next.name).font(.system(size: 22, weight: .bold)).foregroundColor(look.text)
            Text(next.shown).font(.system(size: 15)).foregroundColor(look.muted)
            Text(data.untilText(name: next.name, at: next.at, now: entry.date))
              .font(.system(size: 13, weight: .bold)).foregroundColor(look.primary).lineLimit(2)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          PrayerCard(data: data, date: entry.date, look: look, header: true)
        }
      }
      .widgetURL(link(data.route("prayer")))
    }
  }
}

struct PrayerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezPrayer", provider: PrayerProvider()) { PrayerView(entry: $0) }
      .configurationDisplayName(NSLocalizedString("widget_prayer", comment: ""))
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - The daily ayah

struct AyahView: View {
  let entry: DayEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    let data = entry.data
    let ayahs = data.ayahs
    // The app's rule: day n after the epoch shows ayah n mod count.
    let ayah: [String: Any]? = ayahs.isEmpty ? nil : {
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.dateFormat = "yyyy-MM-dd"
      let epoch = f.date(from: data.ayahEpoch) ?? Date()
      let days = Calendar.current.dateComponents(
        [.day], from: Calendar.current.startOfDay(for: epoch),
        to: Calendar.current.startOfDay(for: entry.date)).day ?? 0
      let n = ayahs.count
      return ayahs[((days % n) + n) % n]
    }()
    Framed(data: data) { look in
      VStack(spacing: 8) {
        Header(glyph: Glyph.ayah, title: data.label("ayah", NSLocalizedString("widget_ayah", comment: "")),
               look: look, trailing: family == .systemMedium ? nil : ayah?["reference"] as? String)
        Spacer(minLength: 0)
        // The verified text, as the app's Quran font draws it.
        Text(ayah?["text"] as? String ?? "")
          .font(widgetFont(["AmiriQuran-Regular", "Amiri Quran"], family == .systemLarge ? 24 : 20))
          .foregroundColor(look.text).multilineTextAlignment(.center)
          .environment(\.layoutDirection, .rightToLeft)
          .minimumScaleFactor(0.5)
        Spacer(minLength: 0)
        if family == .systemLarge, let t = ayah?["translation"] as? String, !t.isEmpty {
          Text(t).font(.system(size: 13)).foregroundColor(look.muted).lineLimit(5)
        } else if family == .systemMedium {
          Text(ayah?["reference"] as? String ?? "").font(.system(size: 12, weight: .bold)).foregroundColor(look.primary)
        }
      }
      .widgetURL(link(ayah?["route"] as? String ?? "/home"))
    }
  }
}

struct AyahWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezAyah", provider: DayProvider()) { AyahView(entry: $0) }
      .configurationDisplayName(NSLocalizedString("widget_ayah", comment: ""))
      .supportedFamilies([.systemMedium, .systemLarge])
  }
}

// MARK: - Continue reading

struct ReadingWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezReading", provider: DayProvider()) { entry in
      let data = entry.data
      Framed(data: data) { look in
        VStack(alignment: .leading, spacing: 6) {
          Header(glyph: Glyph.bookmark, title: data.label("reading", NSLocalizedString("widget_reading", comment: "")), look: look)
          Spacer(minLength: 0)
          if let r = data.reading {
            Text(r["title"] as? String ?? "").font(.system(size: 17, weight: .bold)).foregroundColor(look.text).lineLimit(2)
            Text(r["subtitle"] as? String ?? "").font(.system(size: 13, weight: .semibold)).foregroundColor(look.primary)
          } else {
            Text(data.label("readingEmpty")).font(.system(size: 13)).foregroundColor(look.muted).lineLimit(3)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(link(data.route("reading")))
      }
    }
    .configurationDisplayName(NSLocalizedString("widget_reading", comment: ""))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - The date

struct DateView: View {
  let entry: DayEntry
  var body: some View {
    Framed(data: entry.data) { look in
      DateCard(data: entry.data, date: entry.date, look: look)
        .widgetURL(link(entry.data.route("date")))
    }
  }
}

struct DateWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezDate", provider: DayProvider()) { DateView(entry: $0) }
      .configurationDisplayName(NSLocalizedString("widget_date", comment: ""))
      .supportedFamilies([.systemMedium])
  }
}

// MARK: - Memorization

struct MemorizeView: View {
  let entry: DayEntry
  @Environment(\.widgetFamily) var family
  var body: some View {
    let data = entry.data
    let m = data.memorize
    // Not today's (the app not opened since): what to do, not old marks.
    let current = m?["date"] as? String == isoDate(entry.date) ? m : nil
    let done = current?["done"] as? Int ?? 0
    let total = current?["total"] as? Int ?? 0
    Framed(data: data) { look in
      VStack(alignment: .leading, spacing: 6) {
        Header(glyph: Glyph.memorize, title: data.label("memorize", NSLocalizedString("widget_memorize", comment: "")),
               look: look, trailing: total > 0 ? "\(done)/\(total)" : nil)
        if let current {
          if family == .systemMedium {
            ForEach(Array((current["rows"] as? [[String: Any]] ?? []).prefix(3).enumerated()), id: \.offset) { _, row in
              let isDone = row["done"] as? Bool ?? false
              HStack(spacing: 6) {
                AppIcon(codepoint: isDone ? Glyph.done : Glyph.open, size: 15)
                  .foregroundColor(isDone ? look.primary : look.outline)
                Text(row["title"] as? String ?? "").font(.system(size: 13)).foregroundColor(look.text).lineLimit(1)
                Spacer(minLength: 4)
                Text(row["value"] as? String ?? "").font(.system(size: 12)).foregroundColor(look.muted).lineLimit(1)
              }
            }
          }
          Spacer(minLength: 0)
          ProgressView(value: Double(done), total: Double(max(total, 1))).tint(look.primary)
        } else {
          Spacer(minLength: 0)
          Text(data.label(m == nil ? "memorizeEmpty" : "memorizeOpen")).font(.system(size: 13))
            .foregroundColor(look.muted).lineLimit(3)
        }
      }
      .widgetURL(link(data.route("memorize")))
    }
  }
}

struct MemorizeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezMemorize", provider: DayProvider()) { MemorizeView(entry: $0) }
      .configurationDisplayName(NSLocalizedString("widget_memorize", comment: ""))
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - The khatmah

struct KhatmahWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezKhatmah", provider: DayProvider()) { entry in
      let data = entry.data
      Framed(data: data) { look in
        VStack(alignment: .leading, spacing: 6) {
          let k = data.khatmah
          let progress = k?["progress"] as? Double ?? 0
          Header(glyph: Glyph.khatmah, title: data.label("khatmah", NSLocalizedString("widget_khatmah", comment: "")),
                 look: look, trailing: k == nil ? nil : "\(Int(progress * 100))%")
          Spacer(minLength: 0)
          if let k {
            Text(k["line"] as? String ?? "").font(.system(size: 16, weight: .bold)).foregroundColor(look.text).lineLimit(2)
            Text(k["title"] as? String ?? "").font(.system(size: 12)).foregroundColor(look.muted).lineLimit(1)
            ProgressView(value: progress).tint(look.primary)
          } else {
            Text(data.label("khatmahStart")).font(.system(size: 15, weight: .bold)).foregroundColor(look.primary)
          }
        }
        .widgetURL(link(data.route("khatmah")))
      }
    }
    .configurationDisplayName(NSLocalizedString("widget_khatmah", comment: ""))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Home's top, in one

/// The date card, the prayer times (one row), the three buttons — each on
/// its own glass, as on Home.
struct HomeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezHome", provider: PrayerProvider()) { entry in
      let data = entry.data
      Framed(data: data) { look in
        VStack(spacing: 8) {
          Link(destination: link(data.route("date"))) {
            DateCard(data: data, date: entry.date, look: look)
              .padding(12).background(RoundedRectangle(cornerRadius: 20).fill(look.tile.opacity(0.7)))
          }
          Link(destination: link(data.route("prayer"))) {
            PrayerCard(data: data, date: entry.date, look: look)
              .padding(12).background(RoundedRectangle(cornerRadius: 20).fill(look.tile.opacity(0.7)))
          }
          ButtonsRow(data: data, look: look)
        }
      }
    }
    .configurationDisplayName(NSLocalizedString("widget_home", comment: ""))
    .supportedFamilies([.systemLarge])
  }
}

/// Home's date card and prayer times, without the buttons (owner,
/// 2026-11-22).
struct TodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TahfeezToday", provider: PrayerProvider()) { entry in
      let data = entry.data
      Framed(data: data) { look in
        VStack(spacing: 8) {
          Link(destination: link(data.route("date"))) {
            DateCard(data: data, date: entry.date, look: look)
              .padding(10).background(RoundedRectangle(cornerRadius: 20).fill(look.tile.opacity(0.7)))
          }
          Link(destination: link(data.route("prayer"))) {
            PrayerCard(data: data, date: entry.date, look: look)
              .padding(10).background(RoundedRectangle(cornerRadius: 20).fill(look.tile.opacity(0.7)))
          }
        }
      }
    }
    .configurationDisplayName(NSLocalizedString("widget_today", comment: ""))
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

// MARK: - All of them

@main
struct TahfeezWidgets: WidgetBundle {
  var body: some Widget {
    HomeWidget()
    TodayWidget()
    PrayerWidget()
    ShortcutsWidget()
    QiblaWidget()
    AthkarWidget()
    HabitsWidget()
    AyahWidget()
    ReadingWidget()
    DateWidget()
    MemorizeWidget()
    KhatmahWidget()
    QuranWidget()
  }
}
