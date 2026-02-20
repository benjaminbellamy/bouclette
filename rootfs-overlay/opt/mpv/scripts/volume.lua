-- volume.lua
-- CEC volume with software fallback.
-- Place in /opt/mpv/scripts/volume.lua

local VOLUME_STEP = 5            -- software volume step (%)
local CEC_DEVICE  = "/dev/cec0" -- use /dev/cec1 for second HDMI port on RPi 4

local function cec_volume(direction)
  -- direction: "volume-up" or "volume-down"
  local cmd = string.format(
    "cec-ctl --device=%s --to 0 --user-control-pressed ui-cmd=%s " ..
    "&& cec-ctl --device=%s --to 0 --user-control-released 2>/dev/null",
    CEC_DEVICE, direction, CEC_DEVICE
  )
  return os.execute(cmd) == 0
end

local function software_volume(direction)
  local step = (direction == "volume-up") and VOLUME_STEP or -VOLUME_STEP
  local vol = mp.get_property_number("volume", 100)
  mp.set_property_number("volume", math.max(0, math.min(100, vol + step)))
  mp.osd_message("Volume: " .. math.floor(mp.get_property_number("volume")) .. "%", 1)
end

local function handle(direction)
  if not cec_volume(direction) then
    software_volume(direction)
  end
end

mp.register_script_message("bouclette-volume-up",   function() handle("volume-up")   end)
mp.register_script_message("bouclette-volume-down", function() handle("volume-down") end)
