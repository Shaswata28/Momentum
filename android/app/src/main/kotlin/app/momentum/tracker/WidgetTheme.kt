package app.momentum.tracker

import android.graphics.Color
import android.text.SpannableString
import android.text.Spanned
import android.text.style.TypefaceSpan
import android.widget.RemoteViews

/**
 * Native counterparts of the Flutter palettes. System mode leaves XML colors
 * intact so the launcher can re-inflate day/night resources even without Flutter.
 */
internal data class WidgetTheme(
    val background: Int,
    val card: Int,
    val progress: Int,
    val primary: Int? = null,
    val secondary: Int? = null,
    val divider: Int? = null,
    val retro: Boolean = false,
) {
    fun applyTo(views: RemoteViews) = with(views) {
        setInt(R.id.widget_root, "setBackgroundResource", background)
        setInt(R.id.layout_active_task, "setBackgroundResource", card)
        setInt(R.id.layout_next_task, "setBackgroundResource", card)
        setImageViewResource(R.id.progress_current, progress)
        primary?.let { color ->
            listOf(R.id.tv_headline_title, R.id.tv_total_progress).forEach {
                setTextColor(it, color)
            }
        }
        secondary?.let { color ->
            listOf(R.id.tv_headline_label, R.id.tv_next_label, R.id.tv_next_task_title,
                R.id.tv_next_task_time).forEach { setTextColor(it, color) }
        }
        divider?.let { setInt(R.id.widget_divider, "setBackgroundColor", it) }
    }

    fun text(value: String): CharSequence = if (retro) {
        SpannableString(value).apply {
            setSpan(TypefaceSpan("monospace"), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    } else value

    companion object {
        fun fromMode(mode: String?): WidgetTheme = when (mode) {
            "light" -> WidgetTheme(
                R.drawable.widget_light_background,
                R.drawable.widget_light_card,
                R.drawable.widget_light_progress,
                Color.parseColor("#0F172A"), Color.parseColor("#475569"),
                Color.parseColor("#E2E8F0"), retro = false,
            )
            "dark" -> WidgetTheme(
                R.drawable.widget_dark_background,
                R.drawable.widget_dark_card,
                R.drawable.widget_dark_progress,
                Color.parseColor("#F8FAFC"), Color.parseColor("#94A3B8"),
                Color.parseColor("#2B2D3E"), retro = false,
            )
            "retroLight" -> WidgetTheme(
                R.drawable.widget_retro_light_background,
                R.drawable.widget_retro_light_card,
                R.drawable.widget_retro_light_progress,
                Color.parseColor("#2A2622"), Color.parseColor("#4A443B"),
                Color.parseColor("#DDD6C2"), retro = true,
            )
            "retroDark" -> WidgetTheme(
                R.drawable.widget_retro_dark_background,
                R.drawable.widget_retro_dark_card,
                R.drawable.widget_retro_dark_progress,
                Color.parseColor("#E4E5E9"), Color.parseColor("#C9CBD1"),
                Color.parseColor("#4A4A57"), retro = true,
            )
            else -> WidgetTheme(
                R.drawable.widget_background, R.drawable.widget_card,
                R.drawable.widget_progress,
            )
        }
    }
}
