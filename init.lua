local time_load_start = os.clock()
print("[nuke] loading...")

nuke = nuke or {}

--nuke.preserve_items = false
--nuke.drop_items = false --this will only cause lags
local MESE_TNT_RANGE = 12
local IRON_TNT_RANGE = 6
nuke.seed = 12
nuke.bombs_list = {
	{"iron", "Iron"},
	{"mese", "Mese"},
	{"mossy", "Mossy"}
}

minetest.after(3, function()
	if minetest.get_modpath("extrablocks") then
		nuke.mossy_nodes = {
			{"default:cobble", "default:mossycobble"},
			{"default:stonebrick",	"extrablocks:mossystonebrick"},
			{"extrablocks:wall",	"extrablocks:mossywall"}
		}
	else
		nuke.mossy_nodes = {
			{"default:cobble", "default:mossycobble"}
		}
	end

	local num = 1
	nuke.mossy_nds = {}
	for _,node in ipairs(nuke.mossy_nodes) do
		nuke.mossy_nds[num] = {minetest.get_content_id(node[1]), minetest.get_content_id(node[2])}
		num = num+1
	end
end)

local function r_area(manip, size, pos)
	local emerged_pos1, emerged_pos2 = manip:read_from_map(
		{x=pos.x-size, y=pos.y-size, z=pos.z-size},
		{x=pos.x+size, y=pos.y+size, z=pos.z+size}
	)
	return VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
end

local function set_vm_data(manip, nodes, pos, t1, msg)
	manip:set_data(nodes)
	manip:write_to_map()
	print(string.format("[nuke] "..msg.." at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
	if not nuke.no_map_update then
		local t1 = os.clock()
		manip:update_map()
		print(string.format("[nuke] map updated after ca. %.2fs", os.clock() - t1))
	end
end

function spawn_tnt(pos, entname)
	minetest.sound_play("nuke_ignite", {pos = pos,gain = 1.0,max_hear_distance = 8,})
	return minetest.add_entity(pos, entname)
end

function do_tnt_physics(tnt_np,tntr)
	local objs = minetest.get_objects_inside_radius(tnt_np, tntr)
	for k, obj in pairs(objs) do
		local oname = obj:get_entity_name()
		local v = obj:getvelocity()
		local p = obj:getpos()
		if oname == "experimental:tnt"
		or oname == "nuke:iron_tnt"
		or oname == "nuke:mese_tnt"
		or oname == "nuke:hardcore_iron_tnt"
		or oname == "nuke:hardcore_mese_tnt" then
			obj:setvelocity({x=(p.x - tnt_np.x) + (tntr / 2) + v.x, y=(p.y - tnt_np.y) + tntr + v.y, z=(p.z - tnt_np.z) + (tntr / 2) + v.z})
		else
			if v ~= nil then
				obj:setvelocity({x=(p.x - tnt_np.x) + (tntr / 4) + v.x, y=(p.y - tnt_np.y) + (tntr / 2) + v.y, z=(p.z - tnt_np.z) + (tntr / 4) + v.z})
			else
				if obj:get_player_name() ~= nil then
					obj:set_hp(obj:get_hp() - 1)
				end
			end
		end
	end
end

local function get_volume(pos1, pos2)
	return (pos2.x - pos1.x + 1) * (pos2.y - pos1.y + 1) * (pos2.z - pos1.z + 1)
end


local function get_nuke_random(pos)
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+nuke.seed)
end


local function explosion_table(range)
	local t1 = os.clock()
	local tab = {}
	local n = 1

	local radius = range^2 + range
	for x=-range,range do
		for y=-range,range do
			for z=-range,range do
				local r = x^2+y^2+z^2 
				if r <= radius then
					local np={x=x, y=y, z=z}
					if math.floor(math.sqrt(r) +0.5) > range-1 then
						tab[n] = {np, true}
					else
						tab[n] = {np}
					end
					n = n+1
				end
			end
		end
	end
	print(string.format("[nuke] table created after: %.2fs", os.clock() - t1))
	return tab
end

local c_air = minetest.get_content_id("air")
local c_chest = minetest.get_content_id("default:chest")

local function explode(pos, tab, range)
	local t1 = os.clock()
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*200})

	local manip = minetest.get_voxel_manip()
	local area = r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	local pr = get_nuke_random(pos)

	for _,npos in ipairs(tab) do
		local f = npos[1]
		local p = {x=pos.x+f.x, y=pos.y+f.y, z=pos.z+f.z}
		local p_p = area:index(p.x, p.y, p.z)
		local d_p_p = nodes[p_p]
		if d_p_p ~= c_air
		and d_p_p ~= c_chest then
			if npos[2] then
				if pr:next(1,5) >= 2 then
					nodes[p_p] = c_air
				end
			else
				nodes[p_p] = c_air
			end
		end
	end
	set_vm_data(manip, nodes, pos, t1, "exploded")
