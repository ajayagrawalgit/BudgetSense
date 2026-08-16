package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/**
 * Base for the widgets that only read a few strings out of shared preferences,
 * drop them into text views, and open the app when tapped.
 *
 * Subclasses declare their layout and their field bindings; everything else
 * (iterating widget ids, inflating RemoteViews, wiring the root tap target,
 * pushing the update) happens once here. Widgets that need more than this,
 * such as size-aware layouts or custom drawing, extend AppWidgetProvider
 * directly instead of bending this class out of shape.
 *
 * @param layoutId the RemoteViews layout to inflate.
 * @param rootId the view that should open the app when tapped, or null for
 *   widgets whose only tap targets are their own buttons.
 */
abstract class SimpleWidgetProvider(
    private val layoutId: Int,
    private val rootId: Int? = R.id.widget_root,
) : AppWidgetProvider() {

    /** One preference key rendered into one text view, with a fallback. */
    protected data class TextBinding(
        val viewId: Int,
        val key: String,
        val fallback: String = "-",
    )

    /** The text fields this widget shows. Read once per redraw. */
    protected abstract val textBindings: List<TextBinding>

    /**
     * Hook for anything beyond plain text, for example progress bars or extra
     * tap targets. Called after [textBindings] are applied.
     */
    protected open fun onBind(context: Context, views: RemoteViews) = Unit

    final override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)
            for (binding in textBindings) {
                views.setTextViewText(
                    binding.viewId,
                    WidgetSupport.value(context, binding.key, binding.fallback),
                )
            }
            onBind(context, views)
            rootId?.let {
                views.setOnClickPendingIntent(it, WidgetSupport.openAppIntent(context))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
