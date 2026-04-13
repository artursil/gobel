--- LÖVE configuration: window and module flags.

function love.conf(t)
	t.window.title = "Go 9×9"
	t.window.width = 720
	t.window.height = 820
	t.window.minwidth = 480
	t.window.minheight = 640
	t.window.resizable = true
	t.modules.joystick = false
end
