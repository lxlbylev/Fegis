local kernel = {}

kernel.language = "glsl"
kernel.category = "filter"
kernel.name = "lines"
kernel.isTimeDependent = false

local file = io.open(system.pathForFile("shaders/"..kernel.name..".glsl") )
kernel.fragment = file:read("*a")
file:close()

graphics.defineEffect(kernel)