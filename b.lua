local function throw_bomb(pos, range, particle_texture, sound)
	local t1 = os.clock()

	local dir = {x=math.random(-5,5)/10, y=-1, z=math.random(-5,5)/10}

	local vel = {x=dir.x*nuke.rocket_speed, y=dir.y*nuke.rocket_speed, z=dir.z*nuke.rocket_speed}
	minetest.add_particle(pos, vel, {x=0,y=0,z=0}, 30/nuke.rocket_speed, 2, false, particle_texture)
	nuke.rocket_nodes(pos, dir, player, range)

	print("[nuke] <rocket> my shot was calculated after "..tostring(os.clock()-t1).."s")
end

minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		local pos = vector.round(player:getpos())

		for i = -9,9 do
			for j = -9,9 do
				if math.random(1000) == 1 then
					throw_bomb({x=pos.x+i, y=pos.y+15, z=pos.z+j}, 30, "nuke_firearms_rocket_entity.png")
				end
			end
		end
	end
end)
