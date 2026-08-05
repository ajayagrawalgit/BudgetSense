package com.budgetsense.budgetsense

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import kotlin.math.floor
import kotlin.math.max

/**
 * Spend-activity graph: a GitHub-contributions style calendar, but in the
 * BudgetSense clay palette. Each square is one day, shaded light to dark by how
 * many expense records fell on that day (few to many).
 *
 * The widget is built from TWO separate components so its dimensions never skew:
 *   1. The BACKGROUND is a native drawable on the FrameLayout (a crisp paper
 *      card, or a frosted-glass panel under the transparent theme). Its corners
 *      and edges scale cleanly and never distort.
 *   2. The CONTENT (branding, calendar, footer, legend) is a transparent bitmap
 *      drawn here and shown with fitCenter, so it scales UNIFORMLY, never
 *      stretched.
 *
 * Layout: BudgetSense branding and month labels across the top, weekday labels
 * (Mon/Wed/Fri) down the left, seven rows Sun..Sat, most recent week on the
 * right, a motivating footer line bottom-left and a Less..More legend bottom
 * right. It fills the available width (more weeks on wider phones) and keeps a
 * fixed row height, so it never stretches vertically.
 */
class NoSpendWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId)
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val states = WidgetSupport.value(context, "spendGrid", "")
        val footer = WidgetSupport.value(context, "footerText", "Mindful spending")
        val monthsRaw = WidgetSupport.value(context, "spendMonths", "")
        val transparent =
            WidgetSupport.value(context, "widgetTransparent", "false") == "true"
        val masked =
            states.length != WEEKS * 7 || states.any { it !in "01234." }
        val months = monthsRaw.split('|')
            .let { if (it.size == WEEKS) it else List(WEEKS) { "" } }

        val opts = manager.getAppWidgetOptions(id)
        val widthDp = opts
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            .takeIf { it > 0 } ?: 320
        val heightDp = opts
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            .takeIf { it > 0 } ?: 130

        val bitmap =
            draw(context, states, footer, months, masked, transparent, widthDp, heightDp)

        val views = RemoteViews(context.packageName, R.layout.widget_no_spend)
        // The background is a real native drawable, kept separate from the
        // content bitmap so the card never distorts. Swap it for the theme.
        views.setInt(
            R.id.no_spend_root,
            "setBackgroundResource",
            if (transparent) R.drawable.widget_no_spend_glass
            else R.drawable.widget_no_spend_card,
        )
        views.setImageViewBitmap(R.id.no_spend_grid, bitmap)
        views.setOnClickPendingIntent(
            R.id.no_spend_root,
            WidgetSupport.openAppIntent(context),
        )
        manager.updateAppWidget(id, views)
    }

    @Suppress("LongParameterList", "LongMethod", "CyclomaticComplexMethod")
    private fun draw(
        context: Context,
        states: String,
        footer: String,
        months: List<String>,
        masked: Boolean,
        transparent: Boolean,
        widthDp: Int,
        heightDp: Int,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val w = widthDp * density
        val h = heightDp * density
        val cap = 1400f
        val longest = max(w, h)
        val s = if (longest > cap) cap / longest else 1f
        val bw = (w * s).toInt().coerceAtLeast(1)
        val bh = (h * s).toInt().coerceAtLeast(1)
        val px = density * s

        // Transparent content only. The card/glass background is a native
        // drawable behind this bitmap, so we draw NO card here.
        val bitmap = Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val pad = 14f * px
        val brandSize = 12f * px
        val labelSize = 8.5f * px
        val footerSize = 10f * px
        val rows = 7

        // Level palette: light (few records) to dark (many), from the
        // BudgetSense clay accent. In glass mode the empty cell goes frosted so
        // the wallpaper shows through; the clay shades stay intact.
        val levels = intArrayOf(
            if (transparent) 0x33FFFFFF else color(context, R.color.widget_grid_l0),
            color(context, R.color.widget_grid_l1),
            color(context, R.color.widget_grid_l2),
            color(context, R.color.widget_grid_l3),
            color(context, R.color.widget_grid_l4),
        )
        val accent = color(context, R.color.widget_accent)
        val brandCol = accent
        val labelCol =
            if (transparent) color(context, R.color.widget_ink_soft)
            else color(context, R.color.widget_ink_faint)
        val footerCol = color(context, R.color.widget_ink_soft)
        // On glass, a soft light halo keeps dark text readable over any wallpaper.
        val shadow = if (transparent) 0xB3FFFFFF.toInt() else 0

        // Header: BudgetSense branding (top left).
        val brandPaint = textPaint(brandCol, brandSize, bold = true, shadow = shadow, px = px)
        canvas.drawText("BudgetSense", pad, pad + brandSize, brandPaint)

        val labelPaint = textPaint(labelCol, labelSize, shadow = shadow, px = px)
        val footerPaint = textPaint(footerCol, footerSize, bold = true, shadow = shadow, px = px)

        val gutter = labelPaint.measureText("Wed") + 5f * px
        val monthStripTop = pad + brandSize + 7f * px
        val gridTop = monthStripTop + labelSize + 5f * px
        val footerBaseline = bh - pad
        val gridBottom = footerBaseline - footerSize - 8f * px

        val gridLeft = pad + gutter
        val availW = (bw - pad) - gridLeft
        val availH = gridBottom - gridTop
        if (availW <= 0 || availH <= 0) return bitmap

        // Fixed, GitHub-like squares sized from the row height, so the widget
        // never stretches vertically. Columns then fill the available width
        // (more weeks on wider phones), capped at the full year.
        val gapRatio = 0.3f
        var cell = availH / (rows + (rows - 1) * gapRatio)
        cell = cell.coerceAtMost(18f * px)
        val gap = cell * gapRatio
        val radius = cell * 0.18f
        val step = cell + gap
        val cols = floor((availW + gap) / step).toInt().coerceIn(1, WEEKS)

        val blockH = rows * cell + (rows - 1) * gap
        val gridTopC = gridTop + (availH - blockH).coerceAtLeast(0f) / 2f

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

        // Weekday gutter labels (GitHub shows Mon / Wed / Fri).
        labelPaint.textAlign = Paint.Align.RIGHT
        val weekdays = mapOf(1 to "Mon", 3 to "Wed", 5 to "Fri")
        for ((row, name) in weekdays) {
            val cy = gridTopC + row * step + cell / 2f + labelSize / 2.8f
            canvas.drawText(name, gridLeft - 4f * px, cy, labelPaint)
        }

        // Grid + month labels. Newest week on the right.
        labelPaint.textAlign = Paint.Align.LEFT
        var lastMonthX = -1000f
        for (col in 0 until cols) {
            val srcWeek = WEEKS - cols + col
            val x = gridLeft + col * step
            val m = months[srcWeek]
            if (m.isNotEmpty() &&
                x - lastMonthX > labelPaint.measureText("Sep") + 6f * px
            ) {
                canvas.drawText(m, x, monthStripTop + labelSize, labelPaint)
                lastMonthX = x
            }
            for (row in 0 until rows) {
                val ch = if (masked) '0' else states[srcWeek * 7 + row]
                if (ch == '.') continue // future day
                val level = (ch - '0').coerceIn(0, 4)
                val top = gridTopC + row * step
                val rect = RectF(x, top, x + cell, top + cell)
                fill.color = levels[level]
                canvas.drawRoundRect(rect, radius, radius, fill)
            }
        }

        // Footer: motivating line (left) and a Less..More legend (right).
        footerPaint.textAlign = Paint.Align.LEFT
        val legendW = drawLegend(canvas, levels, labelPaint, bw - pad, footerBaseline, px)
        val footerMax = (bw - pad - legendW - 10f * px) - pad
        canvas.drawText(
            ellipsize(footer, footerPaint, footerMax),
            pad,
            footerBaseline,
            footerPaint,
        )

        return bitmap
    }

    /** Draws "Less [] [] [] [] [] More" right-aligned; returns its total width. */
    private fun drawLegend(
        canvas: Canvas,
        levels: IntArray,
        labelPaint: Paint,
        right: Float,
        baseline: Float,
        px: Float,
    ): Float {
        val box = 8f * px
        val gap = 3f * px
        val radius = box * 0.2f
        val prev = labelPaint.textAlign
        labelPaint.textAlign = Paint.Align.LEFT
        val moreW = labelPaint.measureText("More")
        val lessW = labelPaint.measureText("Less")
        val boxesW = levels.size * box + (levels.size - 1) * gap
        val totalW = lessW + 4f * px + boxesW + 4f * px + moreW
        val startX = right - totalW
        val boxTop = baseline - box + 1f * px

        canvas.drawText("Less", startX, baseline, labelPaint)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        var bx = startX + lessW + 4f * px
        for (c in levels) {
            fill.color = c
            canvas.drawRoundRect(RectF(bx, boxTop, bx + box, boxTop + box), radius, radius, fill)
            bx += box + gap
        }
        canvas.drawText("More", bx - gap + 4f * px, baseline, labelPaint)
        labelPaint.textAlign = prev
        return totalW
    }

    private fun ellipsize(text: String, paint: Paint, maxWidth: Float): String {
        if (maxWidth <= 0f) return ""
        if (paint.measureText(text) <= maxWidth) return text
        var end = text.length
        while (end > 0 && paint.measureText(text.substring(0, end) + "\u2026") > maxWidth) {
            end--
        }
        return if (end <= 0) "" else text.substring(0, end).trimEnd() + "\u2026"
    }

    private fun textPaint(
        col: Int,
        size: Float,
        bold: Boolean = false,
        shadow: Int = 0,
        px: Float,
    ): Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = col
        textSize = size
        if (bold) typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        if (shadow != 0) setShadowLayer(2.5f * px, 0f, 0f, shadow)
    }

    /** Config-aware colour lookup that also works below API 23. */
    private fun color(context: Context, id: Int): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.getColor(id)
        } else {
            @Suppress("DEPRECATION")
            context.resources.getColor(id)
        }

    companion object {
        // Must match kNoSpendWeeks in widget_sync.dart.
        private const val WEEKS = 53
    }
}
