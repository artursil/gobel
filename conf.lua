--- LÖVE configuration: window and module flags.

function love.conf(t)
	t.window.title = "Go 9×9"
	t.window.width = 720
	t.window.height = 780
	t.window.minwidth = 480
	t.window.minheight = 520
	t.window.resizable = true
	t.modules.joystick = false
end
