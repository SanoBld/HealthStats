package com.healthstats.app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.contentColorFor
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.healthstats.app.R

/** True on tablets and unfolded phones (600 dp wide or more). */
@Composable
fun isWide(): Boolean = LocalConfiguration.current.screenWidthDp >= 600

/** A card with a title, an optional value, an "i" button that opens a short explanation, and the content (a chart...). */
@Composable
fun ExplainedCard(
    title: String,
    explanation: String,
    modifier: Modifier = Modifier,
    value: String? = null,
    container: Color = MaterialTheme.colorScheme.surfaceContainer,
    content: @Composable () -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    Card(
        modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = container, contentColor = contentColorFor(container)),
        shape = MaterialTheme.shapes.extraLarge,
    ) {
        Column(Modifier.padding(start = 22.dp, end = 22.dp, top = 8.dp, bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, Modifier.weight(1f), style = MaterialTheme.typography.titleLarge)
                if (value != null) Text(value, style = MaterialTheme.typography.titleLarge)
                IconButton(onClick = { open = !open }) {
                    Icon(if (open) Icons.Rounded.Close else Icons.Rounded.Info, stringResource(R.string.info))
                }
            }
            AnimatedVisibility(open) {
                Text(explanation, style = MaterialTheme.typography.bodySmall, color = LocalContentColor.current.copy(alpha = 0.8f))
            }
            Box { content() }
        }
    }
}

/** Tiles in rows of 2 on phones, 4 on wide screens. */
@Composable
fun TileGrid(tiles: List<Pair<String, String>>, modifier: Modifier = Modifier) {
    val perRow = if (isWide()) 4 else 2
    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        tiles.chunked(perRow).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { (label, value) -> StatTile(label, value, Modifier.weight(1f)) }
                repeat(perRow - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}
