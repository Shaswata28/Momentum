
### Palette

|Token|Light (beige console)|Dark (gray console)|
|---|---|---|
|Background|`#D9D2BE`|`#2B2B33`|
|Surface / card|`#E8E2D0`|`#3E3E49`|
|Bezel / border / ink|`#2A2622`|`#C9CBD1`|
|Text|`#2A2622`|`#E4E5E9`|
|Muted text|`#6B6457`|`#9A9CA6`|
|Orange (primary)|`#F26B21`|`#FF8A3D`|
|Blue (secondary)|`#2F6FD6`|`#5B93F0`|
|Green (success / income)|`#3FA34D`|`#5CC96B`|
|Yellow (warning / highlight)|`#F2C230`|`#FFD54F`|


Suggested color roles for the app’s existing concepts:

- **Orange:** primary actions, the Close Day button, progress.
- **Green:** income, done tasks, and under-budget status.
- **Blue:** info, selected states, and the Focus Shield.
- **Yellow:** warnings and highlights, such as the budget nearing its limit.
- **Red:** I’d keep a muted red for expenses and over-budget, since the four controller colors don’t cover “bad”.

### Typography

- **Headings and labels:** Press Start 2P. It’s very pixelated, so use it sparingly, at 10 to 14 px, for titles, buttons and section labels.
- **Body, numbers and transactions:** Pixelify Sans or VT323. They stay readable at normal sizes, which matters for a finance app.
- **Alternative:** Silkscreen for everything small and uppercase.

All of these are available through the `google_fonts` package, or you can bundle them as assets so the app stays fully offline, which fits your privacy promise.

### Component style

- **Pixel borders:** 2 to 3 px solid ink borders with square corners (radius 0).
- **Hard shadows:** a solid offset block, e.g. 3 px right and 3 px down, with no blur.
- **Buttons:** colored fill, ink border, hard shadow. On press, the button moves down and right by 3 px and the shadow disappears, like a physical key.
- **Progress bars:** chunky segmented blocks instead of smooth fills.
- **Health score ring:** a stepped or blocky ring, or a horizontal segmented bar.
- **Heatmap:** square cells with hard edges, which suits the 35-day grid.
- **Charts (fl_chart):** square bars with ink outlines, no rounded corners, no gradients, and dashed grid lines.
- **Toggle:** the System/Dark/Light control can look like a physical 3-position switch.
- **Icons:** pixel-style icon sets (e.g. `pixelarticons`) or small custom sprites.

**Remove Material’s soft styling globally.** Set `splashFactory: NoSplash.splashFactory`, zero-radius shapes on dialogs, bottom sheets, chips and inputs, and disable page transitions that fade smoothly if you want a snappier feel.

### Things to watch

- **Contrast:** white text on yellow or light orange fails accessibility. Use ink-colored text on yellow, orange and green buttons.
- **Readability:** Press Start 2P gets tiring in long text. Keep it to labels and headings, and use Pixelify Sans for anything people read.
- **Charts and rings** take the most work, because fl_chart defaults to rounded bars and smooth curves.
- **Optional extras:** a subtle dithered texture on the background, and a pixel splash or sound on task completion, would sell the console feel.