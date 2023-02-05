--[[
main-file
local composer = require( "composer" )
display.setStatusBar( display.HiddenStatusBar )
math.randomseed( os.time() )
composer.gotoScene( "menu" )
--]]
local composer = require( "composer" )

local scene = composer.newScene()

local backGroup, mainGroup, lootGroup, enemyGroup, bulletGroup, moveUiGroup, uiGroup, gameUiGroup, levelUpGroup, pickUpGroup, diedGroup

local q = require"base"

local physics = require"physics"
physics.start(true)
physics.setGravity( 0, 0 )
-- physics.setDrawMode( "hybrid" )

local nowScene = "game"

local factory = require("controller.virtual_controller_factory")
local controller = factory:newController()

local js1
local set
local cheater
local function setupController(displayGroup)
  local diff = cheater and 150 or 0
  local js1Properties = {
    nToCRatio = 0.5,  
    radius = 150, 
    left = diff,
    top = 0,
    width = q.fullw-diff,
    height = q.fullh,
    -- x = q.fullw - (210 + 60), 
    -- y = q.fullh - 170 - 70, 
    restingXValue = 0, 
    restingYValue = 0, 
    rangeX = 200, 
    rangeY = 200
  }

  local js1Name = "js1"
  js1 = controller:addJoystick(js1Name, js1Properties)

  controller:displayController(displayGroup)
end

local sounds = {
  back = audio.loadStream( "sounds/nag.mp3" ),
  
  pew = audio.loadSound( "sounds/pew.wav" ),
  enemydie = audio.loadSound( "sounds/enemydie2.wav" ),
  hurt = audio.loadSound( "sounds/hurt.wav" ),
  die = audio.loadSound( "sounds/die.wav" ),
  pickup = audio.loadSound( "sounds/orb.wav" ),
  -- levelUp = audio.loadSound( "sounds/levelup.wav" ),
  meteor = audio.loadSound( "sounds/meteor.wav" ),
}


local gameValues = {
  mp = {
    gain = {
      base = 1, multi = 1, plus = 0
    }
  },
  player = {
    hp = {
      amount = 100,
      base = 100, multi = 1, plus = 0,
    },
    mp = {
      amount = 0,
      base = 140, multi = 1, plus = 14*4,
    },

    dmg = {
      base = 1, multi = 1, plus = 0
    },
    speed = {
      base = 195-40, multi = 1, plus = 45+40
    },
    bulletSpeed = {
      base = 300, multi = 1, plus = 0
    },
    pickZone = {
      base = 100, multi = 1, plus = 0
    },
    hpRegenPerSec = {
      base = .5, multi = 1, plus = 0
    },
    mpRegenPerSec = {
      base = 0, multi = 1, plus = 0
    }
  },
  magicBalls = {
    dmg = {
      base = 150, multi = 1, plus = 0
    }
  },
  electricZone = {
    dmg = {
      base = 60, multi = 1, plus = 0
    },
    radius = {
      base = 200, multi = 1, plus = 0
    },
  },
  meteor = {
    dmg = {
      base = 100, multi = 1, plus = -20
    },
    radius = {
      base = 50, multi = 1, plus = 0
    },
    count = {
      base = 3, multi = 1, plus = 0
    }
  },
  enemy = {
    spawnRate = {
      base = 700, multi = 1, plus = 0
    },
    hp = {
      base = 150, multi = 1, plus = 0
    },
    dmg = {
      base = 20, multi = 1, plus = 0
    },
    speed = {
      base = 45, multi = 1, plus = 0
    }
  },
}

