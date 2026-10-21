package org.shnayimmikrah.shnayim_mikrah

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetScheduler
import java.util.Calendar
import java.util.Locale
import org.json.JSONObject

/**
 * The home-screen widget: this week's parsha, its progress and today's
 * reading (docs/DESIGN_SYSTEM.md §6.30).
 *
 * The app sends a timeline (lib/services/home_widget_sync.dart): an entry
 * for each day from today through next week's Shabbat, every string already
 * in the app's language, and the days of rest for some months after. The
 * widget shows the entry for the day as it comes, turning to the next at the
 * app's day boundary, 3 a.m., and at the times an entry gives
 * (candle-lighting, nightfall), without the app running.
 */
class ParshaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val timeline = Timeline.parse(widgetData.getString(TIMELINE_KEY, null))
        val now = System.currentTimeMillis()
        val content = Content.of(context, timeline, now)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, content, appWidgetManager.getAppWidgetOptions(id)))
        }
        scheduleChanges(context, timeline, now)
    }

    // The last of the widgets is gone from the home screen: nothing to turn.
    override fun onDisabled(context: Context) {
        HomeWidgetScheduler.cancel(context, ParshaWidgetProvider::class.java.name)
        super.onDisabled(context)
    }

    // Below Android 12 the layout for the widget's size is chosen here.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val timeline = Timeline.parse(HomeWidgetPlugin.getData(context).getString(TIMELINE_KEY, null))
        val content = Content.of(context, timeline, System.currentTimeMillis())
        appWidgetManager.updateAppWidget(appWidgetId, views(context, content, newOptions))
    }

    /**
     * The widget's views for each size it may have: small or medium, at each
     * height from which it shows [content] whole down to the least of it
     * ([Metrics.fits]). From Android 12 the launcher picks the largest that
     * fits as the widget is resized; before it, [options] give the widget's
     * size in each orientation.
     */
    private fun views(context: Context, content: Content, options: Bundle?): RemoteViews {
        val metrics = Metrics(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizes = mutableMapOf<SizeF, RemoteViews>()
            for (medium in listOf(false, true)) {
                val width = if (medium) MEDIUM_WIDTH_DP else MIN_SIZE_DP
                for ((height, omit) in metrics.fits(content, medium)) {
                    sizes[SizeF(width, height)] = build(context, content, medium, omit)
                }
            }
            return RemoteViews(sizes)
        }
        fun sized(width: Int, height: Int): RemoteViews {
            val medium = width >= MEDIUM_WIDTH_DP
            val fits = metrics.fits(content, medium)
            // A launcher that doesn't say gets what fits the smallest size. A
            // dp either way is rounding, as Android 12's launchers allow.
            val room = if (height > 0) height.toFloat() else MIN_SIZE_DP
            val omit = (fits.firstOrNull { it.first <= room + 1 } ?: fits.last()).second
            return build(context, content, medium, omit)
        }
        // A widget is at its widest and shortest in landscape, and the other way about in portrait.
        val o = options ?: Bundle.EMPTY
        return RemoteViews(
            sized(o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH), o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)),
            sized(o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH), o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)),
        )
    }

    /** The views showing [content], small or [medium], without the lines in [omit]. */
    private fun build(context: Context, content: Content, medium: Boolean, omit: Set<Line>): RemoteViews {
        val beside = medium && !content.restOnly
        val views = RemoteViews(context.packageName, if (beside) R.layout.widget_parsha_medium else R.layout.widget_parsha_small)
        val root = android.R.id.background
        fun visible(shown: Boolean) = if (shown) View.VISIBLE else View.GONE
        fun text(id: Int, text: String?) {
            views.setViewVisibility(id, visible(text != null))
            if (text != null) views.setTextViewText(id, text)
        }
        // Before the app has sent anything, the device's direction.
        content.rtl?.let { rtl ->
            views.setInt(root, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        }

        // The Latin eyebrow is set in spaced capitals, which Hebrew has no use for.
        val eyebrow = content.eyebrow.takeIf { Line.EYEBROW !in omit }
        text(R.id.widget_eyebrow, eyebrow.takeIf { content.rtl != true })
        text(R.id.widget_eyebrow_he, eyebrow.takeIf { content.rtl == true })
        text(R.id.widget_hebrew, content.title.takeIf { Line.TITLE !in omit || content.part == Part.READING })
        text(R.id.widget_name, content.name.takeIf { Line.NAME !in omit })

        val part = content.part
        views.setViewVisibility(R.id.widget_bars, visible(part == Part.READING))
        views.setViewVisibility(R.id.widget_rest, visible(part == Part.REST))
        text(R.id.widget_progress, content.week?.progress.takeIf { Line.PROGRESS !in omit })
        text(R.id.widget_note, content.line.takeIf { part == Part.NOTE })
        content.week?.let { week ->
            views.setProgressBar(R.id.widget_bar_mikrah1, ALIYOT, week.mikrah1, false)
            views.setProgressBar(R.id.widget_bar_mikrah2, ALIYOT, week.mikrah2, false)
            views.setProgressBar(R.id.widget_bar_targum, ALIYOT, week.targum, false)
        }
        if (part == Part.REST) {
            // Shabbat and Yom Tov ask nothing: a greeting, as Today rests.
            views.setTextViewText(R.id.widget_greeting, content.line)
            // Alone, the candles and greeting sit in the middle.
            if (content.restOnly && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setViewLayoutMargin(R.id.widget_rest, RemoteViews.MARGIN_TOP, 0f, TypedValue.COMPLEX_UNIT_DIP)
            }
        }
        if (beside) {
            text(R.id.widget_today, content.line.takeIf { part == Part.READING && Line.TODAY !in omit })
            text(R.id.widget_continue, content.next)
            if (content.next != null) {
                views.setOnClickPendingIntent(R.id.widget_continue, launch(context, content.continueLink))
            }
        }
        // One sentence for TalkBack, whatever is left out; Continue is a button of its own.
        views.setContentDescription(root, content.description)
        views.setOnClickPendingIntent(root, launch(context, content.openLink))
        return views
    }

    private fun launch(context: Context, link: String?) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, link?.let(Uri::parse))

    /**
     * Updates the widget again whenever its entry may change: at each day
     * boundary through the day after its last (when it says to open the
     * app), at the start and end of each day of rest after them, and at each
     * time an entry gives. Inexact alarms, so no exact-alarm permission is
     * needed; each update schedules the next ones.
     */
    private fun scheduleChanges(context: Context, timeline: Timeline?, now: Long) {
        val provider = ParshaWidgetProvider::class.java.name
        val last = timeline?.days?.lastOrNull()?.date
        if (timeline == null || last == null) {
            HomeWidgetScheduler.cancel(context, provider)
            return
        }
        val end = maxOf(last, timeline.rests.keys.maxOrNull() ?: last)
        val times = mutableListOf<Long>()
        // Each midnight from yesterday's. The app's day turns 3 hours after
        // it by the hours that pass, however the clocks change that night,
        // and the widget a few seconds after.
        val midnight = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_MONTH, -1)
        }
        var previous: String? = null
        var count = 0
        while ((previous == null || previous <= end) && count++ < MAX_DAYS) {
            val date = dateOf(midnight.timeInMillis)
            val turn = midnight.timeInMillis + DAY_STARTS_AT_HOUR * HOUR_MS + TURN_DELAY_MS
            val after = previous != null && (previous <= last || previous in timeline.rests)
            if (turn > now && (date <= last || date in timeline.rests || after)) times += turn
            previous = date
            midnight.add(Calendar.DAY_OF_MONTH, 1)
            // A midnight the clocks skip is the hour after.
            midnight.set(Calendar.HOUR_OF_DAY, 0)
        }
        for (day in timeline.days) {
            val until = day.until ?: continue
            if (until > now) times += until
        }
        HomeWidgetScheduler.schedule(context, provider, times)
    }

    /** What the widget shows below its names, or beside them at the medium size. */
    private enum class Part { READING, REST, NOTE }

    /**
     * The lines the widget leaves out, in this order, where it is too short
     * for them at the system's text size, rather than squeeze or cut them:
     * the aliyot read (the bars still show them), the eyebrow, the
     * transliteration, on the medium widget today's reading beside them
     * (Continue stays), and but on a reading day the title. TalkBack still
     * reads them all.
     */
    private enum class Line { PROGRESS, EYEBROW, NAME, TODAY, TITLE }

    /** What the widget shows at a moment, whatever its size. */
    private class Content(
        /** Whether it is in the Hebrew UI; null, before the app has sent anything, for the device's. */
        val rtl: Boolean?,
        val eyebrow: String?,
        /** The parsha's Hebrew name, or before the app has sent anything the app's. */
        val title: String?,
        /** The parsha's transliteration, in the English UI. */
        val name: String?,
        val part: Part,
        /** On a reading day, the week whose bars it shows. */
        val week: Week?,
        /** The day's reading, the greeting, or the note. */
        val line: String,
        /** Continue's label, on a reading day of a week not yet complete. */
        val next: String?,
        val description: String,
        val openLink: String?,
        val continueLink: String?,
    ) {
        /** Only the candles and the greeting: a day of rest past the timeline's days, known by its date alone. */
        val restOnly get() = part == Part.REST && title == null

        companion object {
            fun of(context: Context, timeline: Timeline?, now: Long): Content {
                if (timeline == null) {
                    // Nothing sent yet: the app is not set up.
                    val name = context.getString(R.string.app_name)
                    val note = context.getString(R.string.widget_empty)
                    return Content(
                        rtl = null, eyebrow = null, title = name, name = null, part = Part.NOTE, week = null,
                        line = note, next = null, description = "$name. $note", openLink = null, continueLink = null,
                    )
                }
                val day = timeline.dayAt(now)
                if (day == null) {
                    // Past its days, the widget still rests on Shabbat and Yom Tov.
                    timeline.rests[appDate(now)]?.let { greeting ->
                        return Content(
                            rtl = timeline.rtl, eyebrow = null, title = null, name = null, part = Part.REST, week = null,
                            line = greeting, next = null, description = greeting, openLink = timeline.openLink,
                            continueLink = null,
                        )
                    }
                }
                // Once its days are over, the last week's parsha, and a word to
                // open the app.
                val shown = day ?: timeline.days.last()
                val week = timeline.weeks[shown.week]
                val part = when {
                    day == null -> Part.NOTE
                    day.rests -> Part.REST
                    else -> Part.READING
                }
                val line = day?.line ?: timeline.stale
                val reading = part == Part.READING
                val spoken = listOfNotNull("${shown.eyebrow}: ${week.spoken}", week.spokenProgress.takeIf { reading }, line)
                return Content(
                    rtl = timeline.rtl,
                    eyebrow = shown.eyebrow,
                    title = week.hebrew,
                    // The Hebrew UI names the parsha in Hebrew alone.
                    name = week.name.takeIf { !timeline.rtl },
                    part = part,
                    week = week.takeIf { reading },
                    line = line,
                    next = week.next.takeIf { reading },
                    description = spoken.joinToString(". "),
                    openLink = timeline.openLink,
                    continueLink = timeline.continueLink,
                )
            }
        }
    }

    /**
     * The heights of the widget's parts in dp at the system's text size,
     * from the dimensions its layouts are set in (res/values/widget_styles.xml).
     */
    private class Metrics(context: Context) {
        private val resources = context.resources

        private fun dp(id: Int) = resources.getDimension(id) / resources.displayMetrics.density

        /** [count] lines of text [size] tall, as tall as a line of Hebrew is. */
        private fun lines(size: Int, count: Int) = count * LINE_HEIGHT * dp(size)

        private val padding = 2 * dp(R.dimen.widget_padding)
        private val eyebrow = dp(R.dimen.widget_eyebrow_box)
        private val eyebrowHebrew = dp(R.dimen.widget_eyebrow_box_hebrew)
        private val title = dp(R.dimen.widget_title_gap) + dp(R.dimen.widget_hebrew_box)
        private val name = dp(R.dimen.widget_name_box)
        private val section = dp(R.dimen.widget_section_gap)
        private val bars = 3 * dp(R.dimen.widget_bar) + 2 * dp(R.dimen.widget_bar_gap)
        private val progress = dp(R.dimen.widget_line_gap) + dp(R.dimen.widget_progress_box)
        private val rest = maxOf(dp(R.dimen.widget_candles), dp(R.dimen.widget_greeting_box))
        private val note = lines(R.dimen.widget_line_text, 3)
        private val today = lines(R.dimen.widget_today_text, 2)
        private val next = dp(R.dimen.widget_line_gap) + maxOf(dp(R.dimen.widget_tap), lines(R.dimen.widget_today_text, 2))

        /** The height the widget needs to show [content] without the lines in [omit], small or [medium]. */
        fun height(content: Content, medium: Boolean, omit: Set<Line>): Float {
            val beside = medium && !content.restOnly
            var column = 0f
            if (content.eyebrow != null && Line.EYEBROW !in omit) column += if (content.rtl == true) eyebrowHebrew else eyebrow
            if (content.title != null && (Line.TITLE !in omit || content.part == Part.READING)) column += title
            if (content.name != null && Line.NAME !in omit) column += name
            var side = 0f
            when (content.part) {
                Part.READING -> {
                    column += section + bars + if (Line.PROGRESS in omit) 0f else progress
                    if (beside) {
                        if (Line.TODAY !in omit) side += today
                        if (content.next != null) side += next
                    }
                }
                Part.REST -> if (beside) side = rest else column += section + rest
                Part.NOTE -> if (beside) side = note else column += section + note
            }
            return padding + maxOf(column, side)
        }

        /**
         * The heights from which the widget shows [content], small or
         * [medium], each with the lines it leaves out there: from all of it
         * down to the least. It leaves out each line in [Line]'s order, but
         * only where that makes it shorter.
         */
        fun fits(content: Content, medium: Boolean): List<Pair<Float, Set<Line>>> {
            var omit = emptySet<Line>()
            var height = height(content, medium, omit)
            val fits = mutableListOf(height to omit)
            while (true) {
                omit = Line.entries.filter { it !in omit }.map { omit + it }
                    .firstOrNull { height(content, medium, it) < height } ?: break
                height = height(content, medium, omit)
                fits += height to omit
            }
            return fits
        }
    }

    private class Week(
        val hebrew: String,
        val name: String,
        val spoken: String,
        val progress: String,
        val spokenProgress: String,
        val mikrah1: Int,
        val mikrah2: Int,
        val targum: Int,
        val next: String?,
    )

    private class Day(
        val date: String,
        val until: Long?,
        val week: Int,
        val kind: String,
        val eyebrow: String,
        val line: String,
    ) {
        val rests get() = kind == "shabbat" || kind == "yomTov"
    }

    private class Timeline(
        val rtl: Boolean,
        val openLink: String,
        val continueLink: String,
        val stale: String,
        val weeks: List<Week>,
        val days: List<Day>,
        /** The greetings of the days of rest after [days], by date. */
        val rests: Map<String, String>,
    ) {
        /**
         * The entry for [now]: the first of the day the app keeps (the date,
         * which turns at 3 a.m.) that has not ended, or the next day's once
         * they all have. Null once the timeline is over.
         */
        fun dayAt(now: Long): Day? {
            val today = appDate(now)
            return days.firstOrNull { day ->
                day.date > today || (day.date == today && (day.until == null || now < day.until))
            }
        }

        companion object {
            /** The timeline in [json], or null if there is none (or it can't be read). */
            fun parse(json: String?): Timeline? {
                if (json == null) return null
                return try {
                    val o = JSONObject(json)
                    val weeks = o.getJSONArray("weeks")
                    val days = o.getJSONArray("days")
                    val rests = o.optJSONObject("rest")
                    Timeline(
                        rtl = o.optBoolean("rtl"),
                        openLink = o.getString("open"),
                        continueLink = o.getString("continue"),
                        stale = o.getString("stale"),
                        weeks = (0 until weeks.length()).map { i ->
                            val w = weeks.getJSONObject(i)
                            Week(
                                hebrew = w.getString("he"),
                                name = w.getString("name"),
                                spoken = w.getString("say"),
                                progress = w.getString("progress"),
                                spokenProgress = w.getString("sayProgress"),
                                mikrah1 = w.getInt("m1"),
                                mikrah2 = w.getInt("m2"),
                                targum = w.getInt("t"),
                                next = if (w.has("next")) w.getString("next") else null,
                            )
                        },
                        days = (0 until days.length()).map { i ->
                            val d = days.getJSONObject(i)
                            Day(
                                date = d.getString("date"),
                                until = if (d.has("until")) d.getLong("until") else null,
                                week = d.getInt("week"),
                                kind = d.getString("kind"),
                                eyebrow = d.getString("eyebrow"),
                                line = d.getString("line"),
                            )
                        },
                        rests = rests?.keys()?.asSequence()?.associateWith { rests.getString(it) } ?: emptyMap(),
                    ).takeIf { it.days.isNotEmpty() && it.days.all { d -> d.week in it.weeks.indices } }
                } catch (e: org.json.JSONException) {
                    null
                }
            }
        }
    }

    private companion object {
        /** Where the app saves the timeline (kWidgetTimelineKey). */
        const val TIMELINE_KEY = "parsha_widget"

        const val ALIYOT = 7

        /** The app's day turns at 3 a.m. (rolloverDate in lib/app/providers.dart). */
        const val DAY_STARTS_AT_HOUR = 3
        const val HOUR_MS = 60 * 60 * 1000L

        /** How long after the app's day turns the widget does, to be sure it has. */
        const val TURN_DELAY_MS = 5000L

        /** More days than any timeline's and its days of rest after, to bound the schedule. */
        const val MAX_DAYS = 200

        /**
         * The widget's smallest size, about 2×2 cells (minResizeWidth and
         * minResizeHeight in res/xml/parsha_widget_info.xml), and the width
         * from which the medium layout fits.
         */
        const val MIN_SIZE_DP = 110f
        const val MEDIUM_WIDTH_DP = 250f

        /**
         * A line of text, in the sizes it is set in: the system's sans is
         * about 1.33 times as tall with its padding, and a line with Hebrew
         * takes the height of Noto Sans Hebrew, about 1.36.
         */
        const val LINE_HEIGHT = 1.45f

        /** The day the app keeps at [time], as yyyy-MM-dd. */
        fun appDate(time: Long) = dateOf(time - DAY_STARTS_AT_HOUR * HOUR_MS)

        /** The local date of [time], as yyyy-MM-dd. */
        fun dateOf(time: Long): String {
            val c = Calendar.getInstance().apply { timeInMillis = time }
            return String.format(
                Locale.ROOT,
                "%04d-%02d-%02d",
                c.get(Calendar.YEAR),
                c.get(Calendar.MONTH) + 1,
                c.get(Calendar.DAY_OF_MONTH),
            )
        }
    }
}
