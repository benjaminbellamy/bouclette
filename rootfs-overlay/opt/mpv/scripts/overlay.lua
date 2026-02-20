-- overlay.lua
-- Real-time chapter progress overlay for mpv.
-- Replicates video_chapters.py visuals without pre-rendering.
-- Place in /opt/mpv/scripts/overlay.lua

-- ── Configuration ─────────────────────────────────────────────────────────────

local CFG = {
  -- Seconds to show chapter list at the start of each chapter
  display_secs  = 5,

  -- Progress bar height in pixels
  bar_h         = 3,

  -- Pie chart radius in pixels
  pie_r         = 20,
  pie_margin    = 10,

  -- Font for chapter list
  font_name     = "sans-serif",
  font_size     = 28,          -- in ASS "points" (scaled to video height)

  -- Colors: ASS format &HAABBGGRR& (AA=00 opaque, FF transparent)
  -- main      = progress fill, pie fill, active chapter title
  -- secondary = bar/pie background, chapter list background
  -- tertiary  = inactive chapter titles
  color_main      = "&H80FF8000&",   -- teal,  50% opacity
  color_secondary = "&H80404040&",   -- dark grey, 50% opacity
  color_tertiary  = "&H80C0C0C0&",   -- light grey, 50% opacity
  alpha_main      = "&H80&",
  alpha_secondary = "&H80&",
  alpha_tertiary  = "&H80&",
}

-- ── ASS helpers ───────────────────────────────────────────────────────────────

-- ASS drawing: filled rectangle
local function ass_rect(x1, y1, x2, y2)
  return string.format("{\\p1}m %d %d l %d %d %d %d %d %d{\\p0}",
    x1, y1,  x2, y1,  x2, y2,  x1, y2)
end

-- ASS drawing: filled circle approximated with 4 cubic bezier curves
-- Center (cx,cy), radius r
local function ass_circle(cx, cy, r)
  -- bezier magic number: 4*(sqrt(2)-1)/3 ≈ 0.5523
  local k = math.floor(r * 0.5523 + 0.5)
  return string.format(
    "{\\p1}m %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d "..
    "b %d %d %d %d %d %d b %d %d %d %d %d %d{\\p0}",
    cx, cy - r,
    cx+k, cy-r,  cx+r, cy-k,  cx+r, cy,
    cx+r, cy+k,  cx+k, cy+r,  cx,   cy+r,
    cx-k, cy+r,  cx-r, cy+k,  cx-r, cy,
    cx-r, cy-k,  cx-k, cy-r,  cx,   cy-r
  )
end

