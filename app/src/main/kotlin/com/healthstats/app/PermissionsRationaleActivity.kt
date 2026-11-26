package com.healthstats.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.data.local.AppSettings
import com.healthstats.app.ui.theme.HealthStatsTheme

// Shown by Health Connect when the user asks "why does this app need access?"
class PermissionsRationaleActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            HealthStatsTheme(AppSettings()) {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    Column(
                        modifier = Modifier.safeDrawingPadding().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(stringResource(R.string.rationale_title), style = MaterialTheme.typography.headlineMedium)
                        Spacer(Modifier.height(16.dp))
                        Text(stringResource(R.string.rationale_body), style = MaterialTheme.typography.bodyLarge)
                        Spacer(Modifier.height(24.dp))
                        Button(onClick = { finish() }) { Text(stringResource(R.string.rationale_close)) }
                    }
                }
            }
        }
    }
}
