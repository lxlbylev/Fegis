--width = 1080,
--height = 2340,
display.setStatusBar( display.HiddenStatusBar )

local composer = require( "composer" )
local scene = composer.newScene()

local option = composer.getVariable( "option" )


-- local admob = require( "plugin.admob" )
-- local function adListener( event )
--   print("ad ph",event.phase)
--   if ( event.phase == "init" ) then
--     -- interstitial, banner, rewardedVideo
--     admob.load( "interstitial", { adUnitId="ca-app-pub-4835333909481232/4703606429" } )
--   end
-- end

-- admob.init( adListener, { appId="ca-app-pub-4835333909481232~4551756700", testMode = true } )

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )
-- physics.setDrawMode( "hybrid" )

local names = {
lasership = {
{"Анимация появления","animIN"},
{"Анимация с лазером","animMOVE"},
{"Анимация исчезновения","animOUT"},
{"Выключать ли лазер?","laserOFF"},
{"Выключить?","OFF"},"Лазерные корабли"},

ship = {{"Размер","size"},
{"Скорость","speed"},
{"Спавн раз в","spawn"},"Корабли"},
aimship = {{"Размер","size"},
{"Скорость","speed"},
{"Длительность слежки","aimTime"},
{"Шанс появления %","random"},"Самонаводка"},
groupship = {{"Размер","size"},
{"Скорость","speed"},
{"Шанс появления %","random"},"Группа"},
hexship = {{"Частота выстрелов","fireTimeOut"},
{"Выключить?","OFF"},"Шестиугольник"},
player = {{"Ширина","width"}, {"Длина","height"}, "Игрок"},
sevship = {
{"Скорость тела","speed"},
{"Скорость частей","outspeed"},
{"Распадение через","startTime"},
{"Шанс появления %","random"}, "Соединенные"},
-- global = {{"Общий спавн рейт",10}}
}
-- local bgsound = audio.loadStream( "sounds/bgMusic8.mp3" )

math.randomseed( os.time() )

local q = require"base"

local left   = q.cx - q.fullw/2
local right  = q.cx + q.fullw/2
local top    = q.cy - q.fullh/2
local bottom = q.cy + q.fullh/2
local _W = q.cx*2
local _H = q.cy*2

local FbackConf
local Flaser
local Fship
local Faimship
local Fsevship

local Teditor = {}
local Tlasership = {}
local TBlasership = {}

local starsTable = {}


local onGL   = false
local onL    = false
local SpawnR = 450

local backGroup
local starsGroup
local mainGroup
local uiGroup

local LS = display.newGroup()
local S = display.newGroup()
local AS = display.newGroup()
local GS = display.newGroup()
local HS = display.newGroup()
local P = display.newGroup()
local SS = display.newGroup()

--[[function tableval_to_str ( v )
   if "string" == type( v ) then
      v = string.gsub( v, "\n", "\\n" )
      if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
         return "'" .. v .. "'"
      end
      return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
   end
   return "table" == type( v ) and tabletostring( v ) or tostring( v )
end

function tablekey_to_str ( k )
   if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
      return k
   end
   return "[" .. tableval_to_str( k ) .. "]"
end

function tabletostring( tbl )
   local result, done = {}, {}
   for k, v in ipairs( tbl ) do
      table.insert( result, tableval_to_str( v ) )
      done[ k ] = true
   end
   for k, v in pairs( tbl ) do
      if not done[ k ] then
         table.insert( result, tablekey_to_str( k ) .. "=" .. tableval_to_str( v ) )
      end
   end
   return "{" .. table.concat( result, "," ) .. "}"
end--]]

local function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end


local function gotoMenu()
  for i=1,3,1 do
    print("GO SC. MENU")
  end
  audio.fadeOut (50)
  audio.stop(1)
  continue=true
  composer.gotoScene( "menu" )
end


local Rotate=function (sx, sy, ax, ay)
  return (((math.atan2(sy - ay, sx - ax) / (math.pi / 180)) + 270) % 360) + 90
end

local height, width = 64, .8
local shape_enemy = {
  0, height*1.4,
  -height*width, 0,
  height*width, 0
}
height, width = nil, nil

local function createEnemy(x,y,r,c)
  local newAsteroid = display.newPolygon( mainGroup, x, y, shape_enemy )
  newAsteroid.yScale=.8
  newAsteroid.xScale=.7

  c = c and c or {1,.2,.2}
  newAsteroid:setFillColor( unpack(c) )
  newAsteroid.rotation=r+180
  newAsteroid.myName = "enemy"
  return newAsteroid
end

