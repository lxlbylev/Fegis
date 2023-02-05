local composer = require( "composer" )

display.setStatusBar( display.HiddenStatusBar )

-- Android Settings -- 
-- if ( system.getInfo("platformName") == "Android" ) then 
-- 	local androidVersion = string.sub( system.getInfo( "platformVersion" ), 1, 3) 
-- 	if( androidVersion and tonumber(androidVersion) >= 4.4 ) then 
-- 		native.setProperty( "androidSystemUiVisibility", "immersiveSticky" ) 
-- 		--native.setProperty( "androidSystemUiVisibility", "lowProfile" ) 
-- 	elseif( androidVersion ) then 
-- 		native.setProperty( "androidSystemUiVisibility", "lowProfile" ) 
-- 	end 
-- end



math.randomseed( os.time() )

require("shaders.lines")   
-- timer.performWithDelay( 1500, function()
	composer.gotoScene( "menu" )
	-- timer.performWithDelay( 100, function()
		local version = system.getInfo("appVersionString")
		local versionLabel = display.newText( "version: "..version, 40, display.actualContentHeight-10, "r_r.ttf", 35)
		versionLabel:setFillColor( 0 )
		versionLabel.anchorX=0
		versionLabel.anchorY=1
		-- if version:sub(1,1)=="0" then
		--   versionLabel.text = versionLabel.text.." beta"
		-- end
	-- end )
-- end )
