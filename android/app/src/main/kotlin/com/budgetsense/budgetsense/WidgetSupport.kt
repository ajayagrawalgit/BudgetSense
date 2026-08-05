package com.budgetsense.budgetsense

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Shared helpers for the home-screen widgets: where the display data lives, how
 * to broadcast an update to every widget, and the PendingIntents that open the
 * app (optionally straight into quick-add).
 */
object WidgetSupport {
    const val PREFS_NAME = "budgetsense_widget"
    const val ACTION_QUICK_ADD = "com.budgetsense.budgetsense.QUICK_ADD"
    const val EXTRA_ACTION = "widget_action"
    const val VALUE_QUICK_ADD = "quick_add"
    const val VALUE_QUICK_ADD_CHAI = "quick_add_chai"

    private val providers = listOf(
        DashboardWidgetProvider::class.java,
        InsightsWidgetProvider::class.java,
        QuickAddWidgetProvider::class.java,
        BalanceWidgetProvider::class.java,
        BucketsWidgetProvider::class.java,
        RatesWidgetProvider::class.java,
        RunwayWidgetProvider::class.java,
        NextDueWidgetProvider::class.java,
        QuickActionsWidgetProvider::class.java,
        GlanceWidgetProvider::class.java,
        NoSpendWidgetProvider::class.java,
    )

    fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun value(context: Context, key: String, fallback: String = "-"): String =
        prefs(context).getString(key, fallback) ?: fallback

    /** Ask every installed BudgetSense widget to redraw from the latest data. */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        for (cls in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isEmpty()) continue
            val intent = Intent(context, cls).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }

    private fun immutable(flags: Int): Int =
        flags or PendingIntent.FLAG_IMMUTABLE

    /** Opens the app normally (tap on the dashboard / insights widgets). */
    fun openAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            immutable(PendingIntent.FLAG_UPDATE_CURRENT),
        )
    }

    /** Opens the app and asks it to present the quick-add sheet. */
    fun quickAddIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_QUICK_ADD
            putExtra(EXTRA_ACTION, VALUE_QUICK_ADD)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            1,
            intent,
            immutable(PendingIntent.FLAG_UPDATE_CURRENT),
        )
    }

    /** Opens the app into a quick-add prefilled by a preset (e.g. the chai
     *  shortcut). [value] is the action string Flutter consumes; [requestCode]
     *  must be unique per distinct PendingIntent. */
    fun presetIntent(context: Context, value: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_QUICK_ADD
            putExtra(EXTRA_ACTION, value)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            immutable(PendingIntent.FLAG_UPDATE_CURRENT),
        )
    }
}
