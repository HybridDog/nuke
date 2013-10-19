local time_load_start = os.clock()
print("[nuke] loading...")

local nuke_preserve_items = false
local nuke_drop_items = false --this will only cause lags
local MESE_TNT_RANGE = 12
local IRON_TNT_RANGE = 6
local nuke_seed = 12

if minetest.get_modpath("extrablocks") then
	nuke_mossy_nodes = {
		{"default:cobble", "default:mossycobble"},
		{"default:stonebrick",	"extrablocks:mossystonebrick"},
		{"extrablocks:wall",	"extrablocks:mossywall"}
	}
else
	nuke_mossy_nodes = {
		{"default:cobble", "default:mossycobble"}
	}
end

local num = 1
local nuke_mossy_nds = {}
for _,node in ipairs(nuke_mossy_nodes) do
	nuke_mossy_nds[num] = {minetest.get_content_id(node[1]), minetest.get_content_id(node[2])}
	num = num+1
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
		if oname == "experimental:tnt" or oname == "nuke:iron_tnt" or oname == "nuke:mese_tnt" or oname == "nuke:hardcore_iron_tnt" or oname == "nuke:hardcore_mese_tnt" then
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
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+nuke_seed)
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
	return tab
end

local mese_tnt_table = explosion_table(MESE_TNT_RANGE)
local iron_tnt_table = explosion_table(IRON_TNT_RANGE)


local c_air = minetest.get_content_id("air")
local c_chest = minetest.get_content_id("default:chest")

local function explode(pos, tab, range)
	local t1 = os.clock()
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*2})

	local manip = minetest.get_voxel_manip()
	local width = range+1
	local emerged_pos1, emerged_pos2 = manip:read_from_map({x=pos.x-width, y=pos.y-width, z=pos.z-width},
		{x=pos.x+width, y=pos.y+width, z=pos.z+width})
	local area = VoxelArea:new{MinEdge=emerged_pos1, MaxEdge=emerged_pos2}
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
	manip:set_data(nodes)
	manip:write_to_map()
	print(string.format("[nuke] exploded in: %.2fs", os.clock() - t1))
	if range <= 100 then
		local t1 = os.clock()
		manip:update_map()
		print(string.format("[nuke] map updated in: %.2fs", os.clock() - t1))
	end
end


local function expl_moss(pos, range)
	local t1 = os.clock()
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*2})

	local manip = minetest.get_voxel_manip()
	local width = range+1
	local emerged_pos1, emerged_pos2 = manip:read_from_map({x=pos.x-width, y=pos.y-width, z=pos.z-width},
		{x=pos.x+width, y=pos.y+width, z=pos.z+width})
	local area = VoxelArea:new{MinEdge=emerged_pos1, MaxEdge=emerged_pos2}
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
							elseif pr:next(1,50) == 1 then
								minetest.sound_play("default_glass_footstep", {pos = np, gain = 0.5, max_hear_distance = 4})
							else
								for _,node in ipairs(nuke_mossy_nds) do
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
	manip:set_data(nodes)
	manip:write_to_map()
	print(string.format("[nuke] exploded in: %.2fs", os.clock() - t1))
	if range <= 100 then
		local t1 = os.clock()
		manip:update_map()
		print(string.format("[nuke] map updated in: %.2fs", os.clock() - t1))
	end
end


--Crafting:

local w = 'default:wood'
local c = 'default:coal_lump'
local s = 'default:steel_ingot'
local m = 'default:mese_crystal'

minetest.register_craft({
	output = 'nuke:iron_tnt 4',
	recipe = {
		{'', w, ''},
		{ s, c, s },
		{'', w, ''}
	}
})

minetest.register_craft({
	output = 'nuke:mese_tnt 4',
	recipe = {
		{'', w, ''},
		{ m, c, m },
		{'', w, ''}
	}
})

minetest.register_craft({
	output = 'nuke:hardcore_iron_tnt',
	recipe = {
		{'', c, ''},
		{c, 'nuke:iron_tnt', c},
		{'', c, ''}
	}
})

minetest.register_craft({
	output = 'nuke:hardcore_mese_tnt',
	recipe = {
		{'', c, ''},
		{c, 'nuke:mese_tnt', c},
		{'', c, ''}
	}
})


-- Iron TNT

minetest.register_node("nuke:iron_tnt", {
	tiles = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png",
			"nuke_iron_tnt_side.png", "nuke_iron_tnt_side.png",
			"nuke_iron_tnt_side.png", "nuke_iron_tnt_side.png"},
	inventory_image = minetest.inventorycube("nuke_iron_tnt_top.png",
			"nuke_iron_tnt_side.png", "nuke_iron_tnt_side.png"),
	dug_item = '', -- Get nothing
	material = {
		diggability = "not",
	},
	description = "Iron Bomb",
})

minetest.register_on_punchnode(function(p, node, puncher)
	if node.name == "nuke:iron_tnt" then
		minetest.remove_node(p)
		spawn_tnt(p, "nuke:iron_tnt")
		nodeupdate(p)
		nuke_puncher = puncher
	end
end)

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

minetest.register_node("nuke:mese_tnt", {
	description = "Mese Bomb",
	tiles = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png", "nuke_mese_tnt_side.png"},
	inventory_image = minetest.inventorycube("nuke_mese_tnt_top.png", "nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png"),
	dug_item = '', -- Get nothing?
	material = {diggability = "not"},
})

minetest.register_on_punchnode(function(p, node, puncher)
	if node.name == "nuke:mese_tnt" then
		minetest.remove_node(p)
		spawn_tnt(p, "nuke:mese_tnt")
		nodeupdate(p)
		nuke_puncher = puncher
	end
end)

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

minetest.register_node("nuke:mossy_tnt", {
	tiles = {"nuke_mossy_tnt_top.png", "nuke_mossy_tnt_bottom.png",
			"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png",
			"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png"},
	inventory_image = minetest.inventorycube("nuke_mossy_tnt_top.png",
			"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png"),
	dug_item = '', -- Get nothing
	material = {
		diggability = "not",
	},
	description = "Mossy Bomb",
})

minetest.register_on_punchnode(function(p, node, puncher)
	if node.name == "nuke:mossy_tnt" then
		minetest.remove_node(p)
		spawn_tnt(p, "nuke:mossy_tnt")
		nodeupdate(p)
		nuke_puncher = puncher
	end
end)

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
		if minetest.get_node(pos).name == "default:water_source" or minetest.get_node(pos).name == "default:water_flowing" then
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
			"nuke_hardcore_iron_tnt_side.png", "nuke_hardcore_iron_tnt_side.png",
			"nuke_hardcore_iron_tnt_side.png", "nuke_hardcore_iron_tnt_side.png"},
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
			"nuke_hardcore_mese_tnt_side.png", "nuke_hardcore_mese_tnt_side.png",
			"nuke_hardcore_mese_tnt_side.png", "nuke_hardcore_mese_tnt_side.png"},
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

print(string.format("[nuke] loaded after ca. %.2fs", os.clock() - time_load_start))
