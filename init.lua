-- Nuke Mod 1.5 by sfan5
-- Licensed under GPLv2

-- differences: https://github.com/HybridDog/nuke/compare/original...master

local time_load_start = os.clock()
minetest.log("verbose", "[nuke] loading...")

if not rawget(_G, "nuke") then
	nuke = {}
end

--nuke.drop_items = false --this will only cause lags
nuke.RANGE = {}

dofile(minetest.get_modpath("nuke").."/settings.lua")

local MESE_TNT_RANGE = nuke.RANGE["mese"]
local IRON_TNT_RANGE = nuke.RANGE["iron"]
local MOSSY_TNT_RANGE = nuke.RANGE["mossy"]
nuke.bombs_list = {
	{"iron", "Iron"},
	{"mese", "Mese"},
	{"mossy", "Mossy"}
}

minetest.after(3, function()
	nuke.mossy_nodes = nuke.mossy_nodes or {}
	for _,i in pairs(moss.registered_moss) do
		table.insert(nuke.mossy_nodes, {i.node, i.result})
	end

	nuke.mossy_nds = {}
	for i,node in pairs(nuke.mossy_nodes) do
		nuke.mossy_nds[i] = {minetest.get_content_id(node[1]), minetest.get_content_id(node[2])}
	end
end)

function nuke.r_area(manip, size, pos)
	local emerged_pos1, emerged_pos2 = manip:read_from_map(
		{x=pos.x-size, y=pos.y-size, z=pos.z-size},
		{x=pos.x+size, y=pos.y+size, z=pos.z+size}
	)
	return VoxelArea:new({MinEdge=emerged_pos1, MaxEdge=emerged_pos2})
end

local no_map_update
function nuke.set_vm_data(manip, nodes, pos, t1, msg)
	manip:set_data(nodes)
	manip:write_to_map()
	minetest.log("info", string.format("[nuke] "..msg.." at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
	if not no_map_update then
		local t1 = os.clock()
		manip:update_map()
		minetest.log("info", string.format("[nuke] map updated after ca. %.2fs", os.clock() - t1))
	end
end

local function table_icontains(t, v)
	for i = 1,#t do
		if v == t[i] then
			return true
		end
	end
	return false
end

function spawn_tnt(pos, entname)
	minetest.sound_play("nuke_ignite", {pos = pos,gain = 1.0,max_hear_distance = 8,})
	return minetest.add_entity(pos, entname)
end

function do_tnt_physics(pos, r)
	local objs = minetest.get_objects_inside_radius(pos, r)
	for k, obj in pairs(objs) do
		local oname = obj:get_entity_name()
		local v = obj:getvelocity()
		local p = obj:getpos()
		if table_icontains(
			{"experimental:tnt", "nuke:iron_tnt"},
			oname
		) then
			obj:setvelocity({x=(p.x - pos.x) + (r / 2) + v.x, y=(p.y - pos.y) + r + v.y, z=(p.z - pos.z) + (r / 2) + v.z})
		else
			if v ~= nil then
				obj:setvelocity({x=(p.x - pos.x) + (r / 4) + v.x, y=(p.y - pos.y) + (r / 2) + v.y, z=(p.z - pos.z) + (r / 4) + v.z})
			else
				if obj:get_player_name() ~= nil then
					local dmg = math.floor(20.5-(vector.distance(pos, p)*20/r))
					obj:set_hp(obj:get_hp() - dmg)
				end
			end
		end
	end
end


--[[function nuke.get_nuke_random(pos)
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+nuke.seed)
end]]

local c_air = minetest.get_content_id("air")
local c_chest = minetest.get_content_id("default:chest")

local function add_c_to_tab(tab, c, nd)
	if not nd then
		tab[c] = 1
	else
		tab[c] = nd+1
	end
	return tab
end

local function get_drops(data)
	local tab = {}
	for c,n in pairs(data) do
		local nodename = minetest.get_name_from_content_id(c)
		while n > 0 do
			local drops = minetest.get_node_drops(nodename)
			for _, item in pairs(drops) do
				local curcnt = tab[item]
				if not curcnt then
					tab[item] = 1
				else
					tab[item] = curcnt+1
				end
			end
			n = n-1
		end
	end
	return tab
end

local nuke_puncher

local function add_to_inv(nodes)
	local inv = nuke_puncher:get_inventory()
	if not inv then
		return
	end
	for name,cnt in pairs(nodes) do
		local item = name.." "..cnt
		if inv:room_for_item("main", item) then
			inv:add_item("main", item)
		end
	end
end

local function move_items(data)
	local drops = get_drops(data)
	add_to_inv(drops)
end

if nuke.safe_mode then

function nuke.explode(pos, tab, range)
	local t1 = os.clock()
	local player = nuke_puncher
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*200})

	for _,npos in pairs(tab) do
		local p = vector.add(pos, npos[1])
		local node = minetest.get_node(p)
		if node.name ~= c_air then
			if npos[2] then
				if math.random(2) == 1 then
					minetest.node_dig(p, node, player)
				end
			else
				minetest.node_dig(p, node, player)
			end
		end
	end
	minetest.log("info", string.format("[nuke] exploded at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))
end

else

function nuke.explode(pos, tab, range)
	local t1 = os.clock()
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*200})

	local manip = minetest.get_voxel_manip()
	local area = nuke.r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	if nuke.preserve_items then
		node_tab = {}
		num = 1
		for _,npos in pairs(tab) do
			local p = vector.add(pos, npos[1])
			local p_p = area:index(p.x, p.y, p.z)
			local d_p_p = nodes[p_p]
			if d_p_p ~= c_air
			and d_p_p ~= c_chest then
				local nd = node_tab[d_p_p]
				if npos[2] then
					if math.random(2) == 1 then
						node_tab = add_c_to_tab(node_tab, d_p_p, nd)
						nodes[p_p] = c_air
					end
				else
					node_tab = add_c_to_tab(node_tab, d_p_p, nd)
					nodes[p_p] = c_air
				end
			end
		end
		move_items(node_tab)
	else
		for _,npos in pairs(tab) do
			local f = npos[1]
			local p = {x=pos.x+f.x, y=pos.y+f.y, z=pos.z+f.z}
			local p_p = area:index(p.x, p.y, p.z)
			local d_p_p = nodes[p_p]
			if d_p_p ~= c_air
			and d_p_p ~= c_chest then
				if npos[2] then
					if math.random(2) == 1 then
						nodes[p_p] = c_air
					end
				else
					nodes[p_p] = c_air
				end
			end
		end
	end
	nuke.set_vm_data(manip, nodes, pos, t1, "exploded")