end


local function expl_moss(pos, range)
	local t1 = os.clock()

	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*200})

	local manip = minetest.get_voxel_manip()
	local area = r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	local pr = get_nuke_random(pos)

	local radius = range^2 + range
	for x=-range,range do
		for y=-range,range do
			for z=-range,range do
				local r = x*x+y*y+z*z 
				if r <= radius then
					local np={x=pos.x+x, y=pos.y+y, z=pos.z+z}
					local p_np = area:index(np.x, np.y, np.z)
					local d_p_np = nodes[p_np]
					if d_p_np ~= c_air
					and d_p_np ~= c_chest then
						if math.floor(math.sqrt(r) +0.5) > range-1 then
							if pr:next(1,5) >= 4 then
								nodes[p_np] = c_air
								--destroy_node(np)
							else
								for _,node in ipairs(nuke.mossy_nds) do
									if d_p_np == node[1] then
										nodes[p_np] = node[2]
										break
									end
								end
							end
						else
							nodes[p_np] = c_air
							--destroy_node(np)
						end
					end
--					activate_if_tnt(n.name, np, pos, range)
				end
			end
		end
	end
	set_vm_data(manip, nodes, pos, t1, "exploded (mossy)")
end


minetest.register_chatcommand('nuke_switch_map_update',{
	description = 'Switch map update',
	params = "",
	privs = {},
	func = function()
		if not nuke.no_map_update then
			nuke.no_map_update = true
			msg = "nuke map_update disabled"
		else
			nuke.no_map_update = false
			msg = "nuke map_update enabled"
		end
		print("[nuke] "..name..": "..msg)
		minetest.chat_send_player(name, msg)
	end
})


--Crafting:

local w = 'default:wood'
local c = 'default:coal_lump'

for _,i in ipairs({
	{"mese", "mese_crystal"},
	{"iron", "steel_ingot"}
}) do
	local s = "default"..i[2]

	minetest.register_craft({
		output = 'nuke:'..i[1]..'_tnt 4',
		recipe = {
			{'', w, ''},
			{ s, c, s },
			{'', w, ''}
		}
	})

	minetest.register_craft({
		output = 'nuke:hardcore_'..i[1]..'_tnt',
		recipe = {
			{'', c, ''},
			{c, 'nuke:'..i[1]..'_tnt', c},
			{'', c, ''}
		}
	})
end

function nuke.lit_tnt(pos, name, puncher)
	minetest.remove_node(pos)
	spawn_tnt(pos, "nuke:"..name.."_tnt")
	nodeupdate(pos)
	nuke_puncher = puncher
end

for _,i in ipairs(nuke.bombs_list) do
	local nnam = "nuke:"..i[1].."_tnt"
	minetest.register_node(nnam, {
		description = i[2].." Bomb",
		tiles = {"nuke_"..i[1].."_tnt_top.png", "nuke_"..i[1].."_tnt_bottom.png", "nuke_"..i[1].."_tnt_side.png"},
		dug_item = '', -- Get nothing
		material = {diggability = "not"},
	})

	minetest.register_on_punchnode(function(p, node, puncher)
		if node.name == nnam then
			nuke.lit_tnt(p, i[1], puncher)
		end
	end)
end

-- Iron TNT

local IRON_TNT = {
	-- Static definition
	physical = true, -- Collides with things
	-- weight = 5,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	textures = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png",
			"nuke_iron_tnt_side.png", "nuke_iron_tnt_side.png",
			"nuke_iron_tnt_side.png", "nuke_iron_tnt_side.png"},
	-- Initial value for our timer
	timer = 0,
	-- Number of punches required to defuse
	health = 1,
	blinktimer = 0,
	blinkstatus = true,
}

function IRON_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
	if not iron_tnt_table then
		iron_tnt_table = explosion_table(IRON_TNT_RANGE)
	end
end

