package ai.tahfeez.tahfeez_ai.widgets

import ai.tahfeez.tahfeez_ai.MainActivity
import ai.tahfeez.tahfeez_ai.R
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetFonts
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Tahfeez's home-screen widgets (owner, 2026-11-22): the app's own look —
 * its glass, colours and icons, light and dark — and what the app wrote for
 * them (`tahfeez.widgets`, lib/features/home_widgets), already in its
 * language. Each fits the size it is given: minimal when small, more when
 * larger. A tap opens the app at the widget's screen.
 */
abstract class TahfeezWidget : HomeWidgetProvider() {

  /** The widget's key in the payload (its route, its labels). */
  abstract val kind: String

  /** The views at [w] × [h] dp. */
  abstract fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val data = WidgetData.read(widgetData)
    for (id in appWidgetIds) {
      appWidgetManager.updateAppWidget(id, views(context, data, appWidgetManager.getAppWidgetOptions(id)))
    }
  }

  // Resized: drawn again for its new size.
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    val data = WidgetData.read(HomeWidgetPlugin.getData(context))
    appWidgetManager.updateAppWidget(appWidgetId, views(context, data, newOptions))
  }

  private fun views(context: Context, data: WidgetData, options: Bundle): RemoteViews {
    val look = Look.of(context, data)
    // Android 12+: a layout for each size the launcher shows it at.
    if (Build.VERSION.SDK_INT >= 31) {
      val sizes =
          options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
      if (!sizes.isNullOrEmpty()) {
        return RemoteViews(sizes.associateWith { draw(context, data, look, it.width, it.height) })
      }
    }
    val portrait = context.resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
    val w = options.getInt(
        if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
        else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 110).toFloat()
    val h = options.getInt(
        if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
        else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).toFloat()
    return draw(context, data, look, w, h)
  }

  // ---- shared parts

  /** The glass, the direction, and a tap opening [route]. */
  protected fun frame(context: Context, views: RemoteViews, data: WidgetData, look: Look, route: String?) {
    views.setInt(R.id.root, "setBackgroundResource", look.glass)
    views.setInt(R.id.root, "setLayoutDirection",
        if (data.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
    views.setOnClickPendingIntent(R.id.root, open(context, route ?: data.route(kind)))
  }

  protected fun open(context: Context, route: String): android.app.PendingIntent =
      HomeWidgetLaunchIntent.getActivity(
          context, MainActivity::class.java,
          Uri.parse("tahfeezwidget://open?route=" + Uri.encode(route)))

  /** The app's icon [codepoint] (its MaterialIcons font) in [color]. */
  protected fun icon(context: Context, views: RemoteViews, id: Int, codepoint: Int, color: Int, sizeDp: Float = 24f) {
    val glyph = String(Character.toChars(codepoint))
    val bitmap = HomeWidgetFonts.textBitmap(
        context, Look.icons(context), glyph, fontSizeSp = sizeDp, maxWidthDp = sizeDp * 2)
    views.setImageViewBitmap(id, bitmap)
    views.setInt(id, "setColorFilter", color)
  }

  protected fun text(views: RemoteViews, id: Int, value: String?, color: Int) {
    views.setTextViewText(id, value ?: "")
    views.setTextColor(id, color)
    views.setViewVisibility(id, if (value.isNullOrEmpty()) View.GONE else View.VISIBLE)
  }

  /** A clock as the app's time format says: [h12] / [h24] patterns; the
   * phone's own choice when the app leaves it to the phone. */
  protected fun clockFormat(views: RemoteViews, id: Int, data: WidgetData, h12: String, h24: String) {
    when (data.clock) {
      "12" -> {
        views.setCharSequence(id, "setFormat12Hour", h12)
        views.setCharSequence(id, "setFormat24Hour", h12)
      }
      "24" -> {
        views.setCharSequence(id, "setFormat12Hour", h24)
        views.setCharSequence(id, "setFormat24Hour", h24)
      }
    }
  }

  protected fun hide(views: RemoteViews, vararg ids: Int) {
    for (id in ids) views.setViewVisibility(id, View.GONE)
  }

  /** Home's date card (part_date). */
  protected fun fillDate(context: Context, views: RemoteViews, data: WidgetData, look: Look) {
    val today = data.today(data.dates)
    // The time on its glass square (the day number gone: owner, 2026-11-22).
    views.setInt(R.id.dayNum, "setBackgroundResource", look.smallGlass)
    views.setTextColor(R.id.tileTime, look.primary)
    views.setTextColor(R.id.tileAmPm, look.primary)
    clockFormat(views, R.id.tileTime, data, "h:mm", "HH:mm")
    clockFormat(views, R.id.tileAmPm, data, "a", "")
    // On a 24-hour clock no AM/PM line at all: an empty one still takes
    // its height and pushes the time above the square's middle.
    val h24 = when (data.clock) {
      "24" -> true
      "12" -> false
      else -> android.text.format.DateFormat.is24HourFormat(context)
    }
    views.setViewVisibility(R.id.tileAmPm, if (h24) View.GONE else View.VISIBLE)
    // Today's date first, emphasized; the Hijri date under it (owner,
    // 2026-11-22: flipped from the app's card, each line's style kept).
    text(views, R.id.hijri, today?.optString("gregorian") ?: data.label("date", context.getString(R.string.widget_date)), look.text)
    text(views, R.id.today, today?.optString("hijri"), look.muted)
    val event = today?.optString("event")?.takeIf { it.isNotEmpty() && it != "null" }
    text(views, R.id.event, event, look.onNext)
    views.setInt(R.id.event, "setBackgroundResource", look.pill)
    icon(context, views, R.id.sky, sky(), look.gold, 22f)
  }

  /** The next of the day's times after now: its index today (-1 when
   * tomorrow's), name, time shown and when. */
  protected data class Next(val index: Int, val name: String, val shown: String, val at: Long)

  protected fun nextPrayer(data: WidgetData): Next? {
    val prayer = data.prayer ?: return null
    val days = prayer.optJSONArray("days") ?: return null
    val names = prayer.optJSONArray("names") ?: JSONArray()
    val today = data.today(days)?.optString("date")
    val now = System.currentTimeMillis()
    for (i in 0 until days.length()) {
      val d = days.optJSONObject(i) ?: continue
      val at = d.optJSONArray("at") ?: continue
      for (k in 0 until at.length()) {
        if (at.optLong(k) > now) {
          return Next(if (d.optString("date") == today) k else -1, names.optString(k),
              d.optJSONArray("shown")?.optString(k) ?: "", at.optLong(k))
        }
      }
    }
    return null
  }

  /** "ʿAsr in 36 min": the app's words, by the minute (redrawn each
   * minute: [tickEveryMinute]). */
  protected fun untilText(data: WidgetData, next: Next): String {
    val minutes = ((next.at - System.currentTimeMillis() + 59_999) / 60_000).toInt().coerceAtLeast(0)
    val until = data.until
    val phrase = if (until.length() == 0) "$minutes" else until.optString(minutes.coerceAtMost(until.length() - 1))
    return data.label("nextIn", "%1 %2").replace("%1", next.name).replace("%2", phrase)
  }

  /** The next minutes' redraws of this widget (the countdown). */
  protected fun tickEveryMinute(context: Context) {
    val now = System.currentTimeMillis()
    val next = now - now % 60_000 + 60_000
    es.antonborri.home_widget.HomeWidgetScheduler.schedule(
        context, javaClass.name, List(60) { next + it * 60_000L })
  }

  /** Home's prayer card (part_prayer), one row high: [header] — the time
   * and today's date in both calendars (alone) or the place (under the
   * date card) — the next prayer "in 36 min", the day's six times. */
  protected fun fillPrayer(
      context: Context, views: RemoteViews, data: WidgetData, look: Look, header: Boolean,
  ) {
    // The time in the app's green, a divider, today's date (owner,
    // 2026-11-22).
    views.setTextColor(R.id.headClock, look.primary)
    views.setTextColor(R.id.headDivider, look.outline)
    clockFormat(views, R.id.headClock, data, "h:mm a", "HH:mm")
    views.setViewVisibility(R.id.headClock, if (header) View.VISIBLE else View.GONE)
    views.setViewVisibility(R.id.headDivider, if (header) View.VISIBLE else View.GONE)
    val today = data.today(data.dates)
    val headLine = if (header) {
      // (Today's date with the time; the Hijri date left to the date card:
      // it didn't fit, owner 2026-11-22.)
      today?.optString("gregorianShort")?.takeIf { it.isNotEmpty() }
    } else null
    val prayer = data.prayer
    val days = prayer?.optJSONArray("days")
    if (prayer == null || days == null || days.length() == 0) {
      text(views, R.id.place, headLine ?: data.label("prayer", context.getString(R.string.widget_prayer)),
          if (header) look.muted else look.text)
      text(views, R.id.empty, data.label("setLocation"), look.muted)
      hide(views, R.id.tiles, R.id.countdown)
      return
    }
    hide(views, R.id.empty)
    views.setViewVisibility(R.id.tiles, View.VISIBLE)
    text(views, R.id.place, headLine ?: prayer.optString("place"), if (header) look.muted else look.text)
    val next = nextPrayer(data)
    text(views, R.id.countdown, next?.let { untilText(data, it) }, look.primary)
    val names = prayer.optJSONArray("names") ?: JSONArray()
    val day = data.today(days) ?: days.optJSONObject(0)
    val shown = day?.optJSONArray("shown") ?: JSONArray()
    val tiles = listOf(R.id.t0, R.id.t1, R.id.t2, R.id.t3, R.id.t4, R.id.t5)
    val nameIds = listOf(R.id.n0, R.id.n1, R.id.n2, R.id.n3, R.id.n4, R.id.n5)
    val timeIds = listOf(R.id.v0, R.id.v1, R.id.v2, R.id.v3, R.id.v4, R.id.v5)
    for (k in 0 until 6) {
      val isNext = next != null && k == next.index
      views.setInt(tiles[k], "setBackgroundResource", if (isNext) look.tileNext else look.tile)
      text(views, nameIds[k], names.optString(k), if (isNext) look.onNext else look.muted)
      text(views, timeIds[k], shown.optString(k), if (isNext) look.onNext else look.text)
    }
  }

  /** Home's date card and prayer card, each on its glass, each opening
   * its screen. */
  protected fun homeCards(context: Context, views: RemoteViews, data: WidgetData, look: Look) {
    views.setInt(R.id.root, "setLayoutDirection",
        if (data.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
    views.setInt(R.id.dateCard, "setBackgroundResource", look.glass)
    views.setInt(R.id.prayerCard, "setBackgroundResource", look.glass)
    views.setOnClickPendingIntent(R.id.dateCard, open(context, data.route("date")))
    views.setOnClickPendingIntent(R.id.prayerCard, open(context, data.route("prayer")))
    fillDate(context, views, data, look)
    fillPrayer(context, views, data, look, header = false)
  }

  /** Home's three buttons (part_buttons), each on its glass. */
  protected fun fillButtons(context: Context, views: RemoteViews, data: WidgetData, look: Look) {
    val buttons = listOf(
        Triple("qibla", EXPLORE, R.string.widget_qibla),
        Triple("athkar", ATHKAR, R.string.widget_athkar),
        Triple("habits", HABITS, R.string.widget_habits))
    val ids = listOf(
        Triple(R.id.b0, R.id.i0, R.id.l0),
        Triple(R.id.b1, R.id.i1, R.id.l1),
        Triple(R.id.b2, R.id.i2, R.id.l2))
    for ((i, b) in buttons.withIndex()) {
      val (box, iconId, labelId) = ids[i]
      views.setInt(box, "setBackgroundResource", look.glass)
      icon(context, views, iconId, b.second, look.primary)
      text(views, labelId, data.label(b.first, context.getString(b.third)), look.primary)
      views.setOnClickPendingIntent(box, open(context, data.route(b.first)))
    }
  }

  companion object {
    // The app's icons (Flutter's Icons, the same ones the app shows).
    const val EXPLORE = 0xf037          // explore_outlined: the Qibla
    const val ATHKAR = 0xf2f3           // record_voice_over_outlined
    const val HABITS = 0xf02c           // event_available_outlined
    const val KHATMAH = 0xeeaf          // auto_stories_outlined
    const val QURAN = 0xf1c2            // menu_book_outlined
    const val MEMORIZE = 0xf33c         // school_outlined
    const val AYAH = 0xeea9             // auto_awesome_outlined
    const val BOOKMARK = 0xe0f4         // bookmark_outline
    const val CALENDAR = 0xf051f        // calendar_month_outlined
    const val DONE = 0xf635             // check_circle_rounded
    const val OPEN = 0xe504             // radio_button_unchecked
    const val TWILIGHT = 0xf02af        // wb_twilight_rounded
    const val SUN = 0xf02ae             // wb_sunny_rounded
    const val MOON = 0xe42f             // nightlight_round

    /** The date card's sun or moon, as the app's SkyTime. */
    fun sky(): Int {
      val c = java.util.Calendar.getInstance()
      val h = c.get(java.util.Calendar.HOUR_OF_DAY) + c.get(java.util.Calendar.MINUTE) / 60.0
      return when {
        h >= 5 && h < 7 -> TWILIGHT
        h >= 7 && h < 17 -> SUN
        h >= 17 && h < 19 -> TWILIGHT
        else -> MOON
      }
    }
  }
}

/** The app's colours for a widget, light or dark (the app's palette). */
class Look(val dark: Boolean) {
  val glass = if (dark) R.drawable.widget_glass_dark else R.drawable.widget_glass_light
  val tile = if (dark) R.drawable.widget_tile_dark else R.drawable.widget_tile_light
  val tileNext = if (dark) R.drawable.widget_tile_next_dark else R.drawable.widget_tile_next_light
  val smallGlass = if (dark) R.drawable.widget_small_glass_dark else R.drawable.widget_small_glass_light
  val pill = if (dark) R.drawable.widget_pill_dark else R.drawable.widget_pill_light
  val gold = 0xFFE0A526.toInt()
  val text = if (dark) 0xFFECF2EF.toInt() else 0xFF18201D.toInt()
  val muted = if (dark) 0xFFAAB6B0.toInt() else 0xFF58635E.toInt()
  val primary = if (dark) 0xFF68C6A8.toInt() else 0xFF176B5B.toInt()
  val onNext = if (dark) 0xFFC3E2D6.toInt() else 0xFF0D3F35.toInt()
  val outline = if (dark) 0xFF5E6B65.toInt() else 0xFFB7C2BC.toInt()

  companion object {
    /** The app's theme; "system": the phone's. */
    fun of(context: Context, data: WidgetData) = Look(
        when (data.theme) {
          "dark" -> true
          "light" -> false
          else -> (context.resources.configuration.uiMode and
              Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        })

    fun icons(context: Context): Typeface? =
        HomeWidgetFonts.assetTypeface(context, "fonts/MaterialIcons-Regular.otf")

    fun quranFont(context: Context): Typeface? =
        HomeWidgetFonts.typeface(context, "Amiri Quran")
  }
}

/** What the app wrote for the widgets (an empty one before its first run). */
class WidgetData(private val json: JSONObject) {
  val rtl = json.optBoolean("rtl", false)
  val theme: String = json.optString("theme", "system")

  /** The app's time format: "12", "24" or "system" (the phone's). */
  val clock: String = json.optString("clock", "system")

  fun label(key: String, fallback: String = ""): String =
      json.optJSONObject("labels")?.optString(key, fallback) ?: fallback

  fun route(kind: String): String = json.optJSONObject("routes")?.optString(kind, "/home") ?: "/home"

  val prayer: JSONObject? get() = json.optJSONObject("prayer")
  val ayahs: JSONArray get() = json.optJSONArray("ayahs") ?: JSONArray()
  val ayahEpoch: String = json.optString("ayahEpoch", "2024-01-01")
  val until: JSONArray get() = json.optJSONArray("until") ?: JSONArray()
  val dates: JSONArray get() = json.optJSONArray("dates") ?: JSONArray()
  val reading: JSONObject? get() = json.optJSONObject("reading")
  val memorize: JSONObject? get() = json.optJSONObject("memorize")
  val khatmah: JSONObject? get() = json.optJSONObject("khatmah")

  /** Today's entry of a list of days (`date` = today), if there is one. */
  fun today(days: JSONArray): JSONObject? {
    val today = LocalDate.now().toString()
    for (i in 0 until days.length()) {
      val d = days.optJSONObject(i)
      if (d?.optString("date") == today) return d
    }
    return null
  }

  val known = json.length() > 0

  companion object {
    fun read(prefs: SharedPreferences): WidgetData =
        WidgetData(
            try {
              JSONObject(prefs.getString("tahfeez.widgets", null) ?: "{}")
            } catch (e: Exception) {
              JSONObject()
            })

    fun daysSince(epoch: String): Long =
        try {
          ChronoUnit.DAYS.between(LocalDate.parse(epoch), LocalDate.now())
        } catch (e: Exception) {
          0
        }
  }
}

/** A widget that is one button: Qibla, Athkar, Habits, the Qur'an. */
abstract class TileWidget : TahfeezWidget() {
  abstract val codepoint: Int
  abstract val fallbackLabel: Int

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_tile)
    frame(context, views, data, look, null)
    icon(context, views, R.id.icon, codepoint, look.primary, if (h < 90) 24f else 30f)
    text(views, R.id.label, data.label(kind, context.getString(fallbackLabel)), look.primary)
    return views
  }
}

class QiblaWidget : TileWidget() {
  override val kind = "qibla"
  override val codepoint = EXPLORE
  override val fallbackLabel = R.string.widget_qibla
}

class AthkarWidget : TileWidget() {
  override val kind = "athkar"
  override val codepoint = ATHKAR
  override val fallbackLabel = R.string.widget_athkar
}

class HabitsWidget : TileWidget() {
  override val kind = "habits"
  override val codepoint = HABITS
  override val fallbackLabel = R.string.widget_habits
}

class QuranWidget : TileWidget() {
  override val kind = "quran"
  override val codepoint = QURAN
  override val fallbackLabel = R.string.widget_quran
}

/** Qibla, Athkar and Habits, each on its own glass, as on Home. */
open class ShortcutsWidget : TahfeezWidget() {
  override val kind = "shortcuts"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_shortcuts)
    views.setInt(R.id.root, "setLayoutDirection",
        if (data.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
    fillButtons(context, views, data, look)
    return views
  }
}

/** The same three buttons, 3 × 1 (owner, 2026-11-22). */
class ShortcutsSmallWidget : ShortcutsWidget()

/** Prayer times, as Home's card: the place, the next prayer counting down,
 * one row of the day's six times (the next one marked); narrow: the next
 * prayer, its time and how long until it. */
class PrayerWidget : TahfeezWidget() {
  override val kind = "prayer"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    tickEveryMinute(context)
    val views = RemoteViews(context.packageName, R.layout.widget_prayer)
    frame(context, views, data, look, null)
    val next = nextPrayer(data)
    if (w >= 250 || next == null) {
      hide(views, R.id.nextBox)
      views.setViewVisibility(R.id.prayerBox, View.VISIBLE)
      fillPrayer(context, views, data, look, header = true)
      return views
    }
    hide(views, R.id.prayerBox)
    views.setViewVisibility(R.id.nextBox, View.VISIBLE)
    text(views, R.id.nextPlace, data.prayer?.optString("place"), look.muted)
    text(views, R.id.nextName, next.name, look.text)
    text(views, R.id.nextTime, next.shown, look.muted)
    text(views, R.id.nextCountdown, untilText(data, next), look.primary)
    return views
  }
}

/** Home's top in one: the date card, the prayer times (one row), the three
 * buttons — each on its own glass, as in the app. */
class HomeWidget : TahfeezWidget() {
  override val kind = "home"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    tickEveryMinute(context)
    val views = RemoteViews(context.packageName, R.layout.widget_home)
    homeCards(context, views, data, look)
    fillButtons(context, views, data, look)
    return views
  }
}

