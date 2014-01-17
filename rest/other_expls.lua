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
