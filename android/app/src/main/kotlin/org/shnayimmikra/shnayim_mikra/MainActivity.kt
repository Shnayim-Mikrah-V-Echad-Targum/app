package org.shnayimmikra.shnayim_mikra

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android recreates the activity (once its process was stopped in the
        // background, say), and reopens it from Recents, with the intent that
        // first started it. After a shortcut on the app's icon started it, that
        // intent still names the shortcut, whose page would then open again in
        // place of the one the user left, even from the plain icon.
        val reopened = savedInstanceState != null ||
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (reopened) intent.removeExtra(QUICK_ACTION_EXTRA)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // A shortcut chosen while the activity is being recreated comes as a
        // new intent, perhaps before Flutter is listening. Keeping it as the
        // activity's own lets quick_actions find it when the app asks which
        // shortcut launched it.
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
