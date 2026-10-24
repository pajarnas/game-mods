-- Saige line code: an auto-rename component for the line manager.
-- Produces a full line name such as "N-FB03 Iron Mine→North Hub" and sets the line color.
--
-- Cargo:     [Region]-[Role][Category][NN] First→Last
-- Passenger: [Region]-P[Mode][NN] First→Last
--
-- Category and passenger mode come from the game (cargo classes, vehicle carrier).
-- Region and role come from the line's current name when it starts with a code
-- ("N-F", "NW-T", "N-FB03 ..."); otherwise role is guessed from warehouse stops
-- and region falls back to D for direct lines and X for the rest.

local M = {}

-- ===== Pure logic (no game API; tested outside the game) =====

local function hex(h)
	return {
		tonumber(h:sub(2, 3), 16) / 255,
		tonumber(h:sub(4, 5), 16) / 255,
		tonumber(h:sub(6, 7), 16) / 255,
	}
end

-- Shades: trunk (darkest), direct (medium), feeder (lightest).
M.CARGO_COLORS = {
	L = { T = hex("#23202B"), D = hex("#4A4458"), F = hex("#9A93AB") }, -- liquid: oil black
	B = { T = hex("#6B3A12"), D = hex("#B5651D"), F = hex("#E0A35C") }, -- bulk: earth brown
	P = { T = hex("#7A2418"), D = hex("#B5402C"), F = hex("#E89A85") }, -- flatbed: rust red
	G = { T = hex("#1E3A8A"), D = hex("#2563EB"), F = hex("#93C5FD") }, -- goods: freight blue
	U = { T = hex("#6E6E6E"), D = hex("#A8A8A8"), F = hex("#E2E2E2") }, -- universal: grey
}
M.PAX_COLORS = {
	R = hex("#14532D"), -- rail: forest
	S = hex("#0F766E"), -- ship: teal
	A = hex("#10A37F"), -- air: jade
	B = hex("#22A35A"), -- bus: grass
	T = hex("#6BAA1F"), -- tram: lime
	H = hex("#9ED9A8"), -- helicopter: mint
}

M.CLASS_TO_CAT = { LIQUID = "L", BULK = "B", FLATBED = "P", GOODS = "G" }

-- A code must be followed by whitespace or the end of the name,
-- so "N-FBus Depot" is not read as an "N-FB" line.
local function codeEnds(rest)
	return rest == "" or rest:match("^%s") ~= nil
end

-- Parse the code at the start of a name. Returns nil when there is none.
-- Category / mode / number are optional, so "N-F 铁矿" and "NW-P" both parse.
function M.parse(name)
	if type(name) ~= "string" then return nil end
	local region, mode, num, rest = name:match("^(%u+)%-P([RSABTH]?)(%d*)(.*)$")
	if region and codeEnds(rest) then
		return { kind = "pax", region = region, mode = mode ~= "" and mode or nil, num = tonumber(num) }
	end
	local role, cat
	region, role, cat, num, rest = name:match("^(%u+)%-([TDF])([LBPGU]?)(%d*)(.*)$")
	if region and codeEnds(rest) then
		return { kind = "cargo", region = region, role = role, cat = cat ~= "" and cat or nil, num = tonumber(num) }
	end
	return nil
end

function M.key(p)
	if p.kind == "pax" then return p.region .. "-P" .. (p.mode or "") end
	return p.region .. "-" .. p.role .. (p.cat or "")
end

-- classLists: one list of cargo classes per cargo the line loads.
-- Returns "PAX", a category letter, or nil when the line loads nothing.
function M.categoryFromClasses(classLists)
	local cats, n, pax = {}, 0, 0
	for _, classes in ipairs(classLists) do
		local specific, isPax = nil, false
		for _, c in ipairs(classes) do
			if c == "PASSENGERS" then isPax = true end
			if M.CLASS_TO_CAT[c] then specific = M.CLASS_TO_CAT[c] end
		end
		if isPax then
			pax = pax + 1
		else
			specific = specific or "U"
			if not cats[specific] then cats[specific] = true; n = n + 1 end
		end
	end
	if pax > 0 and n == 0 then return "PAX" end
	if n == 0 then return nil end
	if n == 1 then return (next(cats)) end
	return "U"
end

-- Role from warehouse stops: none → direct, one → feeder, two or more → trunk.
function M.roleFromWarehouseStops(count)
	if count == nil then return nil end
	if count == 0 then return "D" end
	if count == 1 then return "F" end
	return "T"
end

-- Pick the line's number.
--   key:         code without number, e.g. "N-FB"
--   current:     parsed current name of this line (or nil)
--   otherNames:  names of all other lines of the player
--   reserved:    { [number] = true } numbers handed out this session to other lines
--   ownReserved: number handed out to this line earlier (or nil)
function M.pickNumber(key, current, otherNames, reserved, ownReserved)
	local used, maxNum = {}, 0
	for _, name in ipairs(otherNames) do
		local p = M.parse(name)
		if p and p.num and M.key(p) == key then
			used[p.num] = true
			if p.num > maxNum then maxNum = p.num end
		end
	end
	if current and current.num and M.key(current) == key and not used[current.num] then
		return current.num
	end
	if ownReserved and not used[ownReserved] then return ownReserved end
	for n in pairs(reserved or {}) do
		if n > maxNum then maxNum = n end
	end
	return maxNum + 1
end

