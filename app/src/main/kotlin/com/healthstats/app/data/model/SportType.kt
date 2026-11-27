package com.healthstats.app.data.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import java.util.Locale

/** One sport: names (fr/en), icon, color. */
class SportInfo(
    val fr: String,
    val en: String,
    val icon: ImageVector,
    val color: Color,
) {
    val name: String get() = if (Locale.getDefault().language == "fr") fr else en
}

private fun s(type: Int, fr: String, en: String, icon: ImageVector, color: Long) =
    type to SportInfo(fr, en, icon, Color(color))

/** Key = Health Connect exercise type number. */
val Sports: Map<Int, SportInfo> = mapOf(
    s(56, "Course", "Running", Icons.Rounded.DirectionsRun, 0xFFFF3B30),
    s(57, "Course (tapis)", "Treadmill", Icons.Rounded.DirectionsRun, 0xFFFF6B5E),
    s(79, "Marche", "Walking", Icons.Rounded.DirectionsWalk, 0xFF34C759),
    s(37, "Randonnée", "Hiking", Icons.Rounded.Hiking, 0xFF2E9E5B),
    s(8, "Vélo", "Cycling", Icons.Rounded.DirectionsBike, 0xFFFFB800),
    s(9, "Vélo d'appartement", "Stationary bike", Icons.Rounded.PedalBike, 0xFFFFCC33),
    s(74, "Natation", "Swimming", Icons.Rounded.Pool, 0xFF2D9CDB),
    s(73, "Nage en eau libre", "Open water swim", Icons.Rounded.Pool, 0xFF1E88C8),
    s(70, "Musculation", "Strength training", Icons.Rounded.FitnessCenter, 0xFFB36BFF),
    s(81, "Haltérophilie", "Weightlifting", Icons.Rounded.FitnessCenter, 0xFF9B51E0),
    s(13, "Callisthénie", "Calisthenics", Icons.Rounded.AccessibilityNew, 0xFFA56EFF),
    s(83, "Yoga", "Yoga", Icons.Rounded.SelfImprovement, 0xFFFF8FB1),
    s(48, "Pilates", "Pilates", Icons.Rounded.SelfImprovement, 0xFFFFA3C4),
    s(71, "Étirements", "Stretching", Icons.Rounded.Spa, 0xFFFFB3D1),
    s(33, "Respiration guidée", "Guided breathing", Icons.Rounded.Spa, 0xFF7CC8CB),
    s(36, "HIIT", "HIIT", Icons.Rounded.LocalFireDepartment, 0xFFFF7A00),
    s(10, "Boot camp", "Boot camp", Icons.Rounded.LocalFireDepartment, 0xFFFF8F3A),
    s(26, "Cours collectif", "Exercise class", Icons.Rounded.Groups, 0xFFFF9E40),
    s(16, "Danse", "Dancing", Icons.Rounded.MusicNote, 0xFFE91E8C),
    s(53, "Aviron", "Rowing", Icons.Rounded.Rowing, 0xFF00B8A9),
    s(54, "Rameur", "Rowing machine", Icons.Rounded.Rowing, 0xFF26C6B8),
    s(25, "Elliptique", "Elliptical", Icons.Rounded.DirectionsRun, 0xFF8E8E93),
    s(68, "Escaliers", "Stair climbing", Icons.Rounded.Stairs, 0xFF8E8E93),
    s(69, "Simulateur d'escaliers", "Stair machine", Icons.Rounded.Stairs, 0xFF9E9EA3),
    s(51, "Escalade", "Rock climbing", Icons.Rounded.Terrain, 0xFF8D6E63),
    s(46, "Paddle / canoë", "Paddling", Icons.Rounded.Kayaking, 0xFF00ACC1),
    s(58, "Voile", "Sailing", Icons.Rounded.Sailing, 0xFF29B6F6),
    s(59, "Plongée", "Scuba diving", Icons.Rounded.Pool, 0xFF0277BD),
    s(72, "Surf", "Surfing", Icons.Rounded.Surfing, 0xFF26A69A),
    s(80, "Water-polo", "Water polo", Icons.Rounded.Pool, 0xFF42A5F5),
    s(61, "Ski", "Skiing", Icons.Rounded.DownhillSkiing, 0xFF4FC3F7),
    s(62, "Snowboard", "Snowboarding", Icons.Rounded.Snowboarding, 0xFF4DD0E1),
    s(63, "Raquettes", "Snowshoeing", Icons.Rounded.DirectionsWalk, 0xFF80DEEA),
    s(39, "Patinage sur glace", "Ice skating", Icons.Rounded.IceSkating, 0xFF81D4FA),
    s(60, "Roller / patin", "Skating", Icons.Rounded.DirectionsRun, 0xFFFF6E40),
    s(38, "Hockey sur glace", "Ice hockey", Icons.Rounded.SportsHockey, 0xFF64B5F6),
    s(52, "Roller hockey", "Roller hockey", Icons.Rounded.SportsHockey, 0xFFFF8A65),
    s(2, "Badminton", "Badminton", Icons.Rounded.SportsTennis, 0xFF5AC8FA),
    s(75, "Tennis de table", "Table tennis", Icons.Rounded.SportsTennis, 0xFF4DB6AC),
    s(76, "Tennis", "Tennis", Icons.Rounded.SportsTennis, 0xFFC6E03A),
    s(66, "Squash", "Squash", Icons.Rounded.SportsTennis, 0xFFAED581),
    s(50, "Racquetball", "Racquetball", Icons.Rounded.SportsTennis, 0xFFDCE775),
    s(28, "Football US", "American football", Icons.Rounded.SportsFootball, 0xFF8B5A2B),
    s(29, "Football australien", "Australian football", Icons.Rounded.SportsFootball, 0xFFA1887F),
    s(64, "Football", "Soccer", Icons.Rounded.SportsSoccer, 0xFF30B050),
    s(55, "Rugby", "Rugby", Icons.Rounded.SportsRugby, 0xFF6D4C41),
    s(5, "Basket", "Basketball", Icons.Rounded.SportsBasketball, 0xFFFF8A00),
    s(78, "Volley", "Volleyball", Icons.Rounded.SportsVolleyball, 0xFFFFB74D),
    s(35, "Handball", "Handball", Icons.Rounded.SportsHandball, 0xFFEF6C00),
    s(4, "Baseball", "Baseball", Icons.Rounded.SportsBaseball, 0xFFD32F2F),
    s(65, "Softball", "Softball", Icons.Rounded.SportsBaseball, 0xFFE57373),
    s(14, "Cricket", "Cricket", Icons.Rounded.SportsCricket, 0xFF66BB6A),
    s(32, "Golf", "Golf", Icons.Rounded.SportsGolf, 0xFF43A047),
    s(31, "Frisbee", "Frisbee", Icons.Rounded.Sports, 0xFFFFCA28),
    s(11, "Boxe", "Boxing", Icons.Rounded.SportsMma, 0xFFC62828),
    s(44, "Arts martiaux", "Martial arts", Icons.Rounded.SportsMartialArts, 0xFFAD1457),
    s(27, "Escrime", "Fencing", Icons.Rounded.SportsMartialArts, 0xFF880E4F),
    s(34, "Gymnastique", "Gymnastics", Icons.Rounded.SportsGymnastics, 0xFFBA68C8),
    s(82, "Fauteuil roulant", "Wheelchair", Icons.Rounded.Accessible, 0xFF5C6BC0),
    s(0, "Autre", "Workout", Icons.Rounded.Bolt, 0xFF8E8E93),
)

