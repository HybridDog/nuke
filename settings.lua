--This file contains configuration options for nuke mod.

--uses minetest.node_dig() instead of vm => more lag and protection support
nuke.safe_mode = false

nuke.preserve_items = false

nuke.seed = 12

nuke.RANGE.mese = 15
nuke.RANGE.iron = 9
nuke.RANGE.mossy = 5

--allows crafting
nuke.allow_crafting = minetest.is_singleplayer()
