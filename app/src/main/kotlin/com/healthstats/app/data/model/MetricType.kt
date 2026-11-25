package com.healthstats.app.data.model

/** Health Connect values we can read as a list of (time, value). [permission] = end of the permission name. */
enum class MetricType(val permission: String, val unit: String) {
    RestingHr("READ_RESTING_HEART_RATE", "bpm"),
    Hrv("READ_HEART_RATE_VARIABILITY", "ms"),
    Spo2("READ_OXYGEN_SATURATION", "%"),
    Vo2("READ_VO2_MAX", "ml/kg/min"),
    Resp("READ_RESPIRATORY_RATE", "/min"),
    BodyFat("READ_BODY_FAT", "%"),
    Systolic("READ_BLOOD_PRESSURE", "mmHg"),
    Temp("READ_BODY_TEMPERATURE", "°C"),
    Weight("READ_WEIGHT", "kg"),
}

/** Curves recorded during a session. */
enum class SampleKind { Speed, Power }
