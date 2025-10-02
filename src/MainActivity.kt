package majkrzak.george

import android.app.Activity
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup.LayoutParams
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {

  private val sensorManager by lazy { getSystemService(SENSOR_SERVICE) as SensorManager }
  private val sensor: Sensor? by lazy { sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) }

  private val valueField by lazy { TextView(this).also { it.textSize = 120.0f } }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    sensorManager.registerListener(
        object : SensorEventListener {
          override fun onSensorChanged(event: SensorEvent?) {
            if (event == null) return

            val stepsSinceLastReboot = event.values[0].toLong()

            valueField.text = "$stepsSinceLastReboot"
          }

          override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        },
        sensor,
        SensorManager.SENSOR_DELAY_UI)

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
          it.addView(valueField)
        })
  }
}