-- ASS drawing: filled pie slice from angle a1 to a2 (degrees, 0=right, CCW)
-- Approximated as a polygon fan — good enough at pie_r=20
local function ass_pie(cx, cy, r, a1_deg, a2_deg)
  -- normalise
  while a2_deg < a1_deg do a2_deg = a2_deg + 360 end
  local steps = math.max(3, math.floor((a2_deg - a1_deg) / 6))
  local parts = {string.format("{\\p1}m %d %d", cx, cy)}
  for i = 0, steps do
    local a = math.rad(a1_deg + (a2_deg - a1_deg) * i / steps)
    parts[#parts+1] = string.format("l %d %d",
      math.floor(cx + r * math.cos(a) + 0.5),
      math.floor(cy + r * math.sin(a) + 0.5))
  end
  parts[#parts+1] = string.format("l %d %d{\\p0}", cx, cy)
  return table.concat(parts, " ")
end

-- Wrap a drawing command in ASS color/alpha tags
local function colored(color, alpha, drawing)
  return string.format("{\\c%s\\1a%s\\bord0\\shad0}%s", color, alpha, drawing)
end

-- Wrap a text line in ASS tags (positioned at x,y, left-top anchor)
local function ass_text(x, y, color, alpha, font, size, text)
  return string.format(
    "{\\an7\\pos(%d,%d)\\fn%s\\fs%d\\c%s\\1a%s\\bord0\\shad0}%s",
    x, y, font, size, color, alpha, text)
end

-- ── Chapter helpers ───────────────────────────────────────────────────────────

local function get_chapters()
  local n = mp.get_property_number("chapter-list/count", 0)
  local list = {}
  for i = 0, n - 1 do
    list[i+1] = {
      time  = mp.get_property_number(string.format("chapter-list/%d/time", i), 0),
      title = mp.get_property(string.format("chapter-list/%d/title", i)) or
              string.format("Chapter %d", i + 1),
    }
  end
  return list
end

local function current_chapter_idx(chapters, pos)
  local idx = 1
  for i, c in ipairs(chapters) do
    if pos >= c.time then idx = i end
  end
  return idx
end

-- ── Main tick ─────────────────────────────────────────────────────────────────

local overlay = mp.create_osd_overlay("ass-events")

local function update()
  local pos = mp.get_property_number("time-pos", 0)
  local dur = mp.get_property_number("duration",  0)
  if not pos or not dur or dur == 0 then
    overlay.data = ""
    overlay:update()
    return
  end

  local vw = mp.get_property_number("osd-width",  1920)
  local vh = mp.get_property_number("osd-height", 1080)

  local chapters = get_chapters()
  local has_chapters = #chapters > 0

  -- Per-chapter progress
  local chap_start, chap_end = 0, dur
  local cur_idx = 1
  if has_chapters then
    cur_idx    = current_chapter_idx(chapters, pos)
    chap_start = chapters[cur_idx].time
    chap_end   = (chapters[cur_idx + 1] and chapters[cur_idx + 1].time) or dur
  end
  local chap_dur  = chap_end - chap_start
  local chap_prog = chap_dur > 0 and
                    math.max(0, math.min((pos - chap_start) / chap_dur, 1)) or 0

  -- Global progress
  local glob_prog = math.max(0, math.min(pos / dur, 1))

  local lines = {}

  -- ── Progress bar ────────────────────────────────────────────────────────
  local by = vh - CFG.bar_h
  -- background
  lines[#lines+1] = colored(CFG.color_secondary, CFG.alpha_secondary,
    ass_rect(0, by, vw, vh))
  -- foreground
  local bw = math.floor(chap_prog * vw + 0.5)
  if bw > 0 then
    lines[#lines+1] = colored(CFG.color_main, CFG.alpha_main,
      ass_rect(0, by, bw, vh))
  end

  -- ── Pie chart ───────────────────────────────────────────────────────────
  local pr = CFG.pie_r
  local pm = CFG.pie_margin
  local cx = vw - pr - pm
  local cy = vh - CFG.bar_h - pr - pm
  -- background circle
  lines[#lines+1] = colored(CFG.color_secondary, CFG.alpha_secondary,
    ass_circle(cx, cy, pr))
  -- progress slice (12-o'clock = -90 deg, clockwise)
  if glob_prog > 0.001 then
    lines[#lines+1] = colored(CFG.color_main, CFG.alpha_main,
      ass_pie(cx, cy, pr, -90, -90 + glob_prog * 360))
  end

  -- ── Chapter list ────────────────────────────────────────────────────────
  if has_chapters then
    local elapsed_in_chap = pos - chap_start
    local window = math.min(CFG.display_secs, chap_dur)
    if elapsed_in_chap < window then
      local tx, ty = 20, 20
      local pad    = 10
      local lh     = CFG.font_size + 4  -- line height

      local list_h = #chapters * lh
      local list_w = 0  -- background width; we use a fixed generous width
      -- Estimate background width: longest title * ~0.6 * font_size
      for _, c in ipairs(chapters) do
        local w = #c.title * CFG.font_size * 0.6
        if w > list_w then list_w = w end
      end
      list_w = math.floor(list_w + 0.5)

      -- Background rectangle
      lines[#lines+1] = colored(CFG.color_secondary, CFG.alpha_secondary,
        ass_rect(tx - pad, ty - pad,
                 tx + list_w + pad, ty + list_h + pad))

      -- Chapter titles
      for i, c in ipairs(chapters) do
        local color = (i == cur_idx) and CFG.color_main or CFG.color_tertiary
        local alpha = (i == cur_idx) and CFG.alpha_main or CFG.alpha_tertiary
        lines[#lines+1] = ass_text(
          tx, ty + (i - 1) * lh,
          color, alpha,
          CFG.font_name, CFG.font_size,
          c.title)
      end
    end
  end

  overlay.data = table.concat(lines, "\n")
  overlay:update()
end

-- Hook into mpv's playback tick
mp.register_event("tick", update)

-- Clear overlay when playback stops
mp.register_event("end-file", function()
  overlay.data = ""
  overlay:update()
end)