function IRON_TNT:on_step(dtime)
	self.timer = self.timer + dtime
	self.blinktimer = self.blinktimer + dtime
	if self.timer>5 then
		self.blinktimer = self.blinktimer + dtime

		if self.timer>8 then
			self.blinktimer = self.blinktimer + dtime
			self.blinktimer = self.blinktimer + dtime
		end
	end
	if self.blinktimer > 0.5 then
		self.blinktimer = self.blinktimer - 0.5
		if self.blinkstatus then
			self.object:settexturemod("")
		else
			self.object:settexturemod("^[brighten")
		end
		self.blinkstatus = not self.blinkstatus
	end
	if self.timer > 10 then
		local pos = self.object:getpos()
		pos.x = math.floor(pos.x+0.5)
		pos.y = math.floor(pos.y+0.5)
		pos.z = math.floor(pos.z+0.5)
		do_tnt_physics(pos, IRON_TNT_RANGE)
		if minetest.get_node(pos).name == "default:water_source" or minetest.get_node(pos).name == "default:water_flowing" then
			-- Cancel the Explosion
			self.object:remove()
			return
		end
		explode(pos, iron_tnt_table, IRON_TNT_RANGE)
		self.object:remove()
	end
end

function IRON_TNT:on_punch(hitter)
	self.health = self.health - 1
	if self.health <= 0 then
		self.object:remove()
		hitter:get_inventory():add_item("main", "nuke:iron_tnt")
	end
end

minetest.register_entity("nuke:iron_tnt", IRON_TNT)


-- Mese TNT


local MESE_TNT = {
	-- Static definition
	physical = true, -- Collides with things
	-- weight = 5,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	textures = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png",
			"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png",
			"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png"},
	-- Initial value for our timer
	timer = 0,
	-- Number of punches required to defuse
	health = 1,
	blinktimer = 0,
	blinkstatus = true,
}

function MESE_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
	if not mese_tnt_table then
		mese_tnt_table = explosion_table(MESE_TNT_RANGE)
	end
end

function MESE_TNT:on_step(dtime)
	self.timer = self.timer + dtime
	self.blinktimer = self.blinktimer + dtime
	if self.timer>5 then
		self.blinktimer = self.blinktimer + dtime
		if self.timer>8 then
			self.blinktimer = self.blinktimer + dtime
			self.blinktimer = self.blinktimer + dtime
		end
	end
	if self.blinktimer > 0.5 then
		self.blinktimer = self.blinktimer - 0.5
		if self.blinkstatus then
			self.object:settexturemod("")
		else
			self.object:settexturemod("^[brighten")
		end
		self.blinkstatus = not self.blinkstatus
	end
	if self.timer > 10 then
		local pos = self.object:getpos()
		pos.x = math.floor(pos.x+0.5)
		pos.y = math.floor(pos.y+0.5)
		pos.z = math.floor(pos.z+0.5)
		do_tnt_physics(pos, MESE_TNT_RANGE)
		if minetest.get_node(pos).name == "default:water_source" or minetest.get_node(pos).name == "default:water_flowing" then
			-- Cancel the Explosion
			self.object:remove()
			return
		end
		explode(pos, mese_tnt_table, MESE_TNT_RANGE)
		self.object:remove()
	end
end

function MESE_TNT:on_punch(hitter)
	self.health = self.health - 1
	if self.health <= 0 then
		self.object:remove()
		hitter:get_inventory():add_item("main", "nuke:mese_tnt")
	end
end

minetest.register_entity("nuke:mese_tnt", MESE_TNT)


-- Mossy TNT

local MOSSY_TNT_RANGE = 2
local MOSSY_TNT = {
	-- Static definition
	physical = true, -- Collides with things
	-- weight = 5,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	textures = {"nuke_mossy_tnt_top.png", "nuke_mossy_tnt_bottom.png",
			"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png",
			"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png"},
	-- Initial value for our timer
	timer = 0,
	-- Number of punches required to defuse
	health = 1,
	blinktimer = 0,
	blinkstatus = true,
}

function MOSSY_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
end