-- info: { currentName, category ("PAX"/letter/nil), paxMode, warehouseStops, firstStop, lastStop }
-- Returns parsed code fields (without number) and the color.
function M.resolve(info)
	local cur = M.parse(info.currentName)
	local isPax = info.category == "PAX" or (info.category == nil and cur and cur.kind == "pax")
	local p
	if isPax then
		local mode = info.paxMode
		if mode == "A" and cur and cur.kind == "pax" and cur.mode == "H" then mode = "H" end
		mode = mode or (cur and cur.kind == "pax" and cur.mode) or "B"
		p = { kind = "pax", region = (cur and cur.region) or "X", mode = mode }
	else
		local role = (cur and cur.kind == "cargo" and cur.role)
			or M.roleFromWarehouseStops(info.warehouseStops) or "F"
		local cat = info.category or (cur and cur.kind == "cargo" and cur.cat) or "U"
		local region = (cur and cur.region) or (role == "D" and "D" or "X")
		p = { kind = "cargo", region = region, role = role, cat = cat }
	end
	local color = isPax and M.PAX_COLORS[p.mode] or M.CARGO_COLORS[p.cat][p.role]
	return p, cur, color
end

function M.formatName(key, num, firstStop, lastStop)
	local code = string.format("%s%02d", key, num)
	if firstStop and lastStop and firstStop ~= "" then
		return code .. " " .. firstStop .. "→" .. lastStop
	end
	return code
end

-- ===== Game glue =====

-- numbers handed out during this session: reserved[key][lineEntity] = n
local reserved = {}

local function each(list)
	local out = {}
	if list == nil then return out end
	for i = 1, #list do out[#out + 1] = list[i] end
	return out
end

local function cargoClassLists(lineEntity)
	local lists = {}
	local line = api.engine.getComponent(lineEntity, api.type.ComponentType.LINE)
	local seen = {}
	for _, stop in ipairs(each(line.stops)) do
		for k, v in ipairs(each(stop.stopConfig.load)) do
			if v and not seen[k] then
				seen[k] = true
				local cargoType = api.res.cargoTypeRep.get(k - 1)
				lists[#lists + 1] = each(cargoType.cargoClasses)
			end
		end
	end
	return lists
end

local function paxModeFromCarrier(lineEntity)
	local C = api.type["enum"].Carrier
	local byCarrier = { [C.RAIL] = "R", [C.ROAD] = "B", [C.TRAM] = "T", [C.AIR] = "A", [C.WATER] = "S" }
	for _, vehicle in ipairs(each(api.engine.system.transportVehicleSystem.getLineVehicles(lineEntity))) do
		local tv = api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
		if tv and byCarrier[tv.carrier] then return byCarrier[tv.carrier] end
	end
	return nil
end

local function isWarehouseStop(stationGroup)
	local sg = api.engine.getComponent(stationGroup, api.type.ComponentType.STATION_GROUP)
	for _, station in ipairs(each(sg.stations)) do
		local con = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(station)
		if con and con >= 0 then
			local c = api.engine.getComponent(con, api.type.ComponentType.CONSTRUCTION)
			if c and c.fileName and c.fileName:find("warehouse", 1, true) then return true end
		end
	end
	return false
end

local function stopsInfo(reactLine)
	local first, last, warehouses, seen = nil, nil, 0, {}
	for _, via in ipairs(reactLine.path) do
		if via.stop then
			local g = via.stop.stationGroup
			local name = api.engine.util.getEntityName(g)
			first = first or name
			last = name
			if not seen[g] then
				seen[g] = true
				local ok, wh = pcall(isWarehouseStop, g)
				if not ok then warehouses = nil end
				if warehouses and wh then warehouses = warehouses + 1 end
			end
		end
	end
	return first, last, warehouses
end

local function compute(params)
	local lineEntity = params.lineEntity
	local first, last, warehouses = stopsInfo(params.reactLine)

	local okCat, classLists = pcall(cargoClassLists, lineEntity)
	local okMode, paxMode = pcall(paxModeFromCarrier, lineEntity)

	local p, cur, color = M.resolve({
		currentName = api.engine.util.getEntityName(lineEntity),
		category = okCat and M.categoryFromClasses(classLists) or nil,
		paxMode = okMode and paxMode or nil,
		warehouseStops = warehouses,
	})
	local key = M.key(p)

	local otherNames = {}
	for _, l in ipairs(each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
		if l ~= lineEntity then otherNames[#otherNames + 1] = api.engine.util.getEntityName(l) end
	end
	reserved[key] = reserved[key] or {}
	local others = {}
	for l, n in pairs(reserved[key]) do
		if l ~= lineEntity then others[n] = true end
	end
	local num = M.pickNumber(key, cur, otherNames, others, reserved[key][lineEntity])
	reserved[key][lineEntity] = num

	-- The line manager only applies the name, so the color is set here.
	local c = api.engine.getComponent(lineEntity, api.type.ComponentType.COLOR)
	local same = c and c.color
		and math.abs(c.color.x - color[1]) < 0.004
		and math.abs(c.color.y - color[2]) < 0.004
		and math.abs(c.color.z - color[3]) < 0.004
	if not same then
		api.cmd.sendCommand(api.cmd.makeEntitySetColorCmd(lineEntity,
			api.type.Vec3f.new(color[1], color[2], color[3])))
	end

	return M.formatName(key, num, first, last)
end

M.renameFn = function(params)
	local ok, result = pcall(compute, params)
	if ok then return result end
	print("[saige_line_namer] " .. tostring(result))
	return api.engine.util.getEntityName(params.lineEntity) -- keep the old name on error
end

function data()
	return M
end

return M