local function findMas(str)
  local mas = {}
  for v in str:gmatch("%w+") do
    mas[#mas+1] = v
    -- print(#mas,v)
  end
  return gameValues[mas[1]][mas[2]]
end
local function getValue(str)
  local info = findMas(str)
  return info.base * info.multi + info.plus
end
local function setMulti(str,val)
  local info = findMas(str)
  print(str)
  print("undo",info.multi)
  info.multi = info.multi + val
  print("now",info.multi)
end
local function setPlus(str,val)
  local info = findMas(str)
  info.plus = info.plus + val
end

local function getAmount(str)
  local info = findMas(str)
  return info.amount
end
local function setAmount(str,val)
  local info = findMas(str)
  info.amount = val
end

local tri_shape = {0,-80, 40,0, -40,0}
local colors = {
  black = q.CL"323235",
  neon = q.CL"36d8d4",
  blackneon = q.CL"48b7b1",
  gold = q.CL"d6a938",
  darkgold = q.CL"af8935",
  violet = q.CL"ab38d6",
  darkviolet = q.CL"7d3d9b",
  red = q.CL"dd2a49",
}

local hpBar
local hpImmortalBar
local mpBar

local inPlayTime = 0
local levelUpCounter = 0


local immortal = false
local damageKD = 500

local enemysTable = {}
local lootTable = {}


local function setHp(hp)
  local maxHp = getValue("player.hp")
  if hp<0 then hp = 0 end
  if maxHp<hp then hp = maxHp end

  setAmount("player.hp",hp)

  local hpProcent = hp / maxHp
  hpBar.height = hpProcent * (q.fullh-30)
end
local function regenHp()
  local toHP = getAmount("player.hp") + getValue("player.hpRegenPerSec")
  local maxHp = getValue("player.hp")
  -- print("REGEN HP TO",toHP)
  if toHP>=maxHp then
    toHP = maxHp
    if q.timer.isEnabled("regen") then
      -- print("Off regen")
      q.timer.off("regen")
    end
  end
  setHp(toHP)
end

local playerGroup
local enemysTarget
local function changeDir(enemy)
  if 
  -- index==0 or 
  not (enemy.x and playerGroup.y)
  -- or (math.abs(enemy.x-playerGroup.x)<100 and math.abs(enemy.y-playerGroup.y)<100)
  or PlayerDied
  then enemy.needClear = true return end

  -- transition.to(enemy, {rotation = close(enemy.rotation,q.getAngle(enemy.x, enemy.y, playerGroup.x, playerGroup.y)), time=200})
  local speed = enemy.speed
  local x, y = (enemysTarget.x-enemy.x), (enemysTarget.y-enemy.y)
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
  enemy.rotation = q.getAngle(enemy.x, enemy.y, playerGroup.x, playerGroup.y)
  -- index = index-1
  -- timer.performWithDelay( 100, function() changeDir(index) end )
  timer.performWithDelay( 100, function() changeDir(enemy) end )
end

local createOrb, orbTypes
local enemyDieSpawnOrb = false
local function removeEnemy(enemy, orbSpawn)
  local enemyI
  if type( enemy )=="number" then enemyI = enemy enemy = enemysTable[enemyI] else enemyI = enemy.i end
  if enemy.needClear then return end
  if orbSpawn and math.random(3)==1 then
    local enemyInTable = enemysTable[enemyI] or enemy
    local x, y = enemyInTable.x, enemyInTable.y
    timer.performWithDelay(1, function()
      -- createOrb( x, y, math.random(#orbTypes))
      createOrb( x, y, math.random(3))
    end)
  end
  enemy.needClear=true
  enemy.inCollision=false
  -- print("Removing", enemy.i, " #enemysTable "..#enemysTable)
  table.remove(enemysTable, enemyI)
  for i=enemyI, #enemysTable do
    enemysTable[i].i = enemysTable[i].i - 1
  end
  -- print("Removed", enemy.i, " #enemysTable "..#enemysTable)
  display.remove(enemy)
end
local function rectEnemy(group,x,y,w,h,c)
  local rectA = display.newRect( group, x, y, w, h )
  rectA.fill = {0,0,0,0}
  rectA:setStrokeColor( unpack( c ) )
  rectA.strokeWidth = 3

  local rect = display.newRect( group, x, y, w, h )
  rect.startX, rect.startY = x, y
  -- rect.xScale, rect.yScale = 1.4, 1.4
  rect.fill = {0,0,0,0}
  c[4] = .5
  rect:setStrokeColor( unpack( c ) )
  rect.strokeWidth = 3 * rect.xScale
  group.border[#group.border+1] = rect
  return rectA
end

local function createRedEnemy(x, y)
  local group = display.newGroup()
  enemyGroup:insert( group )
  group.x = x
  group.y = y
  group.hp = 2.0*getValue("enemy.hp")
  group.damage = 2*getValue("enemy.dmg")
  group.damageKD = false
  group.inCollision = false
  group.xScale = 1.1
  group.yScale = 1.1
  
  group.speed = .8 * getValue("enemy.speed")
  
  local img = display.newImageRect( group, "img/bug5.png", 140, 140 )
  -- if set.style==0 then
  --   local qwa = display.newRect( group, 0, 0, 70.4, 70.4 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, 0, 0, 36.9, 36.9 )
  --   qwa.fill = colors.red
  -- else
  --   group.border = {}
  --   rectEnemy(group, 0, 0, 70.4, 70.4, {1,0,0})

  --   local qwa = display.newRect( group, 0, 0, 36.9, 36.9 )
  --   qwa.fill = {1,0,0}
  -- end

  physics.addBody( group, { box={halfWidth=70.4*.5-3, halfHeight=70.4*.5-3} } )
  group.isFixedRotation = true
  group.myName = "enemy"
  
  local i = #enemysTable+1
  group.i = i
  enemysTable[i] = group
  
  group.remove = removeEnemy
  changeDir(group)
end

local function createBigEnemy(x, y)
  local group = display.newGroup()
  enemyGroup:insert( group )
  group.x = x
  group.y = y
  group.hp = 1.5*getValue("enemy.hp")
  group.damage = 1.75*getValue("enemy.dmg")
  group.damageKD = false
  group.inCollision = false
  group.xScale = 1.1
  group.yScale = 1.1
  
  group.speed = .9 * getValue("enemy.speed")

  local img = display.newImageRect( group, "img/bug3.png", 160, 160 )
  -- if set.style==0 then
  --   local qwa = display.newRect( group, -6.84, -43.335, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, 18.374, -25.18, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, 28.3, -1.5, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, 7, 11.3, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, 3.737, -11.3, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, -14.27, 4.19, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, -28.3, -14.577, 32, 32 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, -17.473, -23.17, 32, 32 )
  --   qwa.fill = colors.black
  -- else
  --   group.border = {}
  --   rectEnemy(group, -6.84, -43.335, 32, 32, {1,.7,0})
  --   rectEnemy(group, 18.374, -25.18, 32, 32, {1,.7,0})
  --   rectEnemy(group, 28.3, -1.5, 32, 32, {1,.7,0})
  --   rectEnemy(group, 7, 11.3, 32, 32, {1,.7,0})
  --   rectEnemy(group, 3.737, -11.3, 32, 32, {1,.7,0})
  --   rectEnemy(group, -14.27, 4.19, 32, 32, {1,.7,0})
  --   rectEnemy(group, -28.3, -14.577, 32, 32, {1,.7,0})
  --   rectEnemy(group, -17.473, -23.17, 32, 32, {1,.7,0})
  -- end
  
  physics.addBody( group, { box={halfWidth=88.62*.5, halfHeight=86.67*.5, x=0, y=-15} } )
  group.isFixedRotation = true
  group.myName = "enemy"
  
  local i = #enemysTable+1
  group.i = i
  enemysTable[i] = group
  
  group.remove = removeEnemy
  changeDir(group)
end

local function createNormalEnemy(x,y)
  local group = display.newGroup()
  enemyGroup:insert( group )
  group.x = x
  group.y = y
  group.hp = 1.2*getValue("enemy.hp")
  group.damage = 1.5*getValue("enemy.dmg")
  group.damageKD = false
  group.inCollision = false
  
  group.speed = 1 * getValue("enemy.speed")

  local img = display.newImageRect( group, "img/bug4.png", 130, 130 )
  -- if set.style==0 then
  --   local qwa = display.newRect( group, 0, 0, 42, 42 )
  --   qwa.fill = colors.black
  -- else
  --   group.border = {}
  --   rectEnemy(group, 0, 0, 42, 42, {1,1,0})
  -- end

  physics.addBody( group, { box={halfWidth=42*.5, halfHeight=55*.5} } )
  group.isFixedRotation = true
  group.myName = "enemy"
  
  local i = #enemysTable+1
  group.i = i
  enemysTable[i] = group
  
  group.remove = removeEnemy
  changeDir(group)
end

local function createSmallEnemy(x,y)
  local group = display.newGroup()
  enemyGroup:insert( group )
  group.x = x
  group.y = y
  group.hp = getValue("enemy.hp")
  group.damage = getValue("enemy.dmg")
  group.damageKD = false
  group.inCollision = false
  
  group.speed = 1.2 * getValue("enemy.speed")

  local img = display.newImageRect( group, "img/bug.png", 120, 120 )
  -- if set.style==0 then
  --   local qwa = display.newRect( group, (0-23)*.55, 0+20*.55, 51*.55, 51*.55 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, (10-23)*.55, (-40+20)*.55, 51*.55, 51*.55 )
  --   qwa.fill = colors.black
  --   local qwa = display.newRect( group, (42-23)*.55, (-11+20)*.55, 51*.55, 51*.55 )
  --   qwa.fill = colors.black
  -- else
  --   group.border = {}
  --   rectEnemy(group, (0-23)*.55, 0+20*.55, 51*.55, 51*.55, {0,1,0})
  --   rectEnemy(group, (10-23)*.55, (-40+20)*.55, 51*.55, 51*.55, {0,1,0})
  --   rectEnemy(group, (42-23)*.55, (-11+20)*.55, 51*.55, 51*.55, {0,1,0})
  -- end

  physics.addBody( group, { box={halfWidth=42*.55, halfHeight=55*.55} } )
  group.isFixedRotation = true
  group.myName = "enemy"
  
  local i = #enemysTable+1
  group.i = i
  enemysTable[i] = group
  
  group.remove = removeEnemy
  changeDir(group)
end


local function animEnemy( enemy )
  if enemy.needClear then return end
  enemy.frame = (enemy.frame)%3 + 1
  for i=1, #enemy.image do
    enemy.image[i].alpha = 0
  end
  enemy.image[enemy.frame].alpha = 1
  timer.performWithDelay( 100, 
  function()
    animEnemy(enemy)
  end)

end
-- createPashalkaEnemy(x,y)

local enemyNowTypes = 1
local listEnemys = {
  createSmallEnemy,
  createNormalEnemy,
  createBigEnemy,
  createRedEnemy,
}




orbTypes = {
  {15, colors.neon, "orb"},
  {30, colors.gold, "orb"},
  {15*5, colors.violet, "orb"},
  {25, colors.red, "healOrb"},
  {5000, {.95,.95,.95}, "immortalOrb"},
}
local function removeOrb(orb)
  -- if type( orb )=="number" then orb = lootTable[orb] end
  -- print("Removing", orb.i, " #lootTable "..#lootTable)
  timer.cancel( orb.autoRemove )
  table.remove(lootTable, orb.i)
  for i=orb.i, #lootTable do
    lootTable[i].i = lootTable[i].i - 1
  end
  -- print("Removed", orb.i, " #lootTable "..#lootTable)
  display.remove(orb)
end
local function onTimeRemove(orb)

  if orb.x==nil then return end
    orb.autoRemove = timer.performWithDelay( 5000, function()
      if orb.x==nil then return end
      -- print(orb.i.."# cheking")
      if playerGroup.x+q.cx+200<orb.x or playerGroup.x-q.cx-200>orb.x
      or playerGroup.y+q.cy+200<orb.y or playerGroup.y-q.cy-200>orb.y then
        orb:remove()
      else
        onTimeRemove(orb)
      end
    end )

end
function createOrb(x,y, type)
  local group = display.newGroup()
  lootGroup:insert( group )
  group.x = x
  group.y = y
  group.amount = orbTypes[type][1]
  
  if type==1 then
    local qwa = display.newImageRect( group, "img/leaves2.png", 75, 75 )
  elseif type==2 then
    local qwa = display.newImageRect( group, "img/leaves2.png", 110, 110 )
  elseif type==3 then
    local qwa = display.newImageRect( group, "img/leaves3.png", 100, 100 )
  else
    local qwa = display.newRect( group, 0, 0, 22.4, 22.4 )
    qwa.fill = colors.black
    local qwa = display.newRect( group, 0, 0, 16.85, 16.85 )
    qwa.fill = orbTypes[type][2]  
  end
  -- elseif type==4 then
  -- local qwa = display.newRect( group, 0, 0, 22.4, 22.4 )
  -- qwa.fill = colors.black
  -- local qwa = display.newRect( group, 0, 0, 16.85, 16.85 )
  -- qwa.fill = orbTypes[type][2]
  
  physics.addBody( group,"static", { isSensor=true} )
  group.myName = orbTypes[type][3]
  
  local i = #lootTable+1
  group.i = i
  group.remove = removeOrb
  onTimeRemove(group)
  
  lootTable[i] = group
  print("spawned "..i)
end

local function removeChest(chest)
  if type( chest )=="number" then chest = lootTable[chest] end
  -- print("Removing", orb.i, " #lootTable "..#lootTable)
  table.remove(lootTable, chest.i)
  for i=chest.i, #lootTable do
    lootTable[i].i = lootTable[i].i - 1
  end
  -- print("Removed", orb.i, " #lootTable "..#lootTable)
  display.remove(chest)
end
local function createChest(x,y)
  local group = display.newGroup()
  lootGroup:insert( group )
  group.x = x
  group.y = y
  
  local qwa = display.newRect( group, 0, 0, 55.8, 55.8 )
  qwa.fill = colors.black
  local qwa = display.newRect( group, 0, -12, 55.8, 8 )
  qwa.fill = colors.blackneon
  local qwa = display.newRect( group, 0, -10.85, 11.63, 15.95 )
  qwa.fill = colors.neon
  
  physics.addBody( group,"static", { isSensor=true} )
  group.myName = "chest"
  
  local i = #lootTable+1
  group.i = i
  lootTable[i] = group
  group.remove = removeChest
end



local maxLengthFire = q.getHypLenght(q.fullw,q.fullh)*2
local function getNearestEnemy()
  local onTop = {lenght, i}
  local delete = {}
  local deleteI = 1
  for i=1, #enemysTable do
    local thisEnemy = enemysTable[i]
    if not thisEnemy.needClear then
      local lenght = q.getHypLenght((playerGroup.x-thisEnemy.x),(playerGroup.y-thisEnemy.y))
      -- print(i)
      -- print(lenght)
      if lenght > maxLengthFire then
        -- print(lenght.."  "..maxLength)
        delete[deleteI] = thisEnemy
        deleteI = deleteI + 1
      elseif onTop.lenght==nil or onTop.lenght>lenght then
        onTop.lenght = lenght
        onTop.i = i
      end
    end
  end
  for i=1, #delete do
    removeEnemy(delete[i])
  end
  return (onTop.i~=nil and enemysTable[onTop.i] )
end

local maxLengthLoot = 800
local maxLengthEnemy = 450

local function mapCleaner()
  local delete = {}
  local deleteI = 1
  for i=1, #enemysTable do
    local thisEnemy = enemysTable[i]
    local x, y, ex, ey = playerGroup.x, playerGroup.y, thisEnemy.x, thisEnemy.y
    if x+q.cx+maxLengthEnemy<ex or x-q.cx-maxLengthEnemy>ex
    or y+q.cy+maxLengthEnemy<ey or y-q.cy-maxLengthEnemy>ey then
      delete[deleteI] = thisEnemy
      deleteI = deleteI + 1
    end
  end
  for i=1, #lootTable do
    local thisLoot = lootTable[i]
    local x, y, lx, ly = playerGroup.x, playerGroup.y, thisLoot.x, thisLoot.y
    if x+q.cx+maxLengthLoot<lx or x-q.cx-maxLengthLoot>lx
    or y+q.cy+maxLengthLoot<ly or y-q.cy-maxLengthLoot>ly then
      delete[deleteI] = thisLoot
      deleteI = deleteI + 1
    end
  end
  for i=1, #delete do
    delete[i]:remove()
  end
end

local possivePowers
local function simpleAttack()
  local target = getNearestEnemy()
  if not target then return end
  audio.play(sounds.pew )
  -- local bullet = display.newRect( bulletGroup, playerGroup.x, playerGroup.y, 8, 44 )
  local bullet = display.newImageRect( bulletGroup, "img/igolka.png", 8, 44 )
  bullet.x, bullet.y = playerGroup.x, playerGroup.y
  physics.addBody( bullet, { isSensor=true } )
  local r = q.getAngle(target.x, target.y, playerGroup.x, playerGroup.y)
  bullet.rotation = r
  local x, y = q.getSpeed( getValue("player.bulletSpeed"), r )
  bullet:setLinearVelocity( x, y )
  bullet.myName = "bullet"
  bullet.damage = possivePowers[1].options[possivePowers[1].level].dmg

  timer.performWithDelay(10000, function()
    display.remove(bullet)
  end)
end

local moveFunc
local function circleMove(body)
  body.i = body.i%360 + 1
  local cx, cy = playerGroup.x, playerGroup.y
  local x, y = q.getCathetsLenghtNoAbs(150,body.i)
  body.x, body.y = cx+x, cy+y
end
local function circleMoveLenght(body)
  body.i = body.i%360 + 1
  body.lenght = body.lenght%250 + .5
  local cx, cy = playerGroup.x, playerGroup.y
  local x, y = q.getCathetsLenghtNoAbs(body.lenght,body.i)
  body.x, body.y = cx+x, cy+y
end
moveFunc = circleMove
local function orbitalAttack()
  for i=1, #playerGroup.orbital.list do
    moveFunc(playerGroup.orbital.list[i])
  end
end
local function addOrbital()
  local crc = display.newCircle( playerGroup.orbital, 0, 0, 20 )
  crc.myName = "orbital"
  crc.i = 0
  crc.lenght = 150
  crc.fill = q.CL"e63946"
  crc.alpha = .5
  physics.addBody( crc, "static", {isSensor = true} )
  
  playerGroup.orbital.list[#playerGroup.orbital.list+1] = crc
  for i=1, #playerGroup.orbital.list do
    playerGroup.orbital.list[i].i = math.floor(360/#playerGroup.orbital.list*i)
    playerGroup.orbital.list[i].lenght = math.floor(150/#playerGroup.orbital.list*i)
  end
end
local function removeOrbital()
  display.remove( playerGroup.orbital.list[#playerGroup.orbital.list] )
  playerGroup.orbital.list[#playerGroup.orbital.list] = nil
  for i=1, #playerGroup.orbital.list do
    playerGroup.orbital.list[i].i = math.floor(360/#playerGroup.orbital.list*i)
    playerGroup.orbital.list[i].lenght = math.floor(150/#playerGroup.orbital.list*i)
  end
end


local function meteor(x, y)
  local radius = getValue("meteor.radius")
  
  local group = display.newGroup()
  mainGroup:insert( group )
  group.x, group.y = x-200, y-300
  
  local toScale = (50/radius)
  group.xScale = toScale*2
  group.yScale = toScale*2
  group.alpha = 0
  group.damage = getValue("meteor.dmg")
  group.myName = "meteor"

  local a = display.newCircle( group, 0, 0, radius )

  transition.to( group, {alpha = 1, x=x, y=y, xScale = toScale*.7, yScale = toScale*.7, time = 1300, transition = easing.inCubic, tag = "meteor", onComplete = function()
    if group.x then
      audio.play(sounds.meteor)
      timer.performWithDelay(1, function()
        if group.x and group and group.fill then
          physics.addBody( group, "static", {radius = radius, isSensor = true})
        end
      end)
      transition.to( group, {xScale = 1, yScale = 1, alpha = 0, time = 200, tag = "meteor", onComplete = function()
        display.remove(group)
      end} )
    end
  end } )
end

local function startMeteor()
  local dlina = math.random(200, q.cx-100)
  local x, y = q.getCathetsLenghtNoAbs(dlina, math.random(360))
  meteor(playerGroup.x+x+math.random(-100,100),playerGroup.y+y+math.random(-100,100))
  timer.performWithDelay( 300, function()
    timer.performWithDelay( math.random(50,100), function()
      meteor(playerGroup.x+x+math.random(-100,100),playerGroup.y+y+math.random(-100,100))
    end, 1, "meteor")
  end, math.floor(getValue("meteor.count")-1), "meteor" )
end

local function setElectricZone( plusRadius, plusDamage )
  setMulti("electricZone.radius",plusRadius)
  local radius = getValue("electricZone.radius")

  setMulti("electricZone.dmg",plusDamage)
  local damage = getValue("electricZone.dmg")


  display.remove(playerGroup.zone)
  local zone = display.newCircle( playerGroup, 0, 0, radius )
  zone:toBack()
  zone.alpha = .3
  zone.myName = "electricZone"
  zone.damage = damage
  playerGroup.zone = zone
  playerGroup.bodyElements[3] = { radius=radius, isSensor=true }

  physics.removeBody( playerGroup )
  physics.addBody( playerGroup, unpack(playerGroup.bodyElements) )
  playerGroup.isFixedRotation = true
end

local function setPickZone( plusRadius)
  setMulti("player.pickZone",plusRadius)
  local radius = getValue("player.pickZone")
  playerGroup.bodyElements[2] = { radius=radius, isSensor=true }

  physics.removeBody( playerGroup )
  physics.addBody( playerGroup, unpack(playerGroup.bodyElements) )
  playerGroup.isFixedRotation = true
end

local function hidePower()
  playerGroup.myBody[3].alpha = 0
  playerGroup.copy = q.createPlayer( moveUiGroup, playerGroup.x, playerGroup.y )
  playerGroup.copy.alpha = .5
  
  local speed = 2000
  local a, b = q.getCathetsLenghtNoAbs(speed,math.random(1,360))
  transition.to(playerGroup.copy, {x = playerGroup.x+a, y = playerGroup.y+b,time=10000, onComplete = function()
    enemysTarget = playerGroup
    display.remove(playerGroup.copy)
    playerGroup.myBody[3].alpha = 1
  end})

  enemysTarget = playerGroup.copy
end


local function multiMaxHp(multiMax)
  local hp, oldMax = getAmount"player.hp", getValue"player.hp"
  local percent = hp / oldMax
  
  setMulti("player.hp",multiMax)
  
  local newMax = getValue"player.hp"
  setAmount("player.hp", math.floor(newMax * percent))
end

local getPower
possivePowers = {
  {
    func = simpleAttack, 
    level = 1,
    label = "Удар природы",
    name = "strike",
    timerName = "simpleMagic",
    img = "img/simple.png",
    options = {
      { time = 600, dmg = 100},
      { time = 570, dmg = 120, text = "Урон увеличится на +20%\nКд уменьшиться на -5%"},
      { dmg = 140, text = "Урон увеличится на +20%"},
      { dmg = 160, text = "Урон увеличится на +20%"},
      { time = 510, dmg = 200, text = "Урон увеличится на +40%\nКд уменьшиться на -10%"},
      -- unlimited = { time = 510, dmg = 230, text = "Урон увеличится на +30%\n"},
    },
  },
  {
    func = orbitalAttack, 
    level = 0,
    label = "Лесной пожар",
    name = "balls",
    timerName = "orbitalRotation",
    img = "img/simple.png",
    options = {
      { text = "Огненные шары будут крутиться вокруг древа", init = function()

        addOrbital()
        if q.timer.isEnabled(orbitalRotation)==nil then
          q.timer.add("orbitalRotation", 2500/360, orbitalAttack, 0)
          q.timer.group.add("gameTimers","orbitalRotation")
        end
      end},
      { text = "+1 шар\nУрон увеличится на 10%", init = function()
        setMulti("magicBalls.dmg",.1)
        addOrbital()
      end },
      { text = "+1 шар\nУрон уменьшиться на 10%", init = function()
        setMulti("magicBalls.dmg",.1)
        addOrbital()
      end },
      { text = "Урон увеличится на +30%", init = function()
        setMulti("magicBalls.dmg",.3)
      end },
      { time = 2500/(360*1.2), text = "Скорость +20%\nУрон увеличится на +30%", init = function()
        setMulti("magicBalls.dmg",.3  )
      end },
      -- 2500/(360*x) = 2500/360 * 2500/x
      { time = 2500/(360*1.4), text = "Скорость +20%\nУрон уменьшиться на -10%\n+3 шара", init = function()
        setMulti("magicBalls.dmg",-.1)
        addOrbital()
        addOrbital()
        addOrbital()
      end },
      unlimited = {text = "+1 шар\nУрон увеличится на +5%\nСкорость +15%", init = function()
        setMulti("magicBalls.dmg",.5)
        addOrbital()
        local thisPower = getPower("balls").options
        thisPower[#thisPower].time = thisPower[#thisPower].time * (.75)
        q.timer.change("orbitalRotation", {time=thisPower[#thisPower].time})
      end },
    },
  },
  {
    level = 0,
    label = "Острые корни",
    name = "shockzone",
    img = "img/zone.png",
    options = {
      { text = "Острые корни будут ранить врагов", init = function()
        setElectricZone(0, 0)
      end},
      { text = "Урон увеличится на +30%\nУвеличение территории + 15%", init = function()
        setElectricZone(.15, .3)
      end},
      { text = "Урон увеличится на +20%\nУвеличение территории + 10%", init = function() 
        setElectricZone(.1, .2)
      end},
      { text = "Урон увеличится на +20%\nУвеличение территории + 5%", init = function() 
        setElectricZone(.05, .2)
      end},
      { text = "Урон увеличится на +30%\nУвеличение территории + 5%", init = function() 
        setElectricZone(.05, .3)
      end},
      unlimited = {text = "Урон увеличится на +30%\nУвеличение территории + 5%", init = function() 
        setElectricZone(.05, .3)
      end },
    },
  },
  {
    level = 0,
    label = "Хил",
    name = "healspeed",
    img = "img/zone.png",
    options = {
      { text = "+5% скорости регена", init = function()
        setMulti("player.hpRegenPerSec",.05)
      end},
      { text = "+5% скорости регена", init = function()
        setMulti("player.hpRegenPerSec",.05)
      end},
      { text = "+5% скорости регена", init = function()
        setMulti("player.hpRegenPerSec",.05)
      end},
      { text = "+5% скорости регена", init = function()
        setMulti("player.hpRegenPerSec",.05)
      end},
      unlimited = {text = "+5% скорости регена", init = function()
        setMulti("player.hpRegenPerSec",.05)
      end},
    },
  },
  {
    level = 0,
    label = "Скорость",
    name = "speedAndZone",
    img = "img/zone.png",
    options = {
      { text = "+15% дальности подъема вещей\n+5% скорости движения", init = function()
        setPickZone( .15 )
        setMulti("player.speed",.05)
      end},
      { text = "+15% дальности подъема вещей\n+3% скорости движения", init = function()
        setPickZone( .15 )
        setMulti("player.speed",.03)
      end},
      { text = "+15% дальности подъема вещей\n+3% скорости движения", init = function()
        setPickZone( .15 )
        setMulti("player.speed",.03)
      end},
      { text = "+15% дальности подъема вещей\n+3% скорости движения", init = function()
        setPickZone( .15 )
        setMulti("player.speed",.03)
      end},
      unlimited = {text = "+10% дальности подъема вещей\n+3% скорости движения", init = function()
        setPickZone( .10 )
        setMulti("player.speed",.03)
      end},
    },
  },
  {
    level = 0,
    label = "Макс. хп",
    name = "maxHp",
    img = "img/zone.png",
    options = {
      { text = "+15% макс. здоровья", init = function()
        multiMaxHp(.15)
      end},
      { text = "+15% макс. здоровья", init = function()
        multiMaxHp(.15)
      end},
      { text = "+15% макс. здоровья", init = function()
        multiMaxHp(.15)
      end},
      { text = "+15% макс. здоровья", init = function()
        multiMaxHp(.15)
      end},
      unlimited = {text = "+20% макс. здоровья", init = function()
        multiMaxHp(.2)
      end},
    },
  },
  {
    func = startMeteor, 
    level = 0,
    label = "Град",
    name = "meteor",
    timerName = "meteorMagic",
    img = "img/simple.png",
    options = {
      { time = 1500, text = "Вызывает падение града", init = function()
        startMeteor()
        q.timer.add("meteorMagic", 1500, startMeteor, 0)
        q.timer.group.add("gameTimers","meteorMagic")
      end},
      { time = 3500, text = "Урон увеличится на +20%\n+10% радиус\n+3 града", init = function()
        setMulti("meteor.dmg",.2)
        setMulti("meteor.radius",.1)
        setPlus("meteor.count",3)
      end},
      { text = "Урон увеличится на +30%\n+10% радиус\n+1 град", init = function()
        setMulti("meteor.dmg",.3)
        setMulti("meteor.radius",.1)
        setPlus("meteor.count",1)
      end},
      { text = "Урон увеличится на +40%\n+20% радиус\n+1 град", init = function()
        setMulti("meteor.dmg",.4)
        setMulti("meteor.radius",.2)
        setPlus("meteor.count",1)
      end},
      { text = "Урон увеличится на +50%\n+30% радиус\n+1 град", init = function()
        setMulti("meteor.dmg",.5)
        setMulti("meteor.radius",.3)
        setPlus("meteor.count",1)
      end},
    },
  },
}

getPower = function( name )
  local param
  for i=1, #possivePowers do
    if possivePowers[i].name == name then
      param = possivePowers[i]
      break
    end
  end
  return param
end

local function moveScreen()
  mainGroup.x= -playerGroup.x+q.cx
  mainGroup.y= -playerGroup.y+q.cy
end

local isDevice = (system.getInfo("environment") == "device")


local function setImmortal(time)
  print("SET IMMORTAL")
  
  transition.cancel( "immortal" )
  timer.cancel( "immortal" )
  
  immortal=true
  hpImmortalBar.height = q.fullh - 30
  timer.performWithDelay( time, function()

    immortal=false
    transition.cancel( "immortal" )
    hpImmortalBar.height = 0
  end, 1, "immortal" )
  transition.to( hpImmortalBar, {height = 0, time = time, tag = "immortal"} )
end

local function resumeGame()
  nowScene = "game"
  physics.start()
  setupController(uiGroup)
  q.timer.group.on("gameTimers")
  timer.resume( "meteor" )
  transition.resume( "meteor" )
  gameUiGroup.alpha = 1


  if immortal then
    timer.resume("immortal")
    transition.resume( "immortal" )
  end

end
local function pauseGame(needImmortal)
  physics.pause()
  q.timer.group.off("gameTimers")
  timer.cancel( "damageToPlayer" )
  timer.pause( "meteor" )
  transition.pause( "meteor" )
  controller:removeJoystick("js1")
  gameUiGroup.alpha = 0

  if needImmortal then
    setImmortal(2500)
    timer.pause("immortal")
    transition.pause( "immortal" )
  end
  
end

local finscoreLabel
local function showDie()
  nowScene = "died"
  pauseGame()
  audio.play(sounds.die )
  local score = q.loadScores()
  score = {math.max(inPlayTime,score[1])}
  if cheater==false then
    q.saveScores(score)
  end
  diedGroup.alpha = 1

  local sec = tostring(inPlayTime%60)
  if #sec==1 then sec = "0"..sec end
  finscoreLabel.text = math.floor(inPlayTime/60)..":"..sec
end



local function getDamage(enemy)
  if enemy.damageKD==false and immortal==false then
    enemy.damageKD=true
    
    local toHP = getAmount("player.hp") - enemy.damage
    if toHP<=0 then 
      setHp(0)
      playerGroup.alpha = 0
      enemy.inCollision=false
      showDie()
      return false
    end
    audio.play(sounds.hurt )
    setHp(toHP)

    if not q.timer.isEnabled("regen") then
      q.timer.on("regen")
    end

    
    
    timer.performWithDelay(damageKD, 
      function()
        enemy.damageKD=false 
        if enemy.inCollision then
          getDamage(enemy)
        end
      end, 1, "damageToPlayer"
    )
  end
end
local function spawnEnemys()
  if playerGroup.x==nil then return end
  for i=1, 4 do
    local x,y = playerGroup.x, playerGroup.y
    local whereFrom = math.random(4)
    if whereFrom==1 then
      x, y = x+math.random(-q.cx,q.cx), y-100-q.cy-math.random( 100 )
    elseif whereFrom==2 then
      -- x, y = q.fullw+100, math.random(q.fullh)
      x, y = x+q.cx+100+math.random( 100 ), y+math.random(-q.cy,q.cy)
    elseif whereFrom==3 then
      -- x, y = math.random(q.fullw), q.fullh+100
      x, y = x+math.random(-q.cx,q.cx), y+q.cy+100+math.random( 100 )
    else
      x, y = x-q.cx-100-math.random( 100 ), y+math.random(-q.cy,q.cy)
    end
    
    -- if inPlayTime>5*60 and math.random(3000)==1 then
    --   createPashalkaEnemy(x,y)
    -- else
      listEnemys[math.random(1,enemyNowTypes)](x,y)
    -- end
  
  end
end

local function spawnOrbs()
  for i=1, 2 do
    local whereFrom = math.random(4)
    local x,y = playerGroup.x, playerGroup.y
    if whereFrom==1 then
      x, y = x+math.random(-q.cx,q.cx), y-q.cy-30-math.random(100) - 200
    elseif whereFrom==2 then
      x, y = x+q.cx+30+math.random(100) + 200, y+math.random(-q.cy,q.cy)
    elseif whereFrom==3 then
      x, y = x+math.random(-q.cx,q.cx), y+q.cy+30+math.random(100) + 200
    else
      x, y = x-q.cx-30-math.random(100) - 200, y+math.random(-q.cy,q.cy)
    end

    local rareOrbI = math.random( 40 )

    if rareOrbI <= 4 then -- (1-4) 4/40 10%
      createOrb(x,y,2)
    elseif rareOrbI <= 6 then -- (5-6) 2/40 5%
      createOrb(x,y,3)
    elseif rareOrbI <= 7 then -- (7) 1/40 2.5%
      createOrb(x,y,4)
    elseif rareOrbI <= 8 then -- (8) 1/40 2.5%
      createOrb(x,y,5)
    elseif math.random(120)<=1 then -- <1%
      createChest(x,y)
    else -- 79%
      createOrb(x,y,1)
    end
    
    -- rareOrbI = (rareOrbI)%20 + 1
  end
end

local inventory = {
  "",
  "",
  "",
  "",
  "",
  "",
  "",
  "",
}
local shaderUp
local unlimitedLevelUp = false
local artefacts = {
  {
    name = "fat",
    label = "Искупление чревоугодия",
    disc = "+400% макс. хп\nХилл здоровья\nРегенерация убивает тебя",
    img = "",
    noimg = "ИЧ",
    init = function()
      multiMaxHp(5)
      local maxHp = getValue("player.hp")*5
      setHp(maxHp)
      setMulti("player.hpRegenPerSec",-2*gameValues.player.hpRegenPerSec.multi)
    end,
    remove = function()
      multiMaxHp(-5)
      setMulti("player.hpRegenPerSec",-2*gameValues.player.hpRegenPerSec.multi)
    end
  },
  {
    name = "read",
    label = "Здравоумие",
    disc = "+20% получаемого опыта",
    img = "",
    noimg = "З",
    init = function()
      setMulti("mp.gain",.2)
    end,
    remove = function()
      setMulti("mp.gain",-.2)
    end,
  },
  {
    name = "web",
    label = "Спутаность",
    disc = "-10% скорость противников",
    img = "",
    noimg = "С",
    init = function()
      setMulti("enemy.speed",-.1)
    end,
    remove = function()
      setMulti("enemy.speed",.1)
    end,
  },
  {
    name = "boots",
    label = "Кеды",
    disc = "+10% скорость",
    img = "",
    noimg = "К",
    init = function()
      setMulti("player.speed",.1)
    end,
    remove = function()
      setMulti("player.speed",-.1)
    end,
  },
  {
    name = "bron",
    label = "Кольчуга",
    disc = "-3% скорость\n+30 макс. хп",
    img = "",
    noimg = "КЧ",
    init = function()
      setMulti("player.speed",-.03)
      setMulti("player.hp",.3)
    end,
    remove = function()
      setMulti("player.speed",.03)
      setMulti("player.hp",-.3)
    end,
  },
  {
    name = "heart",
    label = "Хрустальное сердце",
    disc = "+5% регена",
    img = "",
    noimg = "ХС",
    init = function()
      setMulti("player.hpRegenPerSec",.5)
    end,
    remove = function()
      setMulti("player.hpRegenPerSec",-.5)
    end,
  },
  {
    name = "bulspeed",
    label = "C-ID",
    disc = "+15% скорости маг. снарядов",
    img = "",
    noimg = "ID",
    init = function()
      setMulti("player.bulletSpeed",.15)
    end,
    remove = function()
      setMulti("player.bulletSpeed",-.15)
    end,
  },
  {
    name = "zav",
    label = "Искупление зависти",
    disc = "-5% макс. хп\n-5% регена\n-20% хп противников",
    img = "",
    noimg = "ИЗ",
    init = function()
      setMulti("player.hp",-.05)
      setMulti("player.hpRegenPerSec",-.05)
      setMulti("enemy.hp",-.2)
    end,
    remove = function()
      setMulti("player.hp",.05)
      setMulti("player.hpRegenPerSec",.05)
      setMulti("enemy.hp",.2)
    end,
  },
  {
    name = "badtv",
    label = "Старый телевизор",
    disc = "Плохо показывает..\n-5% скорость противников\n+15% наносимого урона",
    img = "",
    noimg = "СТ",
    init = function()
      display.remove(shaderUp)
      shaderUp = display.newRect(uiGroup, q.cx,q.cy, q.fullw, q.fullh)
      shaderUp:setFillColor( 0 )
      shaderUp.fill.effect = "filter.custom.lines"
      setMulti("player.dmg",.15)
      setMulti("enemy.speed",-.05)
    end,
    remove = function()
      display.remove(shaderUp)
      setMulti("player.dmg",-.15)
      setMulti("enemy.speed",.05)
    end,
  },
  {
    name = "cheat",
    label = "Цепочка мага",
    disc = "+5 магических шаров\nИзменяет траекторию полёта",
    img = "",
    noimg = "ЦП",
    init = function()
      moveFunc = circleMoveLenght
      local power = getPower("balls")
      if power.level==0 then
        power.options[1].init()
      else
        addOrbital()
      end
      for i=1, 4 do
        addOrbital()
      end
    end,
    remove = function()
      for i=1, 5 do
        removeOrbital()
      end
      local power = getPower("balls")
      if power.level==0 then
        q.timer.group.removeElement("gameTimers","orbitalRotation")
        q.timer.remove("orbitalRotation")
      end
      moveFunc = circleMove
    end,
  },
  {
    name = "moneymany",
    label = "Рог изобилия",
    disc = "После смерти врага остается\nорб",
    img = "",
    noimg = "РИ",
    init = function()
      enemyDieSpawnOrb = true
    end,
    remove = function()
      enemyDieSpawnOrb = false
    end,
  },
  {
    name = "unlimiter",
    label = "Древняя рукопись",
    disc = "Описаны способы обойти\nограничения улучшений",
    img = "",
    noimg = "ДР",
    init = function()
      unlimitedLevelUp = true
    end,
    remove = function()
      unlimitedLevelUp = false
    end,
  },
  {
    name = "metla",
    label = "Метла",
    disc = "+15% скорости\n-15% дальности подъема вещей",
    img = "",
    noimg = "М",
    init = function()
      setMulti("player.speed",.15)
      setPickZone( -.15 )
    end,
    remove = function()
      setMulti("player.speed",-.15)
      setPickZone( .15 )
    end,
  },
  {
    name = "king",
    label = "Метка короля",
    disc = "Нет эффектов",
    img = "",
    noimg = "МК",
    init = function()
      playerGroup.myBody[2].alpha = 1
    end,
    remove = function()
      playerGroup.myBody[2].alpha = 0
    end,
  },
  {
    name = "copy",
    label = "Зеркало",
    disc = "Создает копию отвлекающу\nврагов",
    img = "",
    noimg = "ЗК",
    init = function()
      hidePower()
      q.timer.add("hidePlayer", 30*1000, hidePower, 0)
      q.timer.group.add("gameTimers","hidePlayer")
    end,
    remove = function()
      q.timer.group.removeElement("gameTimers","hidePlayer")
      q.timer.remove("hidePlayer")
    end,
  },
}
local thispickUpGroup
local function closeAtr()
  -- nowScene = "game"
  display.remove(thispickUpGroup)
  resumeGame()
  pickUpGroup.alpha = 0
  hpBar.alpha = 1
end
local function pickAtr(id)
  nowScene = "artefact"
  pauseGame(true)
  pickUpGroup.alpha = 1
  hpBar.alpha = 0

  thispickUpGroup = display.newGroup()
  pickUpGroup:insert( thispickUpGroup )

  -- levelupLabel.anchorY = 0

  local backArt = display.newRect( thispickUpGroup, q.cx, 170, q.fullw-100, 470 )
  backArt.anchorY = 0
  if set.style==0 then
    backArt.fill = { 0, .4}
  else
    backArt.fill = { 1, .4}
  end

  local backLogo = display.newRect( thispickUpGroup, q.cx, backArt.y + 50, 250, 250 )
  backLogo.anchorY = 0
  backLogo.fill = { 0, 0, 0, .3}

  local logo = display.newText( {
    parent = thispickUpGroup,
    text = "<"..artefacts[id].noimg..">",
    x = backLogo.x,
    y = backLogo.y + backLogo.height*.5,
    font = "r_r.ttf",
    fontSize = 65,
  } )

  local artNameLabel = display.newText( {
    parent = thispickUpGroup,
    text = artefacts[id].label,
    x = backArt.x,
    y = backLogo.y + backLogo.height + 40,
    font = "r_r.ttf",
    fontSize = 50,
  } )
  artNameLabel.anchorY = 0

  local artDiscLabel = display.newText( {
    parent = thispickUpGroup,
    text = artefacts[id].disc,
    x = backArt.x,
    y = artNameLabel.y + artNameLabel.height + 30,
    font = "r_r.ttf",
    fontSize = 43,
  } )
  artDiscLabel.anchorY = 0
    
  local backHeight = backArt.height 
  backArt.height = backArt.height + artDiscLabel.height


  local skipButton = display.newGroup()
  thispickUpGroup:insert(skipButton)
  skipButton.x, skipButton.y = q.cx, q.fullh-150
  
  local skipPickup = display.newRect( skipButton, 0, 0, 350, 120 )
  skipPickup.fill = { 0, 0, 0, .2}

  local skipPickupLabel = display.newText( {
    parent = skipButton,
    text = "Не брать",
    x = 0,
    y = 0,
    font = "r_r.ttf",
    fontSize = 50,
  } )
  skipButton:addEventListener( "tap", function()
    closeAtr(thispickUpGroup)
  end )


  local space = 5
  local size = (q.fullw-space*8)/4

  local zeroy = (q.fullh-100-60) - (size + space)*2 - 80 
  local inChange = false
  local inFreePosTake = false
  local selected = 0
  local cancelButton, acceptButton
  local cells = {}
  for x=1, 4 do
    for y=1, 2 do
      local backItem = display.newRect( thispickUpGroup, (q.fullw/4)*(x-0.5), zeroy + (size+space*2) * (y-1), size, size )
      backItem.anchorY = 0
      if set.style==0 then
        backItem.fill = { 0 }
        backItem.alpha = .3
      else
        backItem.fill = { 1 }
        backItem.alpha = .3
      end
      local itemNum = x + (y-1) * 4
      cells[itemNum] = backItem

      if inventory[itemNum]=="" then
        backItem:addEventListener( "tap", function()
          if inChange then
            cells[selected].alpha = .3
            display.remove(acceptButton)
            display.remove(cancelButton)
            skipButton.alpha = 1
            logo.text = "<"..artefacts[id].noimg..">"
            artNameLabel.text = artefacts[id].label
            artDiscLabel.text = artefacts[id].disc
            backArt.height = backHeight + artDiscLabel.height
            inChange = false
          elseif inFreePosTake then
            cells[selected].alpha = .3
            display.remove(acceptButton)
            if itemNum==selected then
              selected = 0
              inFreePosTake = false
              skipButton.x = q.cx
              return
            end
          end
          inFreePosTake = true
          selected = itemNum
          backItem.alpha = .6
          skipButton.x = q.cx*1.5
          acceptButton = display.newGroup()
          thispickUpGroup:insert(acceptButton)
          acceptButton.x, acceptButton.y = q.cx*.5, q.fullh-150
          
          local acceptPickup = display.newRect( acceptButton, 0, 0, 350, 120 )
          acceptPickup.fill = { 0, 0, 0, .2}

          local acceptPickupLabel = display.newText( {
            parent = acceptButton,
            text = "Взять",
            x = 0,
            y = 0,
            font = "r_r.ttf",
            fontSize = 50,
          } )

          acceptButton:addEventListener( "tap", function()
            inventory[itemNum] = artefacts[id].name
            artefacts[id].init()
            closeAtr(thispickUpGroup)
          end )
        end )
      else
        local inventoryNum
        for i=1, #artefacts do
          if artefacts[i].name==inventory[itemNum] then
            inventoryNum = i
            break
          end
        end
        local invartNameLabel = display.newText( {
          parent = thispickUpGroup,
          text = "<"..artefacts[inventoryNum].noimg..">",
          x = backItem.x,
          y = backItem.y + backItem.height*.5,
          font = "r_r.ttf",
          fontSize = 48,
        } )
        backItem:addEventListener( "tap", function()
          if inChange then
            cells[selected].alpha = .3
            display.remove(acceptButton)
            display.remove(cancelButton)
            if itemNum==selected then
              selected = 0
              inChange = false
              skipButton.x = q.cx
              skipButton.alpha = 1
              logo.text = "<"..artefacts[id].noimg..">"
              artNameLabel.text = artefacts[id].label
              artDiscLabel.text = artefacts[id].disc
              backArt.height = backHeight + artDiscLabel.height
              return
            end
          elseif inFreePosTake then
            cells[selected].alpha = .3
            display.remove(acceptButton)
            inFreePosTake = false
          end
          inChange = true
          selected = itemNum
          backItem.alpha = .6
          skipButton.alpha = 0
          logo.text = "<"..artefacts[inventoryNum].noimg..">"
          artNameLabel.text = artefacts[inventoryNum].label
          artDiscLabel.text = artefacts[inventoryNum].disc
          backArt.height = backHeight + artDiscLabel.height

          acceptButton = display.newGroup()
          thispickUpGroup:insert(acceptButton)
          acceptButton.x, acceptButton.y = q.cx*.5, q.fullh-150
          
          local skipPickup = display.newRect( acceptButton, 0, 0, 350, 120 )
          skipPickup.fill = { 0, 0, 0, .2}

          local skipPickupLabel = display.newText( {
            parent = acceptButton,
            text = "Заменить",
            x = 0,
            y = 0,
            font = "r_r.ttf",
            fontSize = 50,
          } )

          acceptButton:addEventListener( "tap", function()
            inventory[itemNum] = artefacts[id].name
            artefacts[inventoryNum].remove()
            artefacts[id].init()
            closeAtr(thispickUpGroup)
          end )

          cancelButton = display.newGroup()
          thispickUpGroup:insert(cancelButton)
          cancelButton.x, cancelButton.y = q.cx*1.5, q.fullh-150
          
          local skipPickup = display.newRect( cancelButton, 0, 0, 350, 120 )
          skipPickup.fill = { 0, 0, 0, .2}

          local skipPickupLabel = display.newText( {
            parent = cancelButton,
            text = "Отмена",
            x = 0,
            y = 0,
            font = "r_r.ttf",
            fontSize = 50,
          } )
          cancelButton:addEventListener( "tap", function()
            cells[selected].alpha = .3
            selected = 0
            inChange = false
            skipButton.x = q.cx
            skipButton.alpha = 1
            logo.text = "<"..artefacts[id].noimg..">"
            artNameLabel.text = artefacts[id].label
            artDiscLabel.text = artefacts[id].disc
            backArt.height = backHeight + artDiscLabel.height
            display.remove(acceptButton)
            display.remove(cancelButton)
          end )
        end )


      end
    end
  end

end

local thisLevelUp, enemyLevelUp
local timerLabel

cheater = false
local cheatFunctions = {
  orb = function(event)
    createOrb(playerGroup.x,playerGroup.y-100,event.target.i)
  end,
  chest = function()
    createChest(playerGroup.x,playerGroup.y-100)
  end,
  skip1min = function()
    inPlayTime = inPlayTime + 60
    enemyLevelUp()
    enemyLevelUp()
    local sec = tostring(inPlayTime%60)
    if #sec==1 then sec = "0"..sec end
    timerLabel.text = math.floor(inPlayTime/60)..":"..sec
  end,
  zoomIn = function()
    mainGroup.xScale = mainGroup.xScale*1.5
    mainGroup.yScale = mainGroup.yScale*1.5
  end,
  zoomOut = function()
    mainGroup.xScale = mainGroup.xScale*(1/1.5)
    mainGroup.yScale = mainGroup.yScale*(1/1.5)
  end,
}
local function drawCheat()
  Runtime:removeEventListener( "lateUpdate", moveScreen )
  moveScreen = function()
    mainGroup.x= (-playerGroup.x*(mainGroup.xScale)+q.cx)
    mainGroup.y= (-playerGroup.y*(mainGroup.yScale)+q.cy)
  end
  Runtime:addEventListener( "lateUpdate", moveScreen )
  -- system.activate( "multitouch" )
  for i=1, 5 do
    local button = display.newRect(gameUiGroup, 30, q.fullh-130*(i),100,100)
    button.anchorX=0
    button.fill={0,.7}
    button.i=i
    button:addEventListener( "tap", cheatFunctions.orb )
    local label = display.newText( gameUiGroup, "orb"..i, button.x+button.width*.5, button.y, "r_r.ttf", 35 )
  end
  local button = display.newRect(gameUiGroup, 30, q.fullh-130*(6),100,100)
  button.anchorX=0
  button.fill={0,.7}
  button.i=i
  button:addEventListener( "tap", cheatFunctions.chest )
  local label = display.newText( gameUiGroup, "chest", button.x+button.width*.5, button.y, "r_r.ttf", 33 )
    
  local button = display.newRect(gameUiGroup, 30, q.fullh-130*(7),100,100)
  button.anchorX=0
  button.fill={0,.7}
  button.i=i
  button:addEventListener( "tap", cheatFunctions.skip1min )
  local label = display.newText( gameUiGroup, "+1m", button.x+button.width*.5, button.y, "r_r.ttf", 33 )

  local button = display.newRect(gameUiGroup, q.fullw, q.fullh-130,100,100)
  button.anchorX=1
  button.fill={0,.7}
  button.i=i
  button:addEventListener( "tap", cheatFunctions.zoomIn )
  local label = display.newText( gameUiGroup, "+", button.x-button.width*.5, button.y, "r_r.ttf", 50 )

  local button = display.newRect(gameUiGroup, q.fullw-130, q.fullh-130,100,100)
  button.anchorX=1
  button.fill={0,.7}
  button.i=i
  button:addEventListener( "tap", cheatFunctions.zoomOut )
  local label = display.newText( gameUiGroup, "-", button.x-button.width*.5, button.y, "r_r.ttf", 50 )
end
local function cheatListener(event)
  -- print("eveY",event.y)
  if event.phase=="began" then
    display.currentStage:setFocus( event.target )
  elseif event.phase=="moved" and event.y<100 then
    cheater=true
    drawCheat()
    event.target:removeEventListener("touch", cheatListener)
    print("cheater!")
  elseif ( "ended" == phase or "cancelled" == phase ) then
    display.currentStage:setFocus( nil )
  end
end
local countLevelUpLabel
local function levelUp(count)
  nowScene = "levelup"
  pauseGame(true)
  -- gameUiGroup.alpha = 0

  levelUpGroup.alpha = 1

  local canChoose = {}
  for i=1, #possivePowers do
    if possivePowers[i].level~=#possivePowers[i].options or (unlimitedLevelUp and possivePowers[i].options.unlimited~=nil) then
      canChoose[#canChoose+1] = i
    end
  end

  thisLevelUp = display.newGroup()
  levelUpGroup:insert(thisLevelUp)

  for i=1, 3 do
    if #canChoose==0 then break end
    local j = math.random(1,#canChoose)
    local thisPower = canChoose[j]
    table.remove(canChoose,j)
    local y = 360 + (i-1)*320


    local back = display.newRect( thisLevelUp, q.cx, y, q.fullw, 230 )
    back.fill = { 0, 0, 0, .4}

    local logoHeight = back.height*.7
    local spaceX = back.height*.1
    local spaceY = back.height*.1

    local backLogo = display.newRect( thisLevelUp, back.x-back.width*.5+spaceX, back.y-back.height*.5+spaceY, logoHeight, logoHeight*.7 )
    backLogo.fill = { 0, 0, 0, .3}
    backLogo.anchorX = 0
    backLogo.anchorY = 0

    local logo = display.newRect( thisLevelUp, backLogo.x, backLogo.y, backLogo.width, backLogo.height )
    logo.anchorX = 0
    logo.anchorY = 0
    logo.fill = {
      type = "image",
      filename = "img/powers/"..(possivePowers[thisPower].name)..".png"
    }

    local backLVL = display.newRect( thisLevelUp, backLogo.x, backLogo.y+backLogo.height, logoHeight, logoHeight*.3 )
    backLVL.anchorX = 0
    backLVL.anchorY = 0
    backLVL.fill = { 0, 0, 0, .5}

    local xTexts = backLogo.x + backLogo.width + spaceX
    local nameLabel = display.newText( {
      parent = thisLevelUp,
      text = possivePowers[thisPower].label,
      x = xTexts,
      y = y - 250*.5 + 30,
      font = "r_r.ttf",
      fontSize = 45,
    } )
    nameLabel.anchorX = 0
    nameLabel.anchorY = 0

    local lvlLabel = display.newText( {
      parent = thisLevelUp,
      text = possivePowers[thisPower].level.."lvl",
      x = backLVL.x+backLVL.width*.5,
      y = backLVL.y+backLVL.height,
      font = "r_r.ttf",
      fontSize = 45,
    } )
    -- lvlLabel.anchorX = 1
    lvlLabel.anchorY = 1

    local nextUp = possivePowers[thisPower].options[possivePowers[thisPower].level+1]
    if nextUp==nil then
      nextUp = possivePowers[thisPower].options.unlimited
    end
    local discLabel = display.newText( {
      parent = thisLevelUp,
      text = nextUp.text,
      x = xTexts,
      y = y - 250*.5 + 30 + 55,
      width = back.width-30*2,
      font = "r_r.ttf",
      fontSize = 33,
    } )
    discLabel.anchorX = 0
    discLabel.anchorY = 0

    back:addEventListener( "tap", function()
      levelUpCounter = levelUpCounter + 1
      countLevelUpLabel.text = levelUpCounter.."lvl"

      possivePowers[thisPower].level = possivePowers[thisPower].level + 1
      if nextUp.init then nextUp.init() end
      if possivePowers[thisPower].timerName then
        q.timer.change(possivePowers[thisPower].timerName, {time=nextUp.time})
      end
      display.remove(thisLevelUp)
      levelUpGroup.alpha = 0
      if count and count-1>0 then
        levelUp(count-1)
      else
        resumeGame()
      end
    end )

    if i==3 and cheater==false then
      back:addEventListener( "touch", cheatListener)
    end
  end
end

local enemyLevel = 0
local enemysLevels = {
  [0] = {"hp","dmg","speed","plusType","rate"},
  ["normal"] = {6,3,5},
  {10,10,5,true,-10},
  {10,2,5}, -- 1

  {15,0,5},
  {15,2,5}, -- 2
  
  {20,3,10},
  {20,3,10,true}, -- 3
  -- {hp, dmg, spd}
  
  {20,4,15},
  {20,4,15}, -- 4

  {10,5,10},
  {10,5,10,true}, -- 5

  {10,7,5},
  {5, 7,5, nil, -10}, -- 6
  -- {hp, dmg, spd}

  nil,
  nil, -- 7

  nil,
  {5,10,5,nil,-10}, -- 8

  nil,
  nil, -- 9
  -- {hp, dmg, spd}

  nil,
  nil, -- 10
 
  [10*2] = {5,3,5,nil,-10},
  [13*2] = {5,3,5,nil,-10},
  [16*2] = {5,3,5,nil,-10}

}
enemyLevelUp = function()
  enemyLevel = enemyLevel + 1
  local param = enemysLevels[enemyLevel]
  if param == nil then param = enemysLevels.normal end
  local hp, dmg, speed, newEnemy, spawnRate = unpack(param)
  if hp then setMulti("enemy.hp",hp*.01) end
  if dmg then setMulti("enemy.dmg",dmg*.01) end
  if speed then setMulti("enemy.speed",speed*.01) end
  if newEnemy then enemyNowTypes = enemyNowTypes + 1 end
  if spawnRate then setMulti("enemy.spawnRate",spawnRate*.01) q.timer.restart("enemySpawn", getValue("enemy.spawnRate")) end
end


local function exitGame()
  nowScene = "game"
  audio.fadeOut(50)
  timer.performWithDelay( 50, function()
    audio.stop( 1 )
  end )
  composer.gotoScene( "menu" )
  composer.removeScene( "game" )
end
local function exitLevelUp()
  local max = getValue("player.mp")
  setAmount("player.mp",math.floor(max*.2))
  mpBar.width = q.fullw * .2
  display.remove(thisLevelUp)
  levelUpGroup.alpha = 0
  resumeGame()
end
local onKeyEvent
if isDevice==false then
  moveScreen = function()
    mainGroup.x= (-playerGroup.x*(mainGroup.xScale)+q.cx)
    mainGroup.y= (-playerGroup.y*(mainGroup.yScale)+q.cy)
  end
  local nowMove = false
  local nowMoveX = 0
  local nowMoveY = 0
  local sqrt2 = math.sqrt( 2 )
  local function move()
    if nowMove==false then playerGroup:setLinearVelocity(0,0) return end
    if playerGroup.x==nil then return end
    local nx, ny
    if nowMoveX==0 then
      nx = 0      
    end
    if nowMoveY==0 then
      ny = 0      
      if nowMoveX==0 then
        nowMove = false
        playerGroup:setLinearVelocity(0,0)
        return
      end
    end

    local speed = getValue("player.speed")
    if nowMoveX~=0 and nowMoveY~=0 then
      speed = q.round(speed/sqrt2)
    end
    playerGroup:setLinearVelocity(nowMoveX*speed, nowMoveY*speed)
    timer.performWithDelay( 20, move ) 
  end

  local nowRot = false
  local function rot(num)
    if nowRot==false then 
      return 
    end
    playerGroup.rotation = playerGroup.rotation+num
    timer.performWithDelay( 10, function() rot(num) end )
  end
  onKeyEvent = function( event )
    -- print(event.phase)
    local key = event.keyName
    if event.phase == "down" then
      -- print(key)
      if key=="escape" then
        if nowScene=="died" then
          exitGame()
        elseif nowScene=="artefact" then
          closeAtr()
        elseif nowScene=="levelup" then
          exitLevelUp()
        end
      elseif key=="w" then
        nowMoveY=-1
        nowMove = true
        move()
      elseif key=="a" then
        nowMoveX=-1
        nowMove = true
        move()
      elseif key=="s" then
        nowMoveY=1
        nowMove = true
        move()
      elseif key=="d" then
        nowMoveX=1
        nowMove = true
        move()
      elseif key=="q" then
        nowRot=true
        rot(-5)
      elseif key=="e" then
        nowRot=true
        rot(5)
      elseif key=="z" then
        mainGroup.xScale = mainGroup.xScale*.5
        mainGroup.yScale = mainGroup.yScale*.5
      elseif key=="x" then
        mainGroup.xScale = mainGroup.xScale*2
        mainGroup.yScale = mainGroup.yScale*2
      elseif key=="space" then
        -- print(#enemysTable)
        composer.removeScene( "game" )
        composer.gotoScene( "game" )
        return
      elseif key=="1" then
        createOrb(playerGroup.x,playerGroup.y-100,1)
      elseif key=="2" then
        createOrb(playerGroup.x,playerGroup.y-100,2)
      elseif key=="3" then
        createOrb(playerGroup.x,playerGroup.y-100,3)
      elseif key=="4" then
        createOrb(playerGroup.x,playerGroup.y-100,4)
      elseif key=="5" then
        createOrb(playerGroup.x,playerGroup.y-100,5)
      elseif key=="6" then
        createChest(playerGroup.x,playerGroup.y-100)
      elseif key=="t" then
        addOrbital()
      elseif key=="leftShift" then
        setMulti("player.mp",.1)
        levelUp()
      elseif key=="leftControl" then
        inPlayTime = inPlayTime + 60
        enemyLevelUp()
        enemyLevelUp()
      -- elseif key=="rightControl" then
      --   inPlayTime = inPlayTime - 60
      end
    elseif event.phase == "up" then
      -- print("up key",key)
      if key=="w" and nowMoveY==-1 
      then
        nowMoveY=0
      elseif key=="s" and nowMoveY==1  
      then
        nowMoveY=0
      elseif key=="a" and nowMoveX==-1
      then
        nowMoveX=0
      elseif key=="d" and nowMoveX==1
      then
        nowMoveX=0
      elseif key=="q"
      or key=="e" then
        nowRot=false
      end
    end

    return false
  end
else
  onKeyEvent = function( event )
    -- Print which key was pressed down/up
    local message = "Key '" .. event.keyName .. "' was pressed " .. event.phase
    -- If the "back" key was pressed on Android, prevent it from backing out of the app
    if ( event.keyName == "back" and nowScene~="game") then
      
      if ( system.getInfo("platform") == "android" ) then
        
        if nowScene=="died" then
          exitGame()
        elseif nowScene=="artefact" then
          closeAtr()
        elseif nowScene=="levelup" then
          exitLevelUp()
        end
        
        return true
      end
    
    end

    -- IMPORTANT! Return false to indicate that this app is NOT overriding the received key
    -- This lets the operating system execute its default handling of the key
  end
end

local function getXp(plus)
  local mp = getAmount("player.mp")
  local mpMax = getValue("player.mp")
  local toMP = mp + math.floor(plus * getValue("mp.gain"))
  
  local mpProcent = toMP / mpMax

  print("XP",toMP,"/",mpMax)
  if toMP > mpMax then
    local ost = toMP-mpMax
    setAmount("player.mp",ost)
    setMulti("player.mp",.3)
    -- audio.play(sounds.levelUp )
    levelUp()
    mpBar.width = q.fullw * (ost/getValue("player.mp"))
    return
  end
  mpBar.width = mpProcent * (q.fullw-30)
  setAmount("player.mp",toMP)
end

local function onCollision(event)
  local obj1 = event.object1
  local obj2 = event.object2
  if ( event.phase == "began" ) then 

    if ( ( (obj1.myName == "enemy" ) and obj2.myName == "player" )
    or ( (obj2.myName == "enemy" ) and obj1.myName == "player" ) ) then
      local enemy, player, element
      if obj1.myName == "enemy" then
        enemy = obj1
        player = obj2
        element = 2
      else
        player = obj1
        element = 1
        enemy = obj2
      end
      if event["element"..element]==1 then
        getDamage(enemy)
        enemy.inCollision=true
      elseif event["element"..element]==3 then
        -- print("ZONE DMG")
        transition.cancel( "toDarkZone" )
        player.zone.alpha = .5
        transition.to(player.zone, {alpha = .3, time=300,tag="toDarkZone"})
        -- print(enemy.hp)
        enemy.hp = enemy.hp - player.zone.damage * getValue("player.dmg")
        if enemy.hp<=0 then
          audio.play(sounds.enemydie )
          enemy:remove(enemyDieSpawnOrb)      
        end
      end

    elseif ( ( (obj1.myName == "enemy" ) and obj2.myName == "orbital" )
    or ( (obj2.myName == "enemy" ) and obj1.myName == "orbital" ) ) then
      local enemy, orbital
      if obj1.myName == "enemy" then
        enemy = obj1
        orbital = obj2
      else
        orbital = obj1
        enemy = obj2
      end

      orbital.xScale = .6
      orbital.yScale = .6
      transition.to( orbital, { xScale = 1, yScale = 1, time = 300, tag = "orbital"} )
      -- local a = display.newRect( mainGroup, orbital.x, orbital.y, 10, 10 )
      -- a.fill = {0,0,1}
      enemy.hp = enemy.hp - getValue("magicBalls.dmg") * getValue("player.dmg")
      if enemy.hp<=0 then
        audio.play(sounds.enemydie )
        enemy:remove(enemyDieSpawnOrb)      
      end

    elseif ( ( (obj1.myName == "orb" ) and obj2.myName == "player" )
    or ( (obj2.myName == "orb" ) and obj1.myName == "player" ) ) then
      local orb, player, element
      if obj1.myName == "orb" then
        player = obj2
        element = 2
        orb = obj1
      else
        player = obj1
        element = 1

        orb = obj2
      end
      if event["element"..element]==2 then
        audio.play(sounds.pickup )
        orb:remove()
        getXp(orb.amount)
      end

    elseif ( ( (obj1.myName == "healOrb" ) and obj2.myName == "player" )
    or ( (obj2.myName == "healOrb" ) and obj1.myName == "player" ) ) then
      local orb, player, element
      if obj1.myName == "healOrb" then
        player = obj2
        element = 2
        orb = obj1
      else
        player = obj1
        element = 1

        orb = obj2
      end
      if event["element"..element]==2 then
        audio.play(sounds.pickup )
        setHp(getAmount("player.hp")+orb.amount)
        orb:remove()
      end

    elseif ( ( (obj1.myName == "immortalOrb" ) and obj2.myName == "player" )
    or ( (obj2.myName == "immortalOrb" ) and obj1.myName == "player" ) ) then
      local orb, player, element
      if obj1.myName == "immortalOrb" then
        player = obj2
        element = 2
        orb = obj1
      else
        player = obj1
        element = 1

        orb = obj2
      end
      if event["element"..element]==2 then
        audio.play(sounds.pickup )
        setImmortal(orb.amount)
        orb:remove()
      end

    elseif ( ( (obj1.myName == "chest" ) and obj2.myName == "player" )
    or ( (obj2.myName == "chest" ) and obj1.myName == "player" ) ) then
      local chest, player, element
      if obj1.myName == "chest" then
        player = obj2
        element = 2
        chest = obj1
      else
        player = obj1
        element = 1

        chest = obj2
      end
      if event["element"..element]==2 and nowScene=="game" then
        local canFound = {}
        for art=1, #artefacts do
          local inInventory = false
          for inv=1, #inventory do
            if artefacts[art].name == inventory[inv] then
              print(art.."# alredy iqueped",inventory[inv])
              inInventory = true
              break
            end
          end
          if not inInventory then
            print(art.."# can found",artefacts[art].name)
            canFound[#canFound+1] = art
          end
        end
        pickAtr(canFound[math.random( #canFound )])
        audio.play(sounds.pickup )
        chest:remove()
      end

    elseif ( ( obj1.myName == "enemy" and obj2.myName == "bullet" )
    or ( obj2.myName == "enemy" and obj1.myName == "bullet" ) ) then
      local enemy, bullet
      if obj1.myName == "enemy" then
        enemy = obj1
        bullet = obj2
      else
        bullet = obj1
        enemy = obj2
      end


      enemy.hp = enemy.hp - bullet.damage * getValue("player.dmg")
      -- print(enemy.hp)
      if enemy.hp<=0 then
        audio.play(sounds.enemydie )
        enemy:remove(enemyDieSpawnOrb)      
      end
      display.remove(bullet)

    elseif ( ( obj1.myName == "enemy" and obj2.myName == "meteor" )
    or ( obj2.myName == "enemy" and obj1.myName == "meteor" ) ) then
      local enemy, meteor
      if obj1.myName == "enemy" then
        enemy = obj1
        meteor = obj2
      else
        meteor = obj1
        enemy = obj2
      end


      enemy.hp = enemy.hp - meteor.damage * getValue("player.dmg")
      -- print(enemy.hp)
      if enemy.hp<=0 then
        audio.play(sounds.enemydie )
        enemy:remove(enemyDieSpawnOrb)      
      end
    end
  
    


  elseif event.phase=="ended" then
    if ( ( (obj1.myName == "enemy" ) and obj2.myName == "player" )
    or ( (obj2.myName == "enemy" ) and obj1.myName == "player" ) ) then
      local enemy, player, element
      if obj1.myName == "enemy" then
        player = obj2
        element = 2
        
        enemy = obj1
      else
        player = obj1
        element = 1

        enemy = obj2
      end
      if event["element"..element]==1 then
        local enemy = (obj1.myName == "enemy") and obj1 or obj2
        enemy.inCollision=false 
      end
    end
  end
  return true
end



local function gameTimer()
  inPlayTime = inPlayTime + 1
  local sec = tostring(inPlayTime%60)
  if #sec==1 then sec = "0"..sec end
  timerLabel.text = math.floor(inPlayTime/60)..":"..sec

  if inPlayTime%30==0 then
    enemyLevelUp()
    
  end
end

-- local movementTimer, movePlayer
-- local function setupJS1()
--   movementTimer = timer.performWithDelay(100, movePlayer, 0)
-- end

local function movePlayer()
  local coords = js1:getXYValues()
  local speed = getValue("player.speed")*.01
  playerGroup:setLinearVelocity(coords.x*speed, coords.y*speed)
end

function scene:create( event )
  local sceneGroup = self.view

  backGroup = display.newGroup()
  sceneGroup:insert(backGroup)

  mainGroup = display.newGroup()
  sceneGroup:insert(mainGroup)

  lootGroup = display.newGroup()
  mainGroup:insert(lootGroup)

  enemyGroup = display.newGroup()
  mainGroup:insert(enemyGroup)

  bulletGroup = display.newGroup()
  mainGroup:insert(bulletGroup)

  moveUiGroup = display.newGroup()
  mainGroup:insert(moveUiGroup)

  uiGroup = display.newGroup()
  sceneGroup:insert(uiGroup)

  gameUiGroup = display.newGroup()
  uiGroup:insert(gameUiGroup)


  set = composer.getVariable( "settings" )
  -- setupController(uiGroup)

  -- local joyZone = display.newRect(uiGroup, q.cx, q.cy, 300,300)
  -- setupController(joyZone)


  levelUpGroup = display.newGroup()
  uiGroup:insert(levelUpGroup)

  pickUpGroup = display.newGroup()
  uiGroup:insert(levelUpGroup)

  diedGroup = display.newGroup()
  uiGroup:insert(diedGroup)

   

  local backGround = display.newRect(backGroup, q.cx,q.cy, q.fullw, q.fullh)
  
  if set.style==0 then
    backGround.fill = q.CL"e0d3a9"
  else
    backGround.fill = {.05}
  end

  local backhpBar = display.newRect(gameUiGroup, 0, q.cy, 30, q.fullh)
  backhpBar.anchorX=0
  backhpBar.fill = {.25}


  local backMpBar = display.newRect(gameUiGroup, 0, 0, q.fullw, 30)
  backMpBar.anchorX=0
  backMpBar.anchorY=0
  backMpBar.fill = {.25}
  hpBar = display.newRect(gameUiGroup, 0, q.fullh, 30, q.fullh-30)
  hpBar.anchorX=0
  hpBar.anchorY=1
  hpBar.fill = colors.red

  hpImmortalBar = display.newRect(gameUiGroup, 0, q.fullh, 30, 0)
  hpImmortalBar.anchorX=0
  hpImmortalBar.anchorY=1
  hpImmortalBar.alpha = .4

  mpBar = display.newRect(gameUiGroup, 0, 0, 0, 30)
  mpBar.anchorX=0
  mpBar.anchorY=0
  mpBar.fill = {.4,.5,.8}--colors.red

  timerLabel = display.newText( {
    parent = gameUiGroup,
    text = "0:00",
    x = q.fullw-20,
    y = 50,
    font = "r_r.ttf",
    fontSize = 65,
  } )
  timerLabel.anchorX = 1
  timerLabel.anchorY = 0

  countLevelUpLabel = display.newText( {
    parent = gameUiGroup,
    text = "0 lvl",
    x = q.fullw-20,
    y = 120,
    font = "r_r.ttf",
    fontSize = 55,
  } )
  countLevelUpLabel.anchorX = 1
  countLevelUpLabel.anchorY = 0


  if set.style==0 then
    timerLabel:setTextColor( 0 )
    countLevelUpLabel:setTextColor( 0 )
  -- else
    -- timerLabel:setTextColor( 1 )
  end

  playerGroup = q.createPlayer(moveUiGroup, q.cx, q.cy)
  playerGroup.myBody[2].alpha = 0
  playerGroup.myBody[4].xScale = 2
  playerGroup.myBody[4].yScale = 2
  
  playerGroup.orbital = display.newGroup()
  mainGroup:insert( playerGroup.orbital )
  playerGroup.orbital.list = {}


  local radius = getValue("player.pickZone")
  playerGroup.bodyElements = { {box={halfWidth=42*.55, halfHeight=(42+30)*.55}}, { radius=radius, isSensor=true } }

  physics.addBody( playerGroup, { box={halfWidth=42*.55, halfHeight=(42+30)*.55} }, { radius=radius, isSensor=true } )
  playerGroup.isFixedRotation = true
  enemysTarget = playerGroup
  -- =======================

  levelUpGroup:toFront()
  levelUpGroup.alpha = 0

  local backGround = display.newRect(levelUpGroup, q.cx,q.cy, q.fullw, q.fullh)
  backGround.fill = {0, 0, 0, .5}

  local levelupLabel = display.newText( {
    parent = levelUpGroup,
    text = "Вы стали сильнее..",
    x = q.cx,
    y = 65,
    font = "r_r.ttf",
    fontSize = 65,
  } )
  levelupLabel.anchorY = 0

  local skipLevelup = display.newRect( levelUpGroup, q.cx, q.fullh-140-30, 450, 120 )
  skipLevelup.fill = { 0, 0, 0, .4}

  local skipLevelupLabel = display.newText( {
    parent = levelUpGroup,
    text = "Вернуть 20% xp",
    x = skipLevelup.x,
    y = skipLevelup.y,
    font = "r_r.ttf",
    fontSize = 50,
  } )
  skipLevelupLabel:addEventListener( "tap", exitLevelUp )
  
  -- =======================

  pickUpGroup:toFront()
  pickUpGroup.alpha = 0

  local backGround = display.newRect(pickUpGroup, q.cx,q.cy, q.fullw, q.fullh)
  backGround.fill = {0, 0, 0, .7}

  local pickupLabel = display.newText( {
    parent = pickUpGroup,
    text = "Найдет артефакт",
    x = q.cx,
    y = 100,
    font = "r_r.ttf",
    fontSize = 65,
  } )
  
  -- =======================

  diedGroup:toFront()
  diedGroup.alpha = 0

  local backGround = display.newRect(diedGroup, q.cx,q.cy, q.fullw, q.fullh)
  backGround.fill = {0, 0, 0, .5}

  local schetLabel = display.newText( {
    parent = diedGroup,
    text = "Твой счёт\n",
    x = q.cx,
    y = 290,
    font = "r_r.ttf",
    fontSize = 95,
  } )
  schetLabel.anchorY = 0
  
  finscoreLabel = display.newText( {
    parent = diedGroup,
    text = "0:00",
    x = q.cx+10,
    y = 250 + schetLabel.height*.5 + 100,
    font = "r_r.ttf",
    fontSize = 150,
  } )
  finscoreLabel.anchorY = 0

  local retryBack = display.newRect( diedGroup, q.cx, q.cy+200, 450, 120 )
  retryBack.fill = { 0, 0, 0, .4}

  local retryLabel = display.newText( {
    parent = diedGroup,
    text = "Повторить",
    x = retryBack.x,
    y = retryBack.y,
    font = "r_r.ttf",
    fontSize = 65,
  } )
  retryBack:addEventListener( "tap", function()
    composer.removeScene( "game" )
    composer.gotoScene( "game" )
  end )

  local exitBack = display.newRect( diedGroup, q.cx, q.cy+200+200, 450, 120 )
  exitBack.fill = { 0, 0, 0, .4}

  local exitLabel = display.newText( {
    parent = diedGroup,
    text = "Выход",
    x = exitBack.x,
    y = exitBack.y,
    font = "r_r.ttf",
    fontSize = 65,
  } )
  exitBack:addEventListener( "tap", exitGame )

  -- -----------------
  -- =================
  -- -----------------

  q.timer.add("simpleMagic", 800, simpleAttack, 0)
  q.timer.group.add("gameTimers","simpleMagic")



  q.timer.add("gameTimer", 1000, gameTimer, 0)
  q.timer.group.add("gameTimers","gameTimer")
  
  q.timer.add("enemySpawn", getValue("enemy.spawnRate"), spawnEnemys, 0)
  q.timer.group.add("gameTimers","enemySpawn")

  q.timer.add("regen", 1000, regenHp, 0)
  q.timer.group.add("gameTimers","regen")

  q.timer.add("orbsSpawn", 500, spawnOrbs, 0)
  q.timer.group.add("gameTimers","orbsSpawn")

  q.timer.add("mapCleaner", 500, mapCleaner, 0)
  q.timer.group.add("gameTimers","mapCleaner")

  q.timer.add("playerMove", 100, movePlayer, 0)
  q.timer.group.add("gameTimers","playerMove")

end


function scene:show( event )

  local sceneGroup = self.view
  local phase = event.phase

  if ( phase == "will" ) then
    physics.start() 

    if onKeyEvent then Runtime:addEventListener( "key", onKeyEvent ) end
    Runtime:addEventListener( "lateUpdate", moveScreen )
    Runtime:addEventListener( "collision", onCollision )
    
    q.timer.group.on("gameTimers")

    set = composer.getVariable( "settings" )
    audio.reserveChannels( 1 ) 
    local volume = set.volume
    audio.setVolume( volume.all*.01 )
    audio.setVolume( volume.music*.01, { channel=1 } )
    for i=2, 32 do
      audio.setVolume( volume.sfx*.01, { channel=i } )
    end

    if set.volume.music~=0 then
      audio.play(sounds.back,{
        channel = 1,
        loops = -1,
        fadein = 1500
      } )
    end
    levelUp(3)
  elseif ( phase == "did" ) then


    -- createPashalkaEnemy(q.cx, q.cy-200)
    -- drawCheat()
    -- hidePower()
  end
end


function scene:hide( event )

  local sceneGroup = self.view
  local phase = event.phase

  if ( phase == "will" ) then
    

  elseif ( phase == "did" ) then

  end
end


function scene:destroy( event )

  local sceneGroup = self.view
  Runtime:removeEventListener( "lateUpdate", moveScreen )
  Runtime:removeEventListener( "collision", onCollision )
  timer.cancelAll( )
  q.timer.group.remove("gameTimers")
  if onKeyEvent then Runtime:removeEventListener( "key", onKeyEvent ) end
  -- timer.performWithDelay( 1,  physics.stop )
end


scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene
