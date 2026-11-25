package com.healthstats.app.data.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

/** Info about one sport: names (fr/en), icon, color, and two flags. */
class SportInfo(
    val fr: String,
    val en: String,
    val icon: ImageVector,
    val color: Color,
    val strength: Boolean = false, // strength session (shows sets/reps)
    val outdoor: Boolean = false,  // normally has a GPS route
)

/** Key = Health Connect exercise type number. */
val Sports: Map<Int, SportInfo> = mapOf(
    56 to SportInfo("Course", "Running", Icons.Rounded.DirectionsRun, Color(0xFFFF2020), outdoor = true),
    57 to SportInfo("Course (tapis)", "Treadmill", Icons.Rounded.DirectionsRun, Color(0xFFFF5A5A)),
    79 to SportInfo("Marche", "Walking", Icons.Rounded.DirectionsWalk, Color(0xFF34C759), outdoor = true),
    37 to SportInfo("Randonnée", "Hiking", Icons.Rounded.Hiking, Color(0xFF2E9E5B), outdoor = true),
    8 to SportInfo("Vélo", "Cycling", Icons.Rounded.DirectionsBike, Color(0xFFFFC700), outdoor = true),
    9 to SportInfo("Vélo d'appart.", "Stationary bike", Icons.Rounded.PedalBike, Color(0xFFFFD84D)),
    74 to SportInfo("Natation", "Swimming", Icons.Rounded.Pool, Color(0xFF2D9CDB)),
    73 to SportInfo("Nage en eau libre", "Open water", Icons.Rounded.Pool, Color(0xFF1E88C8), outdoor = true),
    70 to SportInfo("Musculation", "Strength", Icons.Rounded.FitnessCenter, Color(0xFFB36BFF), strength = true),
    81 to SportInfo("Haltérophilie", "Weightlifting", Icons.Rounded.FitnessCenter, Color(0xFF9B51E0), strength = true),
    13 to SportInfo("Callisthénie", "Calisthenics", Icons.Rounded.AccessibilityNew, Color(0xFFA56EFF), strength = true),
    83 to SportInfo("Yoga", "Yoga", Icons.Rounded.SelfImprovement, Color(0xFFFF8FB1)),
    48 to SportInfo("Pilates", "Pilates", Icons.Rounded.SelfImprovement, Color(0xFFFFA3C4)),
    71 to SportInfo("Étirements", "Stretching", Icons.Rounded.Spa, Color(0xFFFFB3D1)),
    33 to SportInfo("Respiration guidée", "Guided breathing", Icons.Rounded.Spa, Color(0xFF9AD4D6)),
    36 to SportInfo("HIIT", "HIIT", Icons.Rounded.LocalFireDepartment, Color(0xFFFF7A00)),
    10 to SportInfo("Boot camp", "Boot camp", Icons.Rounded.LocalFireDepartment, Color(0xFFFF8F3A)),
    26 to SportInfo("Cours collectif", "Exercise class", Icons.Rounded.Groups, Color(0xFFFF9E40)),
    16 to SportInfo("Danse", "Dancing", Icons.Rounded.MusicNote, Color(0xFFE91E8C)),
    53 to SportInfo("Aviron", "Rowing", Icons.Rounded.Rowing, Color(0xFF00B8A9), outdoor = true),
    54 to SportInfo("Rameur", "Rowing machine", Icons.Rounded.Rowing, Color(0xFF26C6B8)),
    25 to SportInfo("Elliptique", "Elliptical", Icons.Rounded.DirectionsRun, Color(0xFF8E8E93)),
    68 to SportInfo("Escaliers", "Stair climbing", Icons.Rounded.Stairs, Color(0xFF8E8E93)),
    69 to SportInfo("Simulateur d'escaliers", "Stair machine", Icons.Rounded.Stairs, Color(0xFF9E9EA3)),
    51 to SportInfo("Escalade", "Rock climbing", Icons.Rounded.Terrain, Color(0xFF8D6E63), outdoor = true),
    46 to SportInfo("Paddle / canoë", "Paddling", Icons.Rounded.Kayaking, Color(0xFF00ACC1), outdoor = true),
    58 to SportInfo("Voile", "Sailing", Icons.Rounded.Sailing, Color(0xFF29B6F6), outdoor = true),
    59 to SportInfo("Plongée", "Scuba diving", Icons.Rounded.Pool, Color(0xFF0277BD)),
    72 to SportInfo("Surf", "Surfing", Icons.Rounded.Surfing, Color(0xFF26A69A), outdoor = true),
    80 to SportInfo("Water-polo", "Water polo", Icons.Rounded.Pool, Color(0xFF42A5F5)),
    47 to SportInfo("Parapente", "Paragliding", Icons.Rounded.Paragliding, Color(0xFF7E57C2), outdoor = true),
    61 to SportInfo("Ski", "Skiing", Icons.Rounded.DownhillSkiing, Color(0xFF4FC3F7), outdoor = true),
    62 to SportInfo("Snowboard", "Snowboarding", Icons.Rounded.Snowboarding, Color(0xFF4DD0E1), outdoor = true),
    63 to SportInfo("Raquettes", "Snowshoeing", Icons.Rounded.Snowshoeing, Color(0xFF80DEEA), outdoor = true),
    39 to SportInfo("Patinage sur glace", "Ice skating", Icons.Rounded.IceSkating, Color(0xFF81D4FA), outdoor = true),
    60 to SportInfo("Patin / roller", "Skating", Icons.Rounded.RollerSkating, Color(0xFFFF6E40), outdoor = true),
    38 to SportInfo("Hockey sur glace", "Ice hockey", Icons.Rounded.SportsHockey, Color(0xFF64B5F6)),
    52 to SportInfo("Roller hockey", "Roller hockey", Icons.Rounded.SportsHockey, Color(0xFFFF8A65)),
    2 to SportInfo("Badminton", "Badminton", Icons.Rounded.SportsTennis, Color(0xFF5AC8FA)),
    75 to SportInfo("Tennis de table", "Table tennis", Icons.Rounded.SportsTennis, Color(0xFF4DB6AC)),
    76 to SportInfo("Tennis", "Tennis", Icons.Rounded.SportsTennis, Color(0xFFC6E03A)),
    66 to SportInfo("Squash", "Squash", Icons.Rounded.SportsTennis, Color(0xFFAED581)),
    50 to SportInfo("Racquetball", "Racquetball", Icons.Rounded.SportsTennis, Color(0xFFDCE775)),
    28 to SportInfo("Football US", "American football", Icons.Rounded.SportsFootball, Color(0xFF8B5A2B)),
    29 to SportInfo("Football australien", "Australian football", Icons.Rounded.SportsFootball, Color(0xFFA1887F)),
    64 to SportInfo("Football", "Soccer", Icons.Rounded.SportsSoccer, Color(0xFF30B050), outdoor = true),
    55 to SportInfo("Rugby", "Rugby", Icons.Rounded.SportsRugby, Color(0xFF6D4C41)),
    5 to SportInfo("Basket", "Basketball", Icons.Rounded.SportsBasketball, Color(0xFFFF8A00)),
    78 to SportInfo("Volley", "Volleyball", Icons.Rounded.SportsVolleyball, Color(0xFFFFB74D)),
    35 to SportInfo("Handball", "Handball", Icons.Rounded.SportsHandball, Color(0xFFEF6C00)),
    4 to SportInfo("Baseball", "Baseball", Icons.Rounded.SportsBaseball, Color(0xFFD32F2F)),
    65 to SportInfo("Softball", "Softball", Icons.Rounded.SportsBaseball, Color(0xFFE57373)),
    14 to SportInfo("Cricket", "Cricket", Icons.Rounded.SportsCricket, Color(0xFF66BB6A)),
    32 to SportInfo("Golf", "Golf", Icons.Rounded.SportsGolf, Color(0xFF43A047), outdoor = true),
    31 to SportInfo("Frisbee", "Frisbee", Icons.Rounded.Sports, Color(0xFFFFCA28), outdoor = true),
    11 to SportInfo("Boxe", "Boxing", Icons.Rounded.SportsMma, Color(0xFFC62828)),
    44 to SportInfo("Arts martiaux", "Martial arts", Icons.Rounded.SportsMartialArts, Color(0xFFAD1457)),
    27 to SportInfo("Escrime", "Fencing", Icons.Rounded.SportsMartialArts, Color(0xFF880E4F)),
    34 to SportInfo("Gymnastique", "Gymnastics", Icons.Rounded.SportsGymnastics, Color(0xFFBA68C8)),
    82 to SportInfo("Fauteuil roulant", "Wheelchair", Icons.Rounded.Accessible, Color(0xFF5C6BC0), outdoor = true),
    0 to SportInfo("Autre", "Workout", Icons.Rounded.Bolt, Color(0xFF8E8E93)),
)

