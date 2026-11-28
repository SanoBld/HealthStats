package com.healthstats.app.ui.screens.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.healthstats.app.R
import com.healthstats.app.ui.components.DateField
import com.healthstats.app.ui.components.BigPillButton
import com.healthstats.app.ui.components.CookieLoader

private const val LAST_STEP = 3

@Composable
fun OnboardingScreen(
    permitted: Boolean,
    onConnect: () -> Unit,
    onFinish: (name: String, heightCm: Int, birth: String) -> Unit,
) {
    var step by rememberSaveable { mutableIntStateOf(0) }
    var name by rememberSaveable { mutableStateOf("") }
    var height by rememberSaveable { mutableStateOf("") }
    var birth by rememberSaveable { mutableStateOf("") }
    val finish = { onFinish(name, height.toIntOrNull() ?: 0, birth) }

    Column(
        Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().imePadding().padding(24.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
            repeat(LAST_STEP + 1) { i ->
                Box(
                    Modifier
                        .height(8.dp)
                        .width(if (i == step) 28.dp else 8.dp)
                        .clip(CircleShape)
                        .background(if (i <= step) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest)
                )
            }
        }

        AnimatedContent(
            targetState = step,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            transitionSpec = {
                if (targetState > initialState) {
                    (slideInHorizontally { it / 4 } + fadeIn()) togetherWith (slideOutHorizontally { -it / 4 } + fadeOut())
                } else {
                    (slideInHorizontally { -it / 4 } + fadeIn()) togetherWith (slideOutHorizontally { it / 4 } + fadeOut())
                }
            },
            label = "onboarding",
        ) { s ->
            Column(
                Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            ) {
                when (s) {
                    0 -> {
                        CookieLoader(progress = null, size = 96.dp)
                        Spacer(Modifier.height(8.dp))
                        Text(stringResource(R.string.app_name), style = MaterialTheme.typography.displaySmall)
                        Text(stringResource(R.string.onb_tagline), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(8.dp))
                        Text("•  " + stringResource(R.string.onb_f1), style = MaterialTheme.typography.bodyLarge)
                        Text("•  " + stringResource(R.string.onb_f2), style = MaterialTheme.typography.bodyLarge)
                        Text("•  " + stringResource(R.string.onb_f3), style = MaterialTheme.typography.bodyLarge)
                    }
                    1 -> {
                        Text(stringResource(R.string.onb_name_title), style = MaterialTheme.typography.headlineMedium)
                        Text(stringResource(R.string.onb_name_sub), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        OutlinedTextField(
                            value = name,
                            onValueChange = { name = it.take(30) },
                            label = { Text(stringResource(R.string.onb_name_label)) },
                            singleLine = true,
                            shape = MaterialTheme.shapes.medium,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    2 -> {
                        Text(stringResource(R.string.onb_about_title), style = MaterialTheme.typography.headlineMedium)
                        Text(stringResource(R.string.onb_about_sub), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        OutlinedTextField(
                            value = height,
                            onValueChange = { v -> height = v.filter { it.isDigit() }.take(3) },
                            label = { Text(stringResource(R.string.onb_height)) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            shape = MaterialTheme.shapes.medium,
                            modifier = Modifier.fillMaxWidth(),
                        )
                        DateField(stringResource(R.string.onb_birth), birth, { birth = it })
                    }
                    else -> {
                        Text(stringResource(R.string.onb_hc_title), style = MaterialTheme.typography.headlineMedium)
                        Text(stringResource(R.string.onb_hc_sub), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (permitted) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Icon(Icons.Rounded.CheckCircle, null, Modifier.size(24.dp), tint = MaterialTheme.colorScheme.primary)
                                Text(stringResource(R.string.hc_granted), style = MaterialTheme.typography.titleMedium)
                            }
                        }
                    }
                }
            }
        }

        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (step > 0) {
                TextButton(onClick = { step-- }) { Text(stringResource(R.string.back)) }
            }
            Spacer(Modifier.weight(1f))
            when {
                step < LAST_STEP -> BigPillButton(stringResource(if (step == 0) R.string.onb_start else R.string.onb_next), { step++ })
                permitted -> BigPillButton(stringResource(R.string.onb_next), finish)
                else -> {
                    TextButton(onClick = finish) { Text(stringResource(R.string.hc_skip)) }
                    BigPillButton(stringResource(R.string.hc_allow), onConnect)
                }
            }
        }
    }
}
