local aspectRatio = display.pixelHeight / display.pixelWidth

application = {
	--showRuntimeErrors = false,
	-- 456261155033 Идентификатор вашего приложения 
	-- 
	-- license =
 --    {
 --        google =
 --        {
 --            key = "YOUR_LICENSE_KEY",
 --            policy = "serverManaged"
 --        },
 --    },
	content = {
		-- width = 800,
		-- height = 1200,
		width = aspectRatio > 1.5 and 800 or math.ceil(1200 / aspectRatio),
		height = aspectRatio < 1.5 and 1200 or math.ceil(800 * aspectRatio),
		scale = "letterBox",
		fps = 60,
		imageSuffix = {
			["@2x"] = 1.3
		}
	}
}
