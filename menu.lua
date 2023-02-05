
local composer = require( "composer" )
local scene = composer.newScene()
local json = require( "json" )
local widget = require( "widget" )

local q = require"base"

local unlockConfig = 0 -- 3 чтобы войти 

local backGroup, mainGroup, settingsGroup, setNameGroup

local tri_shape = {0,-80, 40,0, -40,0}
local colors = {
  black = q.CL"323235",
  neon = q.CL"36d8d4",
  gold = q.CL"d6a938",
  violet = q.CL"ab38d6",
  red = q.CL"dd2a49",
}
local playerGroup
local function createPlayer()
  local group = display.newGroup()
  mainGroup:insert( group )
  group.x = q.cx
  group.y = q.cy
  group.myName = "player"
  local qwa = display.newRect( group, 0, 0-28*.55, 80*.55, 80*.55 )
  qwa.fill = colors.black
  local qwa = display.newRect( group, 0, 0-28*.55, 80*.55, 20*.55 )
  -- qwa.fill = colors.black
  local tri = display.newPolygon( group, 0, (40+40*(21/27)-28)*.55, tri_shape )
  tri.fill = colors.black
  tri.xScale = .55
  tri.yScale = (21/27)*.55
  tri.rotation = 180
  playerGroup = group
  group:addEventListener( "tap", function()
    local i = 2
    transition.to( group, {rotation = group.rotation + 360 * i, time = 500 * i} )
  end )
end


local height, width = 64, .8
local shape_enemy = {
  0, height*1.4,
  -height*width, 0,
  height*width, 0
}
height, width = nil, nil

local onSettings = false
local function toSettings()
  onSettings = true
  settingsGroup.alpha = 1
  mainGroup.alpha = 0
end

local function toMenu()
  onSettings = false
  settingsGroup.alpha = 0
  mainGroup.alpha = 1
end


local set
local appVersion = system.getInfo("appVersionString")
appVersion = appVersion~="" and appVersion or "0.2.6"

local myNick
local jsonLink = "https://api.jsonstorage.net/v1/json/7258cfc4-e9f4-4045-be0a-9179b1ee9d45/dc509680-bbfe-4495-977d-0dbce9779ef0"
local apiKey = "b8382c38-40bf-41c5-98ca-190bf3e3c558"

local function patchResponse( event )
  if ( event.isError)  then
    print( "Error!" )
  else
    local myNewData = event.response
    if myNewData==nil or myNewData=="[]" or myNewData=="" then
      print("Server patch: нет ответа")
      return
    elseif myNewData:sub(1,3)=='{"u' then
      print("Server patch: успешно")
    end
    print(myNewData)
  end
end

local function patcher( patch )
  print(patch)
  network.request( jsonLink.."?apiKey="..apiKey, "PATCH", patchResponse, {
    headers = {
      ["Content-Type"] = "application/json"
    },
    body = patch,
    bodyType = "text",
  } )
end

local worldbestGroup, worldbestBodyGroup
local worldButtons = {}
local function worldScoreDraw( worldBests )

  display.remove( worldbestBodyGroup )
  worldbestBodyGroup = display.newGroup()
  worldbestGroup:insert(worldbestBodyGroup)

  local verI = 0
  local myNum = 0
  local winColor = {
    {1,1,.6},
    {.6,1,1},
    {1,.8,.6},
  }
  for k,v in pairs(worldBests) do
    local myV = v
    local j = 1
    for i=1, #myV do
      if myV[i][2]~=0 or myV[i][1]==myNick then
        local secondLabel = tostring( myV[i][2]%60 )
        secondLabel = #secondLabel>1 and secondLabel or "0"..secondLabel
        local wolrdScore = display.newText({
          parent = worldbestBodyGroup, 
          text = j.."# "..myV[i][1].." - "..math.floor(myV[i][2]/60)..":"..secondLabel,
          x = worldbestGroup.width*(.5+verI),
          y = 50*j-10, 
          fontSize = 40, 
          font = "r_r.ttf"
        })
        if wolrdScore.width>worldbestGroup.width then
          local a = wolrdScore.width
          local i = 1
          while a>worldbestGroup.width do
            a = a*.9
            i = i*.9
          end
          wolrdScore.xScale=i 
        end

        local color = {1}
        if myV[i][1]==myNick then
          color = {.6,1,.6}
          -- local color = color[j]
          -- if color then
          --   playerGroup.myBody[2].fill = color
          -- end
        end
        color = winColor[j] or color
        wolrdScore:setFillColor( unpack( color ) )
        j = j + 1
      end
    end
    local wolrdScore = display.newText({
      parent = worldbestBodyGroup, 
      text = "v"..k,
      x = worldbestGroup.width*(.5+verI),
      y = 50*j-10, 
      fontSize = 36, 
      font = "r_r.ttf"
    })
    wolrdScore:setTextColor( .8 )

    local endZone = display.newRect(worldbestBodyGroup, 0, worldbestBodyGroup.height+25, 25, 25)
    endZone.anchorY = 0
    endZone.alpha = .01

    if appVersion==k then
      myNum = verI
    end
    verI = verI + 1
  end
  worldbestBodyGroup.x = worldbestGroup.width*-myNum
end

local function worldScoreLoad( event )
  if ( event.isError)  then
    print( "Error!" )
  else
    local myNewData = event.response
    if myNewData==nil or myNewData=="[]" then
      print("Server read: нет ответа")
      return
    end
    print(myNewData)
    local scores = json.decode(myNewData)
    scores[appVersion] = scores[appVersion]~=nil and scores[appVersion] or {}
    local myBest = q.loadScores()[1]
    if scores[appVersion]==nil then
      
      print("do patch to version - "..appVersion)
      patcher('{"'..appVersion..'": {"'..myNick..'": "'..myBest..'"}}')
      
      scores[appVersion][myNick] = myBest
    elseif scores[appVersion][myNick]==nil then 
      
      print("do patch to nick - "..myNewData)
      patcher('{"'..appVersion..'": {"'..myNick..'": "'..myBest..'"}}')
      scores[appVersion][myNick] = myBest
    elseif tonumber(scores[appVersion][myNick])<myBest then

      print("do patch to newscore by "..myNick.." - "..myBest)
      patcher('{"'..appVersion..'": {"'..myNick..'": "'..myBest..'"}}')
      scores[appVersion][myNick] = myBest
    end

    local sortedScores = {}
    for version in pairs(scores) do
    
      sortedScores[version] = {}
      local i = 0
      for k,v in pairs(scores[version]) do
        i = i + 1
        sortedScores[version][i] = {k,tonumber(v)}
      end

      table.sort( sortedScores[version], function(a,b)
        return a[2]>b[2]
      end )
    end

    worldScoreDraw( sortedScores )
    return sortedScores
  end
end

local onKeyEvent
if ( system.getInfo("environment") == "device" ) then
  onKeyEvent = function( event )
    -- Print which key was pressed down/up
    local message = "Key '" .. event.keyName .. "' was pressed " .. event.phase
    -- If the "back" key was pressed on Android, prevent it from backing out of the app
    if ( event.keyName == "back" ) then
      if ( system.getInfo("platform") == "android" ) then
        if onSettings then
          toMenu()
        end
        
        return true
      end
    end

    -- IMPORTANT! Return false to indicate that this app is NOT overriding the received key
    -- This lets the operating system execute its default handling of the key
  end
end


local scoreLabel
function scene:create( event )

	sceneGroup = self.view

  mainGroup = display.newGroup()
  sceneGroup:insert(mainGroup)

  setNameGroup = display.newGroup()
  sceneGroup:insert(setNameGroup)

  settingsGroup = display.newGroup()
  sceneGroup:insert(settingsGroup)
  settingsGroup.alpha = 0

  do --==== М Е Н Ю ====--
    local backGround = display.newRect(mainGroup, q.cx, q.cy, q.fullw, q.fullh+200)
    -- backGround.anchorY = 0
    backGround.fill = q.CL"a3b18a"

    local backBlack = display.newRect(mainGroup, q.cx,q.cy, q.fullw, q.fullh+display.statusBarHeight+50)
    backBlack.fill = {
      type = "image",
      filename = "img/back.png"
    }
    -- backBlack.fill = {0,0,0,.1}

    local gameLabel = display.newText( {
      parent = mainGroup,
      text = "Fegis",
      x = 50,
      y = 40,
      font = "r_r.ttf",
      fontSize = 105,
    } )
    gameLabel:setFillColor( 0 )
    gameLabel.anchorX = 0
    gameLabel.anchorY = 0


    scoreLabel = display.newText( {
      parent = mainGroup,
      text = "0:00",
      x = 30,
      y = 190,
      font = "r_r.ttf",
      fontSize = 130,
    } )
    scoreLabel:setFillColor( 0 )
    scoreLabel.anchorX = 0
    scoreLabel.anchorY = 0

    local y = q.fullh - 80 - 50

    
    local playButton = display.newRect( mainGroup, 35, y, 350, 140 )
    playButton.fill = {0,0,0,.6}
    playButton.anchorX = 0
    playButton.anchorY = 1

    local playLabel = display.newText( {
      parent = mainGroup,
      text = "Играть",
      x = playButton.x + playButton.width*.5,
      y = playButton.y - playButton.height*.5,
      font = "r_r.ttf",
      fontSize = 65,
    } )


    local settingsButton = display.newRect( mainGroup, q.fullw-35, y, 350, 140 )
    settingsButton.fill = {0,0,0,.6}
    settingsButton.anchorX = 1
    settingsButton.anchorY = 1

    local settingsLabel = display.newText( {
      parent = mainGroup,
      text = "Настройки",
      x = settingsButton.x - settingsButton.width*.5,
      y = settingsButton.y - settingsButton.height*.5,
      font = "r_r.ttf",
      fontSize = 60,
    } )

    -- local settingsButton = display.newRect( mainGroup, q.fullw-35, y-180, 350, 140 )
    -- settingsButton.fill = {0,0,0,.6}
    -- settingsButton.anchorX = 1
    -- settingsButton.anchorY = 1

    -- local settingsLabel = display.newText( {
    --   parent = mainGroup,
    --   text = "Донат",
    --   x = settingsButton.x - settingsButton.width*.5,
    --   y = settingsButton.y - settingsButton.height*.5,
    --   font = "r_r.ttf",
    --   fontSize = 60,
    -- } )



    local scoreBack = display.newRect(mainGroup, 250, q.fullh*.52-(500+100)*.5, 450, 100)
    scoreBack.anchorY = 0
    scoreBack.fill = {0,.7}
    local wolrdScore = display.newText({
      parent = mainGroup, 
      text = "Мировые рекорды", 
      x = scoreBack.x, 
      y = scoreBack.y+50, 
      fontSize = 40, 
      font = "r_r.ttf"
    })

    local x,y,width,height = scoreBack.x, scoreBack.y+scoreBack.height, scoreBack.width, 500
    
    local namesBack = display.newRect(mainGroup, x, y, width, height)
    namesBack.anchorY = 0
    namesBack.fill = {0,.6}
    

    worldbestGroup = widget.newScrollView(
      {
        top =   -namesBack.height*.5,
        height = namesBack.height,
        
        left = -namesBack.width*.5,
        width = namesBack.width,
        
        scrollWidth = 0,
        scrollHeight = 0,
        horizontalScrollDisabled = true,
        -- verticalScrollDisabled = true,
        hideBackground = true,
      }
    )
    worldbestGroup.x = x
    worldbestGroup.y = y+height*.5
    worldbestGroup.size = {
      width = namesBack.width,
      height = namesBack.height
    } 
    mainGroup:insert( worldbestGroup )


    worldbestBodyGroup = display.newGroup()
    worldbestGroup:insert(worldbestBodyGroup)    

    local loadLabel = display.newText({
      parent = worldbestBodyGroup, 
      text = "-- Загрузка --",
      x = width*.5, 
      y = height*.5, 
      fontSize = 40, 
      font = "r_r.ttf"
    })


    playerGroup = q.createPlayer(mainGroup, q.cx, 200)

    playerGroup:addEventListener( "tap", function()
      local i = 2
      transition.to( playerGroup, {rotation = playerGroup.rotation + 360 * i, time = 500 * i} )
    end )
    playerGroup.xScale = 6
    playerGroup.yScale = 6
    playerGroup.x = q.fullw - playerGroup.width * playerGroup.xScale * .5 - 30

    playButton:addEventListener( "tap", function()
      composer.removeScene( "game" )
      composer.gotoScene( "game", {effect = "fade", time = 400} )
    end )

    settingsButton:addEventListener( "tap", toSettings )
  end

  do --==== Н А С Т Р О Й К И ====--

    local backBlack = display.newRect(settingsGroup, q.cx,q.cy, q.fullw, q.fullh)
    backBlack.fill = {0,0,0}

    local settingsLabel = display.newText( {
      parent = settingsGroup,
      text = "Настройки",
      x = q.cx,
      y = 40,
      width = q.fullw-100,
      align = "center",
      font = "r_r.ttf",
      fontSize = 55,
    } )
    settingsLabel.anchorY = 0
    
    local y = 300

    set = q.loadSettings()

    local volumeControl = display.newGroup()
    settingsGroup:insert(volumeControl)
    volumeControl.x = q.cx-100
    volumeControl.y = 150+150

    local color = q.CL("13122f")
    local a=display.newRect( volumeControl, -170, -110, 140, 80 ) a.fill=color
    local a=display.newRect( volumeControl, -170, 0, 140, 80 ) a.fill=color
    local a=display.newRect( volumeControl, -170, 110, 140, 80 ) a.fill=color


    local a=display.newText( volumeControl, "ALL", -230, -100, "M_EB.ttf", 35 ) a.anchorX=0
    local allLabel = display.newText( volumeControl, set.volume.all.."%", -230, -130, "r_r.ttf", 25 ) allLabel.anchorX=0
    local a=display.newText( volumeControl, "MUSIC", -230, 10, "M_EB.ttf", 35 ) a.anchorX=0
    local musicLabel = display.newText( volumeControl, set.volume.music.."%", -230, -20, "r_r.ttf", 25 ) musicLabel.anchorX=0
    local a=display.newText( volumeControl, "SFX", -230, 120, "M_EB.ttf", 30 ) a.anchorX=0
    local sfxLabel = display.newText( volumeControl, set.volume.sfx.."%", -230, 90, "r_r.ttf", 25 ) sfxLabel.anchorX=0

    local widget = require "widget"
    local VolumeMin=0
    local VolumeMax=100
    local VolumeSlider=50

    local opt = {
      sheet=graphics.newImageSheet( "img/slider.png", {
        frames = {
          { x=0, y=0, width=15, height=45 },
          { x=16, y=0, width=130, height=45 },
          { x=332, y=0, width=15, height=45 },
          { x=153, y=0, width=15, height=45 },
          { x=353, y=0, width=47, height=46 },
        },
        sheetContentWidth=400,
        sheetContentHeight=45
      }),
      leftFrame = 1,
      middleFrame = 2,
      rightFrame = 3,
      fillFrame = 4,
      handleFrame = 5,

      frameWidth = 15,
      frameHeight = 65,
      handleWidth = 60,
      handleHeight = 65,
      -- координаты слайдера
      top = -30, left= -50,
      -- размеры слайдера
      width = 500, height=47,
      orientation="horizontal",
      value=100*(set.volume.music-VolumeMin)/(VolumeMax-VolumeMin),
      listener=function (event)
        local a = q.round (VolumeMin + (VolumeMax - VolumeMin) * event.value/100)
        set.volume.music=a
        musicLabel.text=a .."%"
      end
    }
    local weightS=widget.newSlider(opt) opt.top=-50-90 volumeControl:insert(weightS)

    opt.value=100*(set.volume.all-VolumeMin)/(VolumeMax-VolumeMin)
    opt.listener=function(event)
      local a = q.round (VolumeMin + (VolumeMax - VolumeMin) * event.value/100)
      set.volume.all=a
      allLabel.text=a .."%"
    end
    local weightS=widget.newSlider(opt) opt.top=-50+130 volumeControl:insert(weightS)

    opt.value=100*(set.volume.sfx-VolumeMin)/(VolumeMax-VolumeMin)
    opt.listener=function(event)
      local a = q.round (VolumeMin + (VolumeMax - VolumeMin) * event.value/100)
      set.volume.sfx=a
      sfxLabel.text=a .."%"
    end
    local weightS=widget.newSlider(opt) volumeControl:insert(weightS)

    -- local darkMode = display.newText( {
    --   parent = settingsGroup,
    --   text = "Темная тема",
    --   x = q.cx,
    --   y = 580,
    --   font = "r_r.ttf",
    --   fontSize = 50,
    -- } )
    -- local rect = display.newRect( settingsGroup, darkMode.x, darkMode.y, 450,100 )
    -- rect.fill = {0,.01}
    -- rect:setStrokeColor( 1 )
    -- rect.strokeWidth = 5
    -- if set.style==0 then
    --   rect.alpha = .01
    -- else
    --   -- rect.alpha = 1
    -- end


    -- rect:addEventListener( "tap", function()
    --   if set.style==0 then
    --     set.style = 1
    --     transition.to( rect, {alpha = 1, time = 500})
    --   else 
    --     set.style = 0
    --     transition.to( rect, {alpha = .01, time = 500})
    --   end
    -- end )

    local y = q.fullh - 50
    local tomenuButton = display.newRect( settingsGroup, q.cx, y, q.fullw-100, 120 )
    tomenuButton.alpha = .2
    tomenuButton.anchorY = 1

    local tomenuLabel = display.newText( {
      parent = settingsGroup,
      text = "Назад",
      x = tomenuButton.x,
      y = tomenuButton.y - tomenuButton.height*.5,
      font = "r_r.ttf",
      fontSize = 50,
    } )

    tomenuButton:addEventListener( "tap", toMenu )
  
  end

  myNick = q.loadAccount()

  if onKeyEvent then
    Runtime:addEventListener( "key", onKeyEvent )
  end
