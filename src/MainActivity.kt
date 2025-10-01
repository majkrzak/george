package majkrzak.george

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup.LayoutParams
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContentView(
        LinearLayout(this).also {
          it.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
          it.orientation = LinearLayout.VERTICAL
          it.gravity = Gravity.CENTER
          it.addView(
              TextView(this).also {
                it.text = resources.getString(R.string.alert)
                it.textSize = 120.0f
              })
        })
  }
}