/** Home's date card and prayer times, without the buttons (owner,
 * 2026-11-22). */
class TodayWidget : TahfeezWidget() {
  override val kind = "today"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    tickEveryMinute(context)
    val views = RemoteViews(context.packageName, R.layout.widget_today)
    homeCards(context, views, data, look)
    return views
  }
}

/** The daily ayah: its verified text in the app's Quran font (Amiri
 * Quran), its reference; larger, its translation too. */
class AyahWidget : TahfeezWidget() {
  override val kind = "ayah"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_card)
    hide(views, R.id.clock, R.id.big, R.id.progress, R.id.r0, R.id.r1, R.id.r2, R.id.foot)
    icon(context, views, R.id.icon, AYAH, look.primary, 18f)
    text(views, R.id.title, data.label("ayah", context.getString(R.string.widget_ayah)), look.text)
    val ayahs = data.ayahs
    if (ayahs.length() == 0) {
      frame(context, views, data, look, "/home")
      hide(views, R.id.art, R.id.corner, R.id.line)
      return views
    }
    // The app's rule: day n after the epoch shows ayah n mod count.
    val n = ayahs.length()
    val index = ((WidgetData.daysSince(data.ayahEpoch) % n + n) % n).toInt()
    val ayah = ayahs.optJSONObject(index) ?: JSONObject()
    frame(context, views, data, look, ayah.optString("route", "/home"))
    text(views, R.id.corner, if (w >= 250) ayah.optString("reference") else null, look.primary)
    val large = h >= 160
    val textHeight = (h - (if (large) 92 else 44)).coerceAtLeast(30f)
    val bitmap = HomeWidgetFonts.textBitmap(
        context, Look.quranFont(context), ayah.optString("text"),
        fontSizeSp = if (large) 22f else 19f,
        maxWidthDp = (w - 24).coerceAtLeast(60f), maxHeightDp = textHeight, fillWidth = true)
    views.setImageViewBitmap(R.id.art, bitmap)
    views.setInt(R.id.art, "setColorFilter", look.text)
    val translation = ayah.optString("translation").takeIf { it.isNotEmpty() && it != "null" }
    text(views, R.id.line,
        if (large) translation else if (w < 250) ayah.optString("reference") else null,
        look.muted)
    return views
  }
}

