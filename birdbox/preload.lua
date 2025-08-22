gdebug.log_info("Birdbox: preload")
local mod = game.mod_runtime[game.current_mod]

gapi.add_on_every_x_hook(TimeDuration.from_turns(1), function() mod.birdbox_effect() end)