end

end


function nuke.explode_inv(pos, tab, range, dir)
	local t1 = os.clock()
	minetest.sound_play("piston_extend", {pos = pos, max_hear_distance = range*200})

	local manip = minetest.get_voxel_manip()
	local area = nuke.r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	local dones = {}
	local strange = {}
	for _,npos in pairs(tab) do
		local f = npos[1]
		local dif = vector.scalar(dir, f)
		if dif < 0
		and dif ~= math.huge then
			dif = -dif*2
			local p1 = vector.add(pos, f)
			local p = vector.add(p1, vector.multiply(dir, dif))
			local p2 = vector.round(p)
			local p_p = area:indexp(p1)
			local p_p2 = area:indexp(p2)
			--if not dones[p_p]
			if dones[p_p2] then
				table.insert(strange, {p1, p})
			else
				--dones[p_p] = true
				if not npos[2]
				or math.random(2) == 1 then
					dones[p_p2] = true
					nodes[p_p],nodes[p_p2] = nodes[p_p2],nodes[p_p]
				end
				--[[local d1 = nodes[p_p]
				local d2 = nodes[p_p2]
				nodes[p_p] = d2 or c_air
				nodes[p_p2] = d1 or c_air]]
			end
		end
	end
	for _,ps in pairs(strange) do
		local p1,p = unpack(ps)
		local x,y,z = p.x,p.y,p.z
		local fi
		for s = 0.1,range,0.1 do
			local f = s
			for ax = -f,f,1 do
				for ay = -f,f,1 do
					for az = -f,f,1 do
						local t = vector.round({x=x+ax, y=y+ay, z=z+az})
						local p_t = area:indexp(t)
						if not dones[p_t] then
							dones[p_t] = true
							local p_p = area:indexp(p1)
							nodes[p_p],nodes[p_t] = nodes[p_t],nodes[p_p]
							fi = true
							break
						end
					end
					if fi then break end
				end
				if fi then break end
			end
			if fi then break end
		end
	end
	nuke.set_vm_data(manip, nodes, pos, t1, "explodid")
	minetest.sound_play("piston_retract", {pos = pos, max_hear_distance = range*200})
