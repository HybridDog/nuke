local nuke_preserve_items = true
local nuke_drop_items = false --this will only cause lags

nuke_mossy_nodes = { --I hope default:mossystonebrick will exist in the future.
	{"default:cobble", "default:mossycobble"}
}

local function describe_chest()
	if math.random(5) == 1 then return "You nuked. I HAVE NOT!" end
	if math.random(10) == 1 then return "Hehe, I'm the result of your explosion hee!" end
	if math.random(20) == 1 then return "Look into me, I'm fat!" end
	if math.random(30) == 1 then return "Please don't rob me. Else you are as evil as the other persons who took my inventoried stuff." end
	if math.random(300) == 1 then return "I'll follow you until I ate you. Like I did with the other objects here..." end
	return "Feel free to take the nuked items out of me!"
end



local function set_chest(p) --add a chest if the previous one is full
	local pos = p
	while minetest.env:get_node({x=pos.x, y=pos.y-1, z=pos.z}).name == "air" do
		pos.y=pos.y-1
	end
	minetest.env:add_node(pos, {name="default:chest"})
	local meta = minetest.get_meta(pos)
	meta:set_string("formspec",default.chest_formspec)
	meta:set_string("infotext", describe_chest())
	local inve = meta:get_inventory()
	inve:set_size("main", 8*4)
	nuke_chestpos = pos
end

local function destroy_node(pos)
	if nuke_preserve_items then
		local drops = minetest.get_node_drops(minetest.env:get_node(pos).name)
		minetest.env:remove_node(pos)
		if nuke_drop_items then
			for _, item in ipairs(drops) do
				if item ~= "default:cobble" then
					minetest.env:add_item(pos, item)
				end
			end
		elseif nuke_puncher ~= nil then
			local inv = nuke_puncher:get_inventory()
			if inv then
				for _, item in ipairs(drops) do
					if inv:room_for_item("main", item) then
						inv:add_item("main", item)
					else
						if nuke_chestpos == nil then
							set_chest(pos)
						end
						local chestinv = minetest.get_meta(nuke_chestpos):get_inventory()
						if not chestinv:room_for_item("main", item) then
							set_chest(pos)
						end
						chestinv:add_item("main", item)
					end
				end
			end
		end
	else
		minetest.env:remove_node(pos)
	end
end

function spawn_tnt(pos, entname)
	minetest.sound_play("nuke_ignite", {pos = pos,gain = 1.0,max_hear_distance = 8,})
	return minetest.env:add_entity(pos, entname)
end

function activate_if_tnt(nname, np, tnt_np, tntr)
	if nname == "experimental:tnt" or nname == "nuke:iron_tnt" or nname == "nuke:mese_tnt" or nname == "nuke:hardcore_iron_tnt" or nname == "nuke:hardcore_mese_tnt" then
		local e = spawn_tnt(np, nname)
		e:setvelocity({x=(np.x - tnt_np.x)*3+(tntr / 4), y=(np.y - tnt_np.y)*3+(tntr / 3), z=(np.z - tnt_np.z)*3+(tntr / 4)})
	end
end

function do_tnt_physics(tnt_np,tntr)
	local objs = minetest.env:get_objects_inside_radius(tnt_np, tntr)
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

local function explode(pos, range)
	local radius = range^2 + range
	for x=-range,range do
		for y=-range,range do
			for z=-range,range do
				local r = x^2+y^2+z^2 
				if r <= radius then
					local np={x=pos.x+x, y=pos.y+y, z=pos.z+z}
					local n = minetest.env:get_node(np)
					if n.name ~= "air"
					and n.name ~= "default:chest" then
	--				and math.random(1,2^rad) < range*8 then
						if math.floor(math.sqrt(r) +0.5) > range-1 then
							if math.random(1,5) >= 2 then
								destroy_node(np)
							elseif math.random(1,50) == 1 then
								minetest.sound_play("default_glass_footstep", {pos = np, gain = 0.5, max_hear_distance = 4})
							end
						else
							destroy_node(np)
						end
					--[[elseif n.name == "default:chest" then
						local p = pos
						while minetest.env:get_node({x=p.x, y=p.y-1, z=p.z}).name == "air" do
							p.y=p.y-1
						end

						minetest.env:add_node(p, {name="default:chest"})
						minetest.env:get_meta(minetest.env:get_meta(pos))]]
					end
					activate_if_tnt(n.name, np, pos, range)
				end
			end
		end
	end
