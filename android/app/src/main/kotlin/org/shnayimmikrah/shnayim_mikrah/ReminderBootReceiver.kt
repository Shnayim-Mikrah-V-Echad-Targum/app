package org.shnayimmikrah.shnayim_mikrah

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
import java.time.LocalDateTime
import java.time.ZoneId
import org.json.JSONArray
import org.json.JSONObject

/**
 * Arms the reminders again after a reboot or an update of the app, as
 * flutter_local_notifications' own receiver does, once it has forgotten
 * those missed while the phone was off.
 *
 * The plugin keeps each reminder it schedules until it fires, and after a
 * reboot arms them all again, the past ones too, which Android then posts
 * at once: a phone off from Friday morning to Motzaei Shabbat would post
 * Friday's reminders, to finish before Shabbat, when it is switched on after
 * Shabbat (or on Shabbat, were it switched on then). Every reminder may come
 * up to an hour late, and the planner keeps each at least that long before
 * Shabbat or Yom Tov (kMaxDeliveryDelay, lib/services/reminder_planner.dart),
 * so one missed by less than that still comes; one missed by more is
 * forgotten. The app plans them all again whenever it is opened.
 */
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Whatever goes wrong here, the reminders still to come are armed.
        try {
            val prefs = context.getSharedPreferences(CACHE, Context.MODE_PRIVATE)
            val kept = prefs.getString(CACHE, null)?.let { withoutMissed(it, System.currentTimeMillis()) }
            // In memory at once, where the plugin, in this process, reads it next.
            if (kept != null) prefs.edit().putString(CACHE, kept).apply()
        } catch (e: Exception) {
            Log.w(TAG, "Could not look for reminders missed while the phone was off", e)
        }
        ScheduledNotificationBootReceiver().onReceive(context, intent)
    }

    internal companion object {
        private const val TAG = "ReminderBootReceiver"

        /**
         * The plugin's cache of what it has scheduled: a SharedPreferences
         * file, and the key in it, of this name (its SCHEDULED_NOTIFICATIONS),
         * holding a JSON array of its NotificationDetails as Gson writes
         * them, without the fields that are null.
         */
        const val CACHE = "scheduled_notifications"

        /** kMaxDeliveryDelay, in lib/services/reminder_planner.dart. */
        const val MAX_DELIVERY_DELAY_MINUTES = 60L

        /** The fields of a notification that comes again, which is never forgotten. */
        private val REPEATS = listOf(
            "repeatInterval",
            "repeatIntervalMilliseconds",
            "matchDateTimeComponents",
            "scheduledNotificationRepeatFrequency",
        )

        /**
         * The cache [json] without the reminders, each shown once, that were
         * due more than [MAX_DELIVERY_DELAY_MINUTES] before [now] (in
         * milliseconds since 1970), or null when it has none.
         */
        fun withoutMissed(json: String, now: Long): String? {
            val all = JSONArray(json)
            val kept = JSONArray()
            val cutoff = now - MAX_DELIVERY_DELAY_MINUTES * 60_000
            for (i in 0 until all.length()) {
                val details = all.opt(i)
                val due = (details as? JSONObject)?.let { dueOnce(it) }
                if (due == null || due >= cutoff) kept.put(details)
            }
            return if (kept.length() == all.length()) null else kept.toString()
        }

        /**
         * When the notification [details] is due, as the plugin reckons it
         * when it arms it again: null if it repeats, or its time can't be read.
         */
        private fun dueOnce(details: JSONObject): Long? {
            if (REPEATS.any { !details.isNull(it) }) return null
            return try {
                when {
                    // zonedSchedule's: the wall-clock time, and its zone.
                    !details.isNull("scheduledDateTime") && !details.isNull("timeZoneName") ->
                        LocalDateTime.parse(details.getString("scheduledDateTime"))
                            .atZone(ZoneId.of(details.getString("timeZoneName")))
                            .toInstant()
                            .toEpochMilli()
                    // The schedule of the plugin's earlier versions.
                    !details.isNull("millisecondsSinceEpoch") -> details.getLong("millisecondsSinceEpoch")
                    else -> null
                }
            } catch (e: Exception) {
                null
            }
        }
    }
}