fun sportOf(type: Int): SportInfo = Sports[type] ?: Sports.getValue(0)

private val KnownApps: Map<String, String> = mapOf(
    "com.google.android.apps.fitness" to "Google Fit",
    "com.google.android.apps.healthdata" to "Health Connect",
    "com.sec.android.app.shealth" to "Samsung Health",
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
    "com.suunto.connectivity.suuntoconnectivity" to "Suunto",
    "com.nike.plusgps" to "Nike Run Club",
    "com.runtastic.android" to "Adidas Running",
    "com.ouraring.oura" to "Oura",
    "com.whoop.android" to "WHOOP",
    "com.wahoofitness.fitness" to "Wahoo",
    "com.onepeloton.callisto" to "Peloton",
    "com.myfitnesspal.android" to "MyFitnessPal",
    "com.komoot.android" to "Komoot",
    "com.mapmyrun.android2" to "MapMyRun",
    "com.hevy" to "Hevy",
    "com.withings.wiscale2" to "Withings",
    "com.coros.coros" to "COROS",
    "com.sec.android.app.shealth.wearable" to "Galaxy Watch",
    "com.google.android.wearable.healthservices" to "Wear OS",
    "com.healthstats.app" to "HealthStats",
    "import" to "Import GPX/FIT",
    "intervals" to "Intervals.icu",
    "com.stt.android.suunto" to "Suunto",
    "com.stt.android" to "Suunto",
    "com.hihonor.health" to "Honor Health",
    "com.google.android.apps.wear.companion" to "Pixel Watch",
    "com.samsung.android.wear.shealth" to "Galaxy Watch",
    "com.amazfit.zepp" to "Zepp",
    "com.coros.coros.app" to "COROS",
    "com.nothing.cmf.watch" to "CMF Watch",
    "com.polar.polarflow.beat" to "Polar Beat",
    "com.garmin.connect.mobile" to "Garmin Connect",
    "com.wahoofitness.elemnt" to "Wahoo",
    "com.ticwatch.health" to "Mobvoi",
    "com.mobvoi.companion.at" to "Mobvoi",
)

/** Readable name of the app that wrote the data. [real] = label read from the phone, if any. */
fun sourceLabel(pkg: String, real: String? = null): String {
    if (pkg.isEmpty()) return "—"
    if (!real.isNullOrEmpty()) return real
    KnownApps[pkg]?.let { return it }
    val parts = pkg.split('.').filter { it.isNotEmpty() && it !in setOf("android", "app", "apps", "mobile") }
    val last = parts.lastOrNull() ?: pkg
    return last.replaceFirstChar { it.uppercase() }
}