function MOSSY_TNT:on_step(dtime)
	self.timer = self.timer + dtime
	self.blinktimer = self.blinktimer + dtime
	if self.timer>5 then
		self.blinktimer = self.blinktimer + dtime
		if self.timer>8 then
			self.blinktimer = self.blinktimer + dtime
			self.blinktimer = self.blinktimer + dtime
		end
	end
	if self.blinktimer > 0.5 then
		self.blinktimer = self.blinktimer - 0.5
		if self.blinkstatus then
			self.object:settexturemod("")
		else
			self.object:settexturemod("^[brighten")
		end
		self.blinkstatus = not self.blinkstatus
	end
	if self.timer > 10 then
		local pos = self.object:getpos()
		pos.x = math.floor(pos.x+0.5)
		pos.y = math.floor(pos.y+0.5)
		pos.z = math.floor(pos.z+0.5)
		do_tnt_physics(pos, MOSSY_TNT_RANGE)
		if minetest.get_node(pos).name == "default:water_source"
		or minetest.get_node(pos).name == "default:water_flowing" then
			-- Cancel the Explosion
			self.object:remove()
			return
		end
		expl_moss(pos, MOSSY_TNT_RANGE)
		self.object:remove()
	end
end

function MOSSY_TNT:on_punch(hitter)
	self.health = self.health - 1
	if self.health <= 0 then
		self.object:remove()
		hitter:get_inventory():add_item("main", "nuke:mossy_tnt")
	end
end

minetest.register_entity("nuke:mossy_tnt", MOSSY_TNT)


-- Hardcore Iron TNT

minetest.register_node("nuke:hardcore_iron_tnt", {
	tiles = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png",
			"nuke_hardcore_iron_tnt_side.png"},
	inventory_image = minetest.inventorycube("nuke_iron_tnt_top.png",
			"nuke_hardcore_iron_tnt_side.png", "nuke_hardcore_iron_tnt_side.png"),
	dug_item = '', -- Get nothing
	material = {
		diggability = "not",
	},
	description = "Hardcore Iron Bomb",
})

minetest.register_on_punchnode(function(p, node)
	if node.name == "nuke:hardcore_iron_tnt" then
		minetest.remove_node(p)
		spawn_tnt(p, "nuke:hardcore_iron_tnt")
		nodeupdate(p)
	end
end)

local HARDCORE_IRON_TNT_RANGE = 6
local HARDCORE_IRON_TNT = {
	-- Static definition
	physical = true, -- Collides with things
	-- weight = 5,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	textures = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png",
			"nuke_hardcore_iron_tnt_side.png", "nuke_hardcore_iron_tnt_side.png",
			"nuke_hardcore_iron_tnt_side.png", "nuke_hardcore_iron_tnt_side.png"},
	-- Initial value for our timer
	timer = 0,
	-- Number of punches required to defuse
	health = 1,
	blinktimer = 0,
	blinkstatus = true,
}

function HARDCORE_IRON_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
end

function HARDCORE_IRON_TNT:on_step(dtime)
	self.timer = self.timer + dtime
	self.blinktimer = self.blinktimer + dtime
	if self.timer>5 then
		self.blinktimer = self.blinktimer + dtime
		if self.timer>8 then
			self.blinktimer = self.blinktimer + dtime
			self.blinktimer = self.blinktimer + dtime
		end
	end
	if self.blinktimer > 0.5 then
		self.blinktimer = self.blinktimer - 0.5
		if self.blinkstatus then
			self.object:settexturemod("")
		else
			self.object:settexturemod("^[brighten")
		end
		self.blinkstatus = not self.blinkstatus
	end
	if self.timer > 10 then
		local pos = self.object:getpos()
		pos.x = math.floor(pos.x+0.5)
		pos.y = math.floor(pos.y+0.5)
		pos.z = math.floor(pos.z+0.5)
		minetest.sound_play("nuke_explode", {pos = pos,gain = 1.0,max_hear_distance = 16,})
		for x=-HARDCORE_IRON_TNT_RANGE,HARDCORE_IRON_TNT_RANGE do
		for z=-HARDCORE_IRON_TNT_RANGE,HARDCORE_IRON_TNT_RANGE do
			if x*x+z*z <= HARDCORE_IRON_TNT_RANGE * HARDCORE_IRON_TNT_RANGE + HARDCORE_IRON_TNT_RANGE then
				local np={x=pos.x+x,y=pos.y,z=pos.z+z}
				minetest.add_entity(np, "nuke:iron_tnt")
			end
		end
		end
		self.object:remove()
	end
end

function HARDCORE_IRON_TNT:on_punch(hitter)
	self.health = self.health - 1
	if self.health <= 0 then
		self.object:remove()
		hitter:add_to_inventory("node nuke:hardcore_iron_tnt 1")
	end
end

