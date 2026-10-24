-- Line Namer: fills in line numbers and sets cargo-coded colors.
-- Name format: [Region]-[Role][Category][Number] rest   e.g. "N-FB 铁矿→北港仓" -> "N-FB03 铁矿→北港仓"
-- Passenger:   [Region]-P[Mode][Number] rest            e.g. "NW-PR 北港→西山"  -> "NW-PR01 北港→西山"

local M = {}

-- RGB 0-255. Shades: [1] trunk (darkest), [2] direct, [3] feeder (lightest).
local CARGO_COLORS = {
	L = { { 43, 34, 56 },  { 78, 61, 102 },  { 154, 136, 184 } }, -- liquid
	B = { { 107, 58, 18 }, { 181, 101, 29 }, { 224, 163, 92 } },  -- bulk
	P = { { 36, 64, 90 },  { 77, 117, 152 }, { 147, 180, 208 } }, -- flatbed
	G = { { 31, 90, 58 },  { 46, 139, 87 },  { 134, 205, 163 } }, -- goods
	U = { { 110, 110, 110 }, { 168, 168, 168 }, { 226, 226, 226 } }, -- universal
}
local ROLE_SHADE = { T = 1, D = 2, F = 3 }
local PAX_COLORS = {
	R = { 200, 51, 43 },   -- rail
	B = { 47, 111, 208 },  -- bus
	T = { 227, 181, 5 },   -- tram
	A = { 122, 79, 196 },  -- air
	S = { 28, 154, 154 },  -- ship
	H = { 208, 80, 138 },  -- helicopter
}

local SCAN_EVERY = 120 -- simulation steps between scans
local tick = 0

-- The code must be followed by whitespace or the end of the name,
-- so "N-FBus Depot" is not mistaken for an "N-FB" line.
local function tail(rest)
	if rest == "" then return "" end
	if rest:match("^%s") then return (rest:gsub("^%s+", "")) end
	return nil
end

-- Parse a line name. Returns nil when the name does not use the scheme.
function M.parse(name)
	if type(name) ~= "string" then return nil end
	local region, role, cat, num, rest = name:match("^(%u+)%-([TDF])([LBPGU])(%d*)(.*)$")
	if region and tail(rest) then
		return { kind = "cargo", region = region, role = role, cat = cat,
			num = tonumber(num), rest = tail(rest), key = region .. "-" .. role .. cat }
	end
	local pregion, mode, pnum, prest = name:match("^(%u+)%-P([RBTASH])(%d*)(.*)$")
	if pregion and tail(prest) then
		return { kind = "pax", region = pregion, mode = mode,
			num = tonumber(pnum), rest = tail(prest), key = pregion .. "-P" .. mode }
	end
	return nil
end

function M.colorFor(p)
	if p.kind == "pax" then return PAX_COLORS[p.mode] end
	return CARGO_COLORS[p.cat][ROLE_SHADE[p.role]]
end

function M.format(p, num)
	local code = string.format("%s%02d", p.key, num)
	if p.rest ~= nil and p.rest ~= "" then return code .. " " .. p.rest end
	return code
end

-- Pure planning step, testable outside the game.
-- lines: list of { id = <entity>, name = <string>, color = {r,g,b} 0-1 or nil }
-- returns list of { id, name = <new name or nil>, color = {r,g,b} 0-255 or nil }
function M.plan(lines)
	local parsed, maxNum = {}, {}
	for _, l in ipairs(lines) do
		local p = M.parse(l.name)
		if p then
			parsed[#parsed + 1] = { line = l, p = p }
			if p.num and p.num > (maxNum[p.key] or 0) then maxNum[p.key] = p.num end
		end
	end
	local actions = {}
	for _, e in ipairs(parsed) do
		local act = { id = e.line.id }
		if not e.p.num then
			local n = (maxNum[e.p.key] or 0) + 1
			maxNum[e.p.key] = n
			act.name = M.format(e.p, n)
		end
		local target = M.colorFor(e.p)
		local cur = e.line.color
		local same = cur and math.abs(cur[1] - target[1] / 255) < 0.01
			and math.abs(cur[2] - target[2] / 255) < 0.01
			and math.abs(cur[3] - target[3] / 255) < 0.01
		if not same then act.color = target end
		if act.name or act.color then actions[#actions + 1] = act end
	end
	return actions
end

-- ===== Game glue (only runs inside Transport Fever 3) =====

local function readColor(entity)
	local c = api.engine.getComponent(entity, api.type.ComponentType.COLOR)
	if c and c.color then return { c.color.x, c.color.y, c.color.z } end
	return nil
end

local function readName(entity)
	local n = api.engine.getComponent(entity, api.type.ComponentType.NAME)
	return n and n.name or nil
end

local function scan()
	local player = api.engine.util.getPlayer()
	local entities = api.engine.system.lineSystem.getLinesForPlayer(player)
	local lines = {}
	-- Index loop instead of ipairs: works whether the engine returns a table or a vector userdata.
	for i = 1, #entities do
		local e = entities[i]
		lines[#lines + 1] = { id = e, name = readName(e), color = readColor(e) }
	end
	for _, act in ipairs(M.plan(lines)) do
		if act.name then
			api.cmd.sendCommand(api.cmd.makeEntitySetNameCmd(act.id, act.name))
		end
		if act.color then
			local c = act.color
			local v = api.type.Vec3f.new(c[1] / 255, c[2] / 255, c[3] / 255)
			api.cmd.sendCommand(api.cmd.makeEntitySetColorCmd(act.id, v))
		end
	end
end

local failed = false
function M.update(userParams, state, dt)
	if failed then return end
	tick = tick + 1
	if tick % SCAN_EVERY ~= 0 then return end
	local ok, err = pcall(scan)
	if not ok then
		failed = true -- stop retrying so a broken API call does not flood the log
		debugPrint("[saige_line_namer] disabled after error: " .. tostring(err))
	end
end

return M
