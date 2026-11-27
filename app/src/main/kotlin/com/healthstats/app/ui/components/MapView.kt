package com.healthstats.app.ui.components

import android.graphics.Color as AColor
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.view.MotionEvent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.healthstats.app.data.model.RoutePoint
import com.healthstats.app.util.thin
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import org.osmdroid.views.overlay.TilesOverlay

/** OpenStreetMap with the route as a line and an optional round marker (linked to the chart cursor). */
@Composable
fun RouteMap(
    points: List<RoutePoint>,
    marker: RoutePoint?,
    lineColor: Int,
    dark: Boolean,
    modifier: Modifier = Modifier,
) {
    val ctx = LocalContext.current
    val owner = LocalLifecycleOwner.current

    val map = remember {
        MapView(ctx).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            isTilesScaledToDpi = true
            zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
            // Let the map move inside a scrolling screen
            setOnTouchListener { v, ev ->
                if (ev.action == MotionEvent.ACTION_DOWN || ev.action == MotionEvent.ACTION_MOVE) {
                    v.parent?.requestDisallowInterceptTouchEvent(true)
                }
                false
            }
        }
    }

    DisposableEffect(owner, map) {
        val obs = LifecycleEventObserver { _, e ->
            when (e) {
                Lifecycle.Event.ON_RESUME -> map.onResume()
                Lifecycle.Event.ON_PAUSE -> map.onPause()
                else -> {}
            }
        }
        owner.lifecycle.addObserver(obs)
        map.onResume()
        onDispose {
            owner.lifecycle.removeObserver(obs)
            map.onPause()
            map.onDetach()
        }
    }

    val geo = remember(points) { thin(points, 1500).map { GeoPoint(it.lat, it.lng) } }
    val line = remember(geo, lineColor) {
        Polyline().apply {
            setPoints(geo)
            outlinePaint.color = lineColor
            outlinePaint.strokeWidth = 10f
            outlinePaint.strokeCap = Paint.Cap.ROUND
        }
    }
    val dot = remember(map) { Marker(map).apply { setInfoWindow(null); setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER) } }
    remember(lineColor) {
        dot.icon = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(AColor.WHITE)
            setStroke(7, lineColor)
            setSize(40, 40)
        }
    }

    AndroidView(
        factory = { map },
        modifier = modifier,
        update = { m ->
            m.overlayManager.tilesOverlay.setColorFilter(if (dark) TilesOverlay.INVERT_COLORS else null)
            if (m.overlays.firstOrNull() !== line) {
                m.overlays.clear()
                m.overlays.add(line)
                m.overlays.add(dot)
                if (geo.size >= 2) {
                    m.post { m.zoomToBoundingBox(BoundingBox.fromGeoPoints(geo), false, 90) }
                }
            }
            if (marker != null) {
                dot.position = GeoPoint(marker.lat, marker.lng)
                dot.isEnabled = true
            } else {
                dot.isEnabled = false
            }
            m.invalidate()
        },
    )
}