minetest.register_entity("nuke:hardcore_iron_tnt", HARDCORE_IRON_TNT)

-- Hardcore Mese TNT

minetest.register_node("nuke:hardcore_mese_tnt", {
	tiles = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png",
			"nuke_hardcore_mese_tnt_side.png"},
	inventory_image = minetest.inventorycube("nuke_mese_tnt_top.png",
			"nuke_hardcore_mese_tnt_side.png", "nuke_hardcore_mese_tnt_side.png"),
	dug_item = '', -- Get nothing
	material = {
		diggability = "not",
	},
	description = "Hardcore Mese Bomb",
})

minetest.register_on_punchnode(function(p, node)
	if node.name == "nuke:hardcore_mese_tnt" then
		minetest.remove_node(p)
		spawn_tnt(p, "nuke:hardcore_mese_tnt")
		nodeupdate(p)
	end
end)

local HARDCORE_MESE_TNT_RANGE = 6
local HARDCORE_MESE_TNT = {
	-- Static definition
	physical = true, -- Collides with things
	-- weight = 5,
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	textures = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png",
			"nuke_hardcore_mese_tnt_side.png", "nuke_hardcore_mese_tnt_side.png",
			"nuke_hardcore_mese_tnt_side.png", "nuke_hardcore_mese_tnt_side.png"},
	-- Initial value for our timer
	timer = 0,
	-- Number of punches required to defuse
	health = 1,
	blinktimer = 0,
	blinkstatus = true,
}

function HARDCORE_MESE_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
end

function HARDCORE_MESE_TNT:on_step(dtime)
	self.timer = self.timer + dtime
	self.blinktimer = self.blinktimer + dtime
	if self.timer>5 then
		self.blinktimer = self.blinktimer + dtime
		if self.timer>8 then
			self.blinktimer = self.blinktimer + dtime
			self.blinktimer = self.blinktimer + dtime
		end
	end
	if self.blinktimer > 0.5 then
		self.blinktimer = self.blinktimer - 0.5
		if self.blinkstatus then
			self.object:settexturemod("")
		else
			self.object:settexturemod("^[brighten")
		end
		self.blinkstatus = not self.blinkstatus
	end
	if self.timer > 10 then
		local pos = self.object:getpos()
		pos.x = math.floor(pos.x+0.5)
		pos.y = math.floor(pos.y+0.5)
		pos.z = math.floor(pos.z+0.5)
		minetest.sound_play("nuke_explode", {pos = pos,gain = 1.0,max_hear_distance = 16,})
		for x=-HARDCORE_MESE_TNT_RANGE,HARDCORE_MESE_TNT_RANGE do
		for z=-HARDCORE_MESE_TNT_RANGE,HARDCORE_MESE_TNT_RANGE do
			if x*x+z*z <= HARDCORE_MESE_TNT_RANGE * HARDCORE_MESE_TNT_RANGE + HARDCORE_MESE_TNT_RANGE then
				local np={x=pos.x+x,y=pos.y,z=pos.z+z}
				minetest.add_entity(np, "nuke:mese_tnt")
			end
		end
		end
		self.object:remove()
	end
end

function HARDCORE_MESE_TNT:on_punch(hitter)
	self.health = self.health - 1
	if self.health <= 0 then
		self.object:remove()
		hitter:add_to_inventory("node nuke:hardcore_mese_tnt 1")
	end
end

minetest.register_entity("nuke:hardcore_mese_tnt", HARDCORE_MESE_TNT)


-- Rocket Launcher

--license LGPLv2+

nuke.rocket_speed = 2
nuke.rocket_a = 200
local r_corr = 0.25 --sth like antialiasing

local f_1 = 0.5-r_corr
local f_2 = 0.5+r_corr

-- Taken from the Flowers mod by erlehmann.
local function table_contains(t, v)
	for _,i in ipairs(t) do
		if i == v then
			return true
		end
	end
	return false
end

local function rocket_expl(pos, player, pos2)
	local nodenam = minetest.get_node(pos).name
	if nodenam == "air"
	or nodenam == "default:water_source"
	or nodenam == "default:water_flowing" then
		return false
	end
	local delay = nuke.timeacc(vector.distance(pos,pos2), nuke.rocket_speed, nuke.rocket_a)
	minetest.after(delay, function(pos)
		do_tnt_physics(pos, MOSSY_TNT_RANGE)
		expl_moss(pos, MOSSY_TNT_RANGE)
	end, pos)
	return true
