package majkrzak.george

import android.Manifest.permission.ACTIVITY_RECOGNITION
import android.app.Activity
import android.app.Application
import android.content.Intent
import android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK
import android.content.Intent.FLAG_ACTIVITY_NEW_TASK
import android.content.pm.PackageManager.PERMISSION_GRANTED
import android.os.Bundle

class Application : Application() {
  override fun onCreate() {
    super.onCreate()

    registerActivityLifecycleCallbacks(
        object : Application.ActivityLifecycleCallbacks {
          override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            if (activity !is RequestPermissions) {
              if (checkSelfPermission(ACTIVITY_RECOGNITION) != PERMISSION_GRANTED) {
                activity.finishAndRemoveTask()
                startActivity(
                    Intent(activity, RequestPermissions::class.java).also {
                      it.flags = FLAG_ACTIVITY_NEW_TASK + FLAG_ACTIVITY_CLEAR_TASK
                    })
              }
            }
          }

          override fun onActivityDestroyed(activity: Activity) {}

          override fun onActivityPaused(activity: Activity) {}

          override fun onActivityResumed(activity: Activity) {}

          override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

          override fun onActivityStarted(activity: Activity) {}

          override fun onActivityStopped(activity: Activity) {}
        })
  }
}