/** Continue reading: where reading stopped, and a tap goes on there. */
class ReadingWidget : TahfeezWidget() {
  override val kind = "reading"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_card)
    frame(context, views, data, look, null)
    hide(views, R.id.clock, R.id.art, R.id.progress, R.id.r0, R.id.r1, R.id.r2, R.id.corner)
    icon(context, views, R.id.icon, BOOKMARK, look.primary, 18f)
    text(views, R.id.title, data.label("reading", context.getString(R.string.widget_reading)), look.text)
    val reading = data.reading
    text(views, R.id.big, reading?.optString("title"), look.text)
    text(views, R.id.line, if (reading == null) data.label("readingEmpty") else null, look.muted)
    text(views, R.id.foot, reading?.optString("subtitle"), look.primary)
    return views
  }
}

/** The date, as Home's date card: the Hijri day on its glass tile, the
 * Hijri date, today's date and the time, an event coming, the sun or moon. */
class DateWidget : TahfeezWidget() {
  override val kind = "date"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_date)
    frame(context, views, data, look, null)
    fillDate(context, views, data, look)
    return views
  }
}

/** Today's memorization: parts done of today's; larger, each part (the
 * lesson, the revisions) with its mark, as Home's card. */
class MemorizeWidget : TahfeezWidget() {
  override val kind = "memorize"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_card)
    frame(context, views, data, look, null)
    hide(views, R.id.clock, R.id.art, R.id.big, R.id.foot)
    icon(context, views, R.id.icon, MEMORIZE, look.primary, 18f)
    text(views, R.id.title, data.label("memorize", context.getString(R.string.widget_memorize)), look.text)
    val m = data.memorize
    // Not today's (the app not opened since): what to do, not old marks.
    if (m == null || m.optString("date") != LocalDate.now().toString()) {
      hide(views, R.id.corner, R.id.progress, R.id.r0, R.id.r1, R.id.r2)
      text(views, R.id.line, data.label(if (m == null) "memorizeEmpty" else "memorizeOpen"), look.muted)
      return views
    }
    val done = m.optInt("done")
    val total = m.optInt("total")
    text(views, R.id.corner, if (total > 0) "$done/$total" else null, look.primary)
    views.setProgressBar(R.id.progress, 1000, if (total > 0) done * 1000 / total else 0, false)
    if (Build.VERSION.SDK_INT >= 31) {
      views.setColorStateList(R.id.progress, "setProgressTintList", ColorStateList.valueOf(look.primary))
    }
    val rows = m.optJSONArray("rows") ?: JSONArray()
    val large = h >= 140
    val rowIds = listOf(
        listOf(R.id.r0, R.id.rc0, R.id.rt0, R.id.rv0),
        listOf(R.id.r1, R.id.rc1, R.id.rt1, R.id.rv1),
        listOf(R.id.r2, R.id.rc2, R.id.rt2, R.id.rv2))
    for ((i, ids) in rowIds.withIndex()) {
      val row = rows.optJSONObject(i)
      if (!large || row == null) {
        hide(views, ids[0])
        continue
      }
      views.setViewVisibility(ids[0], View.VISIBLE)
      val isDone = row.optBoolean("done")
      icon(context, views, ids[1], if (isDone) DONE else OPEN, if (isDone) look.primary else look.outline, 16f)
      text(views, ids[2], row.optString("title"), look.text)
      text(views, ids[3], row.optString("value"), look.muted)
    }
    hide(views, R.id.line)
    return views
  }
}