end

local function get_used_dir(dir)
	local abs_dir = {x=math.abs(dir.x), y=math.abs(dir.y), z=math.abs(dir.z)}
	local dir_max = math.max(abs_dir.x, abs_dir.y, abs_dir.z)
	if dir_max == abs_dir.x then
		local tab = {"x", {x=1, y=dir.y/dir.x, z=dir.z/dir.x}}
		if dir.x >= 0 then
			tab[3] = "+"
		end
		return tab
	end
	if dir_max == abs_dir.y then
		local tab = {"y", {x=dir.x/dir.y, y=1, z=dir.z/dir.y}}
		if dir.y >= 0 then
			tab[3] = "+"
		end
		return tab
	end
	local tab = {"z", {x=dir.x/dir.z, y=dir.y/dir.z, z=1}}
	if dir.z >= 0 then
		tab[3] = "+"
	end
	return tab
end

local function node_tab(z, d)
	local n1 = math.floor(z*d+f_1)
	local n2 = math.floor(z*d+f_2)
	if n1 == n2 then
		return {n1}
	end
	return {n1, n2}
end

function nuke.rocket_nodes(pos, dir, player, range)
	local t_dir = get_used_dir(dir)
	local dir_typ = t_dir[1]
	if t_dir[3] == "+" then
		f_tab = {0, range, 1}
	else
		f_tab = {0, -range, -1}
	end
	local d_ch = t_dir[2]
	if dir_typ == "x" then
		for d = f_tab[1],f_tab[2],f_tab[3] do
			local x = d
			local ytab = node_tab(d_ch.y, d)
			local ztab = node_tab(d_ch.z, d)
			for _,y in ipairs(ytab) do
				for _,z in ipairs(ztab) do
					if rocket_expl({x=pos.x+x, y=pos.y+y, z=pos.z+z}, player, pos) then
						return
					end
				end
			end
		end
		return
	end
	if dir_typ == "y" then
		for d = f_tab[1],f_tab[2],f_tab[3] do
			local xtab = node_tab(d_ch.x, d)
			local y = d
			local ztab = node_tab(d_ch.z, d)
			for _,x in ipairs(xtab) do
				for _,z in ipairs(ztab) do
					if rocket_expl({x=pos.x+x, y=pos.y+y, z=pos.z+z}, player, pos) then
						return
					end
				end
			end
		end
		return
	end
	for d = f_tab[1],f_tab[2],f_tab[3] do
		local xtab = node_tab(d_ch.x, d)
		local ytab = node_tab(d_ch.y, d)
		local z = d
		for _,x in ipairs(xtab) do
			for _,y in ipairs(ytab) do
				if rocket_expl({x=pos.x+x, y=pos.y+y, z=pos.z+z}, player, pos) then
					return
				end
			end
		end
	end
end

function nuke.timeacc(s, v, a)
	return (math.sqrt(v*v+2*a*s)-v)/a
end

function nuke.rocket_shoot(player, range, particle_texture, sound)
	local t1 = os.clock()

	local playerpos=player:getpos()
	local dir=player:get_look_dir()

	local startpos = {x=playerpos.x, y=playerpos.y+1.6, z=playerpos.z}
	minetest.add_particle(startpos,
		{x=dir.x*nuke.rocket_speed, y=dir.y*nuke.rocket_speed, z=dir.z*nuke.rocket_speed},
		{x=dir.x*nuke.rocket_a, y=dir.y*nuke.rocket_a, z=dir.z*nuke.rocket_a},
		nuke.timeacc(range, nuke.rocket_speed, nuke.rocket_a),
		1, false, particle_texture
	)
	nuke.rocket_nodes(vector.round(startpos), dir, player, range)
	minetest.sound_play(sound, {pos = playerpos, gain = 1.0, max_hear_distance = range})

	print("[nuke] <rocket> my shot was calculated after "..tostring(os.clock()-t1).."s")
end

minetest.register_tool("nuke:rocket_launcher", {
	description = "Rocket Launcher",
	inventory_image = "firearms_bazooka.png",
	stack_max = 1,
	on_use = function(itemstack, user)
		nuke.rocket_shoot(user, 30, "firearms_rocket_entity.png", "firearms_m79_shot")
	end,
})

--dofile(minetest.get_modpath("nuke").."/b.lua")

print(string.format("[nuke] loaded after ca. %.2fs", os.clock() - time_load_start))
