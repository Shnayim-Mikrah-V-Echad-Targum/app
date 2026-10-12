package org.shnayimmikra.shnayim_mikra

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioSession: ListenAudioFocus? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioSession = ListenAudioFocus(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioSession?.close()
        audioSession = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android recreates the activity (once its process was stopped in the
        // background, say), and reopens it from Recents, with the intent that
        // first started it. After a shortcut on the app's icon started it, that
        // intent still names the shortcut, whose page would then open again in
        // place of the one the user left, even from the plain icon.
        val reopened = savedInstanceState != null ||
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (reopened) {
            intent.removeExtra(QUICK_ACTION_EXTRA)
            // So too a tap on the home-screen widget, which home_widget
            // reads from the intent's action and link.
            if (intent.action == HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) {
                intent.action = Intent.ACTION_MAIN
                intent.data = null
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // A shortcut chosen, or the widget tapped, while the activity is being
        // recreated comes as a new intent, perhaps before Flutter is
        // listening. Keeping it as the activity's own lets quick_actions and
        // home_widget find it when the app asks what launched it.
        setIntent(intent)
        super.onNewIntent(intent)
    }

    private companion object {
        // Where quick_actions_android puts the chosen shortcut (its
        // QuickActions.EXTRA_ACTION; test/app/app_shortcuts_platform_test.dart
        // checks that the two agree).
        const val QUICK_ACTION_EXTRA = "some unique action key"
    }
}

/**
 * Audio focus for Listen (lib/services/tts.dart), held from its first verse
 * until speech has stopped rather than taken by the engine for each
 * utterance: music ducks beneath it and comes back up once it stops, rather
 * than at every verse. A call, or another app's audio, taking focus over is
 * told to Dart as 'focusLost', and the page listening pauses there.
 */
private class ListenAudioFocus(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val channel = MethodChannel(messenger, "shnayim_mikra/audio_session")
    private val main = Handler(Looper.getMainLooper())

    // A brief duck (a notification's sound, a navigation prompt) is no
    // interruption: Listen speaks on beneath it.
    private val listener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
            main.post { channel.invokeMethod("focusLost", null) }
        }
    }

    private val request: AudioFocusRequest? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setOnAudioFocusChangeListener(listener, main)
                .build()
        } else {
            null
        }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "activate" -> result.success(activate())
            "deactivate" -> {
                deactivate()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun activate(): Boolean {
        val granted = if (request != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        return granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun deactivate() {
        if (request != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.abandonAudioFocusRequest(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(listener)
        }
    }

    /** The engine is going: focus held for it is given up. */
    fun close() {
        deactivate()
        channel.setMethodCallHandler(null)
        main.removeCallbacksAndMessages(null)
    }
}