local function genXY()
  local x, y
  local whereFrom = math.random( 3 )
  if ( whereFrom == 1 ) then
    x = -60
    y = math.random(100, q.fullh-100)
  elseif ( whereFrom == 2 ) then
    x = math.random(q.fullw)
    y = -60
  elseif ( whereFrom == 3 ) then
    x = q.fullw + 60
    y = math.random(100, q.fullh-100)
  end
  return x,y
end

local function createAsteroid()
  local x, y = genXY()

  local newAsteroid = createEnemy(x,y,q.getAngle(x, y, q.cx, q.cy))--display.newPolygon( mainGroup, x, y, shape_enemy )
  local size = option.ship.size
  newAsteroid.yScale=.8*size
  newAsteroid.xScale=.7*size

  physics.addBody( newAsteroid, "dynamic", { box={halfWidth=30*size, halfHeight=30*size, x=0, y=-20*size}, isSensor=true } )
  local speed = option.ship.speed==0 and 1 or option.ship.speed 
  newAsteroid:setLinearVelocity( (q.cx-x)*speed, (q.cy-y)*speed )
  timer.performWithDelay( 2000, function() display.remove(newAsteroid) end )
end

local function close(now, need)--ищет куда ближе развернуться
  local zero = now%360
   
  local up = need-zero
  up = up<0 and up+360 or up

  local down = zero-need -- Z100 + N350 = Z100 + (360 - 350)
  down = down<0 and down+360 or down
  local exit
  if up<down then
    exit = now+up
  else
    exit = now-down
  end
  return exit 
end

local function createAimEnemy()
  -- local x, y = genXY()
  local x, y = q.cx, 0
  local c = {1,.2,.2}
  local enemy = display.newGroup()
  enemy.xScale = option.aimship.size
  enemy.yScale = option.aimship.size
  mainGroup:insert(enemy)
  enemy.myName="enemy"
  enemy.x=x enemy.y=y
  local a = createEnemy(0,-15,0, {unpack(c)})
  enemy:insert(a)
  a.xScale=.7 a.yScale=.8
  a = createEnemy(0,0,0, {c[1]*.5,c[2]*.5,c[3]*.5})
  enemy:insert(a)
  a.xScale=.7 a.yScale=.8
  enemy.needClear = false

  physics.addBody( enemy, { box={halfWidth=30*option.aimship.size, halfHeight=30*option.aimship.size}, isSensor=true } )
  local speed = option.aimship.speed*100
  local function changeDir(index)
    if index==0
    or not (enemy.x)
    then enemy.needClear = true return end

    local target = {}
    if index%2==0 then
      target.x = enemy.x - 100
      target.y = enemy.y + 100
    else
      target.x = enemy.x + 100
      target.y = enemy.y + 100
    end

    transition.to(enemy, {rotation = close(enemy.rotation,q.getAngle(enemy.x, enemy.y, target.x, target.y)), time=200})

    local x, y = (target.x-enemy.x), (target.y-enemy.y)
    local xs, ys
    if math.abs(y)<math.abs(x) then
      local soot = math.abs(y/x)
      xs, ys = speed*1, math.abs(speed*soot)
    else
      local soot = math.abs(x/y)
      xs, ys = math.abs(speed*soot), speed*1
    end
    if enemy.needClear==true then return end
    enemy:setLinearVelocity( x>0 and xs or -xs, y>0 and ys or -ys )
    index = index-1
    timer.performWithDelay( 100, function() changeDir(index) end )
  end
  changeDir(math.ceil(option.aimship.aimTime*10))
  timer.performWithDelay( math.ceil(option.aimship.aimTime*10)*100*2, function() display.remove(enemy) end )
end

local laserShipTable = {}
local function removeLaser()
  timer.cancel( "laser" )
  transition.cancel( "laser" )
  for i=1, #laserShipTable do
    if laserShipTable.numChildren~=nil then
      for j=1, laserShipTable.numChildren do
        display.remove(laserShipTable.numChildren[i])
      end
    end
    display.remove(laserShipTable[i])
    laserShipTable[i]=nil
  end
  onL=false
