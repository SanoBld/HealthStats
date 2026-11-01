package com.healthstats.app

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/** Écran exigé par Health Connect : explique pourquoi l'app lit les données. */
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val t = TextView(this)
        t.setPadding(48, 96, 48, 48)
        t.textSize = 16f
        t.text = "HealthStats lit vos séances, trajets GPS, pas, fréquence cardiaque, " +
            "sommeil et poids depuis Health Connect, uniquement pour les afficher sur votre appareil. " +
            "Aucune donnée n'est envoyée ailleurs."
        setContentView(t)
    }
}