end


function nuke.explode_mossy(pos, tab, range)
	local t1 = os.clock()
	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*200})

	local manip = minetest.get_voxel_manip()
	local area = nuke.r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	for _,npos in pairs(tab) do

		local f = npos[1]
		local p = {x=pos.x+f.x, y=pos.y+f.y, z=pos.z+f.z}
		local p_p = area:index(p.x, p.y, p.z)
		local d_p_p = nodes[p_p]
		if d_p_p ~= c_air
		and d_p_p ~= c_chest then
			if npos[2] then
				if math.random(5) >= 4 then
					nodes[p_p] = c_air
				else
					for _,node in pairs(nuke.mossy_nds) do
						if d_p_p == node[1] then
							nodes[p_p] = node[2]
							break
						end
					end
				end
			else
				nodes[p_p] = c_air
			end
		end
	end
	nuke.set_vm_data(manip, nodes, pos, t1, "exploded (mossy)")
end

function nuke.explode_tnt(pos, tab, range, delay)
	local t1 = os.clock()

	local manip = minetest.get_voxel_manip()
	local area = nuke.r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	if nuke.preserve_items then
		node_tab = {}
		num = 1
		for _,npos in pairs(tab) do
			local p = vector.add(pos, npos[1])
			local p_p = area:index(p.x, p.y, p.z)
			local d_p_p = nodes[p_p]
			if d_p_p ~= c_air
			and d_p_p ~= c_chest then
				local nd = node_tab[d_p_p]
				if npos[2] then
					if math.random(2) == 1 then
						node_tab = add_c_to_tab(node_tab, d_p_p, nd)
						nodes[p_p] = c_air
					end
				else
					node_tab = add_c_to_tab(node_tab, d_p_p, nd)
					nodes[p_p] = c_air
				end
			end
		end
		move_items(node_tab)
	else
		for _,npos in pairs(tab) do
			local f = npos[1]
			local p = {x=pos.x+f.x, y=pos.y+f.y, z=pos.z+f.z}
			local p_p = area:index(p.x, p.y, p.z)
			local d_p_p = nodes[p_p]
			if d_p_p ~= c_air
			and d_p_p ~= c_chest then
				if npos[2] then
					if math.random(2) == 1 then
						nodes[p_p] = c_air
					end
				else
					nodes[p_p] = c_air
				end
			end
		end
	end
	manip:set_data(nodes)
	manip:write_to_map()
	minetest.log("info", string.format("[nuke] pre exploded at ("..pos.x.."|"..pos.y.."|"..pos.z..") after ca. %.2fs", os.clock() - t1))

	minetest.after(delay, function(param)
		local t1 = os.clock()
		minetest.sound_play("nuke_explode", {pos = param.pos, gain = 1, max_hear_distance = param.range*200})

		if no_map_update then
			return
		end
		minetest.add_particle({
			pos = param.pos,
			vel = {x=0,y=0,z=0},
			acc = {x=0,y=0,z=0},
			expirationtime = 0.5,
			size = 16*(param.range*2-1),
			collisiondetection = false,
			texture = "smoke_puff.png"
		})
		for _,i in pairs({
			{{x=param.pos.x-param.range, y=param.pos.y-param.range, z=param.pos.z-param.range}, {x=-3, y=0, z=-3}},
			{{x=param.pos.x+param.range, y=param.pos.y-param.range, z=param.pos.z-param.range}, {x=3, y=0, z=-3}},
			{{x=param.pos.x-param.range, y=param.pos.y-param.range, z=param.pos.z+param.range}, {x=-3, y=0, z=3}},
			{{x=param.pos.x+param.range, y=param.pos.y-param.range, z=param.pos.z+param.range}, {x=3, y=0, z=3}},
		}) do
			minetest.add_particlespawner({
				amount = 5*param.range, --amount
				time = 0.1, --time
				minpos = i[1], --minpos
				maxpos = {x=param.pos.x, y=param.pos.y+param.range, z=param.pos.z}, --maxpos
				minvel = i[2], --minvel
				maxvel = {x=0, y=0, z=0}, --maxvel
				minacc = {x=0,y=5,z=0}, --minacc
				maxacc = {x=0,y=10,z=0}, --maxacc
				minexptime = 0.1, --minexptime
				maxexptime = 1, --maxexptime
				minsize = 8, --minsize
				maxsize = 15, --maxsize
				collisiondetection = false, --collisiondetection
				texture = "smoke_puff.png" --texture
			})
		end
		param.manip:update_map()
		minetest.log("info", string.format("[nuke] map updated after ca. %.2fs", os.clock() - t1))
	end, {pos=pos, range=range, manip=manip})
