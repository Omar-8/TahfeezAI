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

/// The Duas icon (no icon font has it): two cupped hands, filled.
struct DuaHands: Shape {
  func path(in rect: CGRect) -> Path {
    let s = min(rect.width, rect.height) / 24
    let dx = rect.midX - 12 * s, dy = rect.midY - 12 * s
    var path = Path()
    for poly in duaHandsPolygons {
      path.addLines(poly.map { CGPoint(x: dx + $0.x * s, y: dy + $0.y * s) })
      path.closeSubpath()
    }
    return path
  }
}

/// A button's icon: the app's glyph, or the Duas hands ([Glyph.duas]).
struct ButtonIcon: View {
  let codepoint: UInt32
  var size: CGFloat = 24
  var body: some View {
    if codepoint == Glyph.duas {
      DuaHands().frame(width: size, height: size)
    } else {
      AppIcon(codepoint: codepoint, size: size)
    }
  }
}

// BEGIN dua hands (generated by tool/widgets/make_dua_hands.py)
/// Two cupped hands (Duas) — the app's own drawing, as polygons on a
/// 24-unit grid.
let duaHandsPolygons: [[CGPoint]] = [
  [CGPoint(x: 12.2, y: 11.88), CGPoint(x: 12.2, y: 11.74), CGPoint(x: 12.23, y: 11.61), CGPoint(x: 12.28, y: 11.48), CGPoint(x: 12.36, y: 11.36), CGPoint(x: 12.45, y: 11.27), CGPoint(x: 12.57, y: 11.19), CGPoint(x: 12.69, y: 11.14), CGPoint(x: 12.83, y: 11.11), CGPoint(x: 19.29, y: 10.43), CGPoint(x: 19.43, y: 10.43), CGPoint(x: 19.56, y: 10.45), CGPoint(x: 19.69, y: 10.51), CGPoint(x: 19.8, y: 10.58), CGPoint(x: 19.9, y: 10.68), CGPoint(x: 19.98, y: 10.79), CGPoint(x: 20.03, y: 10.92), CGPoint(x: 20.06, y: 11.05), CGPoint(x: 20.66, y: 16.72), CGPoint(x: 20.66, y: 17.54), CGPoint(x: 20.51, y: 18.35), CGPoint(x: 20.2, y: 19.11), CGPoint(x: 19.74, y: 19.8), CGPoint(x: 19.16, y: 20.39), CGPoint(x: 18.48, y: 20.85), CGPoint(x: 17.72, y: 21.17), CGPoint(x: 16.92, y: 21.34), CGPoint(x: 16.62, y: 21.37), CGPoint(x: 15.95, y: 21.37), CGPoint(x: 15.3, y: 21.25), CGPoint(x: 14.68, y: 21.0), CGPoint(x: 14.12, y: 20.63), CGPoint(x: 13.65, y: 20.16), CGPoint(x: 13.28, y: 19.61), CGPoint(x: 13.02, y: 18.99), CGPoint(x: 12.88, y: 18.34)],
  [CGPoint(x: 13.87, y: 12.41), CGPoint(x: 13.84, y: 12.72), CGPoint(x: 13.69, y: 12.99), CGPoint(x: 13.45, y: 13.19), CGPoint(x: 13.16, y: 13.29), CGPoint(x: 12.84, y: 13.26), CGPoint(x: 12.57, y: 13.11), CGPoint(x: 12.37, y: 12.87), CGPoint(x: 12.28, y: 12.57), CGPoint(x: 11.9, y: 8.99), CGPoint(x: 11.93, y: 8.68), CGPoint(x: 12.07, y: 8.41), CGPoint(x: 12.31, y: 8.21), CGPoint(x: 12.61, y: 8.11), CGPoint(x: 12.92, y: 8.14), CGPoint(x: 13.2, y: 8.29), CGPoint(x: 13.4, y: 8.53), CGPoint(x: 13.49, y: 8.83)],
  [CGPoint(x: 15.96, y: 12.19), CGPoint(x: 15.93, y: 12.5), CGPoint(x: 15.78, y: 12.77), CGPoint(x: 15.54, y: 12.97), CGPoint(x: 15.24, y: 13.07), CGPoint(x: 14.93, y: 13.04), CGPoint(x: 14.66, y: 12.89), CGPoint(x: 14.46, y: 12.65), CGPoint(x: 14.36, y: 12.35), CGPoint(x: 13.82, y: 7.18), CGPoint(x: 13.85, y: 6.87), CGPoint(x: 14.0, y: 6.6), CGPoint(x: 14.24, y: 6.4), CGPoint(x: 14.53, y: 6.3), CGPoint(x: 14.84, y: 6.33), CGPoint(x: 15.12, y: 6.48), CGPoint(x: 15.32, y: 6.72), CGPoint(x: 15.41, y: 7.02)],
  [CGPoint(x: 18.04, y: 11.97), CGPoint(x: 18.02, y: 12.28), CGPoint(x: 17.87, y: 12.55), CGPoint(x: 17.63, y: 12.75), CGPoint(x: 17.33, y: 12.85), CGPoint(x: 17.02, y: 12.82), CGPoint(x: 16.75, y: 12.67), CGPoint(x: 16.55, y: 12.43), CGPoint(x: 16.45, y: 12.13), CGPoint(x: 15.86, y: 6.47), CGPoint(x: 15.89, y: 6.15), CGPoint(x: 16.03, y: 5.88), CGPoint(x: 16.27, y: 5.68), CGPoint(x: 16.57, y: 5.59), CGPoint(x: 16.88, y: 5.61), CGPoint(x: 17.16, y: 5.76), CGPoint(x: 17.36, y: 6.0), CGPoint(x: 17.45, y: 6.3)],
  [CGPoint(x: 20.13, y: 11.75), CGPoint(x: 20.1, y: 12.06), CGPoint(x: 19.96, y: 12.33), CGPoint(x: 19.72, y: 12.53), CGPoint(x: 19.42, y: 12.63), CGPoint(x: 19.11, y: 12.6), CGPoint(x: 18.83, y: 12.45), CGPoint(x: 18.63, y: 12.21), CGPoint(x: 18.54, y: 11.91), CGPoint(x: 18.06, y: 7.34), CGPoint(x: 18.09, y: 7.03), CGPoint(x: 18.23, y: 6.75), CGPoint(x: 18.47, y: 6.55), CGPoint(x: 18.77, y: 6.46), CGPoint(x: 19.08, y: 6.49), CGPoint(x: 19.36, y: 6.63), CGPoint(x: 19.56, y: 6.87), CGPoint(x: 19.65, y: 7.17)],
  [CGPoint(x: 21.22, y: 12.46), CGPoint(x: 21.48, y: 12.09), CGPoint(x: 21.86, y: 11.85), CGPoint(x: 22.31, y: 11.78), CGPoint(x: 22.74, y: 11.88), CGPoint(x: 23.11, y: 12.15), CGPoint(x: 23.34, y: 12.53), CGPoint(x: 23.42, y: 12.97), CGPoint(x: 23.32, y: 13.41), CGPoint(x: 21.11, y: 18.26), CGPoint(x: 20.85, y: 18.63), CGPoint(x: 20.47, y: 18.86), CGPoint(x: 20.03, y: 18.94), CGPoint(x: 19.59, y: 18.84), CGPoint(x: 19.22, y: 18.57), CGPoint(x: 18.99, y: 18.19), CGPoint(x: 18.91, y: 17.75), CGPoint(x: 19.02, y: 17.31)],
  [CGPoint(x: 11.8, y: 11.88), CGPoint(x: 11.8, y: 11.74), CGPoint(x: 11.77, y: 11.61), CGPoint(x: 11.72, y: 11.48), CGPoint(x: 11.64, y: 11.36), CGPoint(x: 11.55, y: 11.27), CGPoint(x: 11.43, y: 11.19), CGPoint(x: 11.31, y: 11.14), CGPoint(x: 11.17, y: 11.11), CGPoint(x: 4.71, y: 10.43), CGPoint(x: 4.57, y: 10.43), CGPoint(x: 4.44, y: 10.45), CGPoint(x: 4.31, y: 10.51), CGPoint(x: 4.2, y: 10.58), CGPoint(x: 4.1, y: 10.68), CGPoint(x: 4.02, y: 10.79), CGPoint(x: 3.97, y: 10.92), CGPoint(x: 3.94, y: 11.05), CGPoint(x: 3.34, y: 16.72), CGPoint(x: 3.34, y: 17.54), CGPoint(x: 3.49, y: 18.35), CGPoint(x: 3.8, y: 19.11), CGPoint(x: 4.26, y: 19.8), CGPoint(x: 4.84, y: 20.39), CGPoint(x: 5.52, y: 20.85), CGPoint(x: 6.28, y: 21.17), CGPoint(x: 7.08, y: 21.34), CGPoint(x: 7.38, y: 21.37), CGPoint(x: 8.05, y: 21.37), CGPoint(x: 8.7, y: 21.25), CGPoint(x: 9.32, y: 21.0), CGPoint(x: 9.88, y: 20.63), CGPoint(x: 10.35, y: 20.16), CGPoint(x: 10.72, y: 19.61), CGPoint(x: 10.98, y: 18.99), CGPoint(x: 11.12, y: 18.34)],
  [CGPoint(x: 10.13, y: 12.41), CGPoint(x: 10.16, y: 12.72), CGPoint(x: 10.31, y: 12.99), CGPoint(x: 10.55, y: 13.19), CGPoint(x: 10.84, y: 13.29), CGPoint(x: 11.16, y: 13.26), CGPoint(x: 11.43, y: 13.11), CGPoint(x: 11.63, y: 12.87), CGPoint(x: 11.72, y: 12.57), CGPoint(x: 12.1, y: 8.99), CGPoint(x: 12.07, y: 8.68), CGPoint(x: 11.93, y: 8.41), CGPoint(x: 11.69, y: 8.21), CGPoint(x: 11.39, y: 8.11), CGPoint(x: 11.08, y: 8.14), CGPoint(x: 10.8, y: 8.29), CGPoint(x: 10.6, y: 8.53), CGPoint(x: 10.51, y: 8.83)],
  [CGPoint(x: 8.04, y: 12.19), CGPoint(x: 8.07, y: 12.5), CGPoint(x: 8.22, y: 12.77), CGPoint(x: 8.46, y: 12.97), CGPoint(x: 8.76, y: 13.07), CGPoint(x: 9.07, y: 13.04), CGPoint(x: 9.34, y: 12.89), CGPoint(x: 9.54, y: 12.65), CGPoint(x: 9.64, y: 12.35), CGPoint(x: 10.18, y: 7.18), CGPoint(x: 10.15, y: 6.87), CGPoint(x: 10.0, y: 6.6), CGPoint(x: 9.76, y: 6.4), CGPoint(x: 9.47, y: 6.3), CGPoint(x: 9.16, y: 6.33), CGPoint(x: 8.88, y: 6.48), CGPoint(x: 8.68, y: 6.72), CGPoint(x: 8.59, y: 7.02)],
  [CGPoint(x: 5.96, y: 11.97), CGPoint(x: 5.98, y: 12.28), CGPoint(x: 6.13, y: 12.55), CGPoint(x: 6.37, y: 12.75), CGPoint(x: 6.67, y: 12.85), CGPoint(x: 6.98, y: 12.82), CGPoint(x: 7.25, y: 12.67), CGPoint(x: 7.45, y: 12.43), CGPoint(x: 7.55, y: 12.13), CGPoint(x: 8.14, y: 6.47), CGPoint(x: 8.11, y: 6.15), CGPoint(x: 7.97, y: 5.88), CGPoint(x: 7.73, y: 5.68), CGPoint(x: 7.43, y: 5.59), CGPoint(x: 7.12, y: 5.61), CGPoint(x: 6.84, y: 5.76), CGPoint(x: 6.64, y: 6.0), CGPoint(x: 6.55, y: 6.3)],
  [CGPoint(x: 3.87, y: 11.75), CGPoint(x: 3.9, y: 12.06), CGPoint(x: 4.04, y: 12.33), CGPoint(x: 4.28, y: 12.53), CGPoint(x: 4.58, y: 12.63), CGPoint(x: 4.89, y: 12.6), CGPoint(x: 5.17, y: 12.45), CGPoint(x: 5.37, y: 12.21), CGPoint(x: 5.46, y: 11.91), CGPoint(x: 5.94, y: 7.34), CGPoint(x: 5.91, y: 7.03), CGPoint(x: 5.77, y: 6.75), CGPoint(x: 5.53, y: 6.55), CGPoint(x: 5.23, y: 6.46), CGPoint(x: 4.92, y: 6.49), CGPoint(x: 4.64, y: 6.63), CGPoint(x: 4.44, y: 6.87), CGPoint(x: 4.35, y: 7.17)],
  [CGPoint(x: 2.78, y: 12.46), CGPoint(x: 2.52, y: 12.09), CGPoint(x: 2.14, y: 11.85), CGPoint(x: 1.69, y: 11.78), CGPoint(x: 1.26, y: 11.88), CGPoint(x: 0.89, y: 12.15), CGPoint(x: 0.66, y: 12.53), CGPoint(x: 0.58, y: 12.97), CGPoint(x: 0.68, y: 13.41), CGPoint(x: 2.89, y: 18.26), CGPoint(x: 3.15, y: 18.63), CGPoint(x: 3.53, y: 18.86), CGPoint(x: 3.97, y: 18.94), CGPoint(x: 4.41, y: 18.84), CGPoint(x: 4.78, y: 18.57), CGPoint(x: 5.01, y: 18.19), CGPoint(x: 5.09, y: 17.75), CGPoint(x: 4.98, y: 17.31)],
]
// END dua hands

