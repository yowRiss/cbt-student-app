package id.sch.cbt.mobile

import android.app.Activity
import android.os.Bundle

class AssistBlockerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Immediately finish so no assistant popup or window is ever displayed
        finish()
    }
}