end
local function createLaser(color)
  if option.lasership.OFF==true then timer.performWithDelay(400, removeLaser) return end
  local color = {1,.2,.2}
  local randomY = q.fullh*.8

  local shipLwidth = 120

  local shipLheight = shipLwidth*2.5
  local shipLfirePos = shipLheight*0.5

  local ls, PRshipL1, PRshipL2

  local shipL1 = display.newGroup()
  mainGroup:insert(shipL1)
  local shipL2 = display.newGroup()
  mainGroup:insert(shipL2)

  local j=0
  local step3, OT

  -- if Delete then removeLaser() return end
  local function updBody()
    if ls==nil or ls.x==nil or ls.alpha==nil then
      removeLaser()
      return
    end
    physics.removeBody( ls )
    physics.addBody( ls, "static", {isSensor=true} )
  end
  local function upd(TR)
    if shipL1.x==nil then removeLaser() return end
    j=j+1
    if j%20==0 then updBody() end

    local x1, y1, x2, y2 = shipL1.x+55, shipL1.y-2, shipL2.x-55, shipL2.y-2

    local a, b = math.abs(x1-x2), math.abs(y1-y2)
    local c = math.sqrt(a*a+b*b)

    local c1, c2 = ((x2-x1)*.5)+x1, (math.abs(y2-y1)*.5)+math.min(y1, y2)
    OT = q.getAngle(x1,y1,x2,y2) + 90
    ls.x=c1
    ls.y=c2
    ls.width=c
    ls.rotation=OT

    if j==math.ceil(option.lasership.animMOVE*1000/20) and TR==true then step3() end
  end

  function step3()
    local r1x, r1y, r2x, r2y = --200, 100, q.fullw-200, 100
     math.random(-200, q.fullw+200), math.random(-q.fullh*2.5, -q.fullh*1.5),
     math.random(-200, q.fullw+200), math.random(-q.fullh*2.5, -q.fullh*1.5)

    local rTime = option.lasership.animOUT*1000
    transition.to(PRshipL1, { x=r1x, y=r1y+shipLfirePos, transition=easing.inOutCirc, time = rTime, tag="laser" } )
    transition.to(PRshipL2, { x=r2x, y=r2y+shipLfirePos, transition=easing.inOutCirc, time = rTime, tag="laser" } )

    transition.to(shipL1, {x=r1x, y =r1y, transition=easing.inOutCirc, time = rTime, tag="laser" } )
    transition.to(shipL2, {x=r2x, y =r2y, transition=easing.inOutCirc, time = rTime, tag="laser",
    onComplete = function()
      removeLaser()
    end})

    local offLaser = option.lasership.laserOFF

    if offLaser==true then
      display.remove(ls)
    else
      timer.performWithDelay( 20, function() upd(false) end, math.ceil(rTime/20), "laser")
    end
  end

  local function step2()
    local x1, y1, x2, y2 = shipL1.x+55, shipL1.y-2, shipL2.x-55, shipL2.y-2

    local a, b = math.abs(x1-x2), math.abs(y1-y2)
    local c = math.sqrt(a*a+b*b)

    local c1, c2 = ((x2-x1)*.5)+x1, (math.abs(y2-y1)*.5)+math.min(y1, y2)
    OT = q.getAngle(x1,y1,x2,y2) + 90

    ls = display.newRect( mainGroup, c1, c2, c, shipLwidth*(1/15) )
    ls.rotation=OT
    physics.addBody( ls, "static",{isSensor=true})
    ls.myName = "laser"
    laserShipTable[#laserShipTable+1]=ls
    ls:toBack()



    local r1x, r1y, r2x, r2y =
    math.random(100, q.cx-150),         math.random((q.fullh - randomY)*.5,  randomY+(q.fullh - randomY)*.5),
    math.random(q.cx+150, q.fullw-100), math.random((q.fullh - randomY)*.5, randomY+(q.fullh - randomY)*.5)

    local rTime = option.lasership.animMOVE*1000
    transition.to(PRshipL1, { x=r1x, y= r1y + shipLfirePos, time = rTime, tag="laser"} )
    transition.to(PRshipL2, { x=r2x, y= r2y + shipLfirePos, time = rTime, tag="laser"} )

    transition.to(shipL1, {x=r1x, y = r1y, time = rTime, tag="laser"} )
    transition.to(shipL2, {x=r2x, y = r2y, time = rTime, tag="laser"} )

    timer.performWithDelay( 20, function() upd(true) end, math.ceil(rTime/20), "laser")
  end


  local function step1()
    local shape_base = {
      0, -80*.8*.4*2,
      80*.8*.6*2, 0,
      0,  80*.8*.4*2,
      -125*2.1, 0
    }

    local shape_center = {
      0, -80*.8*.45,
      80*.8*.6, 0,
      0,  80*.8*.45,
      -125, 0
    }

    local shape_flank = {
      0, -80*.8*.45,
      0,  80*.8*.45,
      80*.8*.6, 0
    }

    local r, g, b = unpack( color )
    local colors =
    {
      {r*.6, g*.6, b*.6},
      {r*.8, g*.8, b*.8},
    }
    local calls = {
      group={shipL1, shipL2},
      emm = {}
    }
    for i=1, 2 do
      local em = display.newEmitter(q.emitters.laserShip)
      em.x = -math.random(120, 220)
      em.y = q.fullh*1.5 + shipLheight*0.5
      mainGroup:insert(em)
      laserShipTable[#laserShipTable+1] = em
      calls.emm[i] = em

      calls.group[i].x = em.x
      calls.group[i].y = q.fullh*1.5


      local part1 = display.newPolygon( calls.group[i], q.cx, q.cy, shape_flank )
      part1.x, part1.y, part1.rotation = -40+50, -38,75
      part1:setFillColor( unpack(colors[1]) )

      local part2 = display.newPolygon( calls.group[i], q.cx, q.cy, shape_flank )
      part2.x, part2.y, part2.rotation = -40+50, 38, -75
      part2:setFillColor( unpack(colors[1]) )

      local part3 = display.newPolygon( calls.group[i], q.cx, q.cy, shape_base )
      part3.x, part3.y, part3.rotation = -55+50, 0,0
      part3:setFillColor( unpack(colors[2]) )

      local part3 = display.newPolygon( calls.group[i], q.cx, q.cy, shape_center )
      part3.x, part3.y, part3.rotation = -10+50, 0, 0
      part3.alpha=.3

      calls.group[i].rotation=-90
      laserShipTable[#laserShipTable+1] = calls.group[i]
    end
    PRshipL1 = calls.emm[1]
    PRshipL2 = calls.emm[2]

    PRshipL2.x = q.fullw-PRshipL2.x
    shipL2.x = PRshipL2.x
    calls=nil

    local rTime = option.lasership.animIN*1000--math.random(1650, 2500)

    local sx1 = 80
    local sx2 = q.fullw-100
    local ry1, ry2 = math.random(-400, 400), math.random(-400, 400)
    transition.to(PRshipL1, {x=sx1,  y=q.cy+ry1+shipLfirePos, transition=easing.inOutCirc, time = rTime, tag="laser" } )

    transition.to(PRshipL2, {x=sx2,  y=q.cy+ry2+shipLfirePos, transition=easing.inOutCirc, time = rTime, tag="laser"  } )

    transition.to(shipL1,   {x=sx1,  y=q.cy+ry1,              transition=easing.inOutCirc, time = rTime, tag="laser"} )

    transition.to(shipL2,   {x=sx2,  y=q.cy+ry2,              transition=easing.inOutCirc, time = rTime, tag="laser",
    onComplete = function()
      step2()
    end} )
  end

  step1()
end


local starsTable = {}
local starIndex = 0
local function starInf()
  local locIndex = starIndex+1
  local a = math.random(600)
  return (locIndex),(#starsTable+1),(a),(a+100),(19500-a*25),("blink"..locIndex)
end
local function moveStar(star, d, number, name)
  starsTable[number]=star
  star.x = math.random(30, q.fullw-30)
  star.y = -60

  local move = transition.to(star, {y = q.fullh+60, time = d,
  onComplete = function()
    display.remove(star)
    starsTable[number]=nil
    star=nil
    transition.cancel(tostring(name))
    starIndex = starIndex - 1
  end} )
  d=nil
end
local function createStar()
  local locIndex, number, a, c, d, name = starInf()
  c=c*(1/12)

  local star = display.newRect(starsGroup, 0, 0, c, c) star.alpha=.5
  local r = math.random( 5,8 )*.1
  local g, b = r, 1

  star:setFillColor(r,g,b)
  moveStar(star, d, number, name)
  if c<50 then
    transition.blink(star,{time=(15500-a*25)*(1/3),transition.continuousLoop, tag=name})
  end
  a, c = nil, nil
end

local who=0
local Gship = function()
  ship = q.createPlayer({nil,0,1})
  ship.x=q.cx
  ship.y=300

  ship.xScale = option.player.width
  ship.yScale = option.player.height
  physics.addBody( ship, "staic", {isSensor=true, box = {halfWidth=30*option.player.width,halfHeight=40*option.player.height}} )

end
local function createSevEnemy()
  local cl = {1,.2,.2}
  local x, y = q.cx, -100
  local enemy = display.newGroup()
  mainGroup:insert(enemy)
  enemy.needClear=false
  enemy.myName="enemy"
  enemy.x=x enemy.y=y
  enemy.rotation=90
  physics.addBody( enemy, { box={halfWidth=30, halfHeight=30, x=0, y=0}, isSensor=true } )

  local a = createEnemy(0,0,0, {unpack(cl)})
  enemy:insert(a)
  a.xScale=.7 a.yScale=.8
  
  local b = createEnemy(-50,-5,-60, {cl[1]*.7,cl[2]*.7,cl[3]*.7})
  enemy:insert(b)
  b.xScale=.7*.5 b.yScale=.8*.5
  
  local c = createEnemy(50,-5,60, {cl[1]*.7,cl[2]*.7,cl[3]*.7})
  enemy:insert(c)
  c.xScale=.7*.5 c.yScale=.8*.5

  local d = createEnemy(0,65,180, {cl[1]*.7,cl[2]*.7,cl[3]*.7})
  enemy:insert(d)
  d.xScale=.7*.5 d.yScale=.8*.5

  local list = {b,c,d}
  local function start()
    if not enemy then return end
    for i=1, 3 do
      local a = list[i]
      if enemy.needClear==true then return end
      if not a.x then return end
      a.myName="enemy"
      timer.performWithDelay(100, function()
      physics.addBody( a, { box={halfWidth=20, halfHeight=20, x=0, y=0}, isSensor=true } )
      end)
      local ax, ay = a.x, a.y
      local c = math.sqrt(ax*ax+ay*ay)
      mainGroup:insert(a)
      a.rotation=a.rotation+enemy.rotation
      local rot = (enemy.rotation + q.getAngle(0, 0, ax, ay)-90)*math.pi/180
      a.x = enemy.x + math.cos(rot)*c
      a.y = enemy.y + math.sin(rot)*c

      local x, y  = q.getCathetsLenght(1000, a.rotation)
      local rot = (a.rotation-180)%360
      print(rot)
      if 90<rot and rot<270 then y= -y end
      if rot>=180 then x= -x end
      transition.to(a, {x=a.x+x,y=a.y-y,time=1500/option.sevship.outspeed, onComplete=function()
        list[i]=nil
        display.remove( a )
      end})
    end
  end
  
  local speed = option.sevship.speed*.1
  enemy.rotation = q.getAngle(x, y, q.cx, q.cy)
  enemy:setLinearVelocity( (q.cx-x)*speed, (q.cy-y)*speed )

  timer.performWithDelay( option.sevship.startTime*1000, start )
  timer.performWithDelay( option.sevship.startTime*1000+3000, function() display.remove(enemy) end )
end
-----------------------------------================================================================================================
local function inputListener( self, event)
  local i

  if(event.phase == "began" ) then
    i = self.i
  elseif(event.phase == "editing" ) then

  elseif(event.phase == "ended" ) then
    i = self.i
    local c = string.gsub(self.text, ",", ".")

    if who==1 then
      
      local param = names.lasership[i][2]
      if c=="" then c=option.lasership[param] end
      option.lasership[param] = c
    elseif who==2 then

      i = self.i
      local param = names.ship[i][2]
      if c=="" then c = option.ship[param]  end
      option.ship[param] = tonumber(c)
      timer.cancel(Fship)
      Fship = timer.performWithDelay( option.ship.spawn*1000, createAsteroid, 0)

    elseif who==3 then
      --if old=nil then old="" end
      -- i = self.i
      -- local param = names.player[i][2]
      -- if c=="" then c=option.player[param] end
      -- option.player[param] = tonumber(c)
      -- display.remove(ship) Gship()
      local param = names.sevship[i][2]
      if c=="" then c=option.sevship[param] end
      option.sevship[param] = c
      timer.cancel(Fsevship)
      Fsevship = timer.performWithDelay( 2000, createSevEnemy, 0)
    elseif who==4 then
      --if old=nil then old="" end
      i = self.i
      local param = names.aimship[i][2]
      if c=="" then c=option.aimship[param] end
      option.aimship[param] = tonumber(c)
      timer.cancel(Faimship)
      Faimship = timer.performWithDelay( option.ship.spawn*1000, createAimEnemy, 0)

    end
    TBlasership[i].fill={.5}
    transition.to(TBlasership[i].fill, {r=.15,g=.15,b=.15,time=500})
  end
end

local Glaser = function()
  if not onL then
    createLaser()
    onL=true
  end
end

local function onCollision( event )

	if ( event.phase == "began" ) then

		local obj1 = event.object1
		local obj2 = event.object2

		if ( obj1.myName == "enemy" and obj2.myName == "enemy" ) then
			display.remove( obj1 )
			display.remove( obj2 )
    end
  end
end
local s1, s2, s3, s4, s5, s6 = false, false, false, false, false, false

local ANIM_TIME = 300
local widthBOX = q.fullw*.7

local BasicSpawnPos = q.fullh-(120*4)
local BasicLeft = q.fullw-200
local BasicRight = 400
local SpisocRight = _W + 550
local SpisocLeft = _W-widthBOX*.5

local cx = q.cx
local cy = q.cy
local fullw = q.fullw
local fullh = q.fullh

local function genSpisok(name,konc,plus,dir)
  konc = konc and konc or 0
  dir = dir and dir or 1
  plus = plus and plus or 0
  for i=1, #names[name] +konc-1, 1 do
    TBlasership[i] = display.newRect(uiGroup, SpisocRight, BasicSpawnPos-(i+plus)*140*dir, widthBOX , 120)--тут -1
    transition.to(TBlasership[i],{x=SpisocLeft, time=ANIM_TIME})

    TBlasership[i]:setFillColor(0.1,0.1,0.1)
    TBlasership[i].alpha=.8

    Tlasership[i] = display.newText(uiGroup, names[name][i][1], TBlasership[i].x,TBlasership[i].y, native.systemFont, 40 )
    transition.to(Tlasership[i],{x=SpisocLeft, time=ANIM_TIME})

    Teditor[i] = native.newTextField(-350, TBlasership[i].y, q.fullw-widthBOX, 120)

    local param = names[name][i][2]
    local text = string.gsub(option[name][param], "%.", ",")
    Teditor[i].text = tostring(text)
    Teditor[i].inputType = "decimal"

    Teditor[i].isEditable = true
    Teditor[i].userInput = inputListener
    Teditor[i]:addEventListener( "userInput" )
    Teditor[i].font = native.newFont( native.systemFontBold, 90)
    Teditor[i].i = i
    transition.to(Teditor[i],{x=(q.fullw-widthBOX)*.5, time=ANIM_TIME})
  end
end
local function genGalka(name,i, pos)
  pos = pos and pos or i
  TBlasership[i] = display.newRect(backuiGroup, SpisocRight, BasicSpawnPos-pos*140, widthBOX , 120) TBlasership[i]:setFillColor(0.1,0.1,0.1)
  transition.to(TBlasership[i],{x=SpisocLeft, time=ANIM_TIME})

  Tlasership[i] = display.newText(backuiGroup, names[name][i][1], TBlasership[i].x,TBlasership[i].y, native.systemFont, 40 )
  transition.to(Tlasership[i],{x=SpisocLeft, time=ANIM_TIME})

  Teditor[i] = display.newRect( uiGroup, -350, TBlasership[i].y, (q.fullw-widthBOX), 120 )
  
  transition.to(Teditor[i],{x=(q.fullw-widthBOX)*.5, time=ANIM_TIME})
  local param = names[name][i][2]
  print(param,option[name][param])
  if option[name][param]==false then
    Teditor[i].fill={1,0,0}
  else
    Teditor[i].fill={0,.8,0}
  end

  local disIna = function()
    if option[name][param]==false then
      option[name][param]=true
      Teditor[i].fill={0,.8,0}
    else
      option[name][param]=false
      Teditor[i].fill={1,0,0}
    end
  end
  Teditor[i]:addEventListener( "tap", disIna)
end
local function hideSections()
  local pos = BasicLeft+BasicRight
  if who~=1 then transition.to(LS, {x=pos, time=ANIM_TIME}) end
  if who~=2 then transition.to(S, {x=pos, time=ANIM_TIME}) end
  -- if who~=3 then transition.to(P, {x=pos, time=ANIM_TIME}) end
  if who~=3 then transition.to(SS, {x=pos, time=ANIM_TIME}) end
  if who~=4 then transition.to(AS, {x=pos, time=ANIM_TIME}) end
  if who~=5 then transition.to(HS, {x=pos, time=ANIM_TIME}) end
end
local function showSections()
  if who~=1 then transition.to(LS, {x=BasicLeft, time=ANIM_TIME}) end
  if who~=2 then transition.to(S, {x=BasicLeft, time=ANIM_TIME}) end
  -- if who~=3 then transition.to(P, {x=BasicLeft, time=ANIM_TIME}) end
  if who~=3 then transition.to(SS, {x=BasicLeft, time=ANIM_TIME}) end
  if who~=4 then transition.to(AS, {x=BasicLeft, time=ANIM_TIME}) end
  if who~=5 then transition.to(HS, {x=BasicLeft, time=ANIM_TIME}) end
end
local function deleteOptions(j)
  for i=1, j, 1 do
    display.remove(TBlasership[i])
    display.remove(Tlasership[i])
    display.remove(Teditor[i])
    TBlasership[i] = nil
    Tlasership[i] = nil
    Teditor[i] = nil
  end
end
local function hideOptions(j)
  native.setKeyboardFocus( nil )
  for i=1, j, 1 do
    transition.to(TBlasership[i],{x = fullw + 550, time=ANIM_TIME})
    transition.to(Tlasership[i], {x = fullw + 550, time=ANIM_TIME})
    transition.to(Teditor[i],    {x = -350, time=ANIM_TIME})
    timer.performWithDelay( ANIM_TIME, function() deleteOptions(j) end)
  end
end

local function showLS()
  local function listLasership()
    who=1
    Flaser = timer.performWithDelay( 500, Glaser, 0 )

    hideSections()
    genSpisok("lasership",-2)
    genGalka("lasership",4)
    genGalka("lasership",5)
    timer.performWithDelay( ANIM_TIME, function() s1=true end)
  end
  local function RlistLasership()
    timer.cancel( Flaser )
    who=0
    hideOptions(#names.lasership-1)

    showSections()
    timer.performWithDelay( ANIM_TIME, function() s1=false end)
  end
  if not s1 and who == 0 then listLasership() elseif s1 and who == 1 then RlistLasership() end
end

local function showS()
  local function listShip()
    who=2

    Fship = timer.performWithDelay( option.ship.spawn*1000, createAsteroid, 0)

    hideSections()
    genSpisok("ship",0,-1)
    timer.performWithDelay( ANIM_TIME, function() s2=true end)
  end
  local function RlistShip()
    timer.cancel( Fship )
    who=0
    hideOptions(#names.ship-1)
    showSections()
    timer.performWithDelay( ANIM_TIME, function() s2=false end)
  end
  if not s2 and who == 0 then listShip() elseif s2 and who==2 then RlistShip() end
end

local function showSS()
  local function listAimship()
    who=3
    Fsevship = timer.performWithDelay( 2000, createSevEnemy, 0)
    hideSections()
    genSpisok("sevship",0,-2)
    timer.performWithDelay( ANIM_TIME, function() s3=true end)
  end
  local function RlistAimship()
    timer.cancel( Fsevship )
    who=0
    hideOptions(#names.sevship-1)
    showSections()

    timer.performWithDelay( ANIM_TIME, function() s3=false end)
  end
  if not s3 and who == 0 then listAimship() elseif s3 and who==3 then RlistAimship() end
end

local function showAS()
  local function listAimship()
    who=4
    createAimEnemy()
    Faimship = timer.performWithDelay( option.ship.spawn*1000, createAimEnemy, 0)
    hideSections()
    genSpisok("aimship",0,-3)
    timer.performWithDelay( ANIM_TIME, function() s4=true end)
  end
  local function RlistAimship()
    timer.cancel( Faimship )
    who=0
    hideOptions(#names.aimship-1)
    showSections()

    timer.performWithDelay( ANIM_TIME, function() s4=false end)
  end
  if not s4 and who == 0 then listAimship() elseif s4 and who==4 then RlistAimship() end
end

local function showHS()
  local function listHexship()
    who=5

    hideSections()
    genSpisok("hexship",-1,-1)
    genGalka("hexship",2,-1)

    timer.performWithDelay( ANIM_TIME, function() s5=true end)
  end
  local function RlistHexship()
    who=0
    hideOptions(#names.hexship-1)
    showSections()
    timer.performWithDelay( ANIM_TIME, function() s5=false end)
  end
  if not s5 and who == 0 then listHexship() elseif s5 and who==5 then RlistHexship() end
end


local function SR ()
	if onGL==false then
		gameLoopTimer = timer.performWithDelay( SpawnR, gameLoop, 1 )
		onGL=true
	end
end

function scene:create( event )

  composer.setVariable( "cheat", true )

  local sceneGroup = self.view
  physics.pause()

  backGroup = display.newGroup()
  sceneGroup:insert( backGroup )

  local bg = display.newRect(backGroup, q.cx,q.cy,q.fullw,q.fullh)
  bg.fill={type = "gradient", color1 = { 55/255, 0, 101/255 }, color2 = { 25/255, 21/255, 65/255 }, direction = -math.random(-360,360)}

  starsGroup = display.newGroup()
  backGroup:insert(starsGroup)

  mainGroup = display.newGroup()
  sceneGroup:insert( mainGroup )

  backuiGroup = display.newGroup()
  sceneGroup:insert( backuiGroup )

  uiGroup = display.newGroup()
  sceneGroup:insert( uiGroup )

  local exitIM = display.newImageRect( uiGroup, "img/fireicon.png", 100, 140)
  exitIM.anchorX=1
  exitIM.anchorY=0
  exitIM.x=20
  exitIM.y=20
  exitIM.rotation=-90

  backuiGroup:insert( LS )
  LS.x, LS.y = BasicLeft, BasicSpawnPos
  local Blasership = display.newRect(LS, 0, 0, BasicRight, 120)
  Blasership:setFillColor(0.15,0.15,0.15)
  Blasership.alpha=.8
  local labelLS = display.newText( LS, names.lasership[#names.lasership], 0, 0, native.systemFont, 40 )

  backuiGroup:insert( S )
  S.x, S.y = BasicLeft, BasicSpawnPos+140
  local Bship = display.newRect(S, 0, 0, BasicRight, 120)
  Bship:setFillColor(0.15,0.15,0.15)
  Bship.alpha=.8
  local labelS  = display.newText( S, names.ship[#names.ship], 0, 0, native.systemFont, 40 )

  -- backuiGroup:insert( P )
  -- P.x, P.y = BasicLeft, BasicSpawnPos+140*2
  -- local Bplayer = display.newRect(P, 0, 0, BasicRight, 120)
  -- Bplayer:setFillColor(0.15,0.15,0.15)
  -- local labelP  = display.newText( P, names.player[#names.player], 0, 0, native.systemFont, 40 )

  backuiGroup:insert( SS )
  SS.x, SS.y = BasicLeft, BasicSpawnPos+140*2
  local Bsevship = display.newRect(SS, 0, 0, BasicRight, 120)
  Bsevship:setFillColor(0.15,0.15,0.15)
  Bsevship.alpha=.8
  local labelSS  = display.newText( SS, names.sevship[#names.sevship], 0, 0, native.systemFont, 40 )

  backuiGroup:insert( AS )
  AS.x, AS.y = BasicLeft, BasicSpawnPos+140*3
  local Baimship = display.newRect(AS, 0, 0, BasicRight, 120)
  Baimship:setFillColor(0.15,0.15,0.15)
  Baimship.alpha=.8
  local labelAS  = display.newText( AS, names.aimship[#names.aimship], 0, 0, native.systemFont, 40 )

  backuiGroup:insert( HS )
  HS.x, HS.y = BasicLeft, BasicSpawnPos-140*1
  local Bhexship = display.newRect(HS, 0, 0, BasicRight, 120)
  Bhexship:setFillColor(0.15,0.15,0.15)
  Bhexship.alpha=.8
  local labelHS  = display.newText( HS, names.hexship[#names.hexship], 0, 0, native.systemFont, 40 )

  exitIM:addEventListener("tap", gotoMenu)

  FbackConf = timer.performWithDelay( 100, createStar, 0 )
end



function scene:show( event )

  local sceneGroup = self.view
  local phase = event.phase
  if ( phase == "will" ) then
    option = composer.getVariable( "option" )
    iui = 0
    timer.resume( FbackConf )

  elseif ( phase == "did" ) then

    physics.start()
    Runtime:addEventListener( "collision", onCollision )

    LS:addEventListener("tap", showLS)
    S:addEventListener("tap", showS)
    -- P:addEventListener("tap", showP)
    SS:addEventListener("tap", showSS)
    AS:addEventListener("tap", showAS)
    HS:addEventListener("tap", showHS)
    
    -- timer.performWithDelay( 1000, function()
    --   if ( admob.isLoaded( "interstitial" ) ) then
    --     admob.show( "interstitial" )
    --   end
    -- end )

  end
end




function scene:hide( event )
  local sceneGroup = self.view
  local phase = event.phase

  if ( phase == "will" ) then
    composer.setVariable( "option", option )
      --timer.cancel(FbackConf)
    for i=1, #Teditor, 1 do
      display.remove(Teditor[i])
      Teditor[i]=nil
    end
  elseif ( phase == "did" ) then

    removeLaser()
    for i=#starsTable,1,-1 do
      display.remove(starsTable[i])
      starsTable[i]=nil
    end
    for i=starsGroup.numChildren, 1, -1 do
      starsGroup[i]:removeSelf()
    end
    for i=#laserShipTable, 1, -1 do
      display.remove(laserShipTable[i])
      laserShipTable[i]=nil
    end

    timer.pause( FbackConf )
    Runtime:removeEventListener( "collision", onCollision )

    LS:removeEventListener("tap", showLS)
    S:removeEventListener("tap", showS)
    -- P:removeEventListener("tap", showP)
    SS:removeEventListener("tap", showSS)
    AS:removeEventListener("tap", showAS)
    HS:removeEventListener("tap", showHS)


    if s1==true then showLS() end
    if s2==true then showS() end
    if s3==true then showSS() end
    if s4==true then showAS() end
    if s5==true then showHS() end
  end
end
function scene:destroy( event )

	local sceneGroup = self.view


end

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )


return scene
