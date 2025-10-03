package majkrzak.george

import android.Manifest.permission.ACTIVITY_RECOGNITION
import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup.LayoutParams
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class RequestPermissions : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContentView(
        LinearLayout(this).also {
          it.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
          it.orientation = LinearLayout.VERTICAL
          it.gravity = Gravity.CENTER
          it.addView(
              TextView(this).also { it.text = resources.getString(R.string.permissions_request) })
          it.addView(
              Button(this).also {
                it.text = resources.getString(android.R.string.ok)
                it.setOnClickListener {
                  shouldShowRequestPermissionRationale(ACTIVITY_RECOGNITION)
                  requestPermissions(arrayOf(ACTIVITY_RECOGNITION), R.id.request_permissions)
                }
              })
        })
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String?>,
      grantResults: IntArray
  ) {
    finishAndRemoveTask()
  }
}
