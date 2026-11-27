package com.healthstats.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.data.local.ThemeMode
import com.healthstats.app.ui.theme.HealthStatsTheme

/** Health Connect opens this screen when the user taps "privacy policy": it says why we read the data. */
class PermissionsRationaleActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HealthStatsTheme(mode = ThemeMode.System, dynamic = true) {
                Surface(Modifier.fillMaxSize()) {
                    Column(
                        Modifier.padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp, androidx.compose.ui.Alignment.CenterVertically),
                    ) {
                        Text(stringResource(R.string.rationale_title), style = MaterialTheme.typography.headlineMedium)
                        Text(stringResource(R.string.rationale_body), style = MaterialTheme.typography.bodyLarge)
                        Button(onClick = { finish() }) { Text(stringResource(R.string.close)) }
                    }
                }
            }
        }
    }
}
