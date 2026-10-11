package org.shnayimmikra.shnayim_mikra

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
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
 * in the app's language. The widget shows the entry for the day as it comes,
 * turning to the next at the app's day boundary, 3 a.m., and at the times an
 * entry gives (candle-lighting, nightfall), without the app running.
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
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, timeline, now, appWidgetManager.getAppWidgetOptions(id)))
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
        appWidgetManager.updateAppWidget(appWidgetId, views(context, timeline, System.currentTimeMillis(), newOptions))
    }

    private fun views(context: Context, timeline: Timeline?, now: Long, options: Bundle?): RemoteViews {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The launcher picks the largest that fits as the widget is resized.
            return RemoteViews(
                mapOf(
                    SizeF(SMALL_DP, SMALL_DP) to build(context, R.layout.widget_parsha_small, timeline, now),
                    SizeF(MEDIUM_WIDTH_DP, SMALL_DP) to build(context, R.layout.widget_parsha_medium, timeline, now),
                ),
            )
        }
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val layout = if (width >= MEDIUM_WIDTH_DP) R.layout.widget_parsha_medium else R.layout.widget_parsha_small
        return build(context, layout, timeline, now)
    }

    private fun build(context: Context, layout: Int, timeline: Timeline?, now: Long): RemoteViews {
        val views = RemoteViews(context.packageName, layout)
        val medium = layout == R.layout.widget_parsha_medium
        val root = android.R.id.background
        if (timeline == null) {
            // Nothing sent yet: the app is not set up.
            val name = context.getString(R.string.app_name)
            views.setViewVisibility(R.id.widget_eyebrow, View.GONE)
            views.setViewVisibility(R.id.widget_eyebrow_he, View.GONE)
            views.setTextViewText(R.id.widget_hebrew, name)
            views.setViewVisibility(R.id.widget_name, View.GONE)
            show(views, Part.NOTE, medium)
            views.setTextViewText(R.id.widget_note, context.getString(R.string.widget_empty))
            views.setContentDescription(root, "$name. ${context.getString(R.string.widget_empty)}")
            views.setOnClickPendingIntent(root, launch(context, null))
            return views
        }

        views.setInt(root, "setLayoutDirection", if (timeline.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        val day = timeline.dayAt(now)
        // Once its days are over, the last week's parsha, and a word to open
        // the app.
        val shownDay = day ?: timeline.days.last()
        val week = timeline.weeks[shownDay.week]
        views.setTextViewText(R.id.widget_eyebrow, shownDay.eyebrow)
        views.setTextViewText(R.id.widget_eyebrow_he, shownDay.eyebrow)
        // The Latin eyebrow is set in spaced capitals, which Hebrew has no use for.
        views.setViewVisibility(R.id.widget_eyebrow, if (timeline.rtl) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_eyebrow_he, if (timeline.rtl) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.widget_hebrew, week.hebrew)
        views.setViewVisibility(R.id.widget_name, View.VISIBLE)
        views.setTextViewText(R.id.widget_name, week.name)

        val spoken = mutableListOf("${shownDay.eyebrow}: ${week.spoken}")
        when {
            day == null -> {
                show(views, Part.NOTE, medium)
                views.setTextViewText(R.id.widget_note, timeline.stale)
                spoken += timeline.stale
            }
            day.rests -> {
                // Shabbat and Yom Tov ask nothing: a greeting, as Today rests.
                show(views, Part.REST, medium)
                views.setTextViewText(R.id.widget_greeting, day.line)
                spoken += day.line
            }
            else -> {
                show(views, Part.READING, medium)
                views.setProgressBar(R.id.widget_bar_mikra1, ALIYOT, week.mikra1, false)
                views.setProgressBar(R.id.widget_bar_mikra2, ALIYOT, week.mikra2, false)
                views.setProgressBar(R.id.widget_bar_targum, ALIYOT, week.targum, false)
                views.setTextViewText(R.id.widget_progress, week.progress)
                spoken += week.spokenProgress
                if (medium) {
                    views.setTextViewText(R.id.widget_today, day.line)
                    val next = week.next
                    if (next == null) {
                        views.setViewVisibility(R.id.widget_continue, View.GONE)
                    } else {
                        views.setViewVisibility(R.id.widget_continue, View.VISIBLE)
                        views.setTextViewText(R.id.widget_continue, next)
                        views.setOnClickPendingIntent(R.id.widget_continue, launch(context, timeline.continueLink))
                    }
                }
                spoken += day.line
            }
        }
        // One sentence for TalkBack; Continue is a button of its own.
        views.setContentDescription(root, spoken.joinToString(". "))
        views.setOnClickPendingIntent(root, launch(context, timeline.openLink))
        return views
    }

    /** Which of the widget's lower parts it shows. */
    private enum class Part { READING, REST, NOTE }

    /** Shows [part], and hides the others; the medium layout has the day's reading beside it. */
    private fun show(views: RemoteViews, part: Part, medium: Boolean) {
        fun visible(shown: Boolean) = if (shown) View.VISIBLE else View.GONE
        views.setViewVisibility(R.id.widget_bars, visible(part == Part.READING))
        views.setViewVisibility(R.id.widget_progress, visible(part == Part.READING))
        views.setViewVisibility(R.id.widget_rest, visible(part == Part.REST))
        views.setViewVisibility(R.id.widget_note, visible(part == Part.NOTE))
        if (medium) {
            views.setViewVisibility(R.id.widget_today, visible(part == Part.READING))
            views.setViewVisibility(R.id.widget_continue, visible(part == Part.READING))
        }
    }

    private fun launch(context: Context, link: String?) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, link?.let(Uri::parse))

    /**
     * Updates the widget again whenever its entry may change: at each day
     * boundary through the day after its last (when it says to open the
     * app), and at each time an entry gives. Inexact alarms, so no exact-alarm
     * permission is needed; each update schedules the next ones.
     */
    private fun scheduleChanges(context: Context, timeline: Timeline?, now: Long) {
        val provider = ParshaWidgetProvider::class.java.name
        val last = timeline?.days?.lastOrNull()?.date
        if (timeline == null || last == null) {
            HomeWidgetScheduler.cancel(context, provider)
            return
        }
        val times = mutableListOf<Long>()
        val boundary = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, DAY_STARTS_AT_HOUR)
            set(Calendar.MINUTE, 0)
            // A few seconds after, as the app's own day turns.
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= now) add(Calendar.DAY_OF_MONTH, 1)
        }
        while (times.size < MAX_DAYS) {
            times += boundary.timeInMillis
            if (dateOf(boundary.timeInMillis) > last) break
            boundary.add(Calendar.DAY_OF_MONTH, 1)
        }
        for (day in timeline.days) {
            val until = day.until ?: continue
            if (until > now) times += until
        }
        HomeWidgetScheduler.schedule(context, provider, times)
    }

    private class Week(
        val hebrew: String,
        val name: String,
        val spoken: String,
        val progress: String,
        val spokenProgress: String,
        val mikra1: Int,
        val mikra2: Int,
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
    ) {
        /**
         * The entry for [now]: the first of the day the app keeps (the date,
         * which turns at 3 a.m.) that has not ended, or the next day's once
         * they all have. Null once the timeline is over.
         */
        fun dayAt(now: Long): Day? {
            val today = dateOf(now - DAY_STARTS_AT_HOUR * HOUR_MS)
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
                                mikra1 = w.getInt("m1"),
                                mikra2 = w.getInt("m2"),
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

        /** More than any timeline's days, to bound the schedule. */
        const val MAX_DAYS = 45

        /** The smallest size, about 2×2 cells, and the width from which the medium layout fits. */
        const val SMALL_DP = 110f
        const val MEDIUM_WIDTH_DP = 250f

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
