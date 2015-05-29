local function explode(pos, range)
	local t1 = os.clock()
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
				local r = x^2+y^2+z^2
				if r <= radius then
					local np={x=pos.x+x, y=pos.y+y, z=pos.z+z}
--					local n = minetest.get_node(np)
					local p_np = area:index(np.x, np.y, np.z)
					local d_p_np = nodes[p_np]
					if d_p_np ~= c_air
					and d_p_np ~= c_chest then
						if math.floor(math.sqrt(r) +0.5) > range-1 then
							if pr:next(1,5) >= 2 then
--								destroy_node(np)
								nodes[area:index(np.x, np.y, np.z)] = c_air
							elseif pr:next(1,10) == 1 then
								minetest.sound_play("default_glass_footstep", {pos = np, gain = 0.5, max_hear_distance = 4})
							end
						else
--							destroy_node(np)
							nodes[area:index(np.x, np.y, np.z)] = c_air
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

local function explode_invert(pos, range)
	local t1 = os.clock()
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*2})

	local manip = minetest.get_voxel_manip()
	local width = range+1
	local emerged_pos1, emerged_pos2 = manip:read_from_map({x=pos.x-width, y=pos.y-width, z=pos.z-width},
		{x=pos.x+width, y=pos.y+width, z=pos.z+width})
	local area = VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
	local nodes = {}

	local ignore = minetest.get_content_id("ignore")
	for i = 1, get_volume(emerged_pos1, emerged_pos2) do
		nodes[i] = ignore
	end

	local c_air = minetest.get_content_id("air")

	local radius = range^2 + range
	for x=-range,range do
		for y=-range,range do
			for z=-range,range do
				local r = x^2+y^2+z^2
				if r <= radius then
					local np={x=pos.x+x, y=pos.y+y, z=pos.z+z}
					local i_np=area:index(pos.x+x, pos.y-y, pos.z+z)
					local n = minetest.get_node(np).name
					local content = minetest.get_content_id(n)
					if math.floor(math.sqrt(r) +0.5) > range-1 then
						if math.random(1,5) >= 2 then
							nodes[i_np] = content
						elseif math.random(1,10) == 1 then
							minetest.sound_play("default_glass_footstep", {pos = np, gain = 0.5, max_hear_distance = 4})
						end
					else
						nodes[i_np] = content
					end
					activate_if_tnt(n.name, np, pos, range)
				end
			end
		end
	end
	manip:set_data(nodes)
	manip:write_to_map()
	print(string.format("[nuke] exploded in: %.2fs", os.clock() - t1))
	local t1 = os.clock()
	manip:update_map()
	print(string.format("[nuke] map updated in: %.2fs", os.clock() - t1))
end




local function destroy_node(pos)
	if nuke_preserve_items then
		local drops = minetest.get_node_drops(minetest.get_node(pos).name)
		if nuke_drop_items then
			for _, item in ipairs(drops) do
				if item ~= "default:cobble" then
					minetest.add_item(pos, item)
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
	end
end

local function copy_meta(pos, p)
	local meta0 = minetest.get_meta(pos):to_table()
	local meta = minetest.get_meta(p)
	meta:from_table(meta0)
end


function activate_if_tnt(nname, np, tnt_np, tntr)
	if nname == "experimental:tnt"
	or nname == "nuke:iron_tnt"
	or nname == "nuke:mese_tnt"
	or nname == "nuke:hardcore_iron_tnt"
	or nname == "nuke:hardcore_mese_tnt" then
		local e = spawn_tnt(np, nname)
		e:setvelocity({x=(np.x - tnt_np.x)*3+(tntr / 4), y=(np.y - tnt_np.y)*3+(tntr / 3), z=(np.z - tnt_np.z)*3+(tntr / 4)})
	end
end





local chest_descs = {
	{5, "You nuked. I HAVE NOT!"},
	{10, "Hehe, I'm the result of your explosion hee!"},
	{20, "Look into me, I'm fat!"},
	{30, "Please don't rob me. Else you are as evil as the other persons who took my inventoried stuff."},
	{300, "I'll follow you until I ate you. Like I did with the other objects here..."},
}

function nuke.describe_chest()
	for _,i in pairs(chest_descs) do
		if math.random(i[1]) == 1 then
			return i[2]
		end
	end
	return "Feel free to take the nuked items out of me!"
end

function nuke.set_chest(pos) --add a chest
	minetest.add_node(pos, {name="default:chest"})
	local meta = minetest.get_meta(pos)
	meta:set_string("formspec", default.chest_formspec)
	meta:set_string("infotext", describe_chest())
	local inve = meta:get_inventory()
	inve:set_size("main", 8*4)
	nuke_chestpos = pos
end


-- Hardcore

		minetest.register_craft({
			output = 'nuke:hardcore_'..i[1]..'_tnt',
			recipe = {
				{'', c, ''},
				{c, 'nuke:'..i[1]..'_tnt', c},
				{'', c, ''}
			}
		})


, "nuke:mese_tnt", "nuke:hardcore_iron_tnt", "nuke:hardcore_mese_tnt"

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




moss.register_moss({
	node = "nuke:iron_tnt",
	result = "nuke:mossy_tnt"
})

moss.register_moss({
	node = "nuke:mese_tnt",
	result = "nuke:mossy_tnt"
})