end


--[[local function expl_moss(pos, range)
	local t1 = os.clock()

	minetest.sound_play("nuke_explode", {pos = pos, gain = 1, max_hear_distance = range*200})

	local manip = minetest.get_voxel_manip()
	local area = nuke.r_area(manip, range+1, pos)
	local nodes = manip:get_data()

	local pr = nuke.get_nuke_random(pos)

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
								for _,node in pairs(nuke.mossy_nds) do
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
	nuke.set_vm_data(manip, nodes, pos, t1, "exploded (mossy)")
end]]


minetest.register_chatcommand('nuke_switch_map_update',{
	description = 'Switch map update',
	params = "",
	privs = {},
	func = function(name)
		no_map_update = not no_map_update
		msg = "nuke map_update: ".. tostring(not no_map_update)
		minetest.log("action", "[nuke] "..name..": "..msg)
		minetest.chat_send_player(name, msg)
	end
})


--Crafting:

if nuke.always_allow_crafting
or minetest.is_singleplayer() then
	local w = 'default:wood'
	local c = 'default:coal_lump'

	for _,i in pairs({
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
	end
end

function nuke.lit_tnt(pos, name, puncher)
	minetest.remove_node(pos)
	spawn_tnt(pos, "nuke:"..name.."_tnt")
	nodeupdate(pos)
	nuke_puncher = puncher
end

for _,i in pairs(nuke.bombs_list) do
	local nnam = "nuke:"..i[1].."_tnt"
	minetest.register_node(nnam, {
		description = i[2].." Bomb",
		tiles = {"nuke_"..i[1].."_tnt_top.png", "nuke_"..i[1].."_tnt_bottom.png", "nuke_"..i[1].."_tnt_side.png"},
		dug_item = '', -- Get nothing?
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
		nuke.explode(pos, vector.explosion_table(IRON_TNT_RANGE), IRON_TNT_RANGE)
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

function nuke.tnt_ent(textures)
	return {
		-- Static definition
		physical = true, -- Collides with things
		-- weight = 5,
		collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
		visual = "cube",
		textures = textures,
		-- Initial value for our timer
		timer = 0,
		-- Number of punches required to defuse
		health = 1,
		blinktimer = 0,
		blinkstatus = true
	}
end

local MESE_TNT = nuke.tnt_ent({
	"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png",
	"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png",
	"nuke_mese_tnt_side.png", "nuke_mese_tnt_side.png"
})

local mese_tnt_table
function MESE_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
	if not mese_tnt_table then
		mese_tnt_table = vector.explosion_table(MESE_TNT_RANGE)
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
		nuke.explode(pos, mese_tnt_table, MESE_TNT_RANGE)
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

local MOSSY_TNT = nuke.tnt_ent({
	"nuke_mossy_tnt_top.png", "nuke_mossy_tnt_bottom.png",
	"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png",
	"nuke_mossy_tnt_side.png", "nuke_mossy_tnt_side.png"
})

local mossy_tnt_table
function MOSSY_TNT:on_activate(staticdata)
	self.object:setvelocity({x=0, y=4, z=0})
	self.object:setacceleration({x=0, y=-10, z=0})
	self.object:settexturemod("^[brighten")
	if not mossy_tnt_table then
		mossy_tnt_table = vector.explosion_table(MOSSY_TNT_RANGE)
	end
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
		local pos = vector.round(self.object:getpos())
		do_tnt_physics(pos, MOSSY_TNT_RANGE)
		if minetest.get_node(pos).name == "default:water_source"
		or minetest.get_node(pos).name == "default:water_flowing" then
			self.object:remove()
			return
		end
		nuke.explode_mossy(pos, mossy_tnt_table, MOSSY_TNT_RANGE)
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





-- Rocket Launcher


nuke.rocket_speed = 1
nuke.rocket_a = 100
nuke.rocket_range = 100
nuke.rocket_expl_range = 3

local function rocket_expl(pos, player, pos2, sound, delay)
	local nodenam = minetest.get_node(pos).name
	if nodenam == "ignore"
	or nodenam == "default:water_source"
	or nodenam == "default:water_flowing"
	or nodenam == "air" then
		return
	end
	--[[local maxp = {x=nuke.rocket_expl_range, y=nuke.rocket_expl_range, z=nuke.rocket_expl_range}
	local minp = vector.multiply(maxp, -1)
	if next(minetest.find_nodes_in_area(vector.add(pos, minp), vector.add(pos, maxp), {"ignore"})) then
		return false
	end]]
	nuke.explode_tnt(pos, vector.explosion_table(nuke.rocket_expl_range), nuke.rocket_expl_range, delay)
	minetest.after(delay, function(pos)
		minetest.sound_stop(sound)
		-- problem: objects already fell because of hidden removing
		do_tnt_physics(pos, nuke.rocket_expl_range)
	end, pos)
end

function nuke.rocket_shoot(player, range, particle_texture, sound)
	local t1 = os.clock()

	local playerpos=player:getpos()
	local dir=player:get_look_dir()

	local startpos = {x=playerpos.x, y=playerpos.y+1.625, z=playerpos.z}
	local bl, pos2 = minetest.line_of_sight(startpos, vector.add(vector.multiply(dir, range), startpos), 1)
	if not pos2 then
		return
	end
	local snd = minetest.sound_play(sound, {pos = playerpos, max_hear_distance = range})
	local delay = vector.straightdelay(math.max(vector.distance(startpos, pos2)-0.5, 0), nuke.rocket_speed, nuke.rocket_a)
	if not bl then
		rocket_expl(vector.round(pos2), player, startpos, snd, delay)
	end
	minetest.add_particle({
		pos = startpos,
		vel = vector.multiply(dir, nuke.rocket_speed),
		acc = vector.multiply(dir, nuke.rocket_a),
		expirationtime = delay,
		size = 1,
		collisiondetection = false,
		texture = particle_texture.."^[transform"..math.random(0,7)
	})
	--nuke.rocket_nodes(vector.round(startpos), dir, player, range, )

	minetest.log("info", "[nuke] <rocket> my shot was calculated after "..tostring(os.clock()-t1).."s")
end

local launcher_active, timer
minetest.register_tool("nuke:rocket_launcher", {
	description = "Rocket Launcher",
	inventory_image = "nuke_rocket_launcher.png",
	range = 0,
	stack_max = 1,
	on_use = function(_, user)
		launcher_active = true
		timer = -0.5
		nuke_puncher = user
		nuke.rocket_shoot(user, nuke.rocket_range, "nuke_rocket_launcher_back.png", "nuke_rocket_launcher")
	end,
})

minetest.register_globalstep(function(dtime)
	-- abort if noone uses it
	if not launcher_active then
		return
	end

	-- abort that it doesn't shoot too often (change it if your pc runs faster)
	timer = timer+dtime
	if timer < 0.1 then
		return
	end
	timer = 0

	local active
	for _,player in pairs(minetest.get_connected_players()) do
		if player:get_wielded_item():to_string() == "nuke:rocket_launcher"
		and player:get_player_control().LMB then
			nuke_puncher = player
			nuke.rocket_shoot(player, nuke.rocket_range, "nuke_rocket_launcher_back.png", "nuke_rocket_launcher")
			active = true
		end
	end

	-- disable the function if noone currently uses it to reduce lag
	if not active then
		launcher_active = false
	end
end)

local srw_range = 15
minetest.register_tool("nuke:mirrortool", {
	description = "SRW",
	inventory_image = "nuke_rocket_launcher.png^[brighten^[transform"..math.random(0,7),
	range = 0,
	stack_max = 1,
	on_use = function(_, user)
		nuke_puncher = user
		local pos = user:getpos()
		pos.y = pos.y+1.625
		pos = vector.round(pos)
		local dir = user:get_look_dir()
		nuke.explode_inv(pos, vector.explosion_table(srw_range), srw_range, dir)
	end,
})
--dofile(minetest.get_modpath("nuke").."/b.lua")

minetest.log("info", string.format("[nuke] loaded after ca. %.2fs", os.clock() - time_load_start))
