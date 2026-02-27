-- bouclette-osd.lua
-- On-screen overlays for bouclette kiosk player:
--   • scrollbar       – chapter progress, 3 px at bottom of screen
--   • radial indicator – overall video progress, 20 px circle, bottom-right
--   • chapter index   – shown 2 s at each chapter start, top-left
--
-- Accent:  #c71f45  (ASS uses BGR order → 451FC7)
-- Passive: #ffffff 50 % / 75 % opacity

local mp      = require "mp"
local assdraw = require "mp.assdraw"

-- ── Configuration ─────────────────────────────────────────────────────────────

local ACCENT = "451FC7"   -- #c71f45 in ASS BGR
local WHITE  = "ffffff"
local BLACK  = "000000"

local BAR_H      = 3    -- scrollbar height (px)
-- CIR_R and CIR_MARG are computed dynamically as 1 % of video width in update()

local CH_MARG_X  = 10   -- chapter index: margin from left edge
local CH_MARG_Y  = 10   -- chapter index: margin from top edge
local CH_PAD     = 10   -- chapter index: padding between box edge and text
-- CH_FS is computed dynamically as 2 % of video height in update()
local CH_LINE_SP = 6    -- extra vertical spacing between lines
local CH_SHOW_S  = 2    -- seconds to display the chapter index

local UPDATE_HZ  = 30   -- overlay refresh rate (fps)

-- ── State ─────────────────────────────────────────────────────────────────────

local overlay         = mp.create_osd_overlay("ass-events")
local chapter_hide_at = 0   -- wall-clock time after which to hide chapter OSD
local last_chapter    = -2
local osd_visible     = true

-- ── Circle geometry ───────────────────────────────────────────────────────────
--
-- Angle convention: 0 = 12 o'clock, increasing clockwise (screen-space Y down).
--   x(a) = cx + r·sin(a)
--   y(a) = cy − r·cos(a)
--
-- Both shapes use line-segment polygons (32 steps = visually smooth at 20 px).

local SEGS = 32

local function ri(x) return math.floor(x + 0.5) end

-- Draw a filled disk.  Call between draw_start() / draw_stop().
local function draw_disk(ass, cx, cy, r)
    local pi = math.pi
    for i = 0, SEGS do
        local a = i * 2 * pi / SEGS
        local x = ri(cx + r * math.sin(a))
        local y = ri(cy - r * math.cos(a))
        if i == 0 then ass:move_to(x, y) else ass:line_to(x, y) end
    end
end

-- Draw a filled clockwise pie sector from 12 o'clock to `angle` radians.
-- 0 < angle ≤ 2π.  Call between draw_start() / draw_stop().
local function draw_sector(ass, cx, cy, r, angle)
    local pi = math.pi
    if angle <= 0 then return end
    if angle > 2 * pi then angle = 2 * pi end

    local n = math.max(3, ri(SEGS * angle / (2 * pi)))

    ass:move_to(ri(cx), ri(cy))       -- centre
    for i = 0, n do
        local a = angle * i / n
        ass:line_to(ri(cx + r * math.sin(a)), ri(cy - r * math.cos(a)))
    end
    ass:line_to(ri(cx), ri(cy))       -- back to centre
end

-- ── OSD update ────────────────────────────────────────────────────────────────

