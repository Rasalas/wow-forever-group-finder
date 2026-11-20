-- Every locale must use the same format specifiers and tokens as enUS, and no unknown keys.
local addon = arg[1]
local ns = { L = {} }
local files = {}
for line in io.lines(addon .. "/AutoGroupFinder.toc") do
  local f = line:match("^%s*(Locales\\%a%a%u%u%.lua)%s*$")
  if f then files[#files + 1] = f end
end
for _, f in ipairs(files) do assert(loadfile(addon .. "/" .. f:gsub("\\", "/")))("AutoGroupFinder", ns) end

local function sig(s)
  local t = {}
  for spec in s:gsub("%%%%", ""):gmatch("%%[%-%d%.]*[%a]") do t[#t + 1] = spec end
  for tok in s:gmatch("{%a+}") do t[#t + 1] = tok end
  if s:match("%%H") then table.sort(t) end -- date formats may reorder day/month
  return table.concat(t, ",")
end

local base, bad = ns.L.enUS, 0
for loc, tbl in pairs(ns.L) do
  if loc ~= "enUS" then
    local n = 0
    for k, v in pairs(tbl) do
      n = n + 1
      if base[k] == nil then print("FAIL " .. loc .. ": unknown key " .. k); bad = bad + 1
      elseif sig(v) ~= sig(base[k]) then
        print(("FAIL %s.%s: %q vs %q"):format(loc, k, sig(v), sig(base[k]))); bad = bad + 1
      end
    end
    local missing = {}
    for k in pairs(base) do if tbl[k] == nil and not k:match("^LANG_%a%a%u%u$") and k ~= "TITLE" then missing[#missing + 1] = k end end
    table.sort(missing)
    print(("%s: %d keys%s"):format(loc, n, #missing > 0 and (", missing: " .. table.concat(missing, " ")) or ""))
  end
end
if bad > 0 then error(bad .. " locale mismatches") end
print("locales consistent")