end

local nickField, errorLabel
local function showWarnin(text,time)
  time = time~=nil and time or 2000
  errorLabel.text=text
  errorLabel.alpha=1
  errorLabel.fill.a=1
  timer.performWithDelay( time, 
  function()
    transition.to(errorLabel.fill,{a=0,time=500} )
  end)
end
local function validateNick()
  local nick = q.trim( nickField.text )
  if nick=="" then
    showWarnin("Ник не может быть пустым") return
  elseif nick:find("%p") then
    showWarnin("Только буквы и числа") return
  elseif q.utf8len(nick)<3 then
    showWarnin("Ник от 3-х символов") return
  elseif q.utf8len(nick)>14 then
    showWarnin("Ник до 14 символов") return
  end
  
  q.saveAccount(nick)
  myNick = nick
  mainGroup.alpha = 1
  display.remove(setNameGroup)
  network.request( jsonLink, "GET", worldScoreLoad )

end

local function getUserName()
  mainGroup.alpha = 0
  local toDefaultLabel = display.newText( {
    parent = setNameGroup,
    text = "Выбирите свой ник",
    x = q.cx,
    y = 200,
    font = "r_r.ttf",
    fontSize = 60,
  } )

  local toDefaultLabel = display.newText( {
    parent = setNameGroup,
    text = "его нельзя будет изменить",
    x = q.cx,
    y = 250,
    font = "r_r.ttf",
    fontSize = 30,
  } )

  nickField = native.newTextField(q.cx, 450, q.fullw*.8, 200)
  setNameGroup:insert( nickField )

  nickField.hasBackground = false
  nickField.placeholder = "Dima2008"

  nickField.font = native.newFont( "ubuntu_r.ttf",20*2)

  nickField:resizeHeightToFitFont()
  nickField:setTextColor( 0, 0, 0 )


  errorLabel = display.newText( {
    parent = setNameGroup,
    text = "его нельзя будет изменить",
    x = q.cx,
    y = 510,
    font = "r_r.ttf",
    fontSize = 30,
  } )
  errorLabel:setTextColor( 1,.2,.4 )
  errorLabel.alpha = 0

  local okButton = display.newRect( setNameGroup, q.cx, 600, 200, 100 )
  okButton.fill = {.5,.8,.8}

  local toDefaultLabel = display.newText( {
    parent = setNameGroup,
    text = "OK",
    x = okButton.x,
    y = okButton.y,
    font = "r_r.ttf",
    fontSize = 60,
  } )
  toDefaultLabel:addEventListener( "tap", validateNick )
end

function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
    local inPlayTime = q.loadScores()[1]
    local sec = tostring(inPlayTime%60)
    if #sec==1 then sec = "0"..sec end
    scoreLabel.text = math.floor(inPlayTime/60)..":"..sec
    
    if myNick~=nil then
      network.request( jsonLink, "GET", worldScoreLoad )
    else
      getUserName()
    end
    
  elseif ( phase == "did" ) then
    audio.stop( 1 )
    timer.performWithDelay( 500, function()
      for i=1, 32 do
        audio.stop( i )
      end
    end )
    -- toJoystick()
    -- toSettings()
    
    -- composer.gotoScene( "game", {effect = "fade", time = 400} )
	end
end


function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
    q.saveSettings(set)
    composer.setVariable( "settings", set )
	elseif ( phase == "did" ) then
  end
end


function scene:destroy( event )

	local sceneGroup = self.view
  if onKeyEvent then Runtime:removeEventListener( "key", onKeyEvent ) end

end


scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