local function update()
    if not osd_visible then return end
    local W, H = mp.get_osd_size()
    if W <= 0 or H <= 0 then return end

    local t          = mp.get_property_number("time-pos",    0) or 0
    local dur        = mp.get_property_number("duration",    0) or 0
    local chap_idx   = mp.get_property_number("chapter",    -1) or -1
    local chap_list  = mp.get_property_native("chapter-list", {}) or {}

    -- Chapter progress (0–1) for the scrollbar ────────────────────────────────
    local chap_pct = 0
    if #chap_list > 0 and chap_idx >= 0 then
        local c0 = chap_list[chap_idx + 1]
        local c1 = chap_list[chap_idx + 2]
        local t0 = c0 and c0.time or 0
        local t1 = c1 and c1.time or dur
        local cd = t1 - t0
        if cd > 0 then
            chap_pct = math.max(0, math.min(1, (t - t0) / cd))
        end
    elseif dur > 0 then
        chap_pct = math.max(0, math.min(1, t / dur))
    end

    -- Overall progress (0–1) for the radial indicator ─────────────────────────
    local total_pct = (dur > 0) and math.max(0, math.min(1, t / dur)) or 0

    -- Chapter-change detection ─────────────────────────────────────────────────
    if chap_idx ~= last_chapter then
        if chap_idx >= 0 then
            chapter_hide_at = mp.get_time() + CH_SHOW_S
        end
        last_chapter = chap_idx
    end
    local show_chap = (#chap_list > 0) and (mp.get_time() < chapter_hide_at)

    -- ── Build ASS data ────────────────────────────────────────────────────────
    local ass = assdraw.ass_new()

    -- ── Scrollbar ─────────────────────────────────────────────────────────────
    local bar_top = H - BAR_H

    -- background (white 50 %)
    ass:new_event(); ass:an(7); ass:pos(0, 0)
    ass:append("{\\bord0\\shad0\\c&H" .. WHITE  .. "&\\1a&H80&}")
    ass:draw_start()
    ass:move_to(0, bar_top); ass:line_to(W,  bar_top)
    ass:line_to(W, H);       ass:line_to(0,  H)
    ass:draw_stop()

    -- foreground (accent 100 %)
    local pw = math.floor(W * chap_pct + 0.5)
    if pw > 0 then
        ass:new_event(); ass:an(7); ass:pos(0, 0)
        ass:append("{\\bord0\\shad0\\c&H" .. ACCENT .. "&\\1a&H00&}")
        ass:draw_start()
        ass:move_to(0,  bar_top); ass:line_to(pw, bar_top)
        ass:line_to(pw, H);       ass:line_to(0,  H)
        ass:draw_stop()
    end

    -- ── Radial progress indicator ─────────────────────────────────────────────
    local CIR_R    = math.max(1, ri(W * 0.01))
    local CIR_MARG = CIR_R
    local cx = W - CIR_MARG - CIR_R
    local cy = H - CIR_MARG - CIR_R

    -- background disk (white 50 %, 4px larger than the progress sector)
    ass:new_event(); ass:an(7); ass:pos(0, 0)
    ass:append("{\\bord0\\shad0\\c&H" .. WHITE  .. "&\\1a&H80&}")
    ass:draw_start()
    draw_disk(ass, cx, cy, CIR_R + 4)
    ass:draw_stop()

    -- foreground sector (accent 100 %)
    if total_pct > 0 then
        ass:new_event(); ass:an(7); ass:pos(0, 0)
        ass:append("{\\bord0\\shad0\\c&H" .. ACCENT .. "&\\1a&H00&}")
        ass:draw_start()
        draw_sector(ass, cx, cy, CIR_R, total_pct * 2 * math.pi)
        ass:draw_stop()
    end

    -- ── Chapter index ─────────────────────────────────────────────────────────
    if show_chap then
        local CH_FS    = math.max(1, ri(H * 0.02))
        local line_h   = CH_FS + CH_LINE_SP
        local n_chaps  = #chap_list

        -- estimate box width from the longest title
        local max_len = 0
        for i, ch in ipairs(chap_list) do
            local s = (ch.title and ch.title ~= "") and ch.title
                      or ("Chapter " .. tostring(i))
            if #s > max_len then max_len = #s end
        end

        local tw = math.floor(max_len * CH_FS * 0.58 + 0.5)
        local th = n_chaps * line_h - CH_LINE_SP

        local bx1 = CH_MARG_X
        local by1 = CH_MARG_Y
        local bx2 = bx1 + tw + 2 * CH_PAD
        local by2 = by1 + th + 2 * CH_PAD

        -- background box (white 50 %)
        ass:new_event(); ass:an(7); ass:pos(0, 0)
        ass:append("{\\bord0\\shad0\\c&H" .. WHITE .. "&\\1a&H80&}")
        ass:draw_start()
        ass:move_to(bx1, by1); ass:line_to(bx2, by1)
        ass:line_to(bx2, by2); ass:line_to(bx1, by2)
        ass:draw_stop()

        -- chapter text lines
        for i, ch in ipairs(chap_list) do
            local title = (ch.title and ch.title ~= "") and ch.title
                          or ("Chapter " .. tostring(i))
            local tx    = bx1 + CH_PAD
            local ty    = by1 + CH_PAD + (i - 1) * line_h
            local cur   = (i - 1 == chap_idx)
            local color = cur and ACCENT or BLACK
            local alpha = cur and "00" or "80"   -- 100 % / 50 %

            ass:new_event()
            ass:append(string.format(
                "{\\an7\\pos(%d,%d)\\fs%d\\bord0\\shad0\\c&H%s&\\1a&H%s&}%s",
                tx, ty, CH_FS, color, alpha, title
            ))
        end
    end

    -- ── Push to screen ────────────────────────────────────────────────────────
    overlay.res_x = W
    overlay.res_y = H
    overlay.data  = ass.text
    overlay:update()
end

-- ── Wiring ────────────────────────────────────────────────────────────────────

mp.add_key_binding("ENTER", "bouclette-toggle-osd", function()
    osd_visible = not osd_visible
    if osd_visible then
        update()
    else
        overlay:remove()
    end
end)

local timer = mp.add_periodic_timer(1 / UPDATE_HZ, update)

mp.observe_property("chapter", "number", update)

mp.observe_property("pause", "bool", function(_, paused)
    if paused then timer:stop() else timer:resume() end
    update()
end)

mp.register_event("file-loaded", function()
    last_chapter    = -2
    chapter_hide_at = 0
    timer:resume()
    update()
end)

mp.register_event("end-file", function()
    overlay:remove()
    timer:stop()
end)
