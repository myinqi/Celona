pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml

Singleton {
  // Global popup context used by Tooltip.qml
  property PopupContext popupContext: PopupContext {}
  readonly property string themeFile: "~/.config/quickshell/Celona/config.json"
  // Expand tilde for components that don't expand it (e.g., FileView path)
  // Use dynamic HOME instead of hardcoded username; falls back to previous default until resolved.
  property string homeDir: ""
  readonly property bool homeReady: homeDir && homeDir.length > 0
  readonly property string themeFileAbs: themeFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + themeFile.slice(1)) : "") : themeFile
  // Niri config path (for optional color sync)
  readonly property string niriConfigFile: "~/.config/niri/config.kdl"
  readonly property string niriConfigFileAbs: niriConfigFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + niriConfigFile.slice(1)) : "") : niriConfigFile
  // Ghostty theme path
  readonly property string ghosttyThemeFile: "~/.config/ghostty/themes/matugen_colors.conf"
  readonly property string ghosttyThemeFileAbs: ghosttyThemeFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + ghosttyThemeFile.slice(1)) : "") : ghosttyThemeFile
  // Fuzzel theme path
  readonly property string fuzzelThemeFile: "~/.config/fuzzel/themes/matugen_colors.ini"
  readonly property string fuzzelThemeFileAbs: fuzzelThemeFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + fuzzelThemeFile.slice(1)) : "") : fuzzelThemeFile
  // Hyprgreetr config path
  readonly property string hyprgreetrConfigFile: "~/.config/hyprgreetr/config.toml"
  readonly property string hyprgreetrConfigFileAbs: hyprgreetrConfigFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + hyprgreetrConfigFile.slice(1)) : "") : hyprgreetrConfigFile
  // Hyprlock config path
  readonly property string hyprlockConfigFile: "~/.config/hypr/hyprlock.conf"
  readonly property string hyprlockConfigFileAbs: hyprlockConfigFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + hyprlockConfigFile.slice(1)) : "") : hyprlockConfigFile
  // Cava config path
  readonly property string cavaConfigFile: "~/.config/cava/config"
  readonly property string cavaConfigFileAbs: cavaConfigFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + cavaConfigFile.slice(1)) : "") : cavaConfigFile
  // SwayNC Matugen CSS path (new unified theme file)
  readonly property string swayncMatugenCssFile: "~/.config/swaync/matugen_colors.css"
  readonly property string swayncMatugenCssFileAbs: swayncMatugenCssFile.indexOf("~/") === 0 ? (homeReady ? (homeDir + swayncMatugenCssFile.slice(1)) : "") : swayncMatugenCssFile
  readonly property string defaultsFile: Qt.resolvedUrl("root:/defaults")
  property string _themeBuf: ""
  // internal flags for async operations
  property bool _resetFromDefaultsRequested: false
  // when true, load defaults file but apply only color-related properties
  property bool _resetColorsFromDefaultsRequested: false

  // Resolve $HOME once at startup to avoid hardcoding usernames
  Process {
    id: homeProc
    running: false
    // Prefer getent to robustly resolve the user's home; fallback to $HOME
    command: ["bash","-lc","getent passwd $(id -u) | cut -d: -f6 || printf %s \"$HOME\""]
    stdout: SplitParser {
      onRead: (data) => {
        const s = String(data).trim()
        if (s && s !== homeDir) homeDir = s
      }
    }
  }
  Component.onCompleted: { homeProc.running = true }

  // THEME COLORS (defaults reflect current bar style)
  // Bar
  property string barBgColor: "#40000000"
  property string barBorderColor: "#00bee7"
  // Bar position: "top" or "bottom"
  property string barPosition: "top"
  // Visual bar height in pixels
  property int baseBarHeight: 38
  // Distance (px) from chosen screen edge to the bar (0–10 typical)
  property int barEdgeMargin: 0
  // Horizontal side margins (px) to shorten the bar from left and right equally (0–10 typical)
  property int barSideMargin: 0
  // When true, hide the full bar and only show the Setup gear window
  property bool barHidden: false
  // Hover highlight for blocks (e.g., Time)
  property string hoverHighlightColor: "#00bee7"

  // Modules (icons vs values)
  property string moduleIconColor: "#FFFFFF"
  property string moduleValueColor: "#FFFFFF"

  // Workspaces
  property string workspaceActiveBg: "#4000bee7"   // translucent cyan
  property string workspaceActiveBorder: "#00bee7"
  property string workspaceInactiveBg: "#00000000"
  property string workspaceInactiveBorder: "#00bee7"
  property string workspaceTextColor: "#FFFFFF"

  // Tooltips (leave empty to fallback to component palette)
  property string tooltipBg: ""
  property string tooltipText: "#FFFFFF"
  property string tooltipBorder: ""
  // Tooltip typography
  // When >0, applies to all tooltip texts; when 0, use component defaults
  property int tooltipFontPixelSize: 12
  // When non-empty, sets tooltip font family; when empty, use component defaults
  property string tooltipFontFamily: ""

  // Popups (menus) (leave empty to fallback to component palette)
  property string popupBg: ""
  property string popupText: "#FFFFFF"
  property string popupBorder: ""

  // SystemTray icons tint (empty = no tint)
  property string trayIconColor: ""

  // Module visibility toggles (default: shown)
  // Left/center
  property bool showWelcome: true
  property bool showWindowTitle: true
  property bool showWorkspaces: true
  // Right side
  property bool showSystemTray: true
  property bool showUpdates: true
  property bool showNetwork: true
  property bool showBluetooth: true
  property bool showCPU: true
  property bool showGPU: true
  property bool showMemory: true
  property bool showPowerProfiles: true
  property bool showClipboard: true
  property bool showNotifications: true
  // New: Window selector (popup listing open windows)
  property bool showWindowSelector: true
  property bool showSound: true
  // Keybinds cheatsheet
  property bool showKeybinds: false
  property bool showBattery: true
  property bool showDate: true
  property bool showTime: true
  property bool showPower: true

  // Reorder mode: when true, bar shows drag UI and allows reordering directly
  property bool reorderMode: false

  // Swap positions of WindowTitle and Workspaces (false: WindowTitle left, Workspaces center; true: Workspaces left, WindowTitle center)
  property bool swapTitleAndWorkspaces: false

  // Matugen integration
  // When true and colors.css exists in the Celona root, we apply mapped colors from it
  property bool useMatugenColors: false
  // Computed availability of colors.css
  property bool matugenAvailable: false
  // last applied colors.css content hash to detect changes
  property string _matugenHash: ""
  // cache last applied matugen palette map to allow late consumers (e.g., hyprlock) to update on load
  property var _lastMatugenMap: null
  // Monotonic counter that increments whenever themes are applied.
  // Modules can watch this to react even when specific color values remain equal.
  property int themeEpoch: 0

  // Custom order for right-side modules (used for dynamic rendering)
  // Default matches current static order
  property var rightModulesOrder: [
    "SystemTray","Updates","Network","Bluetooth","CPU","GPU","Memory",
    "PowerProfiles","Clipboard","Keybinds","Notifications","WindowSelector","Sound","Battery","Date","Time","Power"
  ]

  // Window title
  property string windowTitleColor: "#00bee7"
  // Visualizer bars color
  property string visualizerBarColor: "#00bee7"
  // Weather settings
  // Location can be "lat,lon" or a city name recognized by wttr.in
  property string weatherLocation: "" // empty => auto by IP
  // "C" or "F"
  property string weatherUnit: "C"
  // Toggle for Weather module visibility
  property bool showWeather: false

  // Keybinds cheatsheet: configurable path to Hyprland keybindings file
  // Example: "/home/USER/.config/hypr/conf/keybindings/khrom.conf"
  property string keybindsPath: ""
  // Development: keybindsPath read from repo config.json (root), applied after theme load
  property string _repoKeybindsPath: ""

  // --- Wallpaper control ---
  // Toggle animated wallpaper (mpvpaper)
  property bool wallpaperAnimatedEnabled: false
  // Video file path for animated wallpaper
  property string wallpaperAnimatedPath: ""
  // Image file path for static wallpaper
  property string wallpaperStaticPath: ""
  // Outputs to target (e.g., ["DP-3", "HDMI-A-1"]) — explicit to work on Hyprland and Niri
  property var wallpaperOutputs: []
  // mpvpaper options (without surrounding -o quotes)
  property string mpvpaperOptions: "--loop --no-audio"
  // Tool to set static wallpaper; currently supports "swww"
  property string wallpaperTool: "swww"
  // Feature flag for new setup UI
  property bool useNewSetupUI: false
  // Show bar visualizer module
  property bool showBarvisualizer: false

  // Dock settings
  // Vertical dock position on screen edge: "left" or "right"
  // When false, the dock window is not shown
  property bool dockEnabled: true
  // Vertical dock position on screen edge: "left" or "right"
  property string dockPosition: "right"
  // Show labels under/next to icons
  property bool dockShowLabels: true
  // Tile size in pixels
  property int dockTileSize: 64
  // Vertical spacing between tiles in pixels
  property int dockTileSpacing: 8
  // Items: array of { icon: string, label: string, cmd: string }
  property var dockItems: []

  // New Dock config (config.json-driven only)
  // Visibility and positioning
  property bool showDock: true
  property string dockPositionHorizontal: "right"   // left|right
  property string dockPositionVertical: "center"     // top|center|bottom
  // Layer/visibility behavior: "on top" | "behind" | "autohide"
  property string dockLayerPosition: "on top"
  // Autohide animation duration (ms)
  property int dockAutoHideDurationMs: 120
  // Separate durations for show/hide (ms)
  property int dockAutoHideInDurationMs: 120
  property int dockAutoHideOutDurationMs: 120
  // Icon appearance
  property int dockIconBorderPx: 2
  property int dockIconRadius: 10
  property int dockIconSizePx: 64
  property bool dockIconLabel: true
  property int dockIconSpacing: 0
  // Icon colors (Matugen-aware)
  property string dockIconBGColor: "#202020"
  property string dockIconBorderColor: "#808080"
  property string dockIconLabelColor: "#FFFFFF"
  // Behavior
  property bool allowDockIconMovement: false

  // --- Matugen colors handling ---
  // Helper: convert rgba(r,g,b,a) or #RRGGBB to #AARRGGBB
  function toArgb(hexOrRgba, alphaOverride) {
    try {
      const s = String(hexOrRgba).trim()
      const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x))
      const hx = n => (n.toString(16).padStart(2, '0'))
      if (s.startsWith('rgba')) {
        const m = s.match(/rgba\(([^)]+)\)/i)
        if (!m) return '#ff000000'
        const parts = m[1].split(',').map(p => p.trim())
        let r = clamp(parseInt(parts[0], 10), 0, 255)
        let g = clamp(parseInt(parts[1], 10), 0, 255)
        let b = clamp(parseInt(parts[2], 10), 0, 255)
        let a = parts[3] !== undefined ? clamp(Math.round(parseFloat(parts[3]) * 255), 0, 255) : 255
        if (typeof alphaOverride === 'number') a = clamp(alphaOverride, 0, 255)
        return '#' + hx(a) + hx(r) + hx(g) + hx(b)
      }
      if (s.startsWith('#') && s.length === 7) {
        const a = (typeof alphaOverride === 'number') ? alphaOverride : 255
        return '#' + hx(a) + s.slice(1)
      }
      return '#ff000000'
    } catch (e) { return '#ff000000' }
  }

  // Update Hyprlock config (~/.config/hypr/hyprlock.conf) from Matugen map
  function updateHyprlockThemeFromMap(map) {
    try {
      const pick = (k, d) => (map && map[k] !== undefined ? map[k] : d)
      const onSurf = pick('on_surface', '#e2e2e9')
      const onPrimary = pick('on_primary', '#ffffff')
      const bg = pick('background', '#111318')
      const invPrim = pick('inverse_primary', '#415e91')
      const primary = pick('primary', '#89b4fa')
      const tertiary = pick('tertiary', '#94e2d5')
      const error = pick('error', '#f38ba8')

      function toRgbDec(x) {
        const h = toRgb6(x)
        const r = parseInt(h.slice(0,2), 16)
        const g = parseInt(h.slice(2,4), 16)
        const b = parseInt(h.slice(4,6), 16)
        return 'rgb(' + r + ', ' + g + ', ' + b + ')'
      }
      function rgba8Tag(x) { return 'rgba(' + toRgba8(x) + ')' }

      const inner_color = 'rgba(0, 0, 0, 0.0)'
      const outer_color = rgba8Tag(invPrim) + ' ' + rgba8Tag(primary) + ' 45deg'
      const check_color = rgba8Tag(primary) + ' ' + rgba8Tag(tertiary) + ' 120deg'
      const fail_color  = rgba8Tag(tertiary) + ' ' + rgba8Tag(error) + ' 40deg'
      // Choose readable text: for light backgrounds use on_primary (typically light), otherwise on_surface
      const bg6_for_lum = toRgb6(bg)
      const br = parseInt(bg6_for_lum.slice(0,2),16)/255.0
      const bg_gg = parseInt(bg6_for_lum.slice(2,4),16)/255.0
      const bb = parseInt(bg6_for_lum.slice(4,6),16)/255.0
      const bgLum = 0.2126*br + 0.7152*bg_gg + 0.0722*bb
      const font_color  = (bgLum >= 0.5) ? toRgbDec(onPrimary) : toRgbDec(onSurf)

      let text = ''
      try { text = String(hyprlockView.text() || '') } catch (e) { text = '' }
      // Safety: if file content is not available yet or path unresolved, do NOT overwrite with a template.
      // We only update when existing content is loaded to preserve unrelated settings.
      if (!hyprlockConfigFileAbs || !hyprlockConfigFileAbs.length || !text || !text.length) {
        console.log('[Hyprlock] skip write: config not loaded yet or path unresolved; preserving file')
        return
      }

      function ensureInputFieldBlock(src) {
        if (/(^|\n)\s*input-field\s*\{[\s\S]*?\n\s*\}/.test(src)) return src
        const sep = src.endsWith('\n') || src.length===0 ? '' : '\n'
        return src + sep + 'input-field {\n}\n'
      }
      function setInInputField(src, key, value) {
        // Limit replacement to input-field block
        const reBlock = /(^|\n)(\s*input-field\s*\{)([\s\S]*?)(\n\s*\})(?![\s\S]*\2)/
        const m = reBlock.exec(src)
        if (!m) return src
        const before = src.slice(0, m.index)
        const head = m[2]
        const body = m[3]
        const tail = m[4]
        const reLine = new RegExp('(\\n|^)([\\t ]*)' + key.replace(/[.*+?^${}()|[\]\\]/g,'\\$&') + '\\s*=\\s*[^\\n]*')
        let newBody
        if (reLine.test(body)) {
          newBody = body.replace(reLine, function(s, pre, indent) { return (pre||'') + indent + key + ' = ' + value })
        } else {
          const indent = '    '
          const sep = body.endsWith('\n') ? '' : '\n'
          newBody = body + sep + indent + key + ' = ' + value + '\n'
        }
        return before + (m[1] || '') + head + newBody + tail + src.slice(m.index + m[0].length)
      }

      let out = ensureInputFieldBlock(text)
      out = setInInputField(out, 'inner_color', inner_color)
      out = setInInputField(out, 'outer_color', outer_color)
      out = setInInputField(out, 'check_color', check_color)
      out = setInInputField(out, 'fail_color',  fail_color)
      out = setInInputField(out, 'font_color',  font_color)

      if (out !== text) {
        const b64 = Qt.btoa(out)
        console.log('[Hyprlock] writing theme to', hyprlockConfigFileAbs)
        hyprlockSaveProc.command = [
          'bash','-lc',
          "mkdir -p ~/.config/hypr && printf '%s' '" + b64 + "' | base64 -d > '" + hyprlockConfigFileAbs + "'"
        ]
        hyprlockSaveProc.running = true
      }
    } catch (e) { /* ignore */ }
  }


  // Helper: convert rgba(...)|#AARRGGBB|#RRGGBB -> rrggbb (no leading #)
  function toRgb6(hexOrRgba) {
    try {
      const s0 = String(hexOrRgba||'').trim()
      const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x))
      const hx = n => (n.toString(16).padStart(2, '0'))
      if (s0.startsWith('rgba')) {
        const m = s0.match(/rgba\(([^)]+)\)/i)
        if (!m) return '000000'
        const parts = m[1].split(',').map(p => p.trim())
        const r = clamp(parseInt(parts[0], 10), 0, 255)
        const g = clamp(parseInt(parts[1], 10), 0, 255)
        const b = clamp(parseInt(parts[2], 10), 0, 255)
        return hx(r) + hx(g) + hx(b)
      }
      let s = s0
      if (s.startsWith('#')) s = s.slice(1)
      if (s.length === 8) return s.slice(2)
      if (s.length === 6) return s
      return '000000'
    } catch (e) { return '000000' }
  }

  // Update Cava colors (gradient) based on Matugen map
  function updateCavaThemeFromMap(map) {
    try {
      console.log('[Cava] updating from matugen map')
      const pick = (k, d) => (map && map[k] !== undefined ? map[k] : d)
      const bg = pick('background', '#111318')
      const onSurf = pick('on_surface', '#e2e2e9')
      const primary = pick('primary', '#89b4fa')
      const invPrim = pick('inverse_primary', '#415e91')

      // luminance branch for gradient endpoints
      const bg6 = toRgb6(bg)
      const r = parseInt(bg6.slice(0,2),16)/255.0
      const g = parseInt(bg6.slice(2,4),16)/255.0
      const b = parseInt(bg6.slice(4,6),16)/255.0
      const lum = 0.2126*r + 0.7152*g + 0.0722*b
      const startHex = (lum >= 0.5) ? toRgb6(invPrim) : toRgb6(primary)
      const endHex = toRgb6(onSurf)

      function lerp(a, b, t) { return Math.round(a + (b - a) * t) }
      function hex6ToRgb(hex6) {
        return [parseInt(hex6.slice(0,2),16), parseInt(hex6.slice(2,4),16), parseInt(hex6.slice(4,6),16)]
      }
      function rgbToHex6(r,g,b) {
        const hx = (n) => Math.max(0,Math.min(255, n|0)).toString(16).padStart(2,'0')
        return hx(r) + hx(g) + hx(b)
      }
      const s = hex6ToRgb(startHex)
      const e = hex6ToRgb(endHex)
      const steps = 7
      const grad = []
      for (let i = 0; i < steps; i++) {
        const t = i/(steps-1)
        const rr = lerp(s[0], e[0], t)
        const gg = lerp(s[1], e[1], t)
        const bb = lerp(s[2], e[2], t)
        grad.push('#' + rgbToHex6(rr,gg,bb))
      }

      let text0 = String(cavaView && cavaView.text ? (cavaView.text()||"") : "")
      if (!text0 || !text0.length) text0 = "[color]\n"

      // Replace key within a section [color]
      function replaceKVInSection(src, section, key, value) {
        try {
          const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
          const reSec = new RegExp('(\\n|^)[\t ]*\\[' + esc(section) + '\\][\t ]*(?:\\n|$)')
          let m = reSec.exec(src)
          if (!m) {
            const sep = src.endsWith('\n') ? '' : '\n'
            src = src + sep + '[' + section + ']\n'
            m = reSec.exec(src)
          }
          const startIdx = m.index + m[0].length
          const rest = src.slice(startIdx)
          const mNext = /(\n|^)\s*\[[^\]]+\]\s*(?:\n|$)/.exec(rest)
          const endIdx = startIdx + (mNext ? mNext.index : rest.length)
          const before = src.slice(0, startIdx)
          const secBody = src.slice(startIdx, endIdx)
          const after = src.slice(endIdx)
          const lines = secBody.split('\n')
          const reKey = new RegExp('^\s*' + esc(key) + '\s*=')
          let found = false
          for (let i = 0; i < lines.length; i++) {
            if (reKey.test(lines[i])) {
              const indent = (lines[i].match(/^[\t ]*/) || [''])[0]
              lines[i] = indent + key + ' = ' + value
              found = true
              break
            }
          }
          if (!found) lines.push(key + ' = ' + value)
          return before + lines.join('\n') + after
        } catch (e) { return src }
      }

      let out = text0
      out = replaceKVInSection(out, 'color', 'gradient', '1')
      for (let i = 0; i < grad.length; i++) {
        out = replaceKVInSection(out, 'color', 'gradient_color_' + (i+1), "'" + grad[i] + "'")
      }

      const b64 = Qt.btoa(out)
      console.log('[Cava] writing theme to', cavaConfigFileAbs)
      cavaSaveProc.command = ["bash","-lc",
        "mkdir -p ~/.config/cava && printf '%s' '" + b64 + "' | base64 -d > '" + cavaConfigFileAbs + "' && pkill -USR1 -x cava 2>/dev/null || true"]
      cavaSaveProc.running = true
    } catch (e) { /* ignore */ }
  }

  // New: Write ~/.config/swaync/matugen_colors.css using Ghostty-style palette keys
  function updateSwayncMatugenCssFromMap(map) {
    try {
      console.log('[SwayNC] updateSwayncMatugenCssFromMap: begin; css path=', swayncMatugenCssFileAbs)
      const pick = (k, d) => (map && map[k] !== undefined ? map[k] : d)
      const bg = pick('background', '#111318')
      const onSurf = pick('on_surface', '#e2e2e9')
      const onSurfVar = pick('on_surface_variant', '#c4c6d0')
      const invPrim = pick('inverse_primary', '#415e91')
      const surfVar = pick('surface_variant', '#2a2f37')
      const primary = pick('primary', '#89b4fa')
      const secondary = pick('secondary', '#f5c2e7')
      const tertiary = pick('tertiary', '#94e2d5')
      const error = pick('error', '#f38ba8')

      function H6(x) { return '#' + toRgb6(x) }
      function lighten(hex6, pct) {
        try {
          const p = Math.max(0, Math.min(100, pct)) / 100.0
          const r = parseInt(hex6.slice(0,2),16)
          const g = parseInt(hex6.slice(2,4),16)
          const b = parseInt(hex6.slice(4,6),16)
          const lr = Math.round(r + (255 - r) * p)
          const lg = Math.round(g + (255 - g) * p)
          const lb = Math.round(b + (255 - b) * p)
          const hx = n => n.toString(16).padStart(2,'0')
          return hx(lr) + hx(lg) + hx(lb)
        } catch (e) { return hex6 }
      }

      const surfVar6 = toRgb6(surfVar)
      const onSurfVar6 = toRgb6(onSurfVar)
      const primary6 = toRgb6(primary)
      const secondary6 = toRgb6(secondary)
      const tertiary6 = toRgb6(tertiary)
      const error6 = toRgb6(error)
      const invPrim6 = toRgb6(invPrim)
      const fg6 = toRgb6(onSurf)

      let out = ''
      out += '@define-color shadow rgba(0, 0, 0, 0.25);\n'
      out += '/*\n * Unified Matugen palette for SwayNC (auto-generated)\n */\n\n'
      out += '/* Special */\n'
      out += '@define-color background ' + H6(bg) + ';\n'
      out += '@define-color foreground ' + H6(onSurf) + ';\n'
      out += '@define-color cursor #' + invPrim6 + ';\n\n'
      out += '/* Colors */\n'
      // Base 0-7
      out += '@define-color color0 #' + surfVar6 + ';\n'
      out += '@define-color color1 #' + error6 + ';\n'
      out += '@define-color color2 #' + tertiary6 + ';\n'
      out += '@define-color color3 #' + invPrim6 + ';\n'
      out += '@define-color color4 #' + primary6 + ';\n'
      out += '@define-color color5 #' + secondary6 + ';\n'
      out += '@define-color color6 #' + tertiary6 + ';\n'
      out += '@define-color color7 #' + onSurfVar6 + ';\n'
      // Bright 8-15
      out += '@define-color color8 #'  + lighten(surfVar6, 20) + ';\n'
      out += '@define-color color9 #'  + lighten(error6, 15) + ';\n'
      out += '@define-color color10 #' + lighten(tertiary6, 15) + ';\n'
      out += '@define-color color11 #' + lighten(invPrim6, 15) + ';\n'
      out += '@define-color color12 #' + lighten(primary6, 15) + ';\n'
      out += '@define-color color13 #' + lighten(secondary6, 15) + ';\n'
      out += '@define-color color14 #' + lighten(tertiary6, 25) + ';\n'
      out += '@define-color color15 #' + fg6 + ';\n'

      const b64 = Qt.btoa(out)
      console.log('[SwayNC] writing matugen_colors.css to', swayncMatugenCssFileAbs)
      swayncSaveProc.command = [
        'bash','-lc',
        "mkdir -p ~/.config/swaync && printf '%s' '" + b64 + "' | base64 -d > '" + swayncMatugenCssFileAbs + "' && (command -v swaync-client >/dev/null 2>&1 && swaync-client -R -rs || true)"
      ]
      swayncSaveProc.running = true
    } catch (e) { /* ignore */ }
  }

  // Helper: convert rgba(...)|#AARRGGBB|#RRGGBB -> rrggbbaa (no leading #)
  function toRgba8(hexOrRgba, alphaOverride) {
    try {
      // Reuse toArgb to normalize, then rotate AARRGGBB -> RRGGBBAA (strip '#')
      const aargb = toArgb(hexOrRgba, alphaOverride)
      if (!aargb || aargb.length !== 9 || aargb[0] !== '#') return '000000ff'
      const aa = aargb.slice(1,3)
      const rrggbb = aargb.slice(3)
      return rrggbb + aa
    } catch (e) { return '000000ff' }
  }

  // Update Ghostty theme keys from Matugen map (also adjust a few palette entries)
  function updateGhosttyThemeFromMap(map) {
    try {
      const text0 = String(ghosttyView && ghosttyView.text ? (ghosttyView.text()||"") : "")
      const pick = (k, d) => (map && map[k] !== undefined ? map[k] : d)
      const bg = pick('background', '#111318')
      const onSurf = pick('on_surface', '#e2e2e9')
      const invPrim = pick('inverse_primary', '#415e91')
      const surfVar = pick('surface_variant', '#2a2f37')
      const onSurfVar = pick('on_surface_variant', '#c4c6d0')
      const scHigh = pick('surface_container_high', '#343a46')
      const scLow = pick('surface_container_low', '#1b1f27')

      const bg6 = toRgb6(bg)
      const fg6 = toRgb6(onSurf)
      const inv6 = toRgb6(invPrim)
      // luminance to choose selection background
      const r = parseInt(bg6.slice(0,2),16)/255.0
      const g = parseInt(bg6.slice(2,4),16)/255.0
      const b = parseInt(bg6.slice(4,6),16)/255.0
      const lum = 0.2126*r + 0.7152*g + 0.0722*b
      const selBg6 = toRgb6(lum >= 0.5 ? scHigh : scLow)
      const selFg6 = fg6

      function setPalette(src, index, hex6) {
        const re = new RegExp('(^|\\n)palette\\s*=\\s*' + index + '=#[0-9a-fA-F]{6}')
        const line = 'palette = ' + index + '=#' + hex6
        if (re.test(src)) return src.replace(re, function(m, pre) { return pre + line })
        const sep = src.endsWith('\n') || src.length===0 ? '' : '\n'
        return src + sep + line + '\n'
      }

      function setKV(src, key, value) {
        const re = new RegExp('(^|\\n)('+key+')\\s*=\\s*[^\\n]*')
        if (re.test(src)) return src.replace(re, function(m, pre, k) { return pre + k + ' = ' + value })
        const sep = src.endsWith('\n') || src.length===0 ? '' : '\n'
        return src + sep + key + ' = ' + value + '\n'
      }

      let out = text0
      out = setKV(out, 'background', bg6)
      out = setKV(out, 'foreground', fg6)
      out = setKV(out, 'cursor-color', inv6)
      out = setKV(out, 'cursor-text', bg6)
      out = setKV(out, 'selection-background', selBg6)
      out = setKV(out, 'selection-foreground', selFg6)
      // Map all 16 palette entries. Use Matugen hues where available and derive brights by lightening.
      const surfVar6 = toRgb6(surfVar)
      const onSurfVar6 = toRgb6(onSurfVar)
      const primary6 = toRgb6(pick('primary', '#89b4fa'))
      const secondary6 = toRgb6(pick('secondary', '#f5c2e7'))
      const tertiary6 = toRgb6(pick('tertiary', '#94e2d5'))
      const error6 = toRgb6(pick('error', '#f38ba8'))
      const invPrim6 = toRgb6(invPrim)
      function lighten(hex6, pct) {
        try {
          const p = Math.max(0, Math.min(100, pct)) / 100.0
          const r = parseInt(hex6.slice(0,2),16)
          const g = parseInt(hex6.slice(2,4),16)
          const b = parseInt(hex6.slice(4,6),16)
          const lr = Math.round(r + (255 - r) * p)
          const lg = Math.round(g + (255 - g) * p)
          const lb = Math.round(b + (255 - b) * p)
          const hx = n => n.toString(16).padStart(2,'0')
          return hx(lr) + hx(lg) + hx(lb)
        } catch (e) { return hex6 }
      }
      // Base 0-7: black, red, green, yellow, blue, magenta, cyan, white
      out = setPalette(out, 0, surfVar6)         // black-ish from surface_variant
      out = setPalette(out, 1, error6)           // red
      out = setPalette(out, 2, tertiary6)        // green-like
      out = setPalette(out, 3, invPrim6)         // yellow-ish accent substitute
      out = setPalette(out, 4, primary6)         // blue
      out = setPalette(out, 5, secondary6)       // magenta
      out = setPalette(out, 6, tertiary6)        // cyan-like (same family)
      out = setPalette(out, 7, onSurfVar6)       // white-ish
      // Bright 8-15: lightened variants
      out = setPalette(out, 8,  lighten(surfVar6, 20))
      out = setPalette(out, 9,  lighten(error6, 15))
      out = setPalette(out, 10, lighten(tertiary6, 15))
      out = setPalette(out, 11, lighten(invPrim6, 15))
      out = setPalette(out, 12, lighten(primary6, 15))
      out = setPalette(out, 13, lighten(secondary6, 15))
      out = setPalette(out, 14, lighten(tertiary6, 25))
      out = setPalette(out, 15, fg6)             // bright white = on_surface

      // Always write to ensure terminal picks up changes across theme toggles
      const b64 = Qt.btoa(out)
      console.log('[Ghostty] writing theme to', ghosttyThemeFileAbs)
      ghosttySaveProc.command = ["bash","-lc",
        "mkdir -p ~/.config/ghostty/themes && printf '%s' '" + b64 + "' | base64 -d > " + ghosttyThemeFileAbs]
      ghosttySaveProc.running = true

      // Additionally generate an OSC script in project scripts/ to apply colors live in open Ghostty windows
      try {
        // Collect palette for OSC 4;n;#RRGGBB
        const p = []
        p[0] = surfVar6
        p[1] = error6
        p[2] = tertiary6
        p[3] = invPrim6
        p[4] = primary6
        p[5] = secondary6
        p[6] = tertiary6
        p[7] = onSurfVar6
        p[8] = lighten(surfVar6, 20)
        p[9] = lighten(error6, 15)
        p[10] = lighten(tertiary6, 15)
        p[11] = lighten(invPrim6, 15)
        p[12] = lighten(primary6, 15)
        p[13] = lighten(secondary6, 15)
        p[14] = lighten(tertiary6, 25)
        p[15] = fg6

        let osc = ''
        osc += '#!/usr/bin/env bash\n'
        osc += '# Auto-generated by Celona (Matugen sync)\n'
        osc += 'set -e\n'
        osc += 'echo -ne "\\e]10;#' + fg6 + '\\a"\n'    // foreground
        osc += 'echo -ne "\\e]11;#' + bg6 + '\\a"\n'    // background
        osc += 'echo -ne "\\e]12;#' + inv6 + '\\a"\n'   // cursor
        for (let i = 0; i < 16; i++) {
          osc += 'echo -ne "\\e]4;' + i + ';#' + p[i] + '\\a"\n'
        }

        const projectDir = themeFileAbs.slice(0, themeFileAbs.lastIndexOf('/'))
        const scriptsDir = projectDir + '/scripts'
        const oscPath = scriptsDir + '/apply_osc.sh'
        const b64osc = Qt.btoa(osc)
        console.log('[Ghostty] writing OSC script to', oscPath)
        ghosttySaveProc.command = ["bash","-lc",
          "mkdir -p '" + scriptsDir + "' && printf '%s' '" + b64osc + "' | base64 -d > '" + oscPath + "' && chmod +x '" + oscPath + "' && " +
          "for p in /dev/pts/*; do [ -w \"$p\" ] && bash '" + oscPath + "' > \"$p\" 2>/dev/null || true; done"]
        ghosttySaveProc.running = true
      } catch (e) { /* ignore */ }
    } catch (e) { /* ignore */ }
  }

  // Update Hyprgreetr colors inside config.toml from Matugen map
  function updateHyprgreetrThemeFromMap(map) {
    try {
      const pick = (k, d) => (map && map[k] !== undefined ? map[k] : d)
      const bg = pick('background', '#111318')
      const onSurf = pick('on_surface', '#e2e2e9')
      const onSurfVar = pick('on_surface_variant', '#c4c6d0')
      const invPrim = pick('inverse_primary', '#415e91')
      const primary = pick('primary', '#89b4fa')

      // Luminance on background to branch light/dark if needed later
      const bg6 = toRgb6(bg)
      const r = parseInt(bg6.slice(0,2),16)/255.0
      const g = parseInt(bg6.slice(2,4),16)/255.0
      const b = parseInt(bg6.slice(4,6),16)/255.0
      const lum = 0.2126*r + 0.7152*g + 0.0722*b
      const isLight = (lum >= 0.5)

      // Ensure 6-digit hex with leading '#'
      const H6 = (x) => ('#' + toRgb6(x))
      const titleHex     = H6(primary)
      const moduleHex    = H6(invPrim)
      const infoHex      = H6(onSurf)
      const separatorHex = H6(onSurfVar)
      const borderHex    = moduleHex

      let text0 = String(hyprgreetrView && hyprgreetrView.text ? (hyprgreetrView.text()||"") : "")
      // Safety: if file content is not available yet, do NOT overwrite with a template.
      // We only update when existing content is loaded to preserve unrelated settings.
      if (!text0 || !text0.length) {
        console.log('[Hyprgreetr] skip write: config not loaded yet or empty; preserving file')
        return
      }

      // Replace key within TOML section [section] without complex regex quoting
      function replaceKVInSection(src, section, key, value) {
        try {
          const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
          const reSec = new RegExp('(\\n|^)[\t ]*\\[' + esc(section) + '\\][\t ]*(?:\\n|$)')
          const m = reSec.exec(src)
          // If section is missing, append it at the end with the desired key to avoid destructive rewrites
          if (!m) {
            const sep = src.endsWith('\n') ? '' : '\n'
            return src + sep + '[' + section + ']\n' + key + ' = "' + value + '"\n'
          }
          const startIdx = m.index + m[0].length
          const rest = src.slice(startIdx)
          const mNext = /(\n|^)\s*\[[^\]]+\]\s*(?:\n|$)/.exec(rest)
          const endIdx = startIdx + (mNext ? mNext.index : rest.length)
          const before = src.slice(0, startIdx)
          const secBody = src.slice(startIdx, endIdx)
          const after = src.slice(endIdx)
          const lines = secBody.split('\n')
          const reKey = new RegExp('^\\s*' + esc(key) + '\\s*=')
          let found = false
          for (let i = 0; i < lines.length; i++) {
            if (reKey.test(lines[i])) {
              const indent = (lines[i].match(/^[\t ]*/) || [''])[0]
              lines[i] = indent + key + ' = "' + value + '"'
              found = true
              break
            }
          }
          if (!found) lines.push(key + ' = "' + value + '"')
          let newBody = lines.join('\n')
          // Ensure trailing newline matches original formatting
          if (secBody.endsWith('\n') && !newBody.endsWith('\n')) newBody += '\n'
          return before + newBody + after
        } catch (e) { return src }
      }

      let out = text0
      out = replaceKVInSection(out, 'general.colors', 'title', titleHex)
      out = replaceKVInSection(out, 'general.colors', 'module', moduleHex)
      out = replaceKVInSection(out, 'general.colors', 'info', infoHex)
      out = replaceKVInSection(out, 'general.colors', 'separator', separatorHex)
      out = replaceKVInSection(out, 'display', 'border_color', borderHex)

      // Always write to ensure consistent updates like other integrators
      const b64 = Qt.btoa(out)
      console.log('[Hyprgreetr] writing theme to', hyprgreetrConfigFileAbs)
      hyprgreetrSaveProc.command = [
        "bash","-lc",
        "mkdir -p ~/.config/hyprgreetr && printf '%s' '" + b64 + "' | base64 -d > '" + hyprgreetrConfigFileAbs + "'"
      ]
      hyprgreetrSaveProc.running = true
    } catch (e) { /* ignore */ }
  }

  function applyMatugenMap(map) {
    console.log('[Matugen] applyMatugenMap: starting apply; useMatugenColors=', useMatugenColors)
    // Map Matugen names to our config keys
    // Fallbacks if a key is missing
    const pick = (k, d) => (map[k] !== undefined ? map[k] : d)
    // Cache the latest map so late-loading consumers (e.g., Hyprlock FileView) can update immediately
    _lastMatugenMap = map
    const bg = pick('background', '#111318')
    const onSurf = pick('on_surface', '#e2e2e9')
    const onSurfVar = pick('on_surface_variant', '#c4c6d0')
    const invPrim = pick('inverse_primary', '#415e91')
    const hoverVar = pick('on_secondary_fixed_variant', '#3e4759')
    const blur8 = pick('blur_background8', 'rgba(17,19,24,0.8)')

    barBgColor = toArgb(blur8)
    popupBg = toArgb(bg)
    tooltipBg = toArgb(bg)
    popupText = toArgb(onSurf)
    tooltipText = toArgb(onSurf)
    popupBorder = toArgb(invPrim)
    tooltipBorder = toArgb(invPrim)
    moduleValueColor = toArgb(onSurf)
    windowTitleColor = toArgb(onSurf)
    workspaceTextColor = toArgb(onSurf)
    workspaceActiveBorder = toArgb(invPrim)
    workspaceInactiveBorder = toArgb(invPrim)
    barBorderColor = toArgb(invPrim)
    moduleIconColor = toArgb(onSurfVar)
    trayIconColor = toArgb(onSurfVar)
    hoverHighlightColor = toArgb(hoverVar)
    // active bg: inverse_primary with 0x40 alpha
    workspaceActiveBg = toArgb(invPrim, 0x40)
    workspaceInactiveBg = '#00000000'
    // visualizer bars align with border/accent
    visualizerBarColor = toArgb(invPrim)
    // Dock colors (align with bar theme)
    dockIconBGColor = toArgb(bg)              // solid base background
    dockIconBorderColor = toArgb(invPrim)     // accent border like barBorderColor
    dockIconLabelColor = toArgb(onSurf)       // readable text color
    // Also sync external configs if requested
    if (useMatugenColors) {
      console.log('[Matugen] applying external theme integrations (Niri, Ghostty, Fuzzel, Hyprgreetr, Cava, SwayNC, Hyprlock)')
      updateNiriColorsFromTheme()
      updateGhosttyThemeFromMap(map)
      updateFuzzelThemeFromMap(map)
      updateHyprgreetrThemeFromMap(map)
      updateCavaThemeFromMap(map)
      updateSwayncMatugenCssFromMap(map)
      updateHyprlockThemeFromMap(map)
    }
    // Bump epoch so listeners (e.g., Barvisualizer) can restart/refresh even if values are identical
    themeEpoch = themeEpoch + 1
    console.log('[Matugen] applyMatugenMap: done; themeEpoch ->', themeEpoch)
  }

  function applyMatugenColors() {
    if (!useMatugenColors) return
    // Clear cached hash so a re-enable forces re-apply even if colors.css didn't change
    _matugenHash = ""
    if (matugenView) matugenView.reload()
  }

  // Update Niri colors (active/inactive) based on current theme values
  // Strategy: use barBorderColor as active (accent), hoverHighlightColor as inactive (neutral)
  function updateNiriColorsFromTheme() {
    try {
      const f = niriConfigFileAbs
      if (!f || !niriView) return
      const text = String(niriView.text()||"")
      if (!text || text.length === 0) return
      const active = String(barBorderColor||"").trim()
      const inactive = String(hoverHighlightColor||"").trim()
      if (!/^#?[0-9a-fA-F]{6,8}$/.test(active.replace(/^#/,'#'))) return
      if (!/^#?[0-9a-fA-F]{6,8}$/.test(inactive.replace(/^#/,'#'))) return
      function toRgb6(hex) {
        let s = String(hex).trim()
        if (!s.startsWith('#')) s = '#' + s
        // #AARRGGBB -> #RRGGBB
        if (s.length === 9) return '#' + s.slice(3)
        // already #RRGGBB
        if (s.length === 7) return s
        return s
      }
      const aHex = toRgb6(active)
      const iHex = toRgb6(inactive)
      // Replace first occurrences; preserve indentation and original quote style
      // Match forms like: active-color "#rrggbb", active-color '#rrggbb', with optional colon
      let out = text
      out = out.replace(/(^|\n)([\t ]*)active-color\s*:?\s*(["'])[^"']*\3/, function(m, pre, indent, q) {
        return pre + indent + "active-color " + q + aHex + q
      })
      out = out.replace(/(^|\n)([\t ]*)inactive-color\s*:?\s*(["'])[^"']*\3/, function(m, pre, indent, q) {
        return pre + indent + "inactive-color " + q + iHex + q
      })
      if (out !== text) {
        const b64 = Qt.btoa(out)
        console.log('[Niri] writing updated active/inactive colors to', niriConfigFileAbs)
        niriSaveProc.command = [
          "bash","-lc",
          "mkdir -p ~/.config/niri && printf '%s' '" + b64 + "' | base64 -d > '" + niriConfigFileAbs + "'"
        ]
        niriSaveProc.running = true
      }
    } catch (e) { /* ignore */ }
  }

  // Reset all theme colors to their built-in defaults
  function resetTheme() {
    // Prefer loading from external defaults file; fallback to built-in defaults
    _resetFromDefaultsRequested = true
    if (defaultsView) defaultsView.reload()
  }

  // Reset only COLOR-related properties to built-in defaults.
  // Keeps layout, visibility toggles, margins, etc. intact.
  function resetColorTheme() {
    // Bar colors
    barBgColor = "#40000000"
    barBorderColor = "#00bee7"
    hoverHighlightColor = "#00bee7"
    // Module/text colors
    moduleIconColor = "#FFFFFF"
    moduleValueColor = "#FFFFFF"
    windowTitleColor = "#00bee7"
    visualizerBarColor = "#00bee7"
    // Workspaces
    workspaceActiveBg = "#4000bee7"
    workspaceActiveBorder = "#00bee7"
    workspaceInactiveBg = "#00000000"
    workspaceInactiveBorder = "#00bee7"
    workspaceTextColor = "#FFFFFF"
    // Tooltip/Popup
    tooltipBg = ""
    tooltipText = "#FFFFFF"
    tooltipBorder = ""
    tooltipFontPixelSize = 12
    tooltipFontFamily = ""
    popupBg = ""
    popupText = "#FFFFFF"
    popupBorder = ""
    // System tray
    trayIconColor = ""
  }

  // Reset only COLOR-related properties from external defaults file (root:/defaults)
  // Keeps layout, visibility, margins, etc. intact. Falls back to built-ins if load fails.
  function resetColorsFromDefaults() {
    _resetColorsFromDefaultsRequested = true
    if (defaultsView) defaultsView.reload()
  }

  // Built-in defaults as a fallback when defaults file is missing/invalid
  function applyBuiltinDefaults() {
    // Bar
    barBgColor = "#40000000"
    barBorderColor = "#00bee7"
    barPosition = "top"
    baseBarHeight = 38
    barEdgeMargin = 6
    barSideMargin = 12
    barHidden = false
    hoverHighlightColor = "#00bee7"
    // Modules
    moduleIconColor = "#FFFFFF"
    moduleValueColor = "#FFFFFF"
    // Workspaces
    workspaceActiveBg = "#4000bee7"
    workspaceActiveBorder = "#00bee7"
    workspaceInactiveBg = "#00000000"
    workspaceInactiveBorder = "#00bee7"
    workspaceTextColor = "#FFFFFF"
    // Tooltips
    tooltipBg = ""
    tooltipText = "#FFFFFF"
    tooltipBorder = ""
    tooltipFontPixelSize = 12
    tooltipFontFamily = ""
    // Popups
    popupBg = ""
    popupText = "#FFFFFF"
    popupBorder = ""
    // System tray
    trayIconColor = ""
    // Title & visualizer
    windowTitleColor = "#00bee7"
    // Visualizer bars
    visualizerBarColor = "#00bee7"
    useMatugenColors = false
    // Weather
    weatherLocation = ""
    weatherUnit = "C"
    showWeather = true
    // Keybinds path
    keybindsPath = ""
    // Keybinds
    showKeybinds = true
    // Toggles
    showWelcome = true
    showWindowTitle = true
    showWorkspaces = true
    showSystemTray = true
    showUpdates = true
    showNetwork = true
    showBluetooth = true
    showCPU = true
    showGPU = true
    showMemory = true
    showPowerProfiles = true
    showClipboard = true
    showNotifications = true
    showWindowSelector = true
    showSound = true
    showBattery = true
    showDate = true
    showTime = true
    showPower = true
    // Reorder defaults
    reorderMode = false
    swapTitleAndWorkspaces = false
    rightModulesOrder = [
      "SystemTray","Updates","Network","Bluetooth","CPU","GPU","Memory",
      "PowerProfiles","Battery","Clipboard","Notifications","WindowSelector","Sound","Weather",
      "Date","Time","Keybinds","Power"
    ]
    // Window title
    windowTitleColor = "#00bee7"
    // Visualizer bars
    visualizerBarColor = "#00bee7"
    useMatugenColors = false
    // Weather
    weatherLocation = ""
    weatherUnit = "C"
    showWeather = false
    // Keybinds path
    keybindsPath = ""
    // Keybinds
    showKeybinds = false

    // Dock (legacy)
    dockEnabled = true
    dockPosition = "right"
    dockShowLabels = true
    dockTileSize = 64
    dockTileSpacing = 8
    dockItems = []
    // Dock (new)
    showDock = true
    dockPositionHorizontal = "right"
    dockPositionVertical = "center"
    dockIconBorderPx = 2
    dockIconRadius = 10
    dockIconSizePx = 64
    dockIconLabel = true
    dockIconSpacing = 0
    dockIconBGColor = "#202020"
    dockIconBorderColor = "#808080"
    dockIconLabelColor = "#FFFFFF"
    allowDockIconMovement = false
    dockItems = [
      { label: "Browser", cmd: "xdg-open https://example.com" },
      { label: "Terminal", cmd: "alacritty" }
    ]
    // Wallpaper defaults
    wallpaperAnimatedEnabled = false
    wallpaperAnimatedPath = ""
    wallpaperStaticPath = ""
    wallpaperOutputs = []
    mpvpaperOptions = "--loop --no-audio"
    wallpaperTool = "swww"
  }

  // Apply keys from a loaded theme object safely
  function applyTheme(obj) {
    if (!obj) return
    // Preserve original types from JSON (booleans must stay booleans)
    function setIf(k) { if (obj[k] !== undefined) Globals[k] = obj[k] }
    setIf("barBgColor")
    setIf("barBorderColor")
    setIf("barPosition")
    setIf("baseBarHeight")
    setIf("barEdgeMargin")
    setIf("barSideMargin")
    setIf("barHidden")
    setIf("useMatugenColors")
    setIf("hoverHighlightColor")
    setIf("moduleIconColor")
    setIf("moduleValueColor")
    setIf("workspaceActiveBg")
    setIf("workspaceActiveBorder")
    setIf("workspaceInactiveBg")
    setIf("workspaceInactiveBorder")
    setIf("workspaceTextColor")
    setIf("tooltipBg")
    setIf("tooltipText")
    setIf("tooltipBorder")
    setIf("tooltipFontPixelSize")
    setIf("tooltipFontFamily")
    setIf("popupBg")
    setIf("popupText")
    setIf("popupBorder")
    setIf("trayIconColor")
    setIf("reorderMode")
    setIf("swapTitleAndWorkspaces")
    setIf("useMatugenColors")
    setIf("rightModulesOrder")
    // toggles
    setIf("showWelcome")
    setIf("showWindowTitle")
    setIf("showWorkspaces")
    setIf("showSystemTray")
    setIf("showUpdates")
    setIf("showNetwork")
    setIf("showBluetooth")
    setIf("showCPU")
    setIf("showGPU")
    setIf("showMemory")
    setIf("showPowerProfiles")
    setIf("showClipboard")
    setIf("showNotifications")
    setIf("showWindowSelector")
    setIf("showSound")
    setIf("showKeybinds")
    setIf("showBattery")
    setIf("showDate")
    setIf("showTime")
    setIf("showPower")
    setIf("windowTitleColor")
    setIf("visualizerBarColor")
    setIf("weatherLocation")
    setIf("weatherUnit")
    setIf("showWeather")
    setIf("keybindsPath")
    // Wallpaper
    setIf("wallpaperAnimatedEnabled")
    setIf("wallpaperAnimatedPath")
    setIf("wallpaperStaticPath")
    setIf("wallpaperOutputs")
    setIf("mpvpaperOptions")
    setIf("wallpaperTool")
    // Setup UI
    setIf("useNewSetupUI")
    setIf("showBarvisualizer")
    // Dock (legacy)
    setIf("dockEnabled")
    setIf("dockPosition")
    setIf("dockShowLabels")
    setIf("dockTileSize")
    setIf("dockTileSpacing")
    setIf("dockItems")
    // Dock (new): map uppercase JSON keys to lowercase QML properties
    if (obj.ShowDock !== undefined) Globals.showDock = obj.ShowDock
    if (obj.DockPositionHorizontal !== undefined) Globals.dockPositionHorizontal = obj.DockPositionHorizontal
    if (obj.DockPositionVertical !== undefined) Globals.dockPositionVertical = obj.DockPositionVertical
    if (obj.DockIconBorderPx !== undefined) Globals.dockIconBorderPx = obj.DockIconBorderPx
    if (obj.DockIconRadius !== undefined) Globals.dockIconRadius = obj.DockIconRadius
    if (obj.DockIconSizePx !== undefined) Globals.dockIconSizePx = obj.DockIconSizePx
    if (obj.DockIconLabel !== undefined) Globals.dockIconLabel = obj.DockIconLabel
    if (obj.DockIconSpacing !== undefined) Globals.dockIconSpacing = obj.DockIconSpacing
    if (obj.DockIconBGColor !== undefined) Globals.dockIconBGColor = obj.DockIconBGColor
    // If Matugen is enabled, re-apply the cached palette to avoid theme loads overriding Matugen-driven colors
    if (Globals.useMatugenColors && Globals._lastMatugenMap) {
      Globals.applyMatugenMap(Globals._lastMatugenMap)
    }
    if (obj.DockIconBorderColor !== undefined) Globals.dockIconBorderColor = obj.DockIconBorderColor
    // Prefer new DockIconLabelTextColor; fallback to legacy DockIconLabelColor
    if (obj.DockIconLabelTextColor !== undefined) Globals.dockIconLabelColor = obj.DockIconLabelTextColor
    else if (obj.DockIconLabelColor !== undefined) Globals.dockIconLabelColor = obj.DockIconLabelColor
    if (obj.AllowDockIconMovement !== undefined) Globals.allowDockIconMovement = obj.AllowDockIconMovement
    // Back-compat: accept DockLayerPosition ("on top"|"autohide")
    if (obj.DockLayerPosition !== undefined) Globals.dockLayerPosition = obj.DockLayerPosition
    // New: AutoHide boolean has priority if present
    if (obj.AutoHide !== undefined) Globals.dockLayerPosition = (obj.AutoHide ? "autohide" : "on top")
    // durations: read specific first, then fallback to unified if provided
    const hasIn = (obj.DockAutoHideInDurationMs !== undefined)
    const hasOut = (obj.DockAutoHideOutDurationMs !== undefined)
    if (hasIn) Globals.dockAutoHideInDurationMs = obj.DockAutoHideInDurationMs
    if (hasOut) Globals.dockAutoHideOutDurationMs = obj.DockAutoHideOutDurationMs
    if (obj.DockAutoHideDurationMs !== undefined && !hasIn && !hasOut) {
      Globals.dockAutoHideDurationMs = obj.DockAutoHideDurationMs
      Globals.dockAutoHideInDurationMs = obj.DockAutoHideDurationMs
      Globals.dockAutoHideOutDurationMs = obj.DockAutoHideDurationMs
    }
    if (obj.DockItems !== undefined) Globals.dockItems = obj.DockItems
  }

  // Load theme from file on startup handled by loadThemeProc.running

  // Save current theme to file
  function saveTheme() {
    const obj = {
      // Layout
      barPosition,
      baseBarHeight,
      barEdgeMargin,
      barSideMargin,
      barHidden,
      // Persist Matugen flag right after barHidden as requested
      useMatugenColors,
      // Colors
      barBgColor,
      barBorderColor,
      hoverHighlightColor,
      moduleIconColor,
      moduleValueColor,
      workspaceActiveBg,
      workspaceActiveBorder,
      workspaceInactiveBg,
      workspaceInactiveBorder,
      workspaceTextColor,
      tooltipBg,
      tooltipText,
      tooltipBorder,
      tooltipFontPixelSize,
      tooltipFontFamily,
      popupBg,
      popupText,
      popupBorder,
      trayIconColor,
      windowTitleColor,
      visualizerBarColor,
      // Layout & behavior
      reorderMode,
      swapTitleAndWorkspaces,
      rightModulesOrder,
      // toggles
      showWelcome,
      showWindowTitle,
      showWorkspaces,
      showSystemTray,
      showUpdates,
      showNetwork,
      showBluetooth,
      showCPU,
      showGPU,
      showMemory,
      showPowerProfiles,
      showClipboard,
      showNotifications,
      showWindowSelector,
      showSound,
      showKeybinds,
      showBattery,
      showDate,
      showTime,
      showPower,
      showWeather,
      // Weather
      weatherLocation,
      weatherUnit,
      // Keybinds path
      keybindsPath,
      // Wallpaper
      wallpaperAnimatedEnabled,
      wallpaperAnimatedPath,
      wallpaperStaticPath,
      wallpaperOutputs,
      mpvpaperOptions,
      wallpaperTool,
      // Setup UI flag
      useNewSetupUI,
      showBarvisualizer,
      // Dock (new, persisted with uppercase keys for config.json)
      ShowDock: showDock,
      DockPositionHorizontal: dockPositionHorizontal,
      DockPositionVertical: dockPositionVertical,
      DockIconBorderPx: dockIconBorderPx,
      DockIconRadius: dockIconRadius,
      DockIconSizePx: dockIconSizePx,
      DockIconLabel: dockIconLabel,
      DockIconSpacing: dockIconSpacing,
      DockIconBGColor: dockIconBGColor,
      DockIconBorderColor: dockIconBorderColor,
      DockIconLabelTextColor: dockIconLabelColor,
      AllowDockIconMovement: allowDockIconMovement,
      // New: persist boolean instead of string mode
      AutoHide: (dockLayerPosition === "autohide"),
      DockAutoHideInDurationMs: dockAutoHideInDurationMs,
      DockAutoHideOutDurationMs: dockAutoHideOutDurationMs,
      DockItems: dockItems
    }
    const json = JSON.stringify(obj, null, 2)
    // Avoid complex shell escaping by writing base64 and decoding
    const b64 = Qt.btoa(json)
    saveThemeProc.command = [
      "bash", "-lc",
      "mkdir -p ~/.config/quickshell/Celona && printf '%s' '" + b64 + "' | base64 -d > " + themeFile
    ]
    saveThemeProc.running = true
  }

  Process {
    id: loadThemeProc
    // Read as base64 (single line) to avoid line-splitting issues
    command: ["bash", "-lc", "base64 -w0 " + Globals.themeFile + " 2>/dev/null || true"]
    running: true
    stdout: SplitParser {
      onRead: (data) => { Globals._themeBuf += String(data) }
    }
    onRunningChanged: if (!running) {
      if (Globals._themeBuf && Globals._themeBuf.length) {
        try {
          const jsonText = Qt.atob(Globals._themeBuf)
          Globals.applyTheme(JSON.parse(jsonText))
        } catch (e) { /* ignore parse errors */ }
      }
      Globals._themeBuf = ""
      // After applying theme, override keybindsPath from repo config if provided
      if (Globals._repoKeybindsPath && Globals._repoKeybindsPath.trim().length) {
        Globals.keybindsPath = Globals._repoKeybindsPath
      }
      if (Globals.useMatugenColors) Globals.applyMatugenColors()
      // Apply wallpaper state on startup
      if (Globals.wallpaperAnimatedEnabled === true) {
        Globals.startAnimatedWallpaper()
      } else {
        Globals.stopAnimatedAndSetStatic()
      }
    }
  }

  // Lightweight reader for Niri config to allow in-memory edits
  FileView {
    id: niriView
    path: niriConfigFileAbs
    onLoaded: { /* noop */ }
    onLoadFailed: (error) => { /* ignore (Niri may not be installed) */ }
  }

  // Lightweight reader for Ghostty theme file
  FileView {
    id: ghosttyView
    path: ghosttyThemeFileAbs
    onLoaded: { /* noop */ }
    onLoadFailed: (error) => { /* ok if file doesn't exist; we'll create it on write */ }
  }
  // Lightweight reader for Hyprgreetr config file
  FileView {
    id: hyprgreetrView
    path: hyprgreetrConfigFileAbs
    onLoaded: { /* noop */ }
    onLoadFailed: (error) => { /* ignore (Hyprgreetr may not be installed) */ }
  }
  // Lightweight reader for Hyprlock config file
  FileView {
    id: hyprlockView
    path: hyprlockConfigFileAbs
    onLoaded: {
      // If Matugen is active and we have a cached map, apply immediately
      if (Globals.useMatugenColors && Globals._lastMatugenMap) {
        updateHyprlockThemeFromMap(Globals._lastMatugenMap)
      }
    }
    onLoadFailed: (error) => { /* ignore (Hyprlock may not be installed) */ }
  }
  // Lightweight reader for Cava config file
  FileView {
    id: cavaView
    path: cavaConfigFileAbs
    onLoaded: { /* noop */ }
    onLoadFailed: (error) => { /* ignore (Cava may not be installed) */ }
  }

  Process { id: saveThemeProc; running: false }
  // Writer for Niri config updates
  Process { id: niriSaveProc; running: false }
  // Writer for Ghostty theme updates
  Process { id: ghosttySaveProc; running: false }
  // Writer for Fuzzel theme updates
  Process { id: fuzzelSaveProc; running: false }
  // Writer for Hyprgreetr updates
  Process { id: hyprgreetrSaveProc; running: false }
  // Writer for Hyprlock updates
  Process { id: hyprlockSaveProc; running: false }
  // Writer for Cava updates
  Process { id: cavaSaveProc; running: false }
  // Writer for SwayNC style updates
  Process { id: swayncSaveProc; running: false }

  // --- Wallpaper control processes ---
  // Single process used for wallpaper commands; we queue when busy
  property string _wpQueuedScript: ""
  Process {
    id: wpProc
    running: false
    // Remove custom environment - inherit from parent shell completely
    stdout: SplitParser { }
    stderr: SplitParser { }
    onRunningChanged: if (!running && Globals._wpQueuedScript && Globals._wpQueuedScript.length) {
      const next = Globals._wpQueuedScript
      Globals._wpQueuedScript = ""
      wpProc.command = ["bash", "-lc", next]
      wpProc.running = true
    }
  }

  // Start animated wallpaper with mpvpaper for configured outputs
  function startAnimatedWallpaper() {
    const vid = String(wallpaperAnimatedPath || "").trim()
    const outs = Array.isArray(wallpaperOutputs) ? wallpaperOutputs : []
    if (!vid || outs.length === 0) return
    const opts = String(mpvpaperOptions || "").trim()
    // Build a small bash script: kill existing mpvpaper, then start one per output
    let script = "set -e\n" +
                 "pkill -x mpvpaper 2>/dev/null || true\n" +
                 "sleep 0.2\n" +
                 "vid=\"" + vid.replace(/"/g, '\\"') + "\"\n" +
                 "if [ \"${vid#~/}\" != \"$vid\" ]; then vid=\"$HOME/${vid#~/}\"; fi\n" +
                 "opts=\"" + opts.replace(/"/g, '\\"') + "\"\n"
    for (let i = 0; i < outs.length; i++) {
      const o = String(outs[i])
      if (!o) continue
      script += "nohup mpvpaper -o \"$opts\" \"" + o.replace(/"/g, '\\"') + "\" \"$vid\" >/dev/null 2>&1 &\n"
    }
    if (wpProc.running) {
      Globals._wpQueuedScript = script
    } else {
      wpProc.command = ["bash", "-lc", script]
      wpProc.running = true
    }
  }

  // Stop mpvpaper and set static wallpaper via selected tool
  function stopAnimatedAndSetStatic() {
    const img = String(wallpaperStaticPath || "").trim()
    const outs = Array.isArray(wallpaperOutputs) ? wallpaperOutputs : []
    const tool = String(wallpaperTool || "swww").trim()
    // Always stop mpvpaper
    let script = "pkill -x mpvpaper 2>/dev/null || true\n" +
                 "sleep 0.2\n"
    // Proceed if we have an image
    if (img) {
      if (tool === "swww") {
        // Start swww-daemon if not running, then set wallpaper
        script += "pgrep -x swww-daemon >/dev/null 2>&1 || (nohup swww-daemon >/dev/null 2>&1 & sleep 1)\n"
        script += "swww img '" + img.replace(/'/g, "'\"'\"'") + "' --transition-type none\n"
      } else if (tool === "hyprpaper") {
        // Only applicable on Hyprland where hyprctl is available
        script += "command -v hyprctl >/dev/null 2>&1 || exit 0\n"
        // Ensure hyprpaper is running
        script += "pgrep -x hyprpaper >/dev/null 2>&1 || (nohup hyprpaper >/dev/null 2>&1 & sleep 0.2)\n"
        // Prepare image path and preload
        script += "img=\"" + img.replace(/"/g, '\\"') + "\"\n"
        script += "if [ \"${img#~/}\" != \"$img\" ]; then img=\"$HOME/${img#~/}\"; fi\n"
        script += "hyprctl hyprpaper preload \"$img\" >/dev/null 2>&1 || true\n"
        for (let i = 0; i < outs.length; i++) {
          const o = String(outs[i])
          if (!o) continue
          script += "hyprctl hyprpaper wallpaper \"" + o.replace(/"/g, '\\"') + ",${img}\" >/dev/null 2>&1 || true\n"
        }
      } else {
        // Unknown tool: no-op after stopping mpvpaper
      }
    }
    if (wpProc.running) {
      Globals._wpQueuedScript = script
    } else {
      wpProc.command = ["bash", "-lc", script]
      wpProc.running = true
    }
  }

  // Read colors.css if present
  // Lightweight reader for defaults file
  FileView {
    id: defaultsView
    path: defaultsFile
    onLoaded: {
      if (!_resetFromDefaultsRequested && !_resetColorsFromDefaultsRequested) return
      try {
        const text = defaultsView.text()
        const obj = JSON.parse(text)
        if (_resetFromDefaultsRequested) {
          _resetFromDefaultsRequested = false
          Globals.applyTheme(obj)
          Globals.saveTheme()
        } else if (_resetColorsFromDefaultsRequested) {
          _resetColorsFromDefaultsRequested = false
          // apply only color-related keys when present
          function setIf(k) { if (obj[k] !== undefined) Globals[k] = obj[k] }
          setIf("barBgColor")
          setIf("barBorderColor")
          setIf("hoverHighlightColor")
          setIf("moduleIconColor")
          setIf("moduleValueColor")
          setIf("windowTitleColor")
          setIf("visualizerBarColor")
          setIf("workspaceActiveBg")
          setIf("workspaceActiveBorder")
          setIf("workspaceInactiveBg")
          setIf("workspaceInactiveBorder")
          setIf("workspaceTextColor")
          setIf("tooltipBg")
          setIf("tooltipText")
          setIf("tooltipBorder")
          setIf("tooltipFontPixelSize")
          setIf("tooltipFontFamily")
          setIf("popupBg")
          setIf("popupText")
          setIf("popupBorder")
          setIf("trayIconColor")
          Globals.saveTheme()
        }
      } catch (e) {
        if (_resetFromDefaultsRequested) {
          _resetFromDefaultsRequested = false
          Globals.applyBuiltinDefaults()
        } else if (_resetColorsFromDefaultsRequested) {
          _resetColorsFromDefaultsRequested = false
          Globals.resetColorTheme()
        }
      }
    }
    onLoadFailed: (error) => {
      if (_resetFromDefaultsRequested) {
        _resetFromDefaultsRequested = false
        Globals.applyBuiltinDefaults()
      } else if (_resetColorsFromDefaultsRequested) {
        _resetColorsFromDefaultsRequested = false
        Globals.resetColorTheme()
      }
    }
  }
  // Development convenience: read keybindsPath from repository config.json if present
  // Allows running directly from the repo without saving a theme first.
  FileView {
    id: repoConfigView
    path: Qt.resolvedUrl("root:/config.json")
    onLoaded: {
      try {
        const text = repoConfigView.text()
        const obj = JSON.parse(text)
        if (obj && obj.keybindsPath && String(obj.keybindsPath).trim().length) {
          Globals._repoKeybindsPath = obj.keybindsPath
          // If theme has already loaded, apply immediately
          if (!loadThemeProc.running) Globals.keybindsPath = Globals._repoKeybindsPath
        }
      } catch (e) { /* ignore */ }
    }
    onLoadFailed: (error) => { /* ignore */ }
  }
  FileView {
    id: matugenView
    path: Qt.resolvedUrl("root:/colors.css")
    onLoaded: {
      Globals.matugenAvailable = true
      if (!Globals.useMatugenColors) return
      try {
        const text = matugenView.text()
        const hash = Qt.md5(text)
        const changed = (hash !== Globals._matugenHash)
        const lines = text.split(/\r?\n/)
        const map = {}
        for (let raw of lines) {
          const m = raw.match(/@define-color\s+([a-zA-Z0-9_\-]+)\s+([^;]+);/)
          if (m) map[m[1]] = m[2].trim()
        }
        // Always refresh the cached map for late consumers
        Globals._lastMatugenMap = map
        if (changed) {
          // Set hash first to avoid re-entrancy loops if anything causes another onLoaded during apply
          Globals._matugenHash = hash
          Globals.applyMatugenMap(map)
          Globals.saveTheme()
        }
      } catch (e) { /* ignore */ }
    }
    onLoadFailed: (error) => { Globals.matugenAvailable = false }
  }

  // Update Fuzzel theme keys from Matugen map
  function updateFuzzelThemeFromMap(map) {
    try {
      const pick = (k, d) => (map && map[k] !== undefined ? map[k] : d)
      const bg = pick('background', '#111318')
      const onSurf = pick('on_surface', '#e2e2e9')
      const onSurfVar = pick('on_surface_variant', '#c4c6d0')
      const invPrim = pick('inverse_primary', '#415e91')
      const surfVar = pick('surface_variant', '#2a2f37')
      const scHigh = pick('surface_container_high', '#343a46')
      const scLow = pick('surface_container_low', '#1b1f27')
      const primary = pick('primary', '#89b4fa')
      const blur8 = pick('blur_background8', 'rgba(17,19,24,0.8)')

      // Decide selection bg based on background luminance
      const bg6 = toRgb6(bg)
      const r = parseInt(bg6.slice(0,2),16)/255.0
      const g = parseInt(bg6.slice(2,4),16)/255.0
      const b = parseInt(bg6.slice(4,6),16)/255.0
      const lum = 0.2126*r + 0.7152*g + 0.0722*b
      const selBg6 = toRgb6(lum >= 0.5 ? scHigh : scLow)

      const background = toRgba8(blur8)
      const text = toRgba8(onSurf)
      const prompt = toRgba8(onSurfVar)
      const placeholder = toRgba8(onSurfVar)
      const input = toRgba8(onSurf)
      const match = toRgba8(primary)
      const selection = toRgba8('#' + selBg6)
      const selectionText = toRgba8(onSurf)
      const selectionMatch = toRgba8(primary)
      const counter = toRgba8(onSurfVar)
      const border = toRgba8(primary)

      let out = ''
      out += '[colors]\n'
      out += 'background=' + background + '\n'
      out += 'text=' + text + '\n'
      out += 'prompt=' + prompt + '\n'
      out += 'placeholder=' + placeholder + '\n'
      out += 'input=' + input + '\n'
      out += 'match=' + match + '\n'
      out += 'selection=' + selection + '\n'
      out += 'selection-text=' + selectionText + '\n'
      out += 'selection-match=' + selectionMatch + '\n'
      out += 'counter=' + counter + '\n'
      out += 'border=' + border + '\n'

      const b64 = Qt.btoa(out)
      console.log('[Fuzzel] writing theme to', fuzzelThemeFileAbs)
      fuzzelSaveProc.command = ["bash","-lc",
        "mkdir -p ~/.config/fuzzel/themes && printf '%s' '" + b64 + "' | base64 -d > " + fuzzelThemeFileAbs]
      fuzzelSaveProc.running = true
    } catch (e) { /* ignore */ }
  }

  // Watcher: periodically reload colors.css when Matugen is enabled to auto-apply on changes
  Timer {
    id: matugenWatch
    interval: 3000
    repeat: true
    running: Globals.useMatugenColors && Globals.matugenAvailable
    onTriggered: {
      if (Globals.useMatugenColors) matugenView.reload()
    }
  }

  // --- Live watch for Dock settings in theme file (config.json) ---
  // Only applies Dock-related keys to avoid side effects.
  // Detect changes using a reduced JSON subset hash.
  property string _dockConfigHash: ""
  // Buffer for base64 read of theme file
  property string _dockBuf: ""
  Process {
    id: dockWatchProc
    // Read as base64 to avoid line-splitting; shell expands ~ for any user
    command: ["bash", "-lc", "base64 -w0 " + Globals.themeFile + " 2>/dev/null || true"]
    running: false
    stdout: SplitParser {
      onRead: (data) => { Globals._dockBuf += String(data) }
    }
    onRunningChanged: if (!running) {
      if (Globals._dockBuf && Globals._dockBuf.length) {
        try {
          const jsonText = Qt.atob(Globals._dockBuf)
          const obj = JSON.parse(jsonText)
          // Reduced Dock subset
          const subset = {
            ShowDock: obj.ShowDock,
            DockPositionHorizontal: obj.DockPositionHorizontal,
            DockPositionVertical: obj.DockPositionVertical,
            DockIconBorderPx: obj.DockIconBorderPx,
            DockIconRadius: obj.DockIconRadius,
            DockIconSizePx: obj.DockIconSizePx,
            DockIconLabel: obj.DockIconLabel,
            DockIconSpacing: obj.DockIconSpacing,
            DockIconBGColor: obj.DockIconBGColor,
            DockIconBorderColor: obj.DockIconBorderColor,
            DockIconLabelTextColor: obj.DockIconLabelTextColor !== undefined ? obj.DockIconLabelTextColor : obj.DockIconLabelColor,
            AllowDockIconMovement: obj.AllowDockIconMovement,
            AutoHide: obj.AutoHide,
            DockLayerPosition: obj.DockLayerPosition,
            DockAutoHideInDurationMs: obj.DockAutoHideInDurationMs,
            DockAutoHideOutDurationMs: obj.DockAutoHideOutDurationMs,
            DockItems: obj.DockItems
          }
          const hash = Qt.md5(JSON.stringify(subset))
          if (hash !== Globals._dockConfigHash) {
            Globals._dockConfigHash = hash
            // Apply only Dock-related keys
            if (subset.ShowDock !== undefined) Globals.showDock = subset.ShowDock
            if (subset.DockPositionHorizontal !== undefined) Globals.dockPositionHorizontal = subset.DockPositionHorizontal
            if (subset.DockPositionVertical !== undefined) Globals.dockPositionVertical = subset.DockPositionVertical
            if (subset.DockIconBorderPx !== undefined) Globals.dockIconBorderPx = subset.DockIconBorderPx
            if (subset.DockIconRadius !== undefined) Globals.dockIconRadius = subset.DockIconRadius
            if (subset.DockIconSizePx !== undefined) Globals.dockIconSizePx = subset.DockIconSizePx
            if (subset.DockIconLabel !== undefined) Globals.dockIconLabel = subset.DockIconLabel
            if (subset.DockIconSpacing !== undefined) Globals.dockIconSpacing = subset.DockIconSpacing
            if (subset.DockIconBGColor !== undefined) Globals.dockIconBGColor = subset.DockIconBGColor
            if (subset.DockIconBorderColor !== undefined) Globals.dockIconBorderColor = subset.DockIconBorderColor
            if (subset.DockIconLabelTextColor !== undefined) Globals.dockIconLabelColor = subset.DockIconLabelTextColor
            if (subset.AllowDockIconMovement !== undefined) Globals.allowDockIconMovement = subset.AllowDockIconMovement
            // New boolean has priority; fallback to legacy string
            if (subset.AutoHide !== undefined) Globals.dockLayerPosition = (subset.AutoHide ? "autohide" : "on top")
            else if (subset.DockLayerPosition !== undefined) Globals.dockLayerPosition = subset.DockLayerPosition
            if (subset.DockAutoHideInDurationMs !== undefined && subset.DockAutoHideOutDurationMs === undefined) {
              Globals.dockAutoHideInDurationMs = subset.DockAutoHideInDurationMs
              Globals.dockAutoHideOutDurationMs = subset.DockAutoHideInDurationMs
            } else {
              if (subset.DockAutoHideInDurationMs !== undefined) Globals.dockAutoHideInDurationMs = subset.DockAutoHideInDurationMs
              if (subset.DockAutoHideOutDurationMs !== undefined) Globals.dockAutoHideOutDurationMs = subset.DockAutoHideOutDurationMs
            }
            if (subset.DockItems !== undefined) Globals.dockItems = subset.DockItems
          }
        } catch (e) { /* ignore parse errors */ }
      }
      Globals._dockBuf = ""
    }
  }
  Timer {
    id: themeWatch
    interval: 1500
    repeat: true
    running: true
    onTriggered: if (!dockWatchProc.running) dockWatchProc.running = true
  }

  // Note: we don't use Component.onCompleted in Singleton context
}