enum Glyph {
  /// Not a font glyph: the Duas hands ([DuaHands]).
  static let duas: UInt32 = 0

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

/// Home's four buttons as one group (owner, 2026-11-23): Qibla, Athkar,
/// Duas, Habits on one glass, a fine line between them.
struct ButtonsRow: View {
  let data: WidgetData
  let look: Look
  var body: some View {
    let buttons: [(String, UInt32, String)] = [
      ("qibla", Glyph.explore, "widget_qibla"), ("athkar", Glyph.athkar, "widget_athkar"),
      ("duas", Glyph.duas, "widget_duas"), ("habits", Glyph.habits, "widget_habits"),
    ]
    let labels = buttons.map { data.label($0.0, NSLocalizedString($0.2, comment: "")) }
    GeometryReader { geo in
    // A name wider than its share: all four the same smaller size, not that
    // one alone (owner, 2026-11-23).
    let font = UIFont.systemFont(ofSize: 13, weight: .bold)
    let widest = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
    let room = geo.size.width / 4 - 12
    let size: CGFloat = widest > room ? max(9, 13 * room / widest) : 13
    HStack(spacing: 0) {
      ForEach(Array(buttons.enumerated()), id: \.offset) { i, b in
        if i > 0 {
          Rectangle().fill(look.primary.opacity(0.14)).frame(width: 1).padding(.vertical, 12)
        }
        Link(destination: link(data.route(b.0))) {
          VStack(spacing: 4) {
            ButtonIcon(codepoint: b.1, size: 24).foregroundColor(look.primary)
            Text(labels[i])
              .font(.system(size: size, weight: .bold)).foregroundColor(look.primary)
              .lineLimit(1)
          }
          .padding(.horizontal, 4)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .background(RoundedRectangle(cornerRadius: 18).fill(look.tile))
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

// MARK: - Buttons: Qibla, Athkar, Duas, Habits, the Qur'an; the four together

struct TileView: View {
  let entry: DayEntry
  let kind: String
  let glyph: UInt32
  let fallback: String
  var body: some View {
    Framed(data: entry.data) { look in
      VStack(spacing: 8) {
        ButtonIcon(codepoint: glyph, size: 34).foregroundColor(look.primary)
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
struct DuasWidget: Widget {
  var body: some WidgetConfiguration { tileWidget("duas", Glyph.duas, "widget_duas") }
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
    DuasWidget()
    HabitsWidget()
    AyahWidget()
    ReadingWidget()
    DateWidget()
    MemorizeWidget()
    KhatmahWidget()
    QuranWidget()
  }
}