fun sportOf(type: Int): SportInfo = Sports[type] ?: Sports.getValue(0)

private val KnownApps: Map<String, String> = mapOf(
    "com.google.android.apps.fitness" to "Google Fit",
    "com.google.android.apps.healthdata" to "Health Connect",
    "com.sec.android.app.shealth" to "Samsung Health",
    "com.samsung.android.wear.shealth" to "Galaxy Watch",
    "com.garmin.android.apps.connectmobile" to "Garmin Connect",
    "com.strava" to "Strava",
    "com.fitbit.FitbitMobile" to "Fitbit",
    "com.huawei.health" to "Huawei Health",
    "com.xiaomi.wearable" to "Mi Fitness",
    "com.mi.health" to "Mi Fitness",
    "com.zepp.health" to "Zepp",
    "com.huami.watch.hmwatchmanager" to "Zepp",
    "com.heytap.health" to "HeyTap Health",
    "com.polar.polarflow" to "Polar Flow",
    "com.stt.android.suunto" to "Suunto",
    "com.nike.plusgps" to "Nike Run Club",
    "com.ouraring.oura" to "Oura",
    "com.whoop.android" to "WHOOP",
    "com.wahoofitness.fitness" to "Wahoo",
    "com.onepeloton.callisto" to "Peloton",
    "com.myfitnesspal.android" to "MyFitnessPal",
    "com.komoot.android" to "Komoot",
    "com.hevy" to "Hevy",
    "com.withings.wiscale2" to "Withings",
    "com.coros.coros" to "COROS",
    "com.google.android.wearable.healthservices" to "Wear OS",
    "com.nothing.cmf.watch" to "CMF Watch",
    "com.nothing.nothingx" to "Nothing X",
    "com.healthstats.app" to "HealthStats",
)

/** Readable name of the app that wrote the data. */
fun sourceLabel(pkg: String): String {
    if (pkg.isEmpty()) return "—"
    KnownApps[pkg]?.let { return it }
    val parts = pkg.split('.').filter { it.isNotEmpty() && it !in setOf("android", "app", "apps", "mobile", "com", "org") }
    val last = parts.lastOrNull() ?: pkg
    return last.replaceFirstChar { it.uppercase() }
}
