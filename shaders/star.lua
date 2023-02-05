local kernel = {}

kernel.language = "glsl"
kernel.category = "generator"
kernel.name = "star"
kernel.isTimeDependent = false

local file = io.open(system.pathForFile("shaders/"..kernel.name..".glsl") )
kernel.fragment = file:read("*a")
file:close()

graphics.defineEffect(kernel)