end

local function expl_moss(pos, range)
	local radius = range^2 + range
	for x=-range,range do
		for y=-range,range do
			for z=-range,range do
				local r = x^2+y^2+z^2 
				if r <= radius then
					local np={x=pos.x+x, y=pos.y+y, z=pos.z+z}
					local n = minetest.env:get_node(np)
					if n.name ~= "air"
					and n.name ~= "default:chest" then
						if math.floor(math.sqrt(r) +0.5) > range-1 then
							if math.random(1,5) >= 4 then
								destroy_node(np)
							elseif math.random(1,50) == 1 then
								minetest.sound_play("default_glass_footstep", {pos = np, gain = 0.5, max_hear_distance = 4})
							else
								for _,node in ipairs(nuke_mossy_nodes) do
									if n.name == node[1] then
										minetest.env:add_node (np, {name = node[2]})
									end
								end
							end
						else
							destroy_node(np)
						end
					end
					activate_if_tnt(n.name, np, pos, range)
				end
			end
		end
	end
end


--Crafting:

minetest.register_craft({
	output = 'nuke:iron_tnt 4',
	recipe = {
		{'','default:wood',''},
		{'default:steel_ingot','default:coal_lump','default:steel_ingot'},
		{'','default:wood',''}
	}
})

minetest.register_craft({
	output = 'nuke:mese_tnt 4',
	recipe = {
		{'','default:wood',''},
		{'default:mese_crystal','default:coal_lump','default:mese_crystal'},
		{'','default:wood',''}
	}
})

minetest.register_craft({
	output = 'nuke:hardcore_iron_tnt',
	recipe = {
		{'','default:coal_lump',''},
		{'default:coal_lump','nuke:iron_tnt','default:coal_lump'},
		{'','default:coal_lump',''}
	}
})

minetest.register_craft({
	output = 'nuke:hardcore_mese_tnt',
	recipe = {
		{'','default:coal_lump',''},
		{'default:coal_lump','nuke:mese_tnt','default:coal_lump'},
		{'','default:coal_lump',''}
	}
})


-- Iron TNT

minetest.register_node("nuke:iron_tnt", {
	tile_images = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png",
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
		minetest.env:remove_node(p)
		spawn_tnt(p, "nuke:iron_tnt")
		nodeupdate(p)
		nuke_puncher = puncher
	end
end)

local IRON_TNT_RANGE = 6
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
		minetest.sound_play("nuke_explode", {pos = pos,gain = 1.0,max_hear_distance = 16,})
		if minetest.env:get_node(pos).name == "default:water_source" or minetest.env:get_node(pos).name == "default:water_flowing" then
			-- Cancel the Explosion
			self.object:remove()
			return
		end
		explode(pos, IRON_TNT_RANGE)
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
	tile_images = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png",
			"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png",
			"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png"},
	inventory_image = minetest.inventorycube("nuke_mese_tnt_top.png",
			"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png"),
	dug_item = '', -- Get nothing
	material = {
		diggability = "not",
	},
	description = "Mese Bomb",
})

minetest.register_on_punchnode(function(p, node, puncher)
	if node.name == "nuke:mese_tnt" then
		minetest.env:remove_node(p)
		spawn_tnt(p, "nuke:mese_tnt")
		nodeupdate(p)
		nuke_puncher = puncher
	end
end)

local MESE_TNT_RANGE = 12
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
		minetest.sound_play("nuke_explode", {pos = pos,gain = 1.0,max_hear_distance = 16,})
		if minetest.env:get_node(pos).name == "default:water_source" or minetest.env:get_node(pos).name == "default:water_flowing" then
			-- Cancel the Explosion
			self.object:remove()
			return
		end
		explode(pos, MESE_TNT_RANGE)
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
	tile_images = {"nuke_mossy_tnt_top.png", "nuke_mossy_tnt_bottom.png",
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
		minetest.env:remove_node(p)
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
		minetest.sound_play("nuke_explode", {pos = pos,gain = 1.0,max_hear_distance = 16,})
		if minetest.env:get_node(pos).name == "default:water_source" or minetest.env:get_node(pos).name == "default:water_flowing" then
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
	tile_images = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png",
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
		minetest.env:remove_node(p)
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
				minetest.env:add_entity(np, "nuke:iron_tnt")
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
	tile_images = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png",
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
		minetest.env:remove_node(p)
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
				minetest.env:add_entity(np, "nuke:mese_tnt")
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