/** The khatmah: today's portion, and how far the whole has come. */
class KhatmahWidget : TahfeezWidget() {
  override val kind = "khatmah"

  override fun draw(context: Context, data: WidgetData, look: Look, w: Float, h: Float): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_card)
    frame(context, views, data, look, null)
    hide(views, R.id.clock, R.id.art, R.id.r0, R.id.r1, R.id.r2, R.id.foot)
    icon(context, views, R.id.icon, KHATMAH, look.primary, 18f)
    text(views, R.id.title, data.label("khatmah", context.getString(R.string.widget_khatmah)), look.text)
    val k = data.khatmah
    if (k == null) {
      hide(views, R.id.corner, R.id.progress, R.id.line)
      text(views, R.id.big, data.label("khatmahStart"), look.primary)
      return views
    }
    val progress = k.optDouble("progress", 0.0)
    text(views, R.id.corner, "${(progress * 100).toInt()}%", look.primary)
    text(views, R.id.big, k.optString("line"), look.text)
    text(views, R.id.line, if (h >= 110) k.optString("title") else null, look.muted)
    views.setProgressBar(R.id.progress, 1000, (progress * 1000).toInt(), false)
    if (Build.VERSION.SDK_INT >= 31) {
      views.setColorStateList(R.id.progress, "setProgressTintList", ColorStateList.valueOf(look.primary))
    }
    return views
  }
